import SwiftData
import SwiftUI

/// Auxiliary scan entry point — delegates to the same multi-page capture sheet as **ReceiptsView**.
struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("ocrEnabled") private var ocrEnabled: Bool = true
    @AppStorage("compressionEnabled") private var compressionEnabled: Bool = false

    let scanner: any ScannerService
    var onScanPersisted: (@MainActor () async -> Void)?

    init(
        scanner: any ScannerService = PreviewScannerService(),
        onScanPersisted: (@MainActor () async -> Void)? = nil
    ) {
        self.scanner = scanner
        self.onScanPersisted = onScanPersisted
    }

    var body: some View {
        CameraCaptureView(
            scanner: scanner,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            onSubmit: { scanResult, options in
                await persistScanResult(scanResult, options: options)
                await onScanPersisted?()
                dismiss()
            },
            onManuscriptFile: { url in
                _ = url
            }
        )
    }

    @MainActor
    private func persistScanResult(_ result: ScanResult, options: ReceiptIngestOptions) async {
        do {
            let apiKeyPresent = !GeminiAPIKeyResolver.resolveAPIKeyTrimmed().isEmpty
            let deferGemini = options.scannedViaCamera
                && GeminiAPIKeyResolver.isGeminiExtractionEnabled()
                && apiKeyPresent
            try await ReceiptPersistence.saveScanResult(
                result,
                context: modelContext,
                compressionEnabled: compressionEnabled,
                pendingHumanReview: options.pendingHumanReview,
                scannedViaCamera: options.scannedViaCamera,
                deferGeminiRefinement: deferGemini,
                vaultPathPrefix: options.vaultPathPrefix
            )
        } catch {
            UserMessageCenter.shared.present(
                title: "Could not save scan",
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }
}

#Preview {
    ScannerView()
}
