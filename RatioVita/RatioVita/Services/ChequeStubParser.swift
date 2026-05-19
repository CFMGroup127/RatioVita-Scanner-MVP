import Foundation

/// Parsed corporate cheque + remittance stub (Bell Media, network payouts, etc.).
struct ChequeStubPayload: Equatable, Sendable {
    var payorName: String?
    var payeeName: String?
    var payorAddress: String?
    var chequeNumber: String?
    var internalInvoiceNumber: String?
    var clientAccountingToken: String?
    var paymentDate: Date?
    var invoiceDate: Date?
    var netAmount: Decimal?
}

enum ChequeStubParser {
    static func parse(combinedOCR: String) -> ChequeStubPayload? {
        let ocr = combinedOCR.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ocr.count >= 60 else { return nil }
        let lower = ocr.lowercased()
        guard looksLikeChequeStub(lower) else { return nil }

        let payee = extractPayee(from: ocr, lower: lower)
        let payor = extractPayor(from: ocr, lower: lower)
        let chequeNo = extractChequeNumber(from: ocr, lower: lower)
        let internalInv = extractInternalInvoiceNumber(from: ocr, lower: lower)
        let sap = extractClientAccountingToken(from: ocr, lower: lower)
        let payDate = extractPaymentDate(from: ocr)
        let invDate = extractInvoiceDate(from: ocr, lower: lower)
        let net = extractNetPayment(from: ocr, lower: lower)

        guard payee != nil || payor != nil || chequeNo != nil || internalInv != nil else { return nil }

        return ChequeStubPayload(
            payorName: payor,
            payeeName: payee,
            payorAddress: nil,
            chequeNumber: chequeNo,
            internalInvoiceNumber: internalInv,
            clientAccountingToken: sap,
            paymentDate: payDate,
            invoiceDate: invDate,
            netAmount: net
        )
    }

