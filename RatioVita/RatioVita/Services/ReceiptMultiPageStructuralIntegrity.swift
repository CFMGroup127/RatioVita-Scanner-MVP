import Foundation
import SwiftData

/// **“Wait a minute”** structural pass: multi-page imports that look like unrelated documents merged into one PDF.
@MainActor
enum ReceiptMultiPageStructuralIntegrity {
    private static let forensicTag = "[Forensic] Multi-page mismatch"

    /// After a multi-page receipt is persisted, compare page-level OCR heuristics and flag obvious hodgepodge merges.
    static func evaluatePersistedReceipt(receipt: Receipt, context: ModelContext) throws {
        let pages = receipt.images.sorted { $0.pageIndex < $1.pageIndex }
        guard pages.count >= 2 else { return }

        var merchants: [String] = []
        var docNumbers: [String] = []
        for p in pages {
            let ocr = p.ocrText ?? ""
            let ex = OCRParsing.extractData(from: ocr)
            let m = ex.merchant?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            merchants.append(m)
            let inv = ex.documentNumber?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            docNumbers.append(inv)
        }

        var mismatchPairs = 0
        for i in 1..<merchants.count {
            let a = merchants[i - 1]
            let b = merchants[i]
            if distinctMerchants(a, b) {
                mismatchPairs += 1
            }
        }

        var invoiceNumberClash = false
        let filledNums = docNumbers.enumerated().filter { !$0.element.isEmpty }
        if filledNums.count >= 2 {
            let first = filledNums[0].element
            for j in 1..<filledNums.count {
                if filledNums[j].element != first {
                    invoiceNumberClash = true
                    break
                }
            }
        }

        let firstOcr = (pages.first?.ocrText ?? "").lowercased()
        let lastOcr = (pages.last?.ocrText ?? "").lowercased()
        let mixedModalities = pages.count >= 2
            &&
            ((firstOcr
                    .contains("invoice") && (lastOcr.contains("pay to the order of") || lastOcr.contains("cheque")))
                ||
                (lastOcr
                    .contains("invoice") && (firstOcr.contains("pay to the order of") || firstOcr.contains("cheque"))))

        guard mismatchPairs > 0 || invoiceNumberClash || mixedModalities else { return }

        let ann = receipt.annotations?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if ann.localizedCaseInsensitiveContains(Self.forensicTag) { return }

        let hint =
            "\(Self.forensicTag) — pages look like different jobs or modalities; use **Explode All Pages** in the receipt toolbar, then file each record."
        receipt.annotations = ann.isEmpty ? hint : "\(ann)\n\(hint)"
        /// Strong signals only: a single noisy OCR merchant mismatch should **annotate** but stay in the main library.
        /// Invoice # clashes, modality mixes, or **two or more** merchant-boundary mismatches queue Review.
        let queueReview =
            invoiceNumberClash || mixedModalities || mismatchPairs >= 2
        if queueReview {
            receipt.pendingHumanReview = true
        }
        try context.save()
    }

    private static func distinctMerchants(_ a: String, _ b: String) -> Bool {
        guard a.count >= 4, b.count >= 4 else { return false }
        if a == b { return false }
        if a.contains(b) || b.contains(a) { return false }
        let ta = Set(a.split(whereSeparator: \.isWhitespace).map(String.init))
        let tb = Set(b.split(whereSeparator: \.isWhitespace).map(String.init))
        let inter = ta.intersection(tb).filter { $0.count > 2 }
        if inter.count >= 2 { return false }
        return true
    }
}
