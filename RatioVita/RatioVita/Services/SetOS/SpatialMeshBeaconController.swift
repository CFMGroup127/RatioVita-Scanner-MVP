import Foundation
import SwiftData

/// Passive RF landmark mesh for indoor routing (Sprint TTT).
@MainActor
enum SpatialMeshBeaconController {
    struct RoutingAnchor: Identifiable, Sendable {
        var id: String { rfidToken }
        var rfidToken: String
        var departmentOwner: String
        var gridX: Double
        var gridY: Double
        var zoneLabel: String
    }

    static func seedDemoPath(context: ModelContext, toward zone: SpatialZoneID) throws {
        let existing = try context.fetch(FetchDescriptor<SpatialBeaconAsset>())
        if existing.count >= 4 { return }

        let points: [(String, String, Double, Double)] = [
            ("RFID-GRIP-BOX-12", "GRIP", 10, 4),
            ("RFID-SETDEC-TRUNK", "SET_DEC", 22, 6),
            ("RFID-CAM-CART-03", "CAMERA", 34, 8),
            ("RFID-COST-RACK-07", "COSTUME", 46, 10),
        ]
        for (token, dept, x, y) in points {
            context.insert(
                SpatialBeaconAsset(
                    rfidToken: token,
                    departmentOwner: dept,
                    floorLevel: 1,
                    spatialGridX: x,
                    spatialGridY: y,
                    zoneLabel: zone.displayLabel
                )
            )
        }
        try context.save()
    }

    static func anchors(from beacons: [SpatialBeaconAsset]) -> [RoutingAnchor] {
        beacons.map {
            RoutingAnchor(
                rfidToken: $0.rfidToken,
                departmentOwner: $0.departmentOwner,
                gridX: $0.spatialGridX,
                gridY: $0.spatialGridY,
                zoneLabel: $0.zoneLabel
            )
        }
        .sorted { $0.gridX < $1.gridX }
    }

    static func nearestPathDescription(anchors: [RoutingAnchor], targetZone: SpatialZoneID) -> [String] {
        guard !anchors.isEmpty else {
            return ["No beacons detected — enable demo path seed."]
        }
        var lines = anchors.map { "Pass \($0.departmentOwner) landmark \($0.rfidToken)" }
        lines.append("Arrive \(targetZone.displayLabel)")
        return lines
    }
}
