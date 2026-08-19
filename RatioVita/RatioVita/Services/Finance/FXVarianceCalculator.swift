import Foundation
import SwiftData

struct FXVarianceSummary: Sendable {
    let foreignAmount: Decimal
    let foreignCurrency: String
    let actualBankDebit: Decimal
    let homeCurrency: String
    let explicitWireFee: Decimal

    var netBankDebit: Decimal {
        actualBankDebit - explicitWireFee
    }

    /// Home currency per one unit of foreign currency (e.g. 1.3855 CAD/USD).
    var impliedExchangeRate: Decimal {
        guard foreignAmount > 0 else { return .zero }
        return netBankDebit / foreignAmount
    }

    /// Spread vs an optional book / budget rate, or par when both legs share a currency.
    func calculateNetFXSpread(baselineRate: Decimal?) -> Decimal {
        guard foreignAmount > 0 else { return .zero }

        if let baseline = baselineRate, baseline > 0 {
            let expectedHomeAmount = foreignAmount * baseline
            return netBankDebit - expectedHomeAmount
        }

        if foreignCurrency.uppercased() == homeCurrency.uppercased() {
            return netBankDebit - foreignAmount
        }

        return .zero
    }
}

enum FXVarianceCalculator {
    static func summary(
        foreignAmount: Decimal,
        foreignCurrency: String,
        actualBankDebit: Decimal,
        homeCurrency: String,
        explicitWireFee: Decimal = .zero
    ) -> FXVarianceSummary? {
        guard foreignAmount > 0, actualBankDebit > 0 else { return nil }
        return FXVarianceSummary(
            foreignAmount: abs(foreignAmount),
            foreignCurrency: foreignCurrency.uppercased(),
            actualBankDebit: abs(actualBankDebit),
            homeCurrency: homeCurrency.uppercased(),
            explicitWireFee: max(.zero, explicitWireFee)
        )
    }

    static func summary(from receipt: Receipt, bookExchangeRate: Decimal? = nil) -> FXVarianceSummary? {
        guard receipt.usesSettlementOverride,
              let settlementAmount = receipt.settlementAmount,
              settlementAmount > 0 else { return nil }

        let homeCurrency = receipt.settlementCurrencyCode ?? AppCurrencySettings.defaultCurrencyCode
        let wireFee = receipt.settlementWireFee ?? .zero
        let baseline = bookExchangeRate ?? receipt.settlementBookExchangeRate

        guard let base = summary(
            foreignAmount: abs(receipt.total),
            foreignCurrency: receipt.currencyCode,
            actualBankDebit: settlementAmount,
            homeCurrency: homeCurrency,
            explicitWireFee: wireFee
        ) else { return nil }

        _ = base.calculateNetFXSpread(baselineRate: baseline)
        return base
    }

    static func impliedRateLabel(_ rate: Decimal, homeCurrency: String, foreignCurrency: String) -> String {
        guard rate > .zero else { return "—" }
        let formatted = rate.formatted(.number.precision(.fractionLength(4)))
        return "\(formatted) \(homeCurrency)/\(foreignCurrency)"
    }
}

enum FXVarianceLedgerManager {
    @MainActor
    static func generateVarianceDescription(
        foreignCurrency: String,
        homeCurrency: String,
        varianceAmount: Decimal,
        wireFee: Decimal,
        impliedRate: Decimal
    ) -> String {
        var components: [String] = []

        if impliedRate > 0 {
            components.append(
                "Implied: \(FXVarianceCalculator.impliedRateLabel(impliedRate, homeCurrency: homeCurrency, foreignCurrency: foreignCurrency))"
            )
        }

        if wireFee > 0 {
            components.append(
                "Wire fee: \(CurrencyFormatter.shared.format(wireFee, currencyCode: homeCurrency))"
            )
        }

        if varianceAmount != .zero {
            let typeLabel = varianceAmount > 0 ? "FX loss / spread" : "FX gain"
            components.append(
                "\(typeLabel): \(CurrencyFormatter.shared.format(abs(varianceAmount), currencyCode: homeCurrency))"
            )
        }

        return components.isEmpty ? "No FX variance" : components.joined(separator: " · ")
    }

    @MainActor
    static func applyComputedFields(
        to receipt: Receipt,
        summary: FXVarianceSummary,
        fxSpread: Decimal
    ) {
        receipt.settlementImpliedExchangeRate = summary.impliedExchangeRate
        receipt.settlementFxSpreadAmount = fxSpread
    }

    @MainActor
    static func syncReceiptLedgerAdjustments(
        receipt: Receipt,
        summary: FXVarianceSummary,
        fxSpread: Decimal,
        modelContext: ModelContext
    ) {
        let description = generateVarianceDescription(
            foreignCurrency: summary.foreignCurrency,
            homeCurrency: summary.homeCurrency,
            varianceAmount: fxSpread,
            wireFee: summary.explicitWireFee,
            impliedRate: summary.impliedExchangeRate
        )

        guard let rows = try? modelContext.fetch(FetchDescriptor<SovereignLedgerEntry>()) else { return }

        if let primary = rows.first(where: {
            $0.sourceReceiptID == receipt.id && !$0.anomalyFlags.contains("fx_variance")
        }) {
            let fxNote = "FX: \(description)"
            if primary.lineItemSummary?.contains("FX:") != true {
                if let existing = primary.lineItemSummary, !existing.isEmpty {
                    primary.lineItemSummary = "\(existing) · \(fxNote)"
                } else {
                    primary.lineItemSummary = fxNote
                }
            }
        }

        let fxRows = rows.filter {
            $0.sourceReceiptID == receipt.id && $0.anomalyFlags.contains("fx_variance")
        }

        let adjustmentTotal = summary.explicitWireFee + fxSpread
        guard adjustmentTotal != .zero else {
            for row in fxRows {
                modelContext.delete(row)
            }
            return
        }

        let grossAmount = abs(adjustmentTotal)
        let vendorLabel = receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "FX adjustment"
            : "\(receipt.merchant) · FX adjustment"

        if let existing = fxRows.first {
            existing.vendorName = vendorLabel
            existing.grossAmount = grossAmount
            existing.currencyCode = summary.homeCurrency
            existing.lineItemSummary = description
            existing.transactionTimestamp = receipt.transactionDate ?? receipt.createdAt
            existing.bookkeepingPassID = "fx_variance"
            for duplicate in fxRows.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            let row = SovereignLedgerEntry(
                entryKind: .expense,
                vendorName: vendorLabel,
                grossAmount: grossAmount,
                currencyCode: summary.homeCurrency,
                transactionTimestamp: receipt.transactionDate ?? receipt.createdAt,
                lineItemSummary: description,
                anomalyFlags: ["fx_variance"],
                sourceReceiptID: receipt.id,
                bookkeepingPassID: "fx_variance"
            )
            modelContext.insert(row)
        }
    }

    @MainActor
    static func clearReceiptLedgerAdjustments(receipt: Receipt, modelContext: ModelContext) {
        guard let rows = try? modelContext.fetch(FetchDescriptor<SovereignLedgerEntry>()) else { return }
        for row in rows where row.sourceReceiptID == receipt.id && row.anomalyFlags.contains("fx_variance") {
            modelContext.delete(row)
        }
        receipt.settlementImpliedExchangeRate = nil
        receipt.settlementFxSpreadAmount = nil
    }
}
