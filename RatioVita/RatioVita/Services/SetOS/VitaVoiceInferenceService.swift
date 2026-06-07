import Foundation
import SwiftData

/// Local wake-word routing: "Vita, tell Erin …" (Sprint TTT — simulated transcript parser).
@MainActor
enum VitaVoiceInferenceService {
    static let wakeToken = "vita"

    struct RoutedVoiceMemo: Identifiable, Sendable {
        var id: String { targetToken + transcript }
        var targetToken: String
        var targetDisplayName: String
        var transcript: String
        var routedAt: Date
    }

    static func parseWakeCommand(_ transcript: String) -> (targetName: String, message: String)? {
        let lowered = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard lowered.contains(wakeToken) else { return nil }

        let tellMarkers = ["tell ", "message to ", "message "]
        guard let marker = tellMarkers.first(where: { lowered.contains($0) }),
              let range = lowered.range(of: marker) else { return nil }

        let remainder = String(lowered[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard let splitIndex = remainder.firstIndex(where: { $0 == "," || $0 == ":" }) else { return nil }
        let name = String(remainder[..<splitIndex]).trimmingCharacters(in: .whitespaces)
        let message = String(remainder[remainder.index(after: splitIndex)...]).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !message.isEmpty else { return nil }
        return (name, message)
    }

    static func routeMemo(
        context: ModelContext,
        transcript: String,
        senderToken: String,
        crewDirectory: [SpatialCrewPosition]
    ) throws -> RoutedVoiceMemo? {
        guard let parsed = parseWakeCommand(transcript) else { return nil }
        let target = crewDirectory.first {
            $0.displayName.lowercased().contains(parsed.targetName.lowercased())
                || $0.userToken.lowercased().contains(parsed.targetName.lowercased())
        }
        let targetToken = target?.userToken ?? "CREW-\(parsed.targetName.uppercased())"
        let targetName = target?.displayName ?? parsed.targetName

        try HierarchyCommsEngine.ingest(
            context: context,
            title: "Vita voice · \(senderToken)",
            body: "To \(targetName): \(parsed.message)",
            senderRole: senderToken,
            priority: .operationalUrgent
        )
        try context.save()

        return RoutedVoiceMemo(
            targetToken: targetToken,
            targetDisplayName: targetName,
            transcript: parsed.message,
            routedAt: .now
        )
    }
}
