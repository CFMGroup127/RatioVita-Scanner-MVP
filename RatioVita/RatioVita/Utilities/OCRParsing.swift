import Foundation

/// Heuristic extraction from raw Vision OCR. For structured linking (invoice ↔ payment ↔ statement), see roadmap.
enum OCRParsing {
    static func extractData(from text: String) -> ExtractedData {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let merchant = pickMerchant(from: lines)
        let vendorAddress = pickAddress(from: lines)
        let documentNumber = pickDocumentNumber(from: text)
        let paymentMethodSummary = pickPaymentMethod(from: text)
        let date = pickDate(from: text)
        let (total, currency) = pickTotalAndCurrency(from: text, lines: lines)
        let (subtotal, tax) = pickSubtotalAndTax(from: text)

        return ExtractedData(
            merchant: merchant,
            total: total,
            currency: currency,
            date: date,
            vendorAddress: vendorAddress,
            documentNumber: documentNumber,
            paymentMethodSummary: paymentMethodSummary,
            lineItems: nil,
            taxAmount: tax,
            subtotal: subtotal,
            merchantConfidence: merchant != nil ? 0.72 : nil,
            totalConfidence: total != nil ? 0.78 : nil,
            dateConfidence: date != nil ? 0.68 : nil,
            documentKind: nil
        )
    }

    // MARK: - Private

