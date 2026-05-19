import Foundation

enum HandwrittenAnnotationParsing {
    /// Attempts to parse an “edep … <date>” deposit date from a freeform annotation string.
    /// Supports:
    /// - `edep oct 14/19`
    /// - `edep sept 30/2019`
    /// - `edep 09/30/19`
    static func parseEdepDepositDate(from annotations: String) -> Date? {
        let lower = annotations.lowercased()
        guard lower.contains("edep") else { return nil }

        // Common numeric patterns first.
        let numericPatterns = [
            "M/d/yy",
            "M/d/yyyy",
            "MM/dd/yy",
            "MM/dd/yyyy",
        ]
        for fmt in numericPatterns {
            if let d = parseFirstDate(in: annotations, format: fmt) {
                return d
            }
        }

        // Month name forms: "oct 14/19", "sept 30/2019"
        let monthNameFormats = [
            "MMM d/yy",
            "MMM d/yyyy",
            "MMMM d/yy",
            "MMMM d/yyyy",
        ]
        for fmt in monthNameFormats {
            if let d = parseFirstDate(in: normalizeMonthNames(annotations), format: fmt) {
                return d
            }
        }

        return nil
    }

    private static func parseFirstDate(in text: String, format: String) -> Date? {
        // Extract a short window around edep to avoid picking unrelated dates.
        let window = snippetNearKeyword(text, keyword: "edep", radius: 40) ?? text
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_CA_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = format

        // Tokenize by whitespace and punctuation, then try each contiguous 1–3 token join.
        let rawTokens = window
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let tokens = rawTokens.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",;()[]")) }

        for i in 0..<tokens.count {
            for len in 1...3 {
                guard i + len <= tokens.count else { continue }
                let candidate = tokens[i..<(i + len)].joined(separator: " ")
                if let d = df.date(from: candidate) {
                    return d
                }
            }
        }
        return nil
    }

    private static func snippetNearKeyword(_ text: String, keyword: String, radius: Int) -> String? {
        let lower = text.lowercased()
        guard let range = lower.range(of: keyword) else { return nil }
        let start = lower.index(range.lowerBound, offsetBy: -radius, limitedBy: lower.startIndex) ?? lower.startIndex
        let end = lower.index(range.upperBound, offsetBy: radius, limitedBy: lower.endIndex) ?? lower.endIndex
        return String(text[start..<end])
    }

    private static func normalizeMonthNames(_ text: String) -> String {
        // OCR often returns "sept" (DateFormatter expects "Sep" for MMM)
        text
            .replacingOccurrences(of: "sept", with: "sep", options: .caseInsensitive)
            .replacingOccurrences(of: "april", with: "apr", options: .caseInsensitive)
    }
}
