import Foundation

/// Merchant → year → month path segments for the **Arctic Vault** surface (slash-separated, no leading slash).
enum ReceiptVaultPathing {
    private static let calendar = Calendar.current

    static func sanitizePathSegment(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "Unknown" }
        return t
            .replacingOccurrences(of: "/", with: "·")
            .replacingOccurrences(of: "\\", with: "·")
            .replacingOccurrences(of: "\n", with: " ")
    }

    static func merchantSegment(for receipt: Receipt) -> String {
        sanitizePathSegment(receipt.merchant)
    }

    static func anchorDate(for receipt: Receipt) -> Date {
        receipt.transactionDate ?? receipt.createdAt
    }

    static func yearMonth(for date: Date) -> (year: Int, monthSymbol: String) {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let comps = DateComponents(year: y, month: m, day: 1)
        let anchor = calendar.date(from: comps) ?? date
        let monthSymbol = anchor.formatted(.dateTime.month(.abbreviated))
        return (y, monthSymbol)
    }

    /// Relative path: `Merchant/Year/MonthAbbrev` (no leading slash).
    static func relativeVaultPath(for receipt: Receipt) -> String {
        let m = merchantSegment(for: receipt)
        let d = anchorDate(for: receipt)
        let ym = yearMonth(for: d)
        return "\(m)/\(ym.year)/\(ym.monthSymbol)"
    }

    /// Full logical path including optional prefix from `Receipt.vaultPathPrefix`.
    static func fullVaultPath(for receipt: Receipt) -> String {
        let rel = relativeVaultPath(for: receipt)
        guard let p = receipt.vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty else {
            return rel
        }
        let prefix = p.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(prefix)/\(rel)"
    }

    /// UI string with leading slash (e.g. `/Costco/2026/May` or `/Productions/Bell/Costco/2026/May`).
    static func displayPath(for receipt: Receipt) -> String {
        "/" + fullVaultPath(for: receipt)
    }

    /// Live preview while editing merchant / date in forms (does not read `receipt` fields except prefix).
    static func previewDisplayPath(
        merchant: String,
        transactionDate: Date?,
        createdAt: Date,
        hasTransactionDate: Bool,
        vaultPathPrefix: String?
    ) -> String {
        let anchor = (hasTransactionDate ? (transactionDate ?? createdAt) : createdAt)
        let m = sanitizePathSegment(merchant)
        let ym = yearMonth(for: anchor)
        let rel = "\(m)/\(ym.year)/\(ym.monthSymbol)"
        guard let p = vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty else {
            return "/" + rel
        }
        let prefix = p.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "/\(prefix)/\(rel)"
    }
}
