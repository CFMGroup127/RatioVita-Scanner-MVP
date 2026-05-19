import Foundation
import SwiftData

/// Guards extracted currency fields against OCR garbage (phone numbers, routing IDs, etc.).
enum ReceiptFinancialSanity {
    /// CRA-scale ceiling for a single retail receipt line or tax line.
    static let maxPlausibleReceiptAmount: Decimal = 250_000

    static func isPlausibleCurrencyAmount(_ amount: Decimal?) -> Bool {
        guard let amount else { return true }
        guard amount >= 0 else { return false }
        return amount <= maxPlausibleReceiptAmount
    }

    static func clampOptional(_ amount: Decimal?) -> Decimal? {
        guard let amount else { return nil }
        guard amount >= 0 else { return nil }
        if amount > maxPlausibleReceiptAmount { return nil }
        return amount
    }

    /// Deal memos / contracts are not purchase receipts — strip bogus transaction totals.
    @MainActor
    static func applyDealMemoFinancialPolicy(
        to receipt: Receipt,
        combinedOCR: String? = nil,
        context: ModelContext? = nil
    ) {
        let dt = DocumentTypeOption.fromStored(receipt.documentType)
        guard dt == .dealMemo else { return }
        receipt.total = 0
        receipt.subtotalAmount = nil
        receipt.taxAmount = nil
        if receipt.currencyCode.uppercased() == "EUR" {
            receipt.currencyCode = ReceiptCurrency.CAD.code
        }
        if let ocr = combinedOCR, let ctx = context,
           TaxRegistrationAnchor.scrubRegistrationTokensFromFinancials(combinedOCR: ocr, context: ctx)
        {
            receipt.taxAmount = nil
        }
    }

    /// Sanitize optional amounts before persisting or displaying after extraction.
    static func sanitizedExtractedAmounts(
        documentKind: String?,
        subtotal: Decimal?,
        taxAmount: Decimal?,
        total: Decimal?,
        combinedOCR: String? = nil,
        context: ModelContext? = nil
    ) -> (subtotal: Decimal?, taxAmount: Decimal?, total: Decimal?) {
        let dk = documentKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if dk == "deal_memo" || dk.contains("deal_memo") || dk.contains("deal memo") {
            return (nil, nil, 0)
        }
        var tax = clampOptional(taxAmount)
        if let taxVal = tax, let ctx = context {
            let digits = "\(taxVal)".filter(\.isNumber)
            if TaxRegistrationAnchor.isKnownRegistrationNumber(digits, context: ctx) {
                tax = nil
            }
        }
        if let ocr = combinedOCR, let ctx = context,
           TaxRegistrationAnchor.scrubRegistrationTokensFromFinancials(combinedOCR: ocr, context: ctx)
        {
            tax = nil
        }
        let sub = clampOptional(subtotal)
        var tot = clampOptional(total) ?? total
        if let tax, let sub, tax > sub * 2, tax > 10000 {
            tot = tot == total ? nil : tot
            return (sub, nil, tot)
        }
        if !isPlausibleCurrencyAmount(tax) || !isPlausibleCurrencyAmount(tot) {
            return (sub, nil, isPlausibleCurrencyAmount(tot) ? tot : nil)
        }
        return (sub, tax, tot)
    }
}
