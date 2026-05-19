import Foundation

/// Page-1 deal memo / EP start-slip anchors (position, rate, department, show).
struct DealMemoPage1Payload: Equatable, Sendable {
    var showTitle: String?
    var productionCompany: String?
    var positionTitle: String?
    var department: String?
    var effectiveStartDate: Date?
    var rateKind: DealMemoRateKind
    var hourlyRateCAD: Decimal?
    var flatDailyRateCAD: Decimal?
    var flatGuaranteeHours: Int?
    var isNonUnion: Bool
    var loanOutCompanyName: String?
    var gstHstRegistrationRaw: String?
    var productionManagerName: String?
    var workerName: String?
    var kitPhoneRateCAD: Decimal?
    var kitLaptopRateCAD: Decimal?
    var kitTabletRateCAD: Decimal?
}

/// Parses **page 1 only** of EP / Cast & Crew start slips and indie deal-term sheets.
enum DealMemoSniper {
    static func parsePage1(combinedOCR: String) -> DealMemoPage1Payload? {
        let ocr = combinedOCR.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ocr.count >= 80 else { return nil }
        let lower = ocr.lowercased()
        guard looksLikeDealMemoPage1(lower) else { return nil }

        let show = extractShowTitle(from: ocr, lower: lower)
            ?? extractLabeledValue(from: ocr, labels: ["show title", "production name", "production:"])
        let company = extractLabeledValue(
            from: ocr,
            labels: ["production company", "production co", "company name"]
        )
        let position = extractLabeledValue(from: ocr, labels: ["position", "position:"])
        let department = extractLabeledValue(from: ocr, labels: ["department", "department:"])
        let start = extractStartDate(from: ocr)
        let (kind, hourly, flat, guarantee) = extractCompensation(from: ocr, lower: lower)
        let nonUnion =
            lower.range(of: #"(?i)non[\s-]*union"#, options: .regularExpression) != nil
                || (lower.contains("union") && lower.contains("n/a"))
        let loanOut = extractLabeledValue(from: ocr, labels: ["company name", "loan-out", "loan out"])
        let gst = extractGSTHST(from: ocr)
        let pm = extractProductionManager(from: ocr)
        let worker = extractLabeledValue(from: ocr, labels: ["employee name", "individual worker", "worker"])
        let kitRates = extractKitRentalRates(from: ocr, lower: lower)

        guard show != nil || company != nil || position != nil || hourly != nil || flat != nil
            || kitRates.phone != nil || kitRates.laptop != nil || kitRates.tablet != nil else
        {
            return nil
        }

        return DealMemoPage1Payload(
            showTitle: show,
            productionCompany: company,
            positionTitle: position,
            department: department,
            effectiveStartDate: start,
            rateKind: kind,
            hourlyRateCAD: hourly,
            flatDailyRateCAD: flat,
            flatGuaranteeHours: guarantee,
            isNonUnion: nonUnion,
            loanOutCompanyName: loanOut,
            gstHstRegistrationRaw: gst,
            productionManagerName: pm,
            workerName: worker,
            kitPhoneRateCAD: kitRates.phone,
            kitLaptopRateCAD: kitRates.laptop,
            kitTabletRateCAD: kitRates.tablet
        )
    }

    private static func extractKitRentalRates(
        from ocr: String,
        lower _: String
    ) -> (phone: Decimal?, laptop: Decimal?, tablet: Decimal?) {
        (
            extractKitRate(
                from: ocr,
                keywords: ["cell phone", "mobile phone", "phone kit", "phone rental", "cellular", "smartphone"]
            ),
            extractKitRate(from: ocr, keywords: ["laptop kit", "laptop", "computer kit", "notebook"]),
            extractKitRate(from: ocr, keywords: ["tablet", "ipad"])
        )
    }

    private static func extractKitRate(from ocr: String, keywords: [String]) -> Decimal? {
        for line in ocr.split(whereSeparator: \.isNewline) {
            let t = String(line)
            let lineLower = t.lowercased()
            guard keywords.contains(where: { lineLower.contains($0) }) else { continue }
            if let m = extractDollarAmount(from: t, window: "") { return m }
        }
        let lower = ocr.lowercased()
        for kw in keywords {
            guard let range = lower.range(of: kw) else { continue }
            let start = ocr.distance(from: ocr.startIndex, to: range.lowerBound)
            let lo = max(0, start)
            let hi = min(ocr.count, start + 80)
            let slice = String(ocr[ocr.index(ocr.startIndex, offsetBy: lo)..<ocr.index(ocr.startIndex, offsetBy: hi)])
            if let m = extractDollarAmount(from: slice, window: "") { return m }
        }
        return nil
    }

    private static func looksLikeDealMemoPage1(_ lower: String) -> Bool {
        let signals = [
            "deal terms", "deal memo", "start slip", "personnel services",
            "entertainment partners", "engagement details", "term & compensation",
            "applicable rate", "show title", "production company", "kit rental",
        ]
        return signals.contains { lower.contains($0) }
    }

    private static func extractShowTitle(from ocr: String, lower: String) -> String? {
        if let v = extractLabeledValue(from: ocr, labels: ["show title"]) { return v }
        let lines = ocr.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.count >= 3, t.count <= 60 else { continue }
            if t == t.uppercased(), t.rangeOfCharacter(from: .letters) != nil {
                let l = t.lowercased()
                if l.contains("outstanding") || l.contains("see for me") { return titleCase(t) }
            }
        }
        if lower.contains("see for me") { return "See For Me" }
        if lower.contains("outstanding") { return "Outstanding" }
        return nil
    }

