import Foundation
import SwiftData

/// Intermediate manifest layer: one uploaded invoice artifact shared by many ledger vectors.
@Model
final class MasterInvoiceManifest {
    @Attribute(.unique) var id: UUID
    var vendorName: String
    var transactionDate: Date
    var totalAmount: Decimal
    var currencyCode: String
    /// Single Firebase Storage (or local vault) path — no duplicated media per venture.
    var storagePath: String
    /// True when every child `AtomicLedgerLineItem` has an assigned ledger target.
    var isReconciled: Bool
    var createdAt: Date
    var updatedAt: Date

    /// Optional link to the on-device `Receipt` row (images + OCR source).
    var sourceReceipt: Receipt?

    @Relationship(deleteRule: .cascade, inverse: \AtomicLedgerLineItem.manifest)
    var atomicLineItems: [AtomicLedgerLineItem]

    init(
        id: UUID = UUID(),
        vendorName: String,
        transactionDate: Date,
        totalAmount: Decimal,
        currencyCode: String = ReceiptCurrency.defaultForLocale.code,
        storagePath: String,
        isReconciled: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sourceReceipt: Receipt? = nil,
        atomicLineItems: [AtomicLedgerLineItem] = []
    ) {
        self.id = id
        self.vendorName = vendorName
        self.transactionDate = transactionDate
        self.totalAmount = totalAmount
        self.currencyCode = currencyCode
        self.storagePath = storagePath
        self.isReconciled = isReconciled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceReceipt = sourceReceipt
        self.atomicLineItems = atomicLineItems
    }

    /// Sum of assigned line amounts (for reconciliation checks).
    var assignedLineTotal: Decimal {
        atomicLineItems.reduce(Decimal.zero) { partial, item in
            partial + (item.assignedLedgerTarget != nil ? item.totalLineAmount : .zero)
        }
    }

    var allLinesAssigned: Bool {
        !atomicLineItems.isEmpty && atomicLineItems.allSatisfy { $0.assignedLedgerTarget != nil }
    }

    func refreshReconciledFlag() {
        isReconciled = allLinesAssigned
        updatedAt = .now
    }
}