    private static let headerSkip: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(CUSTOMER\s+RECEIPT|RECEIPT|INVOICE|TAX\s+INVOICE|SALES\s+RECEIPT|POINT\s+OF\s+SALE)\s*$"#,
        options: .caseInsensitive
    )

    private static func pickMerchant(from lines: [String]) -> String? {
        for line in lines.prefix(30) {
            if let re = headerSkip {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                if re.firstMatch(in: line, options: [], range: range) != nil { continue }
            }
            if line.count < 3 || line.count > 120 { continue }
            if line.allSatisfy({ $0.isNumber || $0.isWhitespace || $0 == "." || $0 == "," || $0 == "-" }) { continue }
            return line
        }
        return lines.first
    }

    private static let addressPattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{1,5}\s+.{5,80}\b(Ave|Avenue|St\.?|Street|Rd\.?|Road|Dr\.?|Drive|Blvd|Way|ON|BC|AB|QC|MB|SK|NS|NB|NL|PE|YT|NT|NU|USA|United States|Canada)\b"#,
        options: .caseInsensitive
    )

    private static func pickAddress(from lines: [String]) -> String? {
        guard let re = addressPattern else { return nil }
        for line in lines.prefix(40) {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if re.firstMatch(in: line, options: [], range: range) != nil {
                return line
            }
        }
        return nil
    }

    private static let docNumberPattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)(?:receipt|invoice|confirmation|order)\s*#?\s*[:\-]?\s*([A-Za-z0-9][A-Za-z0-9\-_/]{4,})"#,
        options: []
    )

    private static func pickDocumentNumber(from text: String) -> String? {
        guard let re = docNumberPattern else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, options: [], range: range),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static let paymentPattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)(CREDIT\s+CARD\s*:[^\n]{0,80}|Visa|Mastercard|MasterCard|Amex|American\s+Express|Discover|Debit|Interac|E-?Transfer|PayPal|Apple\s*Pay|Google\s*Pay|Cash|Cheque|Check)"#,
        options: []
    )

    private static func pickPaymentMethod(from text: String) -> String? {
        guard let re = paymentPattern else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, options: [], range: range),
              let r = Range(m.range(at: 0), in: text) else { return nil }
        let s = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        return s.count > 2 ? s : nil
    }

    private static func pickDate(from text: String) -> Date? {
        let fmts = [
            "MM/dd/yyyy", "M/d/yyyy", "dd/MM/yyyy", "d/M/yyyy",
            "yyyy-MM-dd", "dd MMM, yyyy", "d MMM, yyyy", "MMM d, yyyy",
        ]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        for line in text.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            if let d = iso.date(from: t) { return d }
            for pattern in fmts {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = pattern
                if let d = df.date(from: t) { return d }
            }
            // Embedded "Date: 02/02/2026"
            if let colon = t.firstIndex(of: ":") {
                let tail = t[t.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                for pattern in fmts {
                    let df = DateFormatter()
                    df.locale = Locale(identifier: "en_US_POSIX")
                    df.dateFormat = pattern
                    if let d = df.date(from: tail) { return d }
                }
            }
        }
        return nil
    }

    private static func pickTotalAndCurrency(from text: String, lines: [String]) -> (Decimal?, String?) {
        var currency = inferCurrency(from: text)
        let totalPatterns = [
            #"(?i)\b(?:total|amount\s+due|grand\s+total|balance\s+due)\b[^$\d]{0,24}([\d,]+\.?\d*)"#,
            #"\$\s*([\d,]+\.?\d*)\s*(?:CAD|USD|EUR|GBP)?\s*$"#,
        ]
        for pat in totalPatterns {
            guard let re = try? NSRegularExpression(pattern: pat, options: []) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let m = re.firstMatch(in: text, options: [], range: range),
               m.numberOfRanges >= 2,
               let r = Range(m.range(at: 1), in: text)
            {
                let num = String(text[r]).replacingOccurrences(of: ",", with: "")
                if let d = Decimal(string: num) {
                    if currency == nil, text.uppercased().contains("CAD") { currency = "CAD" }
                    if currency == nil, text.uppercased().contains("USD") { currency = "USD" }
                    return (d, currency ?? "USD")
                }
            }
        }
        // Fallback: last currency-looking number on a "Total" line
        for line in lines.reversed() {
            if line.range(of: #"(?i)total"#, options: .regularExpression) != nil {
                if let d = lastDecimal(in: line) {
                    return (d, currency ?? "USD")
                }
            }
        }
        return (nil, currency)
    }

    private static func pickSubtotalAndTax(from text: String) -> (Decimal?, Decimal?) {
        var sub: Decimal?
        var tax: Decimal?
        if let re = try? NSRegularExpression(pattern: #"(?i)subtotal[^$\d]{0,20}([\d,]+\.?\d*)"#, options: []),
           let m = re.firstMatch(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text)),
           m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: text)
        {
            let s = String(text[r]).replacingOccurrences(of: ",", with: "")
            sub = Decimal(string: s)
        }
        if let re = try? NSRegularExpression(
            pattern: #"(?i)(HST|GST|PST|QST|VAT|Tax)\b[^$\d]{0,16}\$?\s*([\d,]+\.?\d*)"#,
            options: []
        ),
            let m = re.firstMatch(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text)),
            m.numberOfRanges >= 3,
            let r = Range(m.range(at: 2), in: text)
        {
            let s = String(text[r]).replacingOccurrences(of: ",", with: "")
            tax = Decimal(string: s)
        }
        return (sub, tax)
    }

    private static func inferCurrency(from text: String) -> String? {
        let u = text.uppercased()
        if u.contains("CAD") || u.contains("CDN$") { return "CAD" }
        if u.contains("USD") || u.contains("US$") { return "USD" }
        if u.contains("EUR") || u.contains("€") { return "EUR" }
        if u.contains("GBP") || u.contains("£") { return "GBP" }
        return nil
    }

    private static func lastDecimal(in line: String) -> Decimal? {
        guard let re = try? NSRegularExpression(pattern: #"([\d,]+\.?\d*)"#, options: []) else { return nil }
        var last: Decimal?
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        re.enumerateMatches(in: line, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2,
                  let r = Range(match.range(at: 1), in: line) else { return }
            let s = String(line[r]).replacingOccurrences(of: ",", with: "")
            if let d = Decimal(string: s) { last = d }
        }
        return last
    }
}
