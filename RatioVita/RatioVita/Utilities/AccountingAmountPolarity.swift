import Foundation

/// Canonical **signed** amounts for RatioVita: money **in** (income, receivables, payroll to you) is **positive**;
/// money **out** (retail receipts, vendor invoices, fuel) is **negative**. Bank rows follow the same rule
/// (credits positive, debits negative).
enum AccountingAmountPolarity {
    enum SignExpectation: Sendable {
        case mustBePositive
        case mustBeNegative
        case unspecified
    }

    /// User-facing document types mapped to sign expectations.
    static func signExpectation(for documentType: DocumentTypeOption) -> SignExpectation {
        switch documentType {
            case .incomeOrCheck, .outgoingInvoice, .paycheck:
                .mustBePositive
            case .receipt, .invoice, .fuel:
                .mustBeNegative
            case .statement, .timeSheet, .warranty, .insurance, .maintenanceLog, .canadianTaxSlip, .dealMemo,
                 .manuscript:
                .unspecified
        }
    }

    /// Enforces sign for a persisted **receipt** total (and same rule for optional subtotal / tax when non-nil).
    static func canonicalTotal(documentType: DocumentTypeOption, amount: Decimal) -> Decimal {
        validateSign(documentType: documentType, amount: amount)
    }

    /// Public alias requested for Sprint E: flip when the amount contradicts the document class.
    static func validateSign(documentType: DocumentTypeOption, amount: Decimal) -> Decimal {
        switch signExpectation(for: documentType) {
            case .mustBePositive:
                amount < 0 ? -amount : amount
            case .mustBeNegative:
                amount > 0 ? -amount : amount
            case .unspecified:
                amount
        }
    }

    static func canonicalOptionalAmount(documentType: DocumentTypeOption, amount: Decimal?) -> Decimal? {
        guard let amount else { return nil }
        return validateSign(documentType: documentType, amount: amount)
    }

    /// Best-effort type before the user picks a picker value (Gemini `document_kind` + OCR hints).
    static func provisionalDocumentType(documentKind: String?) -> DocumentTypeOption {
        let raw = documentKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if raw.isEmpty { return .receipt }
        if raw.contains("pay_stub") || raw == "paystub" { return .paycheck }
        if raw.contains("time_sheet") || raw.contains("timesheet") { return .timeSheet }
        if raw.contains("canadian_t4") || raw.contains("canadian_t4a") || raw.contains("canadian_roe")
            || raw.contains("canadian_tax") || raw.contains("tax_slip") || raw.contains("statement_of_remuneration")
            || raw.contains("record_of_employment")
        {
            return .canadianTaxSlip
        }
        if raw.contains("t4a") || raw.contains("t4-a") { return .canadianTaxSlip }
        if raw.range(of: #"\bt4\b"#, options: .regularExpression) != nil { return .canadianTaxSlip }
        if raw.contains("bank_statement") { return .statement }
        if raw == "outgoing_invoice" ||
            (raw.contains("outgoing") && raw.contains("invoice")) { return .outgoingInvoice }
        if raw.contains("income") || raw.contains("check") || raw.contains("deposit") { return .incomeOrCheck }
        if raw.contains("invoice") { return .invoice }
        if raw.contains("statement") { return .statement }
        if raw == "fuel" || raw.contains("fuel_receipt") || raw.contains("gas_receipt") || raw == "gas" {
            return .fuel
        }
        return .receipt
    }
}
