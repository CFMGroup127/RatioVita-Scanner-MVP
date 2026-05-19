import Foundation

/// When OCR / payee matches a **Corporate Registry** (or shadow) entity and the doc looks like a check, treat as
/// **income**.
enum RegistryEntityPolarity {
    static func normalizedToken(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
            .joined(separator: " ")
    }

    static func matchesEntityName(
        _ candidate: String?,
        in entityLegalNames: [String]
    ) -> Bool {
        let key = normalizedToken(candidate ?? "")
        guard !key.isEmpty else { return false }
        let names = entityLegalNames.map { normalizedToken($0) }.filter { !$0.isEmpty }
        return names.contains { key.contains($0) || $0.contains(key) }
    }

    static func matchesRegistryEntity(
        merchant: String?,
        payee: String?,
        supplementalOCR: String?,
        entityLegalNames: [String]
    ) -> Bool {
        let names = entityLegalNames
            .map { normalizedToken($0) }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return false }
        if matchesEntityName(payee, in: entityLegalNames) { return true }
        if matchesEntityName(merchant, in: entityLegalNames) { return true }
        let hay = normalizedToken(
            [merchant, payee, supplementalOCR]
                .compactMap { $0 }
                .joined(separator: " ")
        )
        guard !hay.isEmpty else { return false }
        return names.contains { hay.contains($0) || $0.contains(hay) }
    }

    static func looksLikeCheckOrInvoice(documentKind: String?) -> Bool {
        let raw = documentKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if raw.isEmpty { return false }
        // Allow **outgoing_invoice** (your AR) — only exclude unrelated "outgoing …" labels.
        if raw.contains("outgoing"), !raw.contains("invoice") { return false }
        if raw.contains("receipt"), !raw.contains("invoice") { return false }
        if raw.contains("fuel") || raw.contains("bank_statement") { return false }
        return raw.contains("check")
            || raw.contains("cheque")
            || raw.contains("invoice")
            || raw.contains("pay_stub")
            || raw.contains("deposit")
            || raw.contains("income")
    }

    /// True when OCR clearly names a registry entity (letterhead) even if `merchant` was misparsed (e.g. phone #).
    static func supplementalOCRNamesRegistryEntity(
        _ supplementalOCR: String?,
        entityLegalNames: [String]
    ) -> Bool {
        guard let ocr = supplementalOCR?.trimmingCharacters(in: .whitespacesAndNewlines), !ocr.isEmpty else {
            return false
        }
        let lower = ocr.lowercased()
        for legal in entityLegalNames {
            let t = legal.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.count >= 6 else { continue }
            if lower.contains(t.lowercased()) { return true }
        }
        return false
    }

    /// Invoice / cheque where **you** (registry or shadow) are the funds recipient or issuer → force AR / income
    /// polarity.
    static func enforcedRegistryIncomeDocumentKind(
        documentKind: String?,
        merchant: String?,
        payee: String?,
        payor _: String?,
        supplementalOCR: String?,
        entityLegalNames: [String]
    ) -> String? {
        guard !entityLegalNames.isEmpty else { return nil }
        let registryHit = matchesRegistryEntity(
            merchant: merchant,
            payee: payee,
            supplementalOCR: supplementalOCR,
            entityLegalNames: entityLegalNames
        ) || supplementalOCRNamesRegistryEntity(supplementalOCR, entityLegalNames: entityLegalNames)

        guard registryHit else { return nil }

        let raw = documentKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let ocrLower = supplementalOCR?.lowercased() ?? ""

        // Physical cheque / income slip first — avoids boilerplate word "invoice" on remittance stubs.
        let checkLike =
            raw.contains("check")
                || raw.contains("cheque")
                || raw == "income"
                || ocrLower.contains("pay to the order")
                || ocrLower.contains("pay to order")
                || (ocrLower.contains("cheque") && ocrLower.contains("pay"))
        if checkLike {
            return "income"
        }

        let invoiceLike =
            raw.contains("invoice")
                || raw.contains("outgoing_invoice")
                || (raw.contains("outgoing") && raw.contains("invoice"))
                || ocrLower.contains("invoice #")
                || ocrLower.contains("invoice no")
                || ocrLower.contains("invoice number")
                || ocrLower.contains("tax invoice")
                || ocrLower.contains(" remit ")
                || ocrLower.contains("amount due")

        if invoiceLike, !raw.contains("bank_statement"), !ocrLower.contains("bank statement") {
            return "outgoing_invoice"
        }

        return nil
    }

    /// **Bespoke hard-lock:** invoice-like docs naming **Bespoke** (e.g. craft & catering AR) → `outgoing_invoice`.
    static func bespokeForensicHardLockOutgoingInvoice(
        documentKind: String?,
        merchant: String?,
        payee: String?,
        payor: String?,
        supplementalOCR: String?
    ) -> String? {
        let corpus = [merchant, payee, payor, supplementalOCR]
            .compactMap { $0 }
            .joined(separator: "\n")
            .lowercased()
        guard corpus.contains("bespoke") else { return nil }

        let raw = documentKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let ocrLower = supplementalOCR?.lowercased() ?? ""

        let checkLike =
            raw.contains("check")
                || raw.contains("cheque")
                || raw == "income"
                || ocrLower.contains("pay to the order")
                || ocrLower.contains("pay to order")
                || (ocrLower.contains("cheque") && ocrLower.contains("pay"))
        if checkLike { return nil }

        let invoiceLike =
            raw.contains("invoice")
                || raw.contains("outgoing_invoice")
                || (raw.contains("outgoing") && raw.contains("invoice"))
                || ocrLower.contains("invoice #")
                || ocrLower.contains("invoice no")
                || ocrLower.contains("invoice number")
                || ocrLower.contains("tax invoice")
                || ocrLower.contains(" remit ")
                || ocrLower.contains("amount due")

        guard invoiceLike, !raw.contains("bank_statement"), !ocrLower.contains("bank statement") else { return nil }
        return "outgoing_invoice"
    }

    static func looksLikeCheckDocument(documentKind: String?, supplementalOCR: String?) -> Bool {
        if looksLikeCheckOrInvoice(documentKind: documentKind) { return true }
        let ocr = supplementalOCR?.lowercased() ?? ""
        return ocr.contains("pay to the order")
            || ocr.contains("pay to order")
            || ocr.contains("payee")
            || (ocr.contains("cheque") && ocr.contains("pay"))
    }

    /// Registry (or shadow) entity as payee on a check → **Income / Check** (positive polarity).
    static func refinedDocumentKindForRegistryIncome(
        documentKind: String?,
        merchant: String?,
        payee: String?,
        supplementalOCR: String?,
        entityLegalNames: [String]
    ) -> String? {
        enforcedRegistryIncomeDocumentKind(
            documentKind: documentKind,
            merchant: merchant,
            payee: payee,
            payor: nil,
            supplementalOCR: supplementalOCR,
            entityLegalNames: entityLegalNames
        )
    }
}
