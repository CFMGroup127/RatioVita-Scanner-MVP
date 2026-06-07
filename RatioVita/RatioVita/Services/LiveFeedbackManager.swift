import Combine
import Foundation
import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Global shake / shortcut feedback catalyst.
@MainActor
final class LiveFeedbackManager: ObservableObject {
    static let shared = LiveFeedbackManager()

    @Published var showOverlay = false
    @Published var currentViewContext = "RatioVita"
    @Published var originatingDepartment = "General"
    @Published var sovereigntyLevel = "Crew"

    private init() {}

    func presentFeedback(context: String, department: String = "General", level: String = "Crew") {
        guard SovereignFeatureFlags.shakeToFeedbackEnabled else { return }
        currentViewContext = context
        originatingDepartment = department
        sovereigntyLevel = level
        showOverlay = true
    }

    func submit(
        context: ModelContext,
        notes: String,
        department: String,
        level: String,
        viewContext: String
    ) throws -> CrewFeedbackTicket {
        #if os(iOS)
        let platform = UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "unknown"
        #endif

        var enrichedNotes = notes
        if let mission = TestingMissionManager.shared.missionContextLine {
            enrichedNotes += "\n\n[Active test mission: \(mission)]"
        }

        let ticket = CrewFeedbackTicket(
            originatingDepartment: department,
            userSovereigntyLevel: level,
            userNotes: enrichedNotes,
            currentViewContext: viewContext,
            devicePlatform: platform
        )
        context.insert(ticket)
        try context.save()

        let snapshot = FeedbackDispatchService.snapshot(from: ticket)
        Task.detached(priority: .utility) {
            await FeedbackDispatchService.dispatch(snapshot: snapshot)
        }
        return ticket
    }
}

/// Background upload of feedback payloads to the cloud vault inbox.
enum FeedbackDispatchService {
    struct TicketSnapshot: Sendable {
        let id: String
        let timestamp: Date
        let department: String
        let level: String
        let notes: String
        let viewContext: String
        let platform: String
    }

    static func snapshot(from ticket: CrewFeedbackTicket) -> TicketSnapshot {
        TicketSnapshot(
            id: ticket.id.uuidString,
            timestamp: ticket.timestamp,
            department: ticket.originatingDepartment,
            level: ticket.userSovereigntyLevel,
            notes: ticket.userNotes,
            viewContext: ticket.currentViewContext,
            platform: ticket.devicePlatform
        )
    }

    static let inboxFileName = "crew_feedback_inbox.jsonl"

    static func dispatch(snapshot: TicketSnapshot) async {
        let payload: [String: String] = [
            "id": snapshot.id,
            "timestamp": ISO8601DateFormatter().string(from: snapshot.timestamp),
            "department": snapshot.department,
            "level": snapshot.level,
            "notes": snapshot.notes,
            "view": snapshot.viewContext,
            "platform": snapshot.platform,
        ]
        guard let line = try? String(data: JSONSerialization.data(withJSONObject: payload), encoding: .utf8) else {
            return
        }
        await MainActor.run {
            do {
                let dir = try VaultImportExportService.ensureCloudVaultDirectory()
                let url = dir.appendingPathComponent(inboxFileName)
                let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let merged = existing.isEmpty ? line + "\n" : existing + line + "\n"
                try merged.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                #if DEBUG
                print("FeedbackDispatch: \(error)")
                #endif
            }
        }
    }
}
