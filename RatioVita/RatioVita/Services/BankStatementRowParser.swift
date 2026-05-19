import Foundation

struct BankStatementParsedRow: Equatable {
    var postedDate: Date
    var amount: Decimal
    var currencyCode: String
    var memo: String?
}

enum BankStatementRowParser {
    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func rows(from payload: GeminiBankStatementPayload, defaultCurrency: String) -> [BankStatementParsedRow] {
        let fallbackCurrency = (payload.defaultCurrency?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0.uppercased() }
            ?? defaultCurrency
        guard let rows = payload.rows else { return [] }
        var out: [BankStatementParsedRow] = []
        for row in rows {
            guard let dateStr = row.postedDate?.trimmingCharacters(in: .whitespacesAndNewlines), !dateStr.isEmpty,
                  let posted = Self.isoDate.date(from: dateStr) else { continue }
            guard let amt = row.amount else { continue }
            // Gemini bank payloads have historically matched statement columns with inverted sign vs RatioVita’s
            // canonical convention (purchases / debits negative, deposits / credits positive). Flip at ingest.
            var dec = -Decimal(amt)
            // Some exports (e.g. Zoho Books “Payments received”) already read as credits in the model’s raw sign;
            // after the global flip, unmistakable **income** memos must stay **positive** credits.
            if dec < 0, memoSuggestsIncomingCredit(row.description) {
                dec = -dec
            }
            let memoTrimmed = row.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            dec = enforceCanonicalBankPosting(amount: dec, memo: memoTrimmed)
            let cur = (row.currency?.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { $0.isEmpty ? nil : $0.uppercased() }
                ?? fallbackCurrency
            let memo = memoTrimmed.flatMap { $0.isEmpty ? nil : $0 }
            out.append(BankStatementParsedRow(
                postedDate: posted,
                amount: dec,
                currencyCode: cur,
                memo: memo
            ))
        }
        return out
    }

    /// Memo text that clearly indicates money **in** (bank credit), used to correct occasional double-inversions.
    private static func memoSuggestsIncomingCredit(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let m = raw.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if m.contains("payment received") { return true }
        if m.contains("payments received") { return true }
        if m.contains("invoice payment") { return true }
        if m.contains("customer payment") { return true }
        if m.contains("e-transfer received") || m.contains("etransfer received") { return true }
        if m.contains("direct deposit") { return true }
        if m.contains("payroll"), m.contains("deposit") { return true }
        if m.contains("zoho"), m.contains("payout") { return true }
        return false
    }

    /// Outflows / purchases should remain **negative** after ingest when the memo is unambiguous.
    private static func memoSuggestsExpenseDebit(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let m = raw.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if memoSuggestsIncomingCredit(raw) { return false }
        if m.contains("pos purchase") || m.contains("point of sale") { return true }
        if m.contains("purchase"), m.contains("authorized") { return true }
        if m.contains("withdrawal") || m.contains("atm ") || m.contains(" atm") { return true }
        if m.contains("debit memo") || m.contains("debit purchase") { return true }
        if m.contains("bill payment") || m.contains("payment to ") { return true }
        if m.contains("pre-authorized debit") || m.contains("preauthorized debit") { return true }
        if m.contains("service charge") || m.contains("monthly fee") { return true }
        return false
    }

    /// Final pass: **credits positive**, **debits negative** when memo keywords are confident.
    private static func enforceCanonicalBankPosting(amount: Decimal, memo: String?) -> Decimal {
        if memoSuggestsIncomingCredit(memo) {
            return amount < 0 ? -amount : amount
        }
        if memoSuggestsExpenseDebit(memo) {
            return amount > 0 ? -amount : amount
        }
        return amount
    }
}
