import Foundation

/// Home-screen **Forensic Pulse** payment watches (long-format Thursday deposit vs. short-format AR clock).
enum ForensicPulsePaymentSentinel {
    /// Outgoing invoices on a **15-day short** cadence past due with no bank link.
    static func fifteenDayOverdueInvoiceCount(
        projectID: UUID,
        receipts: [Receipt],
        calendar: Calendar = .current
    ) -> Int {
        let todayStart = calendar.startOfDay(for: Date())
        return receipts.filter { r in
            guard r.productionProject?.id == projectID else { return false }
            guard !r.pendingHumanReview, r.trashedAt == nil else { return false }
            guard DocumentTypeOption.fromStored(r.documentType) == .outgoingInvoice else { return false }
            guard r.effectivePaymentTerms.isFifteenDayShort else { return false }
            let anchor = r.transactionDate ?? r.createdAt
            let anchorDay = calendar.startOfDay(for: anchor)
            guard let dueStart = calendar.date(byAdding: .day, value: 15, to: anchorDay) else { return false }
            guard todayStart >= dueStart else { return false }
            return r.matchedBankTransaction == nil && !r.isLedgerLinked
        }.count
    }

    /// **True** on **Friday morning** when no payroll-ish **credit** appeared after **Thursday 4 PM** through `now`.
    /// Only meaningful when the active show uses **Long format — Thursday 4 PM pay (Canada)**.
    static func longFormatThursdayDepositLooksMissing(
        bankTransactions: [BankTransaction],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard calendar.component(.weekday, from: now) == 6 else { return false }
        let hour = calendar.component(.hour, from: now)
        guard hour < 12 else { return false }

        let startOfFriday = calendar.startOfDay(for: now)
        guard let priorThursday = calendar.date(byAdding: .day, value: -1, to: startOfFriday) else { return false }
        var comps = calendar.dateComponents([.year, .month, .day], from: priorThursday)
        comps.hour = 16
        comps.minute = 0
        comps.second = 0
        guard let thursdayFourPM = calendar.date(from: comps) else { return false }

        let memoPayroll = ["payroll", "pay roll", "deposit", "dir dep", "direct dep", "eft", "pay"]

        let found = bankTransactions.contains { tx in
            guard tx.amount > 0 else { return false }
            guard tx.postedDate >= thursdayFourPM, tx.postedDate <= now else { return false }
            let memo = (tx.memo ?? "").lowercased()
            return memoPayroll.contains { memo.contains($0) }
        }
        return !found
    }
}
