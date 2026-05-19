import Foundation
import SwiftData

/// High-level lifecycle for document graph / ledger linking (UI + future automation).
enum ReceiptDocumentGraphStatus: String, CaseIterable, Sendable {
    case pending = "Pending"
    case verified = "Verified"
    case linked = "Linked"

    var detailBlurb: String {
        switch self {
            case .pending:
                "OCR / extraction is saved; review and verify when ready."
            case .verified:
                "You confirmed totals, dates, and line items."
            case .linked:
                "Matched to a ledger / bank transaction."
        }
    }
}

extension Receipt {
    /// Derived state: **Linked** wins over **Verified** over **Pending**.
    var documentGraphStatus: ReceiptDocumentGraphStatus {
        if isLedgerLinked { return .linked }
        if isVerified { return .verified }
        return .pending
    }
}
