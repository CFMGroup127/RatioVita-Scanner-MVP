import Foundation
import SwiftData

/// Cube-truck bumper RFID sweep vs rental manifest (Sprint VVV).
@MainActor
enum LocationsEquipmentMeshController {
    struct ManifestLineResult: Identifiable, Sendable {
        var id: String { assetType.rawValue }
        var assetType: LocationsAssetType
        var vendorSource: String
        var expectedCount: Int
        var detectedCount: Int
        var missingCount: Int
        var isComplete: Bool
        var recoveryGuidance: String?
    }

    struct BumperSweepResult: Identifiable, Sendable {
        var id: String { truckLabel }
        var truckLabel: String
        var scannedAt: Date
        var lines: [ManifestLineResult]
        var missingAssets: [LocationsEquipmentAsset]

        var isTruckComplete: Bool {
            lines.allSatisfy(\.isComplete)
        }

        var totalMissing: Int {
            lines.reduce(0) { $0 + $1.missingCount }
        }
    }

    static func defaultCubeManifest(truckLabel: String = "CUBE-02") -> LocationsTruckManifest {
        LocationsTruckManifest(
            truckLabel: truckLabel,
            productionTitle: "Sanctuary · Muskoka",
            lines: [
                LocationsManifestLine(assetType: .chairRental, expectedCount: 150),
                LocationsManifestLine(assetType: .table6ft, expectedCount: 20),
                LocationsManifestLine(assetType: .tent10x10, expectedCount: 8),
                LocationsManifestLine(assetType: .spaceHeater, expectedCount: 4),
                LocationsManifestLine(assetType: .buttBin, expectedCount: 12),
                LocationsManifestLine(assetType: .signageArrow, expectedCount: 24),
                LocationsManifestLine(assetType: .sandbag, expectedCount: 40),
            ]
        )
    }

    static func seedDemoInventory(
        context: ModelContext,
        truckLabel: String = "CUBE-02",
        omitChairCount: Int = 4
    ) throws {
        let existing = try context.fetch(FetchDescriptor<LocationsEquipmentAsset>())
        if !existing.isEmpty { return }

        context.insert(defaultCubeManifest(truckLabel: truckLabel))

        for index in 1...150 {
            let loaded = index > omitChairCount
            let zone: LocationsZoneID = loaded ? .cubeTruckGate : .satelliteBGHolding
            let asset = LocationsEquipmentAsset(
                rfidToken: "RFID-CHAIR-\(String(format: "%03d", index))",
                assetType: .chairRental,
                zone: zone,
                truckLabel: loaded ? truckLabel : ""
            )
            asset.isLoadedInTruck = loaded
            context.insert(asset)
        }

        for index in 1...20 {
            let asset = LocationsEquipmentAsset(
                rfidToken: "RFID-TABLE-\(index)",
                assetType: .table6ft,
                zone: .cubeTruckGate,
                truckLabel: truckLabel
            )
            asset.isLoadedInTruck = true
            context.insert(asset)
        }

        for heaterIndex in 1...4 {
            let asset = LocationsEquipmentAsset(
                rfidToken: "RFID-HEAT-\(heaterIndex)",
                assetType: .spaceHeater,
                zone: .cubeTruckGate,
                truckLabel: truckLabel
            )
            asset.isLoadedInTruck = true
            context.insert(asset)
        }

        try context.save()
    }

    /// Simulated passive sub-gigahertz bumper sweep against truck cargo bed.
    static func performBumperSweep(
        manifest: LocationsTruckManifest,
        assets: [LocationsEquipmentAsset],
        truckLabel: String,
        simulatedOmissions: [LocationsAssetType: Int] = [:]
    ) -> BumperSweepResult {
        var lineResults: [ManifestLineResult] = []
        var allMissing: [LocationsEquipmentAsset] = []

        for line in manifest.lines {
            let type = line.assetType
            let typedAssets = assets.filter { $0.assetType == type }
            let omission = simulatedOmissions[type] ?? 0
            let detectedInSweep: Int
            let missingItems: ArraySlice<LocationsEquipmentAsset>
            if typedAssets.isEmpty {
                detectedInSweep = max(0, line.expectedCount - omission)
                missingItems = []
            } else {
                let loaded = typedAssets.filter(\.isLoadedInTruck).count
                detectedInSweep = max(0, loaded - omission)
                missingItems = typedAssets.filter { !$0.isLoadedInTruck }.prefix(max(
                    0,
                    line.expectedCount - detectedInSweep
                ))
            }
            let missingCount = max(0, line.expectedCount - detectedInSweep)

            var guidance: String?
            if missingCount > 0 {
                let zones = Set(missingItems.map(\.lastKnownZone.displayName))
                guidance = recoveryGuidance(
                    assetType: type,
                    missingCount: missingCount,
                    lastKnownZones: Array(zones)
                )
                allMissing.append(contentsOf: missingItems)
            }

            lineResults.append(
                ManifestLineResult(
                    assetType: type,
                    vendorSource: line.vendorSource,
                    expectedCount: line.expectedCount,
                    detectedCount: detectedInSweep,
                    missingCount: missingCount,
                    isComplete: missingCount == 0,
                    recoveryGuidance: guidance
                )
            )
        }

        return BumperSweepResult(
            truckLabel: truckLabel,
            scannedAt: .now,
            lines: lineResults,
            missingAssets: Array(allMissing)
        )
    }

    static func recoveryGuidance(
        assetType: LocationsAssetType,
        missingCount: Int,
        lastKnownZones: [String]
    ) -> String {
        let zoneList = lastKnownZones.isEmpty ? "last known zone unknown" : lastKnownZones.joined(separator: ", ")
        return "Missing \(missingCount) × \(assetType.displayName). Last seen cluster: \(zoneList)."
    }

    static func applySweepToAssets(
        context: ModelContext,
        assets: [LocationsEquipmentAsset],
        truckLabel: String,
        detectedTokens: Set<String>
    ) throws {
        for asset in assets where asset.assignedTruckLabel == truckLabel || asset.rfidToken.hasPrefix("RFID-") {
            asset.isLoadedInTruck = detectedTokens.contains(asset.rfidToken)
            if asset.isLoadedInTruck {
                asset.lastKnownZone = .cubeTruckGate
            }
        }
        try context.save()
    }
}