    private static func firstLine(_ text: String) -> String {
        String(text.split(whereSeparator: \.isNewline).first ?? Substring(text))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeChequeStub(_ lower: String) -> Bool {
        let signals = [
            "pay to the order", "to the order of", "à l'ordre", "cheque no", "chèque no", "no du chèque",
            "facture / invoice", "montant paye", "montant payé", "montant net", "paid on behalf",
            "banque de montréal", "bank of montreal", "micr",
        ]
        return signals.contains { lower.contains($0) }
    }

    private static func extractPayee(from ocr: String, lower _: String) -> String? {
        let patterns = [
            #"(?i)l'ordre de\s+([A-Za-z][^\n]{4,80})"#,
            #"(?i)(?:pay to the order of|to the order of)\s*(?:/\s*[^\n]{0,30}l'ordre de\s*)?([A-Za-z][^\n]{4,80})"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
                  let r = Range(m.range(at: 1), in: ocr) else { continue }
            let name = firstLine(String(ocr[r])).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if name.count >= 4 { return name }
        }
        return nil
    }

    private static func extractPayor(from ocr: String, lower: String) -> String? {
        if let re = try? NSRegularExpression(
            pattern: #"(?i)(?:payé au nom de[/\s]*)?paid on behalf of\s+([A-Za-z0-9][^\n]{4,60})"#
        ),
            let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
            let r = Range(m.range(at: 1), in: ocr)
        {
            return firstLine(String(ocr[r])).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if lower.contains("bell media") { return "Bell Media Inc." }
        for line in ocr.split(whereSeparator: \.isNewline) {
            let t = String(line).trimmingCharacters(in: .whitespaces)
            if t.lowercased().contains("bell"), t.lowercased().contains("media") { return t }
        }
        return nil
    }

    private static func extractChequeNumber(from ocr: String, lower _: String) -> String? {
        let labeled = [
            #"(?i)no\s*du\s*ch[eèè]que\s*/?\s*cheque\s*no\s*[:.]?\s*(\d{10,14})"#,
            #"(?i)no\s*du\s*cheque\s*/?\s*cheque\s*no\s*[:.]?\s*(\d{10,14})"#,
            #"(?i)cheque\s*no\s*[:.]?\s*(\d{10,14})"#,
            #"(?i)ch[eè]que\s*#\s*(\d{10,14})"#,
        ]
        for pattern in labeled {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
                  let r = Range(m.range(at: 1), in: ocr) else { continue }
            return String(ocr[r])
        }
        if let re = try? NSRegularExpression(pattern: #"\b(\d{13})\b"#),
           let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
           let r = Range(m.range(at: 1), in: ocr)
        {
            return String(ocr[r])
        }
        return nil
    }

    private static func extractInternalInvoiceNumber(from ocr: String, lower _: String) -> String? {
        let patterns = [
            #"(?i)facture\s*/\s*invoice\s+(\d{3,8})\b"#,
            #"(?i)facture\s*/\s*invoice[\s\S]{0,80}?(\d{3,8})\s+\d{4}-\d{2}-\d{2}"#,
            #"(?i)invoice\s+(\d{3,8})\b"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
                  let r = Range(m.range(at: 1), in: ocr) else { continue }
            return String(ocr[r])
        }
        if let re = try? NSRegularExpression(pattern: #"(?m)^\s*(\d{3,6})\s+\d{4}-\d{2}-\d{2}\s+\d{8,12}"#),
           let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
           let r = Range(m.range(at: 1), in: ocr)
        {
            return String(ocr[r])
        }
        return nil
    }

    private static func extractClientAccountingToken(from ocr: String, lower _: String) -> String? {
        let patterns = [
            #"(?i)sap\s*document\s*no\s*[:.]?\s*(\d{8,12})"#,
            #"(?i)ref\.?\s*document\s*[:.]?\s*(\d{8,12})"#,
            #"(?i)ref\.?\s*document[\s\S]{0,40}?(\d{10})\b"#,
            #"\b(800\d{7})\b"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
                  let r = Range(m.range(at: 1), in: ocr) else { continue }
            return String(ocr[r])
        }
        return nil
    }

    private static func extractPaymentDate(from ocr: String) -> Date? {
        parseDateNearLabel(ocr, labels: ["date:", "date "], preferAfter: "cheque")
    }

    private static func extractInvoiceDate(from ocr: String, lower _: String) -> Date? {
        parseDateNearLabel(ocr, labels: ["facture", "invoice"], preferAfter: nil)
    }

    private static func extractNetPayment(from ocr: String, lower _: String) -> Decimal? {
        let pattern = #"(?i)montant\s*pay[eé]\s*/\s*net\s*payment\s*[:.]?\s*([\d,]+\.\d{2})"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
              let r = Range(m.range(at: 1), in: ocr) else { return nil }
        return Decimal(string: String(ocr[r]).replacingOccurrences(of: ",", with: ""))
    }

    private static func parseDateNearLabel(
        _ ocr: String,
        labels: [String],
        preferAfter: String?
    ) -> Date? {
        let fmts = ["yyyy-MM-dd", "yyyy MM dd", "MMM d, yyyy", "MMMM d, yyyy", "dd/MM/yyyy"]
        for line in ocr.split(whereSeparator: \.isNewline) {
            let t = String(line).trimmingCharacters(in: .whitespaces)
            let low = t.lowercased()
            guard labels.contains(where: { low.contains($0) }) else { continue }
            if let pref = preferAfter, !low.contains(pref) { continue }
            for fmt in fmts {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_CA_POSIX")
                df.dateFormat = fmt
                if let d = df.date(from: t) { return Calendar.current.startOfDay(for: d) }
            }
            if let re = try? NSRegularExpression(pattern: #"(\d{4}[-\s]\d{2}[-\s]\d{2})"#),
               let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
               let r = Range(m.range(at: 1), in: t)
            {
                let raw = String(t[r]).replacingOccurrences(of: " ", with: "-")
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_CA_POSIX")
                df.dateFormat = "yyyy-MM-dd"
                if let d = df.date(from: raw) { return Calendar.current.startOfDay(for: d) }
            }
        }
        return nil
    }
}
