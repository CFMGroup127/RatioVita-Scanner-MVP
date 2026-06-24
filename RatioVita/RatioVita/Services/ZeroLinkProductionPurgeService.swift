import Foundation
import SwiftData

/// Local-first purge for empty production shells — never waits on Firestore quota or network ACK.
@MainActor
enum ZeroLinkProductionPurgeService {
    struct BatchResult {
        let purgedCount: Int
        let purgedIDs: [UUID]
        let clearedActiveProduction: Bool
    }

    /// Deletes every zero-link production in one SwiftData save; clears active selection when needed.
    static func batchPurgeLocal(
        candidates: [ProductionProject],
        modelContext: ModelContext,
        activeProductionIDString: inout String
    ) -> BatchResult {
        let targets = candidates.filter(\.hasZeroLinkedItems)
        guard !targets.isEmpty else {
            return BatchResult(purgedCount: 0, purgedIDs: [], clearedActiveProduction: false)
        }

        let purgedIDs = targets.map(\.id)
        let purgedIDStrings = Set(purgedIDs.map(\.uuidString))
        let clearedActive = purgedIDStrings.contains(activeProductionIDString)
        if clearedActive {
            activeProductionIDString = ""
        }

        for project in targets {
            modelContext.delete(project)
        }
        try? modelContext.save()

        return BatchResult(
            purgedCount: targets.count,
            purgedIDs: purgedIDs,
            clearedActiveProduction: clearedActive
        )
    }

    /// Single-item purge — same local-first semantics as batch.
    static func purgeOne(
        _ project: ProductionProject,
        modelContext: ModelContext,
        activeProductionIDString: inout String
    ) -> Bool {
        guard project.hasZeroLinkedItems else { return false }
        let sid = project.id.uuidString
        if activeProductionIDString == sid {
            activeProductionIDString = ""
        }
        modelContext.delete(project)
        try? modelContext.save()
        return true
    }
}
