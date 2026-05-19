import Foundation
import SwiftData

/// Re-runs structured extraction on pending review receipts (payee / polarity / shadow).
@MainActor
enum ReceiptBulkGeminiReanalysis {
    struct Progress: Sendable {
        var completed: Int
        var total: Int
        var currentMerchant: String?
    }

    static func reanalyzePending(
        receipts: [Receipt],
        context: ModelContext,
        onProgress: (@Sendable (Progress) -> Void)? = nil
    ) async throws {
        let pending = receipts.filter { $0.pendingHumanReview && $0.trashedAt == nil }
        let total = pending.count
        var done = 0
        for receipt in pending {
            let ocr = receipt.images
                .sorted { $0.pageIndex < $1.pageIndex }
                .compactMap(\.ocrText)
                .joined(separator: "\n\n")
            guard !ocr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                done += 1
                onProgress?(Progress(completed: done, total: total, currentMerchant: receipt.merchant))
                continue
            }
            let heuristic = OCRParsing.extractData(from: ocr)
            let entityNames = ReceiptPersistence.fetchPolarityEntityLegalNames(context: context)
            let (merged, source) = await ReceiptStructuredExtractor.extractMerged(
                combinedOCRText: ocr,
                heuristic: heuristic,
                registryEntityLegalNames: entityNames
            )
            try ReceiptPersistence.applyGeminiRefinementProfile(
                merged: merged,
                extractionSource: source,
                receiptID: receipt.id,
                context: context
            )
            if receipt.taxCategory == nil || receipt.taxCategory?.isEmpty == true {
                let corpus = [receipt.merchant, ocr, merged.payee, merged.payor].compactMap { $0 }
                    .joined(separator: " ")
                if let rd = TaxCategoryCatalog.suggestFromCorpus(corpus) {
                    receipt.taxCategory = rd
                } else if let tax = ReceiptFinanceAgentsHeuristics.suggestTaxCategory(fromCorpus: corpus) {
                    receipt.taxCategory = tax
                }
            }
            done += 1
            onProgress?(Progress(completed: done, total: total, currentMerchant: receipt.merchant))
        }
        try context.save()
    }
}
