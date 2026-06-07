import CoreLocation
import Foundation

/// Sorts shuttle hops by geographic sequence along the active route polyline.
@MainActor
enum TransportGeofenceMesh {
    struct HopUpdate: Sendable {
        var statusLabel: String
        var sortedWaypoints: [LocationWaypointPayload]
        var nextWaypointName: String?
    }

    /// Re-order pending stops relative to origin → ultimate destination bearing.
    static func resortWaypoints(
        origin: CLLocationCoordinate2D,
        ultimateDestination: CLLocationCoordinate2D,
        pending: [LocationWaypointPayload]
    ) -> [LocationWaypointPayload] {
        guard pending.count > 1 else { return pending }
        let bearing = bearingDegrees(from: origin, to: ultimateDestination)
        return pending.sorted { lhs, rhs in
            let a = projectionScore(origin: origin, bearing: bearing, point: lhs)
            let b = projectionScore(origin: origin, bearing: bearing, point: rhs)
            if a != b { return a < b }
            return lhs.sequenceOrder < rhs.sequenceOrder
        }
        .enumerated()
        .map { idx, wp in
            var copy = wp
            copy.sequenceOrder = idx
            return copy
        }
    }

    static func applyPassengerHop(
        run: TransportVehicleRun,
        newStopName: String,
        latitude: Double,
        longitude: Double
    ) -> HopUpdate {
        var stops = run.waypoints.filter { !$0.isCompleted }
        let newStop = LocationWaypointPayload(
            name: newStopName,
            latitude: latitude,
            longitude: longitude,
            sequenceOrder: stops.count
        )
        stops.append(newStop)

        guard let first = stops.first, let last = stops.last else {
            return HopUpdate(statusLabel: run.statusLabel, sortedWaypoints: run.waypoints, nextWaypointName: nil)
        }
        let origin = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
        let dest = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
        let sorted = resortWaypoints(origin: origin, ultimateDestination: dest, pending: stops)
        run.waypoints = mergeCompleted(run.waypoints, with: sorted)
        let next = run.waypoints.first(where: { !$0.isCompleted })
        let label = if let next {
            "Travelling toward \(next.name)"
        } else {
            "Route complete"
        }
        run.statusLabel = label
        run.updatedAt = .now
        return HopUpdate(statusLabel: label, sortedWaypoints: run.waypoints, nextWaypointName: next?.name)
    }

    static func taskCompletionPercent(for run: TransportVehicleRun) -> Double {
        let legs = run.waypoints
        guard !legs.isEmpty else { return run.progressPercent }
        let done = legs.filter(\.isCompleted).count
        return min(1, max(0, Double(done) / Double(legs.count)))
    }

    static func diversionRecommendation(
        delayedRun: TransportVehicleRun,
        candidateRun: TransportVehicleRun,
        interceptStopName: String
    ) -> String? {
        guard delayedRun.trafficDelayMinutes >= 15 else { return nil }
        return """
        \(delayedRun.driverName) delayed \(delayedRun.trafficDelayMinutes)m on route. \
        Divert \(candidateRun.driverName) to \(interceptStopName)? Auto-notify waiting parties.
        """
    }

    private static func mergeCompleted(
        _ existing: [LocationWaypointPayload],
        with sorted: [LocationWaypointPayload]
    ) -> [LocationWaypointPayload] {
        let completed = existing.filter(\.isCompleted)
        return completed + sorted
    }

    private static func bearingDegrees(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    private static func projectionScore(
        origin: CLLocationCoordinate2D,
        bearing: Double,
        point: LocationWaypointPayload
    ) -> Double {
        let θ1 = bearing * .pi / 180
        let θ2 = bearingDegrees(
            from: origin,
            to: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        ) * .pi / 180
        let dθ = atan2(sin(θ2 - θ1), cos(θ2 - θ1))
        let dist = hypot(
            point.latitude - origin.latitude,
            point.longitude - origin.longitude
        )
        return dist * cos(dθ)
    }
}
