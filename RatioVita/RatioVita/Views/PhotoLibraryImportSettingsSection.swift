#if os(iOS)
import SwiftData
import SwiftUI

/// Settings controls for bulk Photo Library ingest (resume-safe registry).
struct PhotoLibraryImportSettingsSection: View {
    @Environment(\.modelContext) private var modelContext

    let ocrEnabled: Bool
    let compressionEnabled: Bool

    @AppStorage("autoScanPhotosOnLaunch") private var autoScanPhotosOnLaunch = false

    @State private var pendingCount: Int?
    @State private var registryCount = 0
    @State private var isImporting = false
    @State private var importStatus: String?
    @State private var showImportConfirm = false
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Divider()

            Text("Bulk import from Photos")
                .font(DesignSystem.Typography.bodyEmphasized)

            Text(
                "Scans your Photo Library for images RatioVita has not imported yet (tracked by Apple’s local asset id). Use this for large backlogs instead of manual multi-select."
            )
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(Color.ratioVitaTextSecondary)

            Toggle(isOn: $autoScanPhotosOnLaunch) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-scan on launch")
                        .font(DesignSystem.Typography.subheadline)
                    Text("Quietly imports new photos in the background when you open the app.")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                }
            }

            if let pendingCount {
                Text("\(pendingCount) new image(s) ready · \(registryCount) already imported")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            if let importStatus {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(importStatus)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                }
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button("Refresh count") {
                    Task { await refreshCounts() }
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)

                Button("Import new photos") {
                    showImportConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ratioVitaPrimary)
                .disabled(isImporting || (pendingCount ?? 0) == 0)
            }

            Button("Reset import registry", role: .destructive) {
                showResetConfirm = true
            }
            .font(DesignSystem.Typography.caption)
            .disabled(isImporting)
        }
        .task { await refreshCounts() }
        .confirmationDialog("Import new photos?", isPresented: $showImportConfirm, titleVisibility: .visible) {
            Button("Import \(pendingCount ?? 0) photo(s)") {
                Task { await runImport() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Each photo becomes its own receipt in Review. Keep the app open; large libraries may take a while.")
        }
        .confirmationDialog("Reset import registry?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                PhotoLibraryScanManager.resetImportRegistry()
                Task { await refreshCounts() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "RatioVita will treat all Photo Library images as new on the next bulk import. Existing receipts are not deleted."
            )
        }
    }

    @MainActor
    private func refreshCounts() async {
        registryCount = PhotoLibraryScanManager.importedIdentifierCount()
        pendingCount = await PhotoLibraryScanManager.pendingAssetCount()
    }

    @MainActor
    private func runImport() async {
        isImporting = true
        defer {
            isImporting = false
            importStatus = nil
        }
        let options = ReceiptIngestOptions(pendingHumanReview: true, scannedViaCamera: false, vaultPathPrefix: nil)
        let summary = await PhotoLibraryScanManager.importPending(
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            options: options,
            ingest: { scan, opts in
                try await ReceiptPersistence.saveScanResult(
                    scan,
                    context: modelContext,
                    compressionEnabled: compressionEnabled,
                    pendingHumanReview: opts.pendingHumanReview,
                    scannedViaCamera: opts.scannedViaCamera,
                    deferGeminiRefinement: false,
                    vaultPathPrefix: opts.vaultPathPrefix
                )
            },
            onProgress: { processed, total, _ in
                importStatus = total > 0 ? "Importing \(processed)/\(total)…" : nil
            }
        )
        await refreshCounts()
        RatioVitaBackupManager.archiveAfterSignificantWrite(modelContext: modelContext)
        UserMessageCenter.shared.present(
            title: "Photo import complete",
            message: "Imported \(summary.imported) receipt(s). Skipped \(summary.failed) failure(s)."
        )
    }
}
#endif

#if os(iOS)
import SwiftData

/// Launch hook for optional Photo Library auto-scan (Sprint VV).
enum PhotoLibraryLaunchAutoScan {
    @MainActor
    static func runIfEnabled(modelContext: ModelContext) async {
        guard UserDefaults.standard.bool(forKey: "autoScanPhotosOnLaunch") else { return }
        let pending = await PhotoLibraryScanManager.pendingAssetCount()
        guard pending > 0 else { return }

        let ocr = UserDefaults.standard.object(forKey: "ocrEnabled") as? Bool ?? true
        let compression = UserDefaults.standard.object(forKey: "compressionEnabled") as? Bool ?? false
        let options = ReceiptIngestOptions(pendingHumanReview: true, scannedViaCamera: false, vaultPathPrefix: nil)
        _ = await PhotoLibraryScanManager.importPending(
            ocrEnabled: ocr,
            compressionEnabled: compression,
            options: options,
            ingest: { scan, opts in
                try await ReceiptPersistence.saveScanResult(
                    scan,
                    context: modelContext,
                    compressionEnabled: compression,
                    pendingHumanReview: opts.pendingHumanReview,
                    scannedViaCamera: opts.scannedViaCamera,
                    deferGeminiRefinement: false,
                    vaultPathPrefix: opts.vaultPathPrefix
                )
            },
            onProgress: { _, _, _ in }
        )
        RatioVitaBackupManager.archiveAfterSignificantWrite(modelContext: modelContext)
    }
}
#endif
