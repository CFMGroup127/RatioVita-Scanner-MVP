import Foundation
import SwiftData

/// Lightweight diagnostics so “everything vanished” can be distinguished from a UI filter vs a store reset.
@MainActor
enum LibraryPersistenceMonitor {
    private static let lastSnapshotKey = "com.ratiovita.library.lastSnapshot"
    private static let lastSchemaKey = "com.ratiovita.library.lastSchemaFingerprint"

    struct Snapshot: Codable, Sendable {
        var capturedAt: Date
        var schemaFingerprint: String
        var receiptCount: Int
        var reviewQueueCount: Int
        var trashedCount: Int
    }

    static func recordSnapshot(context: ModelContext, reason: String) {
        let snap = capture(context: context)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: lastSnapshotKey)
        }
        UserDefaults.standard.set(snap.schemaFingerprint, forKey: lastSchemaKey)

        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: "library.persistence.snapshot",
            title: "Library snapshot (\(reason))",
            detail:
            "schema:\(snap.schemaFingerprint)·receipts:\(snap.receiptCount)·review:\(snap.reviewQueueCount)·trash:\(snap.trashedCount)"
        )
        try? context.save()
    }

    static func capture(context: ModelContext) -> Snapshot {
        let receipts = (try? context.fetch(FetchDescriptor<Receipt>())) ?? []
        let review = receipts.filter { $0.pendingHumanReview && $0.trashedAt == nil }.count
        let trashed = receipts.filter { $0.trashedAt != nil }.count
        return Snapshot(
            capturedAt: .now,
            schemaFingerprint: LibrarySwiftDataSchema.schemaFingerprint,
            receiptCount: receipts.count,
            reviewQueueCount: review,
            trashedCount: trashed
        )
    }

    /// Compares previous launch snapshot; returns a user-facing hint when counts dropped sharply.
    static func regressionHint(context: ModelContext) -> String? {
        guard let data = UserDefaults.standard.data(forKey: lastSnapshotKey),
              let prior = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }

        let now = capture(context: context)
        let schemaChanged = prior.schemaFingerprint != now.schemaFingerprint
        let lostAll = prior.receiptCount > 0 && now.receiptCount == 0

        if lostAll {
            if schemaChanged {
                return
                    "Receipt count went from \(prior.receiptCount) to 0 after a schema change. Check for a `default.store.backup-*` file beside your SwiftData store, or restore a Sovereign archive."
            }
            return
                "Receipt count went from \(prior.receiptCount) to 0. If you did not run Factory reset, check Settings → Sovereign restore or your latest backup file."
        }

        if schemaChanged, prior.receiptCount > now.receiptCount, now.receiptCount == 0 {
            return "Library counts dropped after schema upgrade. A backup may exist from the last launch."
        }

        return nil
    }
}
