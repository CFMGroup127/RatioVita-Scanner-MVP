import Foundation
import SwiftData

/// Keeps multi-page batch parents visible in Review after extract/decouple commits (data stays in SwiftData).
@MainActor
enum ReceiptWorkspaceBatchGuard {
    private static let schemaFingerprintKey = "com.ratiovita.swiftdata.schemaFingerprint"
    private static let lastStoreRecoveryKey = "com.ratiovita.swiftdata.lastStoreRecoveryMessage"

    /// Call after ingest when more than one page lands on a single receipt.
    static func pinMultiPageBatchIfNeeded(_ receipt: Receipt) {
        guard receipt.images.count > 1 else { return }
        receipt.workspaceBatchPinned = true
        if !receipt.pendingHumanReview {
            receipt.pendingHumanReview = true
        }
    }

    /// Retain parent + child in the review workbench after a decoupler commit.
    static func retainAfterDecouple(
        parent: Receipt,
        spawned: [Receipt],
        context: ModelContext
    ) {
        parent.workspaceBatchPinned = true
        parent.pendingHumanReview = true
        for child in spawned {
            child.parentBatchReceiptID = parent.id
            child.workspaceBatchPinned = false
            child.pendingHumanReview = true
            child.reviewChecklistDone = false
        }
        context.processPendingChanges()
    }

    static func retainAfterDecouple(parent: Receipt, spawned: Receipt, context: ModelContext) {
        retainAfterDecouple(parent: parent, spawned: [spawned], context: context)
    }

    /// Clears batch pin when the user files from Review.
    static func clearPinOnFile(_ receipt: Receipt) {
        receipt.workspaceBatchPinned = false
    }

    /// User explicitly decouples the batch from the workbench (e.g. Decouple & File Later).
    static func releaseBatchPin(_ receipt: Receipt) {
        receipt.workspaceBatchPinned = false
    }

    // MARK: - SwiftData store recovery (prevents silent full-library wipes)

    static func currentSchemaFingerprint() -> String {
        LibrarySwiftDataSchema.schemaFingerprint
    }

    static func consumePendingRecoveryAlert() -> String? {
        let msg = UserDefaults.standard.string(forKey: lastStoreRecoveryKey)
        if msg != nil {
            UserDefaults.standard.removeObject(forKey: lastStoreRecoveryKey)
        }
        return msg
    }

    static func backupAndRemoveStore(at storeURL: URL) {
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("\(storeURL.lastPathComponent).backup-\(stamp)")
        try? fm.copyItem(at: storeURL, to: backupURL)

        let parent = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent
        if let siblings = try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil) {
            for url in siblings where url.lastPathComponent.hasPrefix(base) && url != backupURL {
                let sideBackup = url.deletingLastPathComponent()
                    .appendingPathComponent("\(url.lastPathComponent).backup-\(stamp)")
                try? fm.copyItem(at: url, to: sideBackup)
                try? fm.removeItem(at: url)
            }
        }
        try? fm.removeItem(at: storeURL)

        let message =
            "Your library database was reset after a schema upgrade. A backup was saved beside the store as \(backupURL.lastPathComponent). Re-import or restore from Sovereign if needed."
        UserDefaults.standard.set(message, forKey: lastStoreRecoveryKey)
        UserDefaults.standard.set(currentSchemaFingerprint(), forKey: schemaFingerprintKey)
    }
}
