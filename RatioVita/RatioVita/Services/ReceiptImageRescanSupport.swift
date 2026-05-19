import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// Replace a single `ReceiptImage` raster from disk (JPEG/PNG/HEIC/TIFF) and re-run the import OCR pipeline.
@MainActor
enum ReceiptImageRescanSupport {
    static func replacePageRasterFromFile(
        receiptImage: ReceiptImage,
        fileURL: URL,
        modelContext: ModelContext
    ) async throws {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { fileURL.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: fileURL)
        guard let raw = RVImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
            throw RescanError.couldNotDecodeImage
        }
        let result = try await ReceiptScanPipeline.processImported(
            image: raw,
            ocrEnabled: true,
            compressionEnabled: true
        )
        guard let page = result.scannedPages.first else { throw RescanError.emptyScan }
        receiptImage.replaceRasterAndOCR(image: page.image, ocrText: page.ocrText, compressionQuality: 0.9)

        if let receipt = receiptImage.receipt {
            try ReceiptForensicRefresh.reapplyHeuristicPolarityAndShadow(receipt: receipt, context: modelContext)
        }
    }

    enum RescanError: LocalizedError {
        case couldNotDecodeImage
        case emptyScan

        var errorDescription: String? {
            switch self {
                case .couldNotDecodeImage: "Could not read that image file."
                case .emptyScan: "Scan pipeline returned no pages."
            }
        }
    }
}
