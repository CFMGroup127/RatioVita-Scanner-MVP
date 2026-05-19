import Foundation

/// Lightweight CSV row scan: finds a date and a signed amount per line (common export layouts).
enum BankStatementCSVImporter {
    private static let dateFormatters: [DateFormatter] = {
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy", "dd/MM/yyyy", "d/M/yyyy", "yyyy/MM/dd"]
        return formats.map { pattern in
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = pattern
            return f
        }
    }()

    static func parseRows(from text: String, defaultCurrency: String) -> [BankStatementParsedRow] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        var rows: [BankStatementParsedRow] = []
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let fields = splitCSVLine(line).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard fields.count >= 2 else { continue }

            var foundDate: Date?
            var foundAmount: Decimal?
            var memoBits: [String] = []

            for field in fields {
                if foundDate == nil, let d = parseDate(field) {
                    foundDate = d
                    continue
                }
                if foundAmount == nil, let a = parseAmount(field) {
                    foundAmount = a
                    continue
                }
                memoBits.append(field)
            }

            guard let date = foundDate, let amount = foundAmount else { continue }
            let memo = memoBits.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            rows.append(BankStatementParsedRow(
                postedDate: date,
                amount: amount,
                currencyCode: defaultCurrency.uppercased(),
                memo: memo.isEmpty ? nil : memo
            ))
        }
        return rows
    }

    private static func parseDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for f in dateFormatters {
            if let d = f.date(from: trimmed) { return d }
        }
        return nil
    }

    private static func parseAmount(_ s: String) -> Decimal? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let negatives = t.hasPrefix("(") && t.hasSuffix(")")
        if negatives {
            t = String(t.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        t = t.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "CAD", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "USD", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        t = t.replacingOccurrences(of: ",", with: "")
        guard let dec = Decimal(string: t) else { return nil }
        return negatives ? -dec : dec
    }

    /// Minimal RFC-style CSV split (handles quoted fields with commas).
    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
                continue
            }
            if ch == ",", !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields
    }
}
