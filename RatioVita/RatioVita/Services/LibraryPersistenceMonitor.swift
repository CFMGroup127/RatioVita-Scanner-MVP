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

    /// Captures counts off the main thread, then persists metadata without blocking navigation.
    static func recordSnapshot(container: ModelContainer, reason: String) {
        guard !LocalIndexEnvironmentGuard.shouldDeferSystemIndexing else {
            #if DEBUG
            print("[LibraryPersistenceMonitor] Skipping snapshot (\(reason)) — index environment under pressure.")
            #endif
            return
        }
        Task.detached(priority: .utility) {
            let snap = captureOnBackground(container: container)
            await MainActor.run {
                applySnapshot(snap, reason: reason, container: container)
            }
        }
    }

    static func recordSnapshot(context: ModelContext, reason: String) {
        recordSnapshot(container: context.container, reason: reason)
    }

    static func capture(context: ModelContext) -> Snapshot {
        captureOnBackground(container: context.container)
    }

    /// Compares previous launch snapshot; returns a user-facing hint when counts dropped sharply.
    static func regressionHint(container: ModelContainer) async -> String? {
        let now = await Task.detached(priority: .utility) {
            captureOnBackground(container: container)
        }.value
        return regressionHint(for: now)
    }

    static func regressionHint(context: ModelContext) -> String? {
        regressionHint(for: capture(context: context))
    }

    private static func regressionHint(for now: Snapshot) -> String? {
        guard let data = UserDefaults.standard.data(forKey: lastSnapshotKey),
              let prior = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }

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

    private static func applySnapshot(_ snap: Snapshot, reason: String, container: ModelContainer) {
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: lastSnapshotKey)
        }
        UserDefaults.standard.set(snap.schemaFingerprint, forKey: lastSchemaKey)

        guard !LocalIndexEnvironmentGuard.shouldDeferSystemIndexing else { return }

        Task { @MainActor in
            await Task.yield()
            let context = ModelContext(container)
            FilingCoordinator.appendAudit(
                context: context,
                kindRaw: "library.persistence.snapshot",
                title: "Library snapshot (\(reason))",
                detail:
                "schema:\(snap.schemaFingerprint)·receipts:\(snap.receiptCount)·review:\(snap.reviewQueueCount)·trash:\(snap.trashedCount)"
            )
            try? context.save()
        }
    }

    nonisolated private static func captureOnBackground(container: ModelContainer) -> Snapshot {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var descriptor = FetchDescriptor<Receipt>()
        descriptor.includePendingChanges = false
        let receiptCount = (try? context.fetchCount(descriptor)) ?? 0

        var reviewDescriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate { $0.pendingHumanReview == true && $0.trashedAt == nil }
        )
        reviewDescriptor.includePendingChanges = false
        let review = (try? context.fetchCount(reviewDescriptor)) ?? 0

        var trashedDescriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate { $0.trashedAt != nil }
        )
        trashedDescriptor.includePendingChanges = false
        let trashed = (try? context.fetchCount(trashedDescriptor)) ?? 0

        return Snapshot(
            capturedAt: .now,
            schemaFingerprint: LibrarySwiftDataSchema.schemaFingerprint,
            receiptCount: receiptCount,
            reviewQueueCount: review,
            trashedCount: trashed
        )
    }
}
