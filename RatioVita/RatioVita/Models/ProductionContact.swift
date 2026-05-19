import Foundation
import SwiftData

/// A person or company in the production accounting **contact graph** (Zoho CSV + manual). One row can carry
/// multiple **role tags** (e.g. Producer vs PM on different shows) without duplicating legal identity fields.
@Model
final class ProductionContact {
    @Attribute(.unique) var id: UUID
    var name: String
    var companyName: String?
    var email: String?
    /// Role / relationship labels (e.g. `Producer`, `PM`, `Catering Client`). Zoho “Tags” maps here when present.
    var tags: [String]
    var notes: String?
    /// `ContactEntityClassification.rawValue` — nil = external vendor (lightweight-migration safe).
    var entityClassificationRaw: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Receipt.counterpartyContact)
    var linkedReceipts: [Receipt]

    init(
        id: UUID = UUID(),
        name: String,
        companyName: String? = nil,
        email: String? = nil,
        tags: [String] = [],
        notes: String? = nil,
        entityClassificationRaw: String? = ContactEntityClassification.externalVendor.rawValue,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        linkedReceipts: [Receipt] = []
    ) {
        self.id = id
        self.name = name
        self.companyName = companyName
        self.email = email
        self.tags = tags
        self.notes = notes
        self.entityClassificationRaw = entityClassificationRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedReceipts = linkedReceipts
    }
}

extension ProductionContact {
    var entityClassification: ContactEntityClassification {
        get {
            guard let raw = entityClassificationRaw else { return .externalVendor }
            return ContactEntityClassification(rawValue: raw) ?? .externalVendor
        }
        set { entityClassificationRaw = newValue.rawValue }
    }
}
