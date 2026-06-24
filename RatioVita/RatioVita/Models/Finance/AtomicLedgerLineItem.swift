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

    /// Primitive ledger assignment columns — safe for SwiftData background persistence (no JSON Codable).
    var assignedLedgerTargetKindRaw: String?
    var assignedLedgerTargetRegimenTrackingEnabled: Bool
    var assignedLedgerTargetVentureEntityID: UUID?

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
        assignedLedgerTargetKindRaw = assignedLedgerTarget?.kind.rawValue
        assignedLedgerTargetRegimenTrackingEnabled = assignedLedgerTarget?.regimenTrackingEnabled ?? false
        assignedLedgerTargetVentureEntityID = assignedLedgerTarget?.ventureEntityID
        self.sourceReceiptLineItemID = sourceReceiptLineItemID
        self.receiptHighlightRectRaw = receiptHighlightRectRaw
        self.manifest = manifest
    }

    var agentSuggestedCategory: FinancialCategory {
        FinancialCategory(rawValue: agentSuggestedCategoryRaw) ?? .unknown
    }

    var assignedLedgerTarget: LedgerTargetAssignment? {
        get {
            guard let kindRaw = assignedLedgerTargetKindRaw,
                  let kind = LedgerTargetKind(rawValue: kindRaw) else { return nil }
            return LedgerTargetAssignment(
                kind: kind,
                regimenTrackingEnabled: assignedLedgerTargetRegimenTrackingEnabled,
                ventureEntityID: assignedLedgerTargetVentureEntityID
            )
        }
        set {
            assignedLedgerTargetKindRaw = newValue?.kind.rawValue
            assignedLedgerTargetRegimenTrackingEnabled = newValue?.regimenTrackingEnabled ?? false
            assignedLedgerTargetVentureEntityID = newValue?.ventureEntityID
            manifest?.refreshReconciledFlag()
        }
    }
}
