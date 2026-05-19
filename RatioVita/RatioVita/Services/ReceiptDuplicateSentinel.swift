import Foundation
import SwiftData

/// Duplicate detection beyond identical file bytes: same **invoice # + document date + total** suggests a rescan.
enum ReceiptDuplicateSentinel {
    static func normalizedInvoiceToken(_ raw: String?) -> String {
        guard let raw else { return "" }
        return raw
            .lowercased()
            .filter { $0.isNumber || $0.isLetter }
    }

    /// True when `b` looks like the same commercial invoice as `a` (do **not** treat different invoice # as dup).
    static func isLikelyDuplicateReceipt(a: Receipt, b: Receipt) -> Bool {
        guard a.id != b.id else { return false }
        let ta = normalizedInvoiceToken(a.documentNumber)
        let tb = normalizedInvoiceToken(b.documentNumber)
        guard ta.count >= 2, ta == tb else { return false }
        let cal = Calendar.current
        guard let da = a.transactionDate, let db = b.transactionDate, cal.isDate(da, inSameDayAs: db) else {
            return false
        }
        return abs(a.total) == abs(b.total)
    }

    /// Other receipts in the library (excluding trashed / optional review-only) that look like duplicates of `receipt`.
    @MainActor
    static func findLikelyDuplicates(
        of receipt: Receipt,
        context: ModelContext,
        includePendingReview: Bool
    ) -> [Receipt] {
        let fd = FetchDescriptor<Receipt>(sortBy: [SortDescriptor(\Receipt.createdAt, order: .reverse)])
        let all = (try? context.fetch(fd)) ?? []
        return all.filter { other in
            if other.id == receipt.id { return false }
            if other.trashedAt != nil { return false }
            if !includePendingReview, other.pendingHumanReview { return false }
            return isLikelyDuplicateReceipt(a: receipt, b: other)
        }
    }
}
