import Foundation
import SwiftData

/// **Shadow profile** discovered from payee lines on checks/invoices before official Corporate Registry onboarding.
@Model
final class PreliminaryBusinessEntity {
    @Attribute(.unique) var id: UUID
    /// Display / filing name from OCR (e.g. “Pay to the order of …”).
    var detectedLegalName: String
    /// Fuzzy-match key (`RegistryEntityPolarity.normalizedToken`).
    var normalizedKey: String
    var businessAddress: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    /// Set when the user promotes this shadow into a `BusinessEntity`.
    var mergedIntoBusinessEntity: BusinessEntity?

    @Relationship(deleteRule: .nullify, inverse: \Receipt.preliminaryBusinessEntity)
    var linkedReceipts: [Receipt]

    @Relationship(deleteRule: .nullify, inverse: \EquipmentAsset.preliminaryBusinessEntity)
    var equipmentAssets: [EquipmentAsset]

    init(
        id: UUID = UUID(),
        detectedLegalName: String,
        normalizedKey: String,
        businessAddress: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        mergedIntoBusinessEntity: BusinessEntity? = nil,
        linkedReceipts: [Receipt] = [],
        equipmentAssets: [EquipmentAsset] = []
    ) {
        self.id = id
        self.detectedLegalName = detectedLegalName
        self.normalizedKey = normalizedKey
        self.businessAddress = businessAddress
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mergedIntoBusinessEntity = mergedIntoBusinessEntity
        self.linkedReceipts = linkedReceipts
        self.equipmentAssets = equipmentAssets
    }

    /// Arctic Vault root segment (payee name; no `Shadow/` prefix).
    var vaultPathPrefix: String {
        ReceiptVaultPathing.sanitizePathSegment(detectedLegalName)
    }

    var isMerged: Bool { mergedIntoBusinessEntity != nil }
}

extension PreliminaryBusinessEntity {
    static func makeNormalizedKey(from legalName: String) -> String {
        RegistryEntityPolarity.normalizedToken(legalName)
    }
}
