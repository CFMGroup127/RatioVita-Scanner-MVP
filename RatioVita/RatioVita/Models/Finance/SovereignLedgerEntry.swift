import Foundation
import SwiftData

enum SovereignLedgerEntryKind: String, Codable, CaseIterable, Sendable {
    case expense = "Expense"
    case mileage = "Mileage"
    case fuel = "Fuel"
}

/// Normalized bookkeeping row emitted by `OperationalBookkeeper` — PUID / venture stamped.
@Model
final class SovereignLedgerEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var entryKindRaw: String
    var vendorName: String
    var netAmount: Decimal?
    var taxAmount: Decimal?
    var grossAmount: Decimal
    var currencyCode: String
    var transactionTimestamp: Date?
    var lineItemSummary: String?
    var productionPUID: String?
    var ventureEntityID: UUID?
    var taxCategory: String?
    var glCode: String?
    var mileageKilometers: Double?
    var odometerReading: Double?
    var routeDescription: String?
    var deductionRatePerUnit: Decimal?
    var estimatedDeductionAmount: Decimal?
    /// Comma-separated anomaly tokens (e.g. `tax_rate_mismatch`, `unassigned_scope`).
    var anomalyFlagsRaw: String?
    var sourceReceiptID: UUID?
    var sourceMasterInvoiceID: UUID?
    var sourceAtomicLineItemID: UUID?
    var bookkeepingPassID: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        entryKind: SovereignLedgerEntryKind,
        vendorName: String,
        netAmount: Decimal? = nil,
        taxAmount: Decimal? = nil,
        grossAmount: Decimal,
        currencyCode: String,
        transactionTimestamp: Date? = nil,
        lineItemSummary: String? = nil,
        productionPUID: String? = nil,
        ventureEntityID: UUID? = nil,
        taxCategory: String? = nil,
        glCode: String? = nil,
        mileageKilometers: Double? = nil,
        odometerReading: Double? = nil,
        routeDescription: String? = nil,
        deductionRatePerUnit: Decimal? = nil,
        estimatedDeductionAmount: Decimal? = nil,
        anomalyFlags: [String] = [],
        sourceReceiptID: UUID? = nil,
        sourceMasterInvoiceID: UUID? = nil,
        sourceAtomicLineItemID: UUID? = nil,
        bookkeepingPassID: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        entryKindRaw = entryKind.rawValue
        self.vendorName = vendorName
        self.netAmount = netAmount
        self.taxAmount = taxAmount
        self.grossAmount = grossAmount
        self.currencyCode = currencyCode
        self.transactionTimestamp = transactionTimestamp
        self.lineItemSummary = lineItemSummary
        self.productionPUID = productionPUID
        self.ventureEntityID = ventureEntityID
        self.taxCategory = taxCategory
        self.glCode = glCode
        self.mileageKilometers = mileageKilometers
        self.odometerReading = odometerReading
        self.routeDescription = routeDescription
        self.deductionRatePerUnit = deductionRatePerUnit
        self.estimatedDeductionAmount = estimatedDeductionAmount
        anomalyFlagsRaw = anomalyFlags.isEmpty ? nil : anomalyFlags.joined(separator: ",")
        self.sourceReceiptID = sourceReceiptID
        self.sourceMasterInvoiceID = sourceMasterInvoiceID
        self.sourceAtomicLineItemID = sourceAtomicLineItemID
        self.bookkeepingPassID = bookkeepingPassID
    }

    var entryKind: SovereignLedgerEntryKind {
        SovereignLedgerEntryKind(rawValue: entryKindRaw) ?? .expense
    }

    var anomalyFlags: [String] {
        guard let raw = anomalyFlagsRaw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
