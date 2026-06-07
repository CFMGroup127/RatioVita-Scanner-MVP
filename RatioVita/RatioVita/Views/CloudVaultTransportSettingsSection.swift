import SwiftData
import SwiftUI

/// Settings UI for `.rvvault` cloud/local transport (Sprint VV).
struct CloudVaultTransportSettingsSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var cloudPath = VaultImportExportService.cloudVaultDisplayPath()
    @State private var isBusy = false
    @State private var statusMessage: String?
    @State private var pendingSnapshot: VaultImportExportService.CloudSnapshotInfo?
    @State private var showPullCollision = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Divider()

            Text("Cloud vault transport")
                .font(DesignSystem.Typography.bodyEmphasized)

            Text(
                "Packages your library into `.rvvault` files in \(cloudPath). On a Personal Team build, files land in the local Documents vault until you enable **iCloud Documents** with a paid Apple Developer account."
            )
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(Color.ratioVitaTextSecondary)

            if VaultImportExportService.isICloudDriveContainerAvailable() {
                Label("iCloud Drive container available", systemImage: "icloud.fill")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaPrimary)
            } else {
                Label("Using on-device vault folder (Files app)", systemImage: "folder.fill")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    Task { await pushToCloud() }
                } label: {
                    Label("Push snapshot", systemImage: "icloud.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ratioVitaPrimary)
                .disabled(isBusy)

                Button {
                    Task { await preparePull() }
                } label: {
                    Label("Pull snapshot", systemImage: "icloud.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }

            if let local = RatioVitaBackupManager.lastLocalBackupURL() {
                Text("Latest local backup: \(local.lastPathComponent)")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
        }
        .confirmationDialog(
            pullDialogTitle,
            isPresented: $showPullCollision,
            titleVisibility: .visible
        ) {
            Button("Merge missing records") {
                Task { await executePull(resolution: .mergeMissingRecords) }
            }
            Button("Replace local library", role: .destructive) {
                Task { await executePull(resolution: .replaceLocalLibrary) }
            }
            Button("Cancel", role: .cancel) {
                pendingSnapshot = nil
            }
        } message: {
            Text(pullDialogMessage)
        }
    }

    private var pullDialogTitle: String {
        guard let snap = pendingSnapshot else { return "Pull snapshot" }
        let device = snap.header.deviceName
        return "Newer vault from \(device)"
    }

    private var pullDialogMessage: String {
        guard let snap = pendingSnapshot else { return "" }
        let when = snap.header.timestamp.formatted(date: .abbreviated, time: .shortened)
        return """
        Snapshot dated \(when) with \(snap.header.receiptCount) receipt(s). \
        Merge keeps your existing rows and adds missing IDs. Replace clears this device’s library first (a safety backup is written locally), then imports the remote snapshot.
        """
    }

    @MainActor
    private func pushToCloud() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let url = try VaultImportExportService.pushSnapshotToCloudVault(modelContext: modelContext)
            statusMessage = "Pushed \(url.lastPathComponent)"
            UserMessageCenter.shared.present(
                title: "Cloud vault updated",
                message: "Saved to \(VaultImportExportService.cloudVaultDisplayPath())."
            )
        } catch {
            UserMessageCenter.shared.present(
                title: "Push failed",
                message: error.ratioVitaUserDescription
            )
        }
    }

    @MainActor
    private func preparePull() async {
        isBusy = true
        defer { isBusy = false }
        cloudPath = VaultImportExportService.cloudVaultDisplayPath()
        let localID = RatioVitaBackupManager.deviceIdentifier()
        guard let snap = VaultImportExportService.newestCloudSnapshot(localDeviceID: localID) else {
            UserMessageCenter.shared.present(
                title: "No cloud snapshot",
                message: "No `.rvvault` file found in \(cloudPath)."
            )
            return
        }
        pendingSnapshot = snap
        if snap.isFromOtherDevice || snap.isNewerThanLastPull {
            showPullCollision = true
        } else {
            await executePull(resolution: .mergeMissingRecords)
        }
    }

    @MainActor
    private func executePull(resolution: VaultImportExportService.PullResolution) async {
        guard let snap = pendingSnapshot else { return }
        isBusy = true
        defer {
            isBusy = false
            pendingSnapshot = nil
        }
        do {
            let summary = try VaultImportExportService.pullSnapshotFromCloudVault(
                modelContext: modelContext,
                snapshot: snap,
                resolution: resolution
            )
            statusMessage = "Imported \(summary.receiptsImported), skipped \(summary.receiptsSkippedExisting)"
            UserMessageCenter.shared.present(
                title: resolution == .mergeMissingRecords ? "Vault merged" : "Library replaced",
                message:
                "Imported \(summary.receiptsImported) receipt(s); \(summary.receiptsSkippedExisting) already on this device."
            )
        } catch {
            UserMessageCenter.shared.present(
                title: "Pull failed",
                message: error.ratioVitaUserDescription
            )
        }
    }
}
