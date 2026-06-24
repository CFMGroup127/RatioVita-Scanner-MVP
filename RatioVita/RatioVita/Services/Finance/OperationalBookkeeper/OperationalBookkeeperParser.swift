import Foundation
import SwiftData

/// Deterministic expense metadata extraction from receipt rows and OCR corpus.
enum OperationalBookkeeperParser {
    struct ParsedExpense: Sendable {
        let vendorName: String
        let netAmount: Decimal?
        let taxAmount: Decimal?
        let grossAmount: Decimal
        let currencyCode: String
        let transactionTimestamp: Date?
        let lineItemDescriptions: [String]
        let taxCategory: String?
        let glCode: String?
        let productionPUID: String?
        let ventureEntityID: UUID?
        let anomalyFlags: [String]
    }

    static func parse(receipt: Receipt, scope: BookkeepingScope) -> ParsedExpense {
        let corpus = receiptTextCorpus(receipt)
        let vendor = normalizedVendor(receipt.merchant)
        let currency = receipt.currencyCode.isEmpty ? "CAD" : receipt.currencyCode

        let net = receipt.subtotalAmount ?? inferredNet(receipt: receipt)
        let tax = receipt.taxAmount
        let gross = receipt.total

        let lineDescriptions = receipt.lineItems
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(\.lineDescription)
            .filter { !$0.isEmpty }

        var taxCategory = receipt.taxCategory
        if taxCategory == nil {
            taxCategory = ReceiptFinanceAgentsHeuristics.suggestTaxCategory(fromCorpus: corpus)
        }

        var glCode: String?
        for line in receipt.lineItems where line.glCode != nil {
            glCode = line.glCode
            break
        }
        if glCode == nil {
            glCode = ReceiptFinanceAgentsHeuristics.suggestGLCode(fromCorpus: corpus)
        }

        var flags = detectAnomalies(
            receipt: receipt,
            scope: scope,
            net: net,
            tax: tax,
            gross: gross,
            currency: currency
        )

        let puid = scope.productionPUID ?? receipt.productionProject?.sovereignPUID
        let ventureID = scope.ventureEntityID ?? receipt.productionProject?.businessEntity?.id

        if scope.requiresPUID, puid == nil {
            flags.append("unassigned_puid")
        }
        if scope.requiresVentureEntity, ventureID == nil {
            flags.append("unassigned_venture_entity")
        }

        return ParsedExpense(
            vendorName: vendor,
            netAmount: net,
            taxAmount: tax,
            grossAmount: gross,
            currencyCode: currency,
            transactionTimestamp: receipt.transactionDate ?? receipt.createdAt,
            lineItemDescriptions: lineDescriptions,
            taxCategory: taxCategory,
            glCode: glCode,
            productionPUID: puid,
            ventureEntityID: ventureID,
            anomalyFlags: flags
        )
    }

    private static func normalizedVendor(_ merchant: String) -> String {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown vendor" : trimmed
    }

    private static func inferredNet(receipt: Receipt) -> Decimal? {
        guard let tax = receipt.taxAmount, receipt.total > tax else { return nil }
        return receipt.total - tax
    }

    private static func receiptTextCorpus(_ receipt: Receipt) -> String {
        var parts = [
            receipt.merchant,
            receipt.notes ?? "",
            receipt.annotations ?? "",
            receipt.department ?? "",
        ]
        for li in receipt.lineItems {
            parts.append(li.lineDescription)
        }
        return parts.joined(separator: " ")
    }

    private static func detectAnomalies(
        receipt: Receipt,
        scope: BookkeepingScope,
        net: Decimal?,
        tax: Decimal?,
        gross: Decimal,
        currency: String
    ) -> [String] {
        var flags: [String] = []

        if let net, let tax, net + tax != gross {
            flags.append("total_mismatch")
        }

        if let net, let tax, net > .zero {
            let impliedRate = (tax as NSDecimalNumber).doubleValue / (net as NSDecimalNumber).doubleValue
            let isCanadian = currency.uppercased() == "CAD"
            let expectedBand = isCanadian ? 0.05 ... 0.15 : 0.0 ... 0.12
            if !expectedBand.contains(impliedRate) {
                flags.append("tax_rate_mismatch")
            }
        }

        if receipt.productionProject == nil, scope.requiresPUID {
            flags.append("unassigned_project_code")
        }

        return flags
    }
}

struct BookkeepingScope: Sendable {
    let productionPUID: String?
    let ventureEntityID: UUID?
    let requiresPUID: Bool
    let requiresVentureEntity: Bool

    static func fromSovereignContext(_ context: SovereignContextManager, modelContext: ModelContext) -> BookkeepingScope {
        switch context.activeHub {
        case .production:
            let puid: String? = {
                guard let id = context.activeProductionID else { return nil }
                let projects = (try? modelContext.fetch(FetchDescriptor<ProductionProject>())) ?? []
                return projects.first(where: { $0.id == id })?.sovereignPUID
            }()
            return BookkeepingScope(
                productionPUID: puid,
                ventureEntityID: nil,
                requiresPUID: true,
                requiresVentureEntity: false
            )
        case .ventures:
            return BookkeepingScope(
                productionPUID: nil,
                ventureEntityID: context.activeVentureEntityID,
                requiresPUID: false,
                requiresVentureEntity: true
            )
        case .personal:
            return BookkeepingScope(
                productionPUID: nil,
                ventureEntityID: nil,
                requiresPUID: false,
                requiresVentureEntity: false
            )
        }
    }
}
