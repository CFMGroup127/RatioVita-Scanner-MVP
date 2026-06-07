import Foundation
import SwiftData

/// On launch, surfaces a user message when a newer cross-device `.rvvault` snapshot exists in the cloud vault.
enum VaultLaunchSyncPrompt {
    private static let suppressUntilKey = "com.ratiovita.vault.launchPromptSuppressedUntil"

    @MainActor
    static func checkAndNotify(modelContext _: ModelContext) async {
        if let until = UserDefaults.standard.object(forKey: suppressUntilKey) as? Date, until > Date() {
            return
        }
        let localID = RatioVitaBackupManager.deviceIdentifier()
        guard let snap = VaultImportExportService.newestCloudSnapshot(localDeviceID: localID) else { return }
        guard snap.isFromOtherDevice, snap.isNewerThanLastPull else { return }

        let when = snap.header.timestamp.formatted(date: .abbreviated, time: .shortened)
        UserMessageCenter.shared.present(
            title: "Newer vault on \(snap.header.deviceName)",
            message:
            "A snapshot from \(when) with \(snap.header.receiptCount) receipt(s) is waiting in \(VaultImportExportService.cloudVaultDisplayPath()). Open Settings → Vault transport → Pull snapshot to merge or replace."
        )
        UserDefaults.standard.set(Date().addingTimeInterval(6 * 3600), forKey: suppressUntilKey)
    }
}
