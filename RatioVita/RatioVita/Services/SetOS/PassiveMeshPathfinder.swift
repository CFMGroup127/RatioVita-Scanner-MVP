import Foundation

/// Step-by-step auditory routing from beacon landmarks (Sprint UUU).
@MainActor
enum PassiveMeshPathfinder {
    static func progressiveCueQueue(
        anchors: [SpatialMeshBeaconController.RoutingAnchor],
        targetZone: SpatialZoneID,
        stepIndex: Int
    ) -> String? {
        let path = SpatialMeshBeaconController.nearestPathDescription(
            anchors: anchors,
            targetZone: targetZone
        )
        guard stepIndex >= 0, stepIndex < path.count else { return nil }
        return path[stepIndex]
    }

    static func fullHandsFreeScript(
        anchors: [SpatialMeshBeaconController.RoutingAnchor],
        targetZone: SpatialZoneID
    ) -> [String] {
        SpatialMeshBeaconController.nearestPathDescription(anchors: anchors, targetZone: targetZone)
    }
}
