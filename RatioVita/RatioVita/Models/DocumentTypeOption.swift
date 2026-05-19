import Foundation

/// User-facing document classification for filing + linking.
enum DocumentTypeOption: String, CaseIterable, Identifiable, Codable, Hashable {
    case receipt = "Receipt"
    case invoice = "Invoice"
    case statement = "Statement"
    case paycheck = "Paycheck"
    case timeSheet = "Time Sheet"
    case incomeOrCheck = "Income / Check"
    case outgoingInvoice = "Outgoing Invoice"
    case warranty = "Warranty"
    case insurance = "Insurance"
    case maintenanceLog = "Maintenance Log"
    case fuel = "Fuel"
    /// T4, T4A, ROE, and similar CRA **slips** (not generic “tax receipts” for HST on purchases).
    case canadianTaxSlip = "Canadian Tax Slip"
    /// EP / production deal memo — rates archive, not a purchase receipt.
    case dealMemo = "Deal Memo"

    var id: String { rawValue }

    /// Maps persisted strings (including legacy `"Document"`) to a valid picker value.
    static func fromStored(_ raw: String) -> DocumentTypeOption {
        if let v = DocumentTypeOption(rawValue: raw) { return v }
        if raw == "Document" { return .receipt }
        return .receipt
    }

    /// Matches receipt detail / edit UX: hide business-use % for income-like document types.
    var showsBusinessUsePercentControls: Bool {
        switch self {
            case .incomeOrCheck, .outgoingInvoice, .paycheck, .statement, .canadianTaxSlip, .dealMemo:
                false
            default:
                true
        }
    }

    /// Standard subtotal / tax / total block (hidden for deal memos and time sheets).
    var showsRetailFinancialFields: Bool {
        switch self {
            case .dealMemo, .timeSheet:
                false
            default:
                true
        }
    }
}
