import Foundation

/// Heuristic document kind / type before the user opens Review.
enum DocumentKindAutoClassifier {
    /// Returns updated `documentKind` and optional `DocumentTypeOption` when confidence is high.
    static func classify(
        combinedOCR: String,
        currentDocumentKind: String?
    ) -> (documentKind: String?, documentType: DocumentTypeOption?) {
        let page1 = firstPageOCR(from: combinedOCR)
        if DealMemoSniper.parsePage1(combinedOCR: page1) != nil {
            return ("deal_memo", .dealMemo)
        }
        if ChequeStubParser.parse(combinedOCR: combinedOCR) != nil {
            return ("income", .incomeOrCheck)
        }
        let lower = combinedOCR.lowercased()
        if lower.contains("deal memo") || lower.contains("deal terms")
            || lower.contains("personnel services agreement")
        {
            return ("deal_memo", .dealMemo)
        }
        if let k = currentDocumentKind?.trimmingCharacters(in: .whitespacesAndNewlines), !k.isEmpty {
            return (k, nil)
        }
        return (nil, nil)
    }

    private static func firstPageOCR(from combined: String) -> String {
        let parts = combined.components(separatedBy: "\n\n")
        if let first = parts.first, first.count >= 80 { return first }
        return String(combined.prefix(4000))
    }
}
