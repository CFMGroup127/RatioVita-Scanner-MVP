import Foundation

/// Canadian **T4 / T4A / ROE** (and related) classification + “auto-lock” once filed into the vault.
enum ReceiptCanadianTaxSlipPolicy {
    /// When OCR / Gemini did not emit a `documentKind`, infer a stable token from raw text (aggressive CRA forms).
    static func inferDocumentKindSupplement(from ocr: String) -> String? {
        let t = ocr.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        guard !t.isEmpty else { return nil }

        if t.contains("record of employment") || t.range(of: #"\broe\b"#, options: .regularExpression) != nil {
            return "canadian_roe"
        }
        if t.contains("t4a") || t.contains("t4-a") {
            return "canadian_t4a"
        }
        if t.range(of: #"\bt4\b"#, options: .regularExpression) != nil
            || t.contains("statement of remuneration")
            || (t.contains("feuillet") && t.contains("remuneration"))
        {
            return "canadian_t4"
        }
        return nil
    }

    /// Maps extractor / Gemini `documentKind` tokens onto `Receipt.documentType` when they denote Canadian tax slips.
    static func applyModelKindToReceiptDocumentType(receipt: Receipt, documentKind: String?) {
        guard let raw = documentKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else {
            return
        }
        let taxSlip = DocumentTypeOption.canadianTaxSlip.rawValue
        if raw == "canadian_t4" || raw == "canadian_t4a" || raw == "canadian_roe" || raw == "canadian_tax_slip"
            || raw == "tax_slip" || raw.contains("statement_of_remuneration")
            || raw.contains("record_of_employment") || raw.contains("t4a") || raw.contains("t4-a")
            || raw.range(of: #"\bt4\b"#, options: .regularExpression) != nil
        {
            receipt.documentType = taxSlip
            return
        }
    }

    /// After filing rules set `vaultPathPrefix`, auto-verify Canadian tax slips so they do not linger in review limbo.
    @MainActor
    static func applyAutoLockIfNeeded(receipt: Receipt) {
        let dt = DocumentTypeOption.fromStored(receipt.documentType)
        guard dt == .canadianTaxSlip else { return }
        let prefix = receipt.vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prefix.isEmpty else { return }
        receipt.isVerified = true
        receipt.reviewChecklistDone = true
        receipt.pendingHumanReview = false
    }
}
