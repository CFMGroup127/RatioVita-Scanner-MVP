import Foundation
import SwiftData

/// Many-to-many reference graph between receipts/documents (invoice ↔ warranty ↔ maintenance logs, etc.).
@Model
final class ReceiptReferenceLink {
    @Attribute(.unique) var id: UUID
    /// The document the user is currently viewing / filing from. Plain optional: `@Relationship` + inverse lives on
    /// `Receipt.referenceLinks`.
    var fromReceipt: Receipt?
    /// The related document (warranty, invoice, maintenance log, etc.). Plain optional: inverse on
    /// `Receipt.incomingReferenceLinks`.
    var toReceipt: Receipt?
    /// Optional user hint describing the relationship.
    var relationshipLabel: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fromReceipt: Receipt? = nil,
        toReceipt: Receipt? = nil,
        relationshipLabel: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.fromReceipt = fromReceipt
        self.toReceipt = toReceipt
        self.relationshipLabel = relationshipLabel
        self.createdAt = createdAt
    }
}
