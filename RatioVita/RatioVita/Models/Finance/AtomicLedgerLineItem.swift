import Foundation
import SwiftData

/// One parsed invoice row — independently routable to a venture ledger without copying media.
@Model
final class AtomicLedgerLineItem {
    @Attribute(.unique) var id: UUID
    /// Denormalized for ledger queries without joining the manifest graph.
    var masterInvoiceID: UUID
    var sortIndex: Int
    var itemDescription: String
    var quantity: Int
    var unitPrice: Decimal
    var totalLineAmount: Decimal

    var agentSuggestedCategoryRaw: String
    /// JSON-encoded `LedgerTargetAssignment` when user confirms routing.
    var assignedLedgerTargetJSON: String?

    /// Optional OCR source line on the parent receipt.
    var sourceReceiptLineItemID: UUID?
    /// Normalized 0…1 rect on the master image for highlight-on-hover UX (`x,y,w,h` CSV).
    var receiptHighlightRectRaw: String?

    var manifest: MasterInvoiceManifest?

    init(
        id: UUID = UUID(),
        masterInvoiceID: UUID,
        sortIndex: Int = 0,
        itemDescription: String,
        quantity: Int = 1,
        unitPrice: Decimal,
        totalLineAmount: Decimal? = nil,
        agentSuggestedCategory: FinancialCategory = .unknown,
        assignedLedgerTarget: LedgerTargetAssignment? = nil,
        sourceReceiptLineItemID: UUID? = nil,
        receiptHighlightRectRaw: String? = nil,
        manifest: MasterInvoiceManifest? = nil
    ) {
        self.id = id
        self.masterInvoiceID = masterInvoiceID
        self.sortIndex = sortIndex
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalLineAmount = totalLineAmount ?? (unitPrice * Decimal(quantity))
        agentSuggestedCategoryRaw = agentSuggestedCategory.rawValue
        assignedLedgerTargetJSON = assignedLedgerTarget.flatMap { Self.encodeLedgerTarget($0) }
        self.sourceReceiptLineItemID = sourceReceiptLineItemID
        self.receiptHighlightRectRaw = receiptHighlightRectRaw
        self.manifest = manifest
    }

    var agentSuggestedCategory: FinancialCategory {
        FinancialCategory(rawValue: agentSuggestedCategoryRaw) ?? .unknown
    }

    var assignedLedgerTarget: LedgerTargetAssignment? {
        get {
            guard let assignedLedgerTargetJSON else { return nil }
            return Self.decodeLedgerTarget(assignedLedgerTargetJSON)
        }
        set {
            assignedLedgerTargetJSON = newValue.flatMap { Self.encodeLedgerTarget($0) }
            manifest?.refreshReconciledFlag()
        }
    }

    private static func encodeLedgerTarget(_ target: LedgerTargetAssignment) -> String? {
        guard let data = try? JSONEncoder().encode(target) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeLedgerTarget(_ json: String) -> LedgerTargetAssignment? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LedgerTargetAssignment.self, from: data)
    }
}
