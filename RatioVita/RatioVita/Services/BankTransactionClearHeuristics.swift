import Foundation

/// After a user manually clears one bank row, find other **unmatched** rows that look like duplicates (same statement
/// file, amount, currency, and memo) so the queue stays tidy without over-clearing unrelated postings.
enum BankTransactionClearHeuristics {
    static func peersToAutoClear(matching cleared: BankTransaction, in all: [BankTransaction]) -> [BankTransaction] {
        let memo = (cleared.memo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !memo.isEmpty else { return [] }
        guard let importFile = BankStatementImportCoordinator
            .sourceImportFilename(fromExternalReference: cleared.externalReference) else
        {
            return []
        }

        return all.filter { other in
            guard other.id != cleared.id else { return false }
            guard other.matchedReceipt == nil, !other.manuallyClearedForReconciliation else { return false }
            guard other.currencyCode == cleared.currencyCode else { return false }
            guard other.amount == cleared.amount else { return false }
            let om = (other.memo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard om == memo else { return false }
            let of = BankStatementImportCoordinator.sourceImportFilename(fromExternalReference: other.externalReference)
            guard of == importFile else { return false }
            let cal = Calendar.current
            let days = abs(cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: other.postedDate),
                to: cal.startOfDay(for: cleared.postedDate)
            ).day ?? 99)
            return days <= 2
        }
    }
}