    private static func titleCase(_ s: String) -> String {
        s.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    private static func extractLabeledValue(from ocr: String, labels: [String]) -> String? {
        let lines = ocr.split(whereSeparator: \.isNewline).map { String($0) }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            for label in labels {
                let pattern = #"(?i)^\#(NSRegularExpression.escapedPattern(for: label))\s*[:.]?\s*(.+)$"#
                guard let re = try? NSRegularExpression(pattern: pattern),
                      let m = re.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                      m.numberOfRanges > 1,
                      let r = Range(m.range(at: 1), in: trimmed) else { continue }
                let tail = String(trimmed[r]).trimmingCharacters(in: .whitespaces)
                if !tail.isEmpty, tail.lowercased() != "n/a" { return tail }
            }
        }
        return nil
    }

    private static func extractStartDate(from ocr: String) -> Date? {
        let patterns = [
            #"(?i)start\s*date\s*[:.]?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})"#,
            #"(?i)start\s*date\s*[:.]?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
                  let r = Range(m.range(at: 1), in: ocr) else { continue }
            let raw = String(ocr[r])
            for fmt in ["MMMM d, yyyy", "MMM d, yyyy", "MM/dd/yyyy", "M/d/yyyy"] {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_CA")
                f.dateFormat = fmt
                if let d = f.date(from: raw) { return Calendar.current.startOfDay(for: d) }
            }
        }
        return nil
    }

    private static func extractCompensation(
        from ocr: String,
        lower: String
    ) -> (DealMemoRateKind, Decimal?, Decimal?, Int?) {
        if lower.contains("per day") || lower.contains("flat rate"), let m = extractDollarAmount(
            from: ocr,
            window: "rate"
        ) {
            let hours = extractGuaranteeHours(from: ocr) ?? 14
            return (.flatDaily, nil, m, hours)
        }
        if let flat = extractMoneyNearKeywords(from: ocr, keywords: ["per day", "flat rate", "daily rate"]) {
            let hours = extractGuaranteeHours(from: ocr) ?? 14
            return (.flatDaily, nil, flat, hours)
        }
        if lower.contains("per day"), let m = extractDollarAmount(from: ocr, window: "rate") {
            let hours = extractGuaranteeHours(from: ocr) ?? 14
            return (.flatDaily, nil, m, hours)
        }
        if let hourly = extractApplicableHourly(from: ocr) {
            return (.hourly, hourly, nil, nil)
        }
        if lower.contains("hourly"), let m = extractDollarAmount(from: ocr, window: "applicable rate") {
            return (.hourly, m, nil, nil)
        }
        return (.hourly, nil, nil, nil)
    }

    private static func extractApplicableHourly(from ocr: String) -> Decimal? {
        let pattern = #"(?i)applicable\s*rate\s*[:.]?\s*\$?\s*(\d{1,3}(?:\.\d{1,2})?)"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
              let r = Range(m.range(at: 1), in: ocr),
              let d = Decimal(string: String(ocr[r])) else { return nil }
        return d
    }

    private static func extractGuaranteeHours(from ocr: String) -> Int? {
        let pattern = #"(?i)(\d{1,2})\s*hours?"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
              let r = Range(m.range(at: 1), in: ocr),
              let h = Int(ocr[r]), h > 0, h <= 24 else { return nil }
        return h
    }

    private static func extractMoneyNearKeywords(from ocr: String, keywords: [String]) -> Decimal? {
        let lower = ocr.lowercased()
        for kw in keywords {
            guard let range = lower.range(of: kw) else { continue }
            let start = ocr.distance(from: ocr.startIndex, to: range.lowerBound)
            let lo = max(0, start - 80)
            let hi = min(ocr.count, start + 80)
            let slice = String(ocr[ocr.index(ocr.startIndex, offsetBy: lo)..<ocr.index(ocr.startIndex, offsetBy: hi)])
            if let m = extractDollarAmount(from: slice, window: "") { return m }
        }
        return nil
    }

    private static func extractDollarAmount(from ocr: String, window: String) -> Decimal? {
        let search: String
        if window.isEmpty {
            search = ocr
        } else if let r = ocr.lowercased().range(of: window.lowercased()) {
            let start = ocr.distance(from: ocr.startIndex, to: r.lowerBound)
            let lo = max(0, start)
            let hi = min(ocr.count, start + 120)
            search = String(ocr[ocr.index(ocr.startIndex, offsetBy: lo)..<ocr.index(ocr.startIndex, offsetBy: hi)])
        } else {
            search = ocr
        }
        let patterns = [
            #"\$\s*(\d{1,4}(?:\.\d{1,2})?)"#,
            #"(?i)rate\s*[:.]?\s*\$?\s*(\d{1,4}(?:\.\d{1,2})?)"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: search, range: NSRange(search.startIndex..., in: search)),
                  let r = Range(m.range(at: 1), in: search),
                  let d = Decimal(string: String(search[r])) else { continue }
            return d
        }
        return nil
    }

    private static func extractGSTHST(from ocr: String) -> String? {
        let pattern = #"(?i)(?:gst/?hst|gst|hst)\s*#?\s*[:.]?\s*([0-9]{9}(?:\s*RT\s*0*1)?)"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
              let r = Range(m.range(at: 1), in: ocr) else { return nil }
        return String(ocr[r]).trimmingCharacters(in: .whitespaces)
    }

    private static func extractProductionManager(from ocr: String) -> String? {
        if let v = extractLabeledValue(from: ocr, labels: ["production manager", "pm:", "pm approval"]) {
            return v
        }
        let pattern = #"(?i)production\s*manager\s*approval\s*[:.]?\s*([A-Za-z][A-Za-z\s.'-]{3,40})"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
              let r = Range(m.range(at: 1), in: ocr) else { return nil }
        return String(ocr[r]).trimmingCharacters(in: .whitespaces)
    }
}
