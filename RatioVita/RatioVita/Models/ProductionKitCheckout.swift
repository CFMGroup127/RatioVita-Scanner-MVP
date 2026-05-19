import Foundation
import SwiftData

/// Active checkout of an `EquipmentAsset` to a production (feeds EP **Other rates**).
@Model
final class ProductionKitCheckout {
    @Attribute(.unique) var id: UUID
    var deviceKindRaw: String
    var checkedOutAt: Date
    var checkedInAt: Date?
    var notes: String?

    var productionProject: ProductionProject?
    var equipmentAsset: EquipmentAsset?

    init(
        id: UUID = UUID(),
        deviceKindRaw: String,
        checkedOutAt: Date = .now,
        checkedInAt: Date? = nil,
        notes: String? = nil,
        productionProject: ProductionProject? = nil,
        equipmentAsset: EquipmentAsset? = nil
    ) {
        self.id = id
        self.deviceKindRaw = deviceKindRaw
        self.checkedOutAt = checkedOutAt
        self.checkedInAt = checkedInAt
        self.notes = notes
        self.productionProject = productionProject
        self.equipmentAsset = equipmentAsset
    }

    var deviceKind: ProductionKitDeviceKind {
        ProductionKitDeviceKind(rawValue: deviceKindRaw) ?? .computer
    }

    var isActive: Bool { checkedInAt == nil }
}
