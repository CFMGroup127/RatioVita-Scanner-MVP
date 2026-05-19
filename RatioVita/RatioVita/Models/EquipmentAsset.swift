import Foundation
import SwiftData

/// Gear / kit row in the **Inventory** module (linked to corporate or shadow entities).
@Model
final class EquipmentAsset {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var modelName: String?
    var serialNumber: String?
    var purchaseDate: Date?
    var warrantyExpiryDate: Date?
    /// Daily kit / box rental rate (CAD) for EP “Other Rates”.
    var dailyRentalRateCAD: Decimal?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    /// Official corporate registry (inverse on `BusinessEntity.equipmentAssets`).
    var businessEntity: BusinessEntity?
    /// Shadow profile (inverse on `PreliminaryBusinessEntity.equipmentAssets`).
    var preliminaryBusinessEntity: PreliminaryBusinessEntity?

    @Relationship(deleteRule: .nullify, inverse: \Receipt.sourceEquipmentAsset)
    var sourceReceipt: Receipt?

    init(
        id: UUID = UUID(),
        displayName: String,
        modelName: String? = nil,
        serialNumber: String? = nil,
        purchaseDate: Date? = nil,
        warrantyExpiryDate: Date? = nil,
        dailyRentalRateCAD: Decimal? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        businessEntity: BusinessEntity? = nil,
        preliminaryBusinessEntity: PreliminaryBusinessEntity? = nil,
        sourceReceipt: Receipt? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.modelName = modelName
        self.serialNumber = serialNumber
        self.purchaseDate = purchaseDate
        self.warrantyExpiryDate = warrantyExpiryDate
        self.dailyRentalRateCAD = dailyRentalRateCAD
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.businessEntity = businessEntity
        self.preliminaryBusinessEntity = preliminaryBusinessEntity
        self.sourceReceipt = sourceReceipt
    }

    var isWarrantyExpiringSoon: Bool {
        guard let expiry = warrantyExpiryDate else { return false }
        let horizon = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return expiry <= horizon
    }
}
