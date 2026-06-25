import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class ReceiptsViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var searchText: String = ""
    @Published var showScanner = false

    // Mutable so dependencies can be updated without replacing the StateObject.
    private var scannerStorage: ScannerService?
    private(set) var context: ModelContext?

    /// Serializes overlapping ingest saves (e.g. duplicate “Send to review” firing two `Task`s).
    private var ingestSaveInFlight = false

    @AppStorage("ocrEnabled") private var ocrEnabled: Bool = true
    @AppStorage("compressionEnabled") private var compressionEnabled: Bool = false
    @AppStorage("mirrorScannedReceiptsToPhotoLibrary") private var mirrorScannedReceiptsToPhotoLibrary: Bool = true

    init() {}

    /// Installs the preview scanner once — never mutates during SwiftUI body evaluation.
    func bootstrapScannerIfNeeded() {
        guard scannerStorage == nil else { return }
        scannerStorage = PreviewScannerService()
    }

    /// Scanner passed into capture sheets after explicit bootstrap (read-only accessor).
    var scannerForUI: ScannerService {
        guard let scannerStorage else {
            assertionFailure("bootstrapScannerIfNeeded() must run before presenting scanner UI")
            return PreviewScannerService()
        }
        return scannerStorage
    }

    // Update dependencies safely (avoid reassigning the @StateObject in the view).
    func updateDependencies(scanner: ScannerService? = nil, context: ModelContext) {
        if let scanner {
            scannerStorage = scanner
        }
        self.context = context
    }

    private func requireContext() -> ModelContext? {
        context
    }

    /// Swaps the preview placeholder for a production AVFoundation scanner only when capture is requested.
    func ensureProductionScannerIfNeeded() {
        guard scannerStorage == nil || scannerStorage is PreviewScannerService else { return }
        #if os(iOS)
        #if targetEnvironment(simulator)
        return
        #else
        scannerStorage = RealScannerService()
        #endif
        #elseif os(visionOS)
        #if targetEnvironment(simulator)
        return
        #else
        scannerStorage = RealScannerService()
        #endif
        #elseif os(macOS)
        scannerStorage = MacAVScannerService()
        #endif
    }

    func scanAndSave() async {
        bootstrapScannerIfNeeded()
        ensureProductionScannerIfNeeded()
        guard let scanner = scannerStorage else { return }
        isScanning = true
        defer { isScanning = false }

        do {
            let result = try await scanner.scanReceipt(ocrEnabled: ocrEnabled, compressionEnabled: compressionEnabled)
            let opts = ReceiptIngestOptions.filedImmediateCamera(true)
            try await persistScanResult(result, options: opts)
            if mirrorScannedReceiptsToPhotoLibrary, !opts.pendingHumanReview, opts.scannedViaCamera {
                await ReceiptPhotosLibraryExporter.mirrorReceiptAfterSave(scan: result)
            }
        } catch {
            UserMessageCenter.shared.present(
                title: "Scan failed",
                message: error.ratioVitaUserDescription
            )
        }
    }

    func delete(_ receipts: [Receipt]) {
        guard let context = requireContext() else { return }
        let now = Date()
        for r in receipts {
            r.trashedAt = now
        }
        do {
            try ModelContextMainActorSave.saveThrows(context)
        } catch {
            UserMessageCenter.shared.present(
                title: "Couldn't update library",
                message: error.ratioVitaUserDescription
            )
        }
    }
    
    // MARK: - Scanner Presentation
    
    func showScannerUI() {
        showScanner = true
    }
    
    func importManuscriptFile(at url: URL, vaultPathPrefix: String? = nil) async {
        guard let context = requireContext() else { return }
        isScanning = true
        defer { isScanning = false }
        do {
            let summary = try ManuscriptVaultImportService.importManuscriptFile(
                at: url,
                vaultPathPrefix: vaultPathPrefix,
                context: context
            )
            UserMessageCenter.shared.present(
                title: "Manuscript archived",
                message:
                "“\(summary.title)” is in the Manuscript Vault and Media Core knowledge graph. Vault path: \(ManuscriptVaultImportService.defaultVaultPrefix)."
            )
            showScanner = false
        } catch {
            UserMessageCenter.shared.present(
                title: "Manuscript import failed",
                message: error.ratioVitaUserDescription
            )
        }
    }

    func handleScanResult(_ result: ScanResult, options: ReceiptIngestOptions) async {
        guard !ingestSaveInFlight else {
            UserMessageCenter.shared.present(
                title: "Still saving",
                message: "Please wait for the current import to finish."
            )
            return
        }
        ingestSaveInFlight = true
        defer { ingestSaveInFlight = false }

        isScanning = true
        defer { isScanning = false }

        guard !result.scannedPages.isEmpty else {
            UserMessageCenter.shared.present(
                title: "Nothing to save",
                message: "No receipt image was captured. Please try scanning or importing again."
            )
            return
        }

        await Task.yield()

        do {
            try await persistScanResult(result, options: options)
            if mirrorScannedReceiptsToPhotoLibrary, !options.pendingHumanReview, options.scannedViaCamera {
                await ReceiptPhotosLibraryExporter.mirrorReceiptAfterSave(scan: result)
            }
        } catch {
            UserMessageCenter.shared.present(
                title: "Couldn't save receipt",
                message: error.ratioVitaUserDescription
            )
        }
    }

    private func persistScanResult(_ result: ScanResult, options: ReceiptIngestOptions) async throws {
        guard let context = requireContext() else { return }
        let apiKeyPresent = !GeminiAPIKeyResolver.resolveAPIKeyTrimmed().isEmpty
        let deferGemini = options.scannedViaCamera
            && GeminiAPIKeyResolver.isGeminiExtractionEnabled()
            && apiKeyPresent

        try await ReceiptPersistence.saveScanResult(
            result,
            context: context,
            compressionEnabled: compressionEnabled,
            pendingHumanReview: options.pendingHumanReview,
            scannedViaCamera: options.scannedViaCamera,
            deferGeminiRefinement: deferGemini,
            vaultPathPrefix: options.vaultPathPrefix
        )
    }

    /// DEBUG / QA: import real scans bundled as `Resources/RVArchive2020__*` (flattened 2020 archive) through the same
    /// pipeline as
    /// file import.
    func importBundledHistoricalArchive(limit: Int?) async {
        guard let context = requireContext() else { return }
        isScanning = true
        defer { isScanning = false }

        do {
            let count = try await BundledReceiptArchiveImporter.importArchive(
                into: context,
                limit: limit,
                ocrEnabled: ocrEnabled,
                compressionEnabled: compressionEnabled
            )
            let detail = limit.map { "First \($0) file(s) from the bundle." } ?? "All files in the bundle."
            UserMessageCenter.shared.present(
                title: "Archive import complete",
                message: "Imported \(count) receipt(s). \(detail) Each used Vision OCR and OCRParsing."
            )
        } catch {
            UserMessageCenter.shared.present(
                title: "Archive import failed",
                message: error.ratioVitaUserDescription
            )
        }
    }
}
