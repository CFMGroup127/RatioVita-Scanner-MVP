import Foundation
import SwiftData

/// Re-runs **heuristic + polarity + shadow registry** on an existing receipt (e.g. after **Explode** splits pages).
@MainActor
enum ReceiptForensicRefresh {
    static func reapplyHeuristicPolarityAndShadow(receipt: Receipt, context: ModelContext) throws {
        let ocr = receipt.images.sorted { $0.pageIndex < $1.pageIndex }
            .compactMap(\.ocrText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let base = OCRParsing.extractData(from: ocr)
        let names = ReceiptPersistence.fetchPolarityEntityLegalNames(context: context)
        let merged = ReceiptStructuredExtractor.polarizedHeuristic(
            base,
            supplementalOCR: ocr.isEmpty ? nil : ocr,
            registryEntityLegalNames: names
        )
        try ReceiptPersistence.applyGeminiRefinementProfile(
            merged: merged,
            extractionSource: "heuristic_forensic_refresh",
            receiptID: receipt.id,
            context: context
        )
        try context.save()
    }
}
