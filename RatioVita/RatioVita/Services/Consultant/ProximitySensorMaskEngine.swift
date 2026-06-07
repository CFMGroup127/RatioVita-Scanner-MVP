import Foundation

/// Filters RFID pings to active character profile only (Jaden #1 mode).
@MainActor
enum ProximitySensorMaskEngine {
    static func maskedAssets(
        activeCharacterID: String,
        allAssets: [RFIDAssetItem]
    ) -> [RFIDAssetItem] {
        allAssets.filter { $0.assignedCharacterID == activeCharacterID }
    }

    static func interferenceIgnored(
        activeCharacterID: String,
        allAssets: [RFIDAssetItem]
    ) -> [RFIDAssetItem] {
        allAssets.filter { $0.assignedCharacterID != activeCharacterID }
    }
}

@MainActor
enum RFIDAssetRegistry {
    static func logUnauthorizedExit(
        asset: RFIDAssetItem,
        perimeterLabel: String
    ) -> String {
        "ALERT: \(asset.itemDescription) (\(asset.rfidToken)) crossed \(perimeterLabel) without assignment update."
    }
}
