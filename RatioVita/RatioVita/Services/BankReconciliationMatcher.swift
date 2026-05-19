import Foundation

/// Multi-factor bank ↔ receipt scoring: amount, **transactionDate / depositDate** windows, and memo ↔ merchant text
/// overlap.
enum BankReconciliationMatcher {
    private static let amountTolerance: Decimal = 0.02

    enum Confidence: String, CaseIterable {
        case high
        case medium
        case low
    }

    struct Match: Identifiable, Sendable {
        var id: UUID { receiptID }
        let receiptID: UUID
        let totalScore: Double
        /// Best calendar-day distance to the nearest of `transactionDate` or `depositDate` (nil when only `createdAt`
        /// was used as a weak anchor).
        let bestAnchorDayDistance: Int?
        /// 0…1 token overlap between bank memo and receipt merchant / address.
        let memoOverlap: Double
        let confidence: Confidence
    }

    /// Best open receipt for automation / legacy callers (first ranked candidate).
    static func bestSuggestedReceipt(for transaction: BankTransaction, openReceipts: [Receipt]) -> Receipt? {
        rankedMatches(for: transaction, openReceipts: openReceipts).first.flatMap { m in
            openReceipts.first { $0.id == m.receiptID }
        }
    }

    /// Ranked suggestions (highest score first). Includes same-amount ties with different date/memo scores.
    static func rankedMatches(for transaction: BankTransaction, openReceipts: [Receipt]) -> [Match] {
        let txAmount = absDecimal(transaction.amount)
        let memo = transaction.memo ?? ""
        let calendar = Calendar.current

        var rows: [(receipt: Receipt, score: Double, dayDist: Int?, memoOverlap: Double)] = []

        for receipt in openReceipts {
            guard receipt.trashedAt == nil, !receipt.isLedgerLinked else { continue }
            guard receipt.currencyCode.caseInsensitiveCompare(transaction.currencyCode) == .orderedSame else { continue }

            let receiptAmount = absDecimal(receipt.total)
            guard decimalDistance(txAmount, receiptAmount) <= amountTolerance else { continue }

            let memoOverlap = memoMerchantOverlap(memo: memo, receipt: receipt)
            let (temporal, anchorDayDist) = temporalScore(
                posted: transaction.postedDate,
                receipt: receipt,
                calendar: calendar
            )
            let creditBoost = creditRowIncomeBoost(transaction: transaction, receipt: receipt)
            let score = min(100, temporal + memoOverlap * 38 + creditBoost)

            rows.append((receipt, score, anchorDayDist, memoOverlap))
        }

        rows.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            let da = a.dayDist ?? 99
            let db = b.dayDist ?? 99
            if da != db { return da < db }
            return a.memoOverlap > b.memoOverlap
        }

        let capped = rows.prefix(15)
        return capped.map { row in
            let conf = confidenceTier(
                score: row.score,
                dayDistance: row.dayDist,
                memoOverlap: row.memoOverlap
            )
            return Match(
                receiptID: row.receipt.id,
                totalScore: row.score,
                bestAnchorDayDistance: row.dayDist,
                memoOverlap: row.memoOverlap,
                confidence: conf
            )
        }
    }

    /// Conservative auto-link for background agents (reduces wrong links when amounts collide).
    static func shouldAutoLink(_ match: Match) -> Bool {
        switch match.confidence {
            case .high:
                true
            case .medium:
                match.totalScore >= 68 && (match.bestAnchorDayDistance.map { $0 <= 5 } ?? false)
            case .low:
                false
        }
    }

    // MARK: - Scoring

    private static func creditRowIncomeBoost(transaction: BankTransaction, receipt: Receipt) -> Double {
        guard transaction.amount > 0 else { return 0 }
        switch DocumentTypeOption.fromStored(receipt.documentType) {
            case .incomeOrCheck, .paycheck, .outgoingInvoice:
                return 26
            default:
                return 0
        }
    }

    private static func temporalScore(
        posted: Date,
        receipt: Receipt,
        calendar: Calendar
    ) -> (score: Double, anchorDayDistance: Int?) {
        var primaryAnchors: [Date] = []
        if let td = receipt.transactionDate { primaryAnchors.append(td) }
        if let dd = receipt.depositDate { primaryAnchors.append(dd) }

        let weakFallback = primaryAnchors.isEmpty
        let anchors = weakFallback ? [receipt.createdAt] : primaryAnchors

        let bestDist = anchors.map { calendarDayDistance(calendar: calendar, from: $0, to: posted) }.min() ?? 99
        let score = scoreForDayDistance(bestDist, weakAnchor: weakFallback)
        return (score, weakFallback ? nil : bestDist)
    }

    private static func calendarDayDistance(calendar: Calendar, from: Date, to: Date) -> Int {
        let a = calendar.startOfDay(for: from)
        let b = calendar.startOfDay(for: to)
        return abs(calendar.dateComponents([.day], from: a, to: b).day ?? 99)
    }

    private static func scoreForDayDistance(_ d: Int, weakAnchor: Bool) -> Double {
        let cap: Double = weakAnchor ? 38 : 55
        if d <= 3 {
            let base: Double = weakAnchor ? 28 : 42
            return min(cap, base + Double(3 - d) * 5)
        }
        if d <= 7 {
            return max(0, (weakAnchor ? 18 : 30) - Double(d - 3) * 3)
        }
        if d <= 14 {
            return max(0, (weakAnchor ? 8 : 14) - Double(d - 7))
        }
        return 0
    }

    private static func memoMerchantOverlap(memo: String, receipt: Receipt) -> Double {
        let memoTokens = normalizedTokens(memo)
        guard !memoTokens.isEmpty else { return 0 }

        var receiptText = "\(receipt.merchant) \(receipt.vendorAddress ?? "")"
        receiptText = receiptText.lowercased()
        let receiptTokens = normalizedTokens(receiptText)
        guard !receiptTokens.isEmpty else { return 0 }

        let inter = memoTokens.intersection(receiptTokens)
        let union = memoTokens.union(receiptTokens)
        guard !union.isEmpty else { return 0 }
        return Double(inter.count) / Double(union.count)
    }

    private static func normalizedTokens(_ s: String) -> Set<String> {
        let lowered = s.lowercased()
        let parts = lowered.split { !$0.isLetter && !$0.isNumber }
        return Set(parts.map(String.init).filter { $0.count >= 2 })
    }

    private static func confidenceTier(score: Double, dayDistance: Int?, memoOverlap: Double) -> Confidence {
        let tightDate = (dayDistance ?? 99) <= 3
        let okDate = (dayDistance ?? 99) <= 7
        if score >= 78, tightDate { return .high }
        if score >= 72, tightDate, memoOverlap >= 0.12 { return .high }
        if score >= 70, okDate, memoOverlap >= 0.2 { return .high }
        if score >= 58 { return .medium }
        return .low
    }

    private static func absDecimal(_ x: Decimal) -> Decimal {
        x < 0 ? -x : x
    }

    private static func decimalDistance(_ a: Decimal, _ b: Decimal) -> Decimal {
        a >= b ? a - b : b - a
    }
}
