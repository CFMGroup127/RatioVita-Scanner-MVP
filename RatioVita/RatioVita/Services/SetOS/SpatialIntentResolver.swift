import Foundation

/// Resolves voice intent vs RF truth (Sprint UUU).
@MainActor
enum SpatialIntentResolver {
    static func resolveGuidance(
        target: SpatialCrewPosition,
        statedZone: SpatialZoneID
    ) -> VoiceIntentPayload {
        let actual = target.verifiedZone
        let mismatch = statedZone != actual && actual != .unknown
        let correction = if mismatch {
            "\(target.displayName) is at \(actual.displayLabel), not \(statedZone.displayLabel). Guiding you there and alerting \(target.displayName) you are en route."
        } else {
            "Guiding you to \(target.displayName) at \(actual.displayLabel)."
        }
        return VoiceIntentPayload(
            targetUserToken: target.userToken,
            statedLocationZoneID: statedZone.rawValue,
            actualLocationZoneID: actual.rawValue,
            requiresTrajectoryCorrection: mismatch,
            spokenCorrection: correction
        )
    }

    static func parseStatedZone(from transcript: String) -> SpatialZoneID {
        let lowered = transcript.lowercased()
        if lowered.contains("green room") { return .greenRoom }
        if lowered.contains("video village") { return .videoVillage }
        if lowered.contains("base camp") || lowered.contains("trailer") { return .baseCampTrailers }
        if lowered.contains("tech land") || lowered.contains("set") { return .techLandSet }
        return .unknown
    }

    static func parseTargetName(from transcript: String) -> String? {
        let lowered = transcript.lowercased()
        guard let range = lowered.range(of: "wayne") ?? lowered.range(of: "guide me to ") else { return nil }
        if lowered.contains("wayne") { return "Wayne" }
        let fragment = String(lowered[range.lowerBound...])
        let parts = fragment.split(separator: " ")
        return parts.last.map { String($0).capitalized }
    }
}
