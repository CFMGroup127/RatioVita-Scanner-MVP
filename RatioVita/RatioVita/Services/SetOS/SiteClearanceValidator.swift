import Foundation
import SwiftData

/// Final master-receiver site lock-off (Sprint YYY).
@MainActor
enum SiteClearanceValidator {
    struct ClearanceWarning: Identifiable, Sendable {
        var id: String { itemDescription + zoneLabel }
        var itemDescription: String
        var rfidToken: String
        var zoneLabel: String
        var supervisorContact: String
        var vehicleLabel: String
    }

    struct ClearanceReport: Sendable {
        var isSiteClear: Bool
        var warnings: [ClearanceWarning]
        var masterNodeOffline: Bool
    }

    static func validateSiteTeardown(
        context: ModelContext,
        assets: [LocationsEquipmentAsset],
        masterNodeID: String = "SITE_MASTER_RX"
    ) throws -> ClearanceReport {
        let nodes = try context.fetch(FetchDescriptor<RTLSReceiverNode>())
        let master = nodes.first { $0.deviceNodeID == masterNodeID }

        let stranded = assets.filter { asset in
            !asset.isLoadedInTruck && asset.lastKnownZone != .cubeTruckGate
        }

        let warnings = stranded.map { asset in
            ClearanceWarning(
                itemDescription: asset.assetType.displayName,
                rfidToken: asset.rfidToken,
                zoneLabel: asset.lastKnownZone.displayName,
                supervisorContact: supervisorFor(asset: asset),
                vehicleLabel: asset.assignedTruckLabel.isEmpty ? "On location grid" : asset.assignedTruckLabel
            )
        }

        if !warnings.isEmpty {
            let summary = warnings.prefix(3).map(\.itemDescription).joined(separator: ", ")
            try HierarchyCommsEngine.ingest(
                context: context,
                title: "Site clearance · items remain",
                body: "\(warnings.count) asset(s) still on grid: \(summary)",
                senderRole: "Site Clearance",
                priority: .operationalUrgent
            )
            try context.save()
        }

        return ClearanceReport(
            isSiteClear: warnings.isEmpty,
            warnings: warnings,
            masterNodeOffline: master == nil
        )
    }

    private static func supervisorFor(asset: LocationsEquipmentAsset) -> String {
        switch asset.assetType {
            case .chairRental, .table6ft, .tent10x10:
                "Locations PA on channel 2"
            default:
                "Dept supervisor — see vehicle token"
        }
    }
}
