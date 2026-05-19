import Foundation

/// Parsed **page-1 call sheet** anchors (crew call, set line) for Labor Sentinel pre-fill.
struct CallSheetLaborPrefillPayload: Equatable, Sendable {
    /// Calendar day the scan should attach to (start-of-day normalized).
    var anchorDay: Date
    var crewCallHour: Int
    var crewCallMinute: Int
    var setLocationLine: String?
    /// Best-effort production / episode title from the call sheet header (e.g. "THE SYSTEM").
    var productionTitleLine: String?
}

enum CallSheetHeaderParser {
    /// Best-effort parse of OCR from a photographed / PDF-rasterized call sheet header.
    static func parseLaborPrefill(combinedOCR: String, anchorDayIfNoDateInOCR: Date) -> CallSheetLaborPrefillPayload? {
        let ocr = combinedOCR
        guard !ocr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let time = extractCrewCallTime(from: ocr) else { return nil }
        let cal = Calendar.current
        let anchor = extractDocumentDay(from: ocr).map { cal.startOfDay(for: $0) }
            ?? cal.startOfDay(for: anchorDayIfNoDateInOCR)
        let loc = extractPrimaryLocationLine(from: ocr)
        let prod = extractProductionTitleLine(from: ocr)
        return CallSheetLaborPrefillPayload(
            anchorDay: anchor,
            crewCallHour: time.hour,
            crewCallMinute: time.minute,
            setLocationLine: loc,
            productionTitleLine: prod
        )
    }

    private static func extractCrewCallTime(from ocr: String) -> (hour: Int, minute: Int)? {
        let lower = ocr.lowercased()
        guard let range = lower.range(of: "crew call") else { return nil }
        let tail = String(ocr[range.upperBound...])
        let window = String(tail.prefix(120))

        let winRange = NSRange(location: 0, length: (window as NSString).length)
        if let re = try? NSRegularExpression(pattern: #"(?i)\b(\d{1,2})\s*[:.]\s*(\d{2})\s*(am|pm)?\b"#, options: []),
           let m = re.firstMatch(in: window, options: [], range: winRange)
        {
            let ns = window as NSString
            let hStr = ns.substring(with: m.range(at: 1))
            let mStr = ns.substring(with: m.range(at: 2))
            var h = Int(hStr) ?? -1
            let mm = Int(mStr) ?? -1
            if m.range(at: 3).location != NSNotFound {
                let ap = ns.substring(with: m.range(at: 3)).lowercased()
                if ap == "pm", h < 12 { h += 12 }
                if ap == "am", h == 12 { h = 0 }
            }
            if h >= 0, h < 24, mm >= 0, mm < 60 { return (h, mm) }
        }

        if let re = try? NSRegularExpression(pattern: #"\b(\d{3,4})\b"#, options: []),
           let m = re.firstMatch(in: window, options: [], range: winRange)
        {
            let ns = window as NSString
            let digits = ns.substring(with: m.range(at: 1))
            guard let n = Int(digits) else { return nil }
            if digits.count == 4, n >= 100, n < 2400 {
                let h = n / 100
                let mm = n % 100
                if mm < 60, h < 24 { return (h, mm) }
            }
            if digits.count == 3, n >= 100, n < 240 {
                let h = n / 100
                let mm = n % 100
                if mm < 60, h < 24 { return (h, mm) }
            }
        }
        return nil
    }

    private static func extractPrimaryLocationLine(from ocr: String) -> String? {
        let lines = ocr.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        for line in lines {
            let low = line.lowercased()
            guard low.contains("location") else { continue }
            if let colon = line.firstIndex(of: ":") {
                let tail = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if !tail.isEmpty { return String(tail) }
            } else {
                return line
            }
        }
        return nil
    }

    private static func extractProductionTitleLine(from ocr: String) -> String? {
        let lines = ocr.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        for line in lines {
            let low = line.lowercased()
            if low.hasPrefix("production") || low.hasPrefix("show:") || low.hasPrefix("series:") {
                if let colon = line.firstIndex(of: ":") {
                    let tail = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    if !tail.isEmpty { return String(tail) }
                }
            }
        }
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.count >= 4, t.count <= 80 else { continue }
            let letters = t.filter(\.isLetter)
            guard Double(letters.count) / Double(max(t.count, 1)) > 0.7 else { continue }
            if t == t.uppercased(), t.rangeOfCharacter(from: .letters) != nil {
                let low = t.lowercased()
                if low.contains("CREW") || low.contains("CALL") || low.contains("DAY ") { continue }
                return t
            }
        }
        return nil
    }

    private static func extractDocumentDay(from ocr: String) -> Date? {
        let pattern =
            #"(?i)(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s*,\s*([A-Za-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?\s*,\s*(\d{4})"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: []),
              let m = re
              .firstMatch(in: ocr, options: [], range: NSRange(location: 0, length: (ocr as NSString).length)) else { return nil }
        let ns = ocr as NSString
        let weekday = ns.substring(with: m.range(at: 1))
        let monthName = ns.substring(with: m.range(at: 2))
        let dayNum = ns.substring(with: m.range(at: 3))
        let year = ns.substring(with: m.range(at: 4))

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "EEEE, MMMM d, yyyy"
        let candidate = "\(weekday), \(monthName) \(dayNum), \(year)"
        return df.date(from: candidate)
    }
}
