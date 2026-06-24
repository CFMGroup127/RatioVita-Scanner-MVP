import Foundation

/// Regional vehicle deduction heuristics for fuel logs and mileage OCR payloads.
enum MileageLogTracker {
    static let travelDeductionCategory = "Travel_Deduction_AutoCalculated"

    struct MileageParseResult: Sendable {
        let odometerReading: Double?
        let distanceKilometers: Double?
        let distanceMiles: Double?
        let routeDescription: String?
        let fuelCost: Decimal?
        let deductionRatePerUnit: Decimal
        let estimatedDeduction: Decimal?
        let entryKind: SovereignLedgerEntryKind
        let jurisdiction: MileageJurisdiction
        let travelDeductionCategory: String
        let anomalyFlags: [String]
    }

    enum MileageJurisdiction: String, Sendable {
        case canadaCRA = "CA_CRA"
        case unitedStatesIRS = "US_IRS"
    }

    /// CRA first-tier automobile allowance (CAD / km) — 2024 reference rate.
    private static let craRatePerKm: Decimal = 0.70
    /// IRS standard mileage rate (USD / mile) — 2024 reference rate.
    private static let irsRatePerMile: Decimal = 0.67

    static func parse(receipt: Receipt, parsed: OperationalBookkeeperParser.ParsedExpense) -> MileageParseResult? {
        let corpus = mileageCorpus(receipt)
        guard verifyMileageLogFormat(corpus) else { return nil }

        let jurisdiction = detectJurisdiction(corpus: corpus, currencyCode: parsed.currencyCode)
        let odometer = extractOdometer(from: corpus)
        let odometerDeltaKm = extractOdometerDeltaKilometers(from: corpus)
        let explicitKm = extractDistanceKilometers(from: corpus)
        let explicitMi = extractDistanceMiles(from: corpus)
        let route = extractRoute(from: corpus)
        let isFuelDoc = isFuel(corpus)
        let fuelCost = isFuelDoc ? parsed.grossAmount : nil

        let distanceKm: Double?
        let distanceMi: Double?
        if let delta = odometerDeltaKm {
            distanceKm = delta
            distanceMi = delta / 1.60934
        } else if let km = explicitKm {
            distanceKm = km
            distanceMi = km / 1.60934
        } else if let mi = explicitMi {
            distanceMi = mi
            distanceKm = mi * 1.60934
        } else {
            distanceKm = nil
            distanceMi = nil
        }

        let rate = jurisdiction == .canadaCRA ? craRatePerKm : irsRatePerMile
        var flags: [String] = []
        var estimated: Decimal?

        switch jurisdiction {
        case .canadaCRA:
            if let distanceKm, distanceKm > 0 {
                estimated = rate * Decimal(distanceKm)
            }
        case .unitedStatesIRS:
            if let distanceMi, distanceMi > 0 {
                estimated = rate * Decimal(distanceMi)
            } else if let distanceKm, distanceKm > 0 {
                let miles = distanceKm / 1.60934
                estimated = rate * Decimal(miles)
            }
        }

        if estimated == nil, odometer == nil, distanceKm == nil, fuelCost == nil {
            flags.append("mileage_metadata_incomplete")
        }

        let kind: SovereignLedgerEntryKind = fuelCost != nil ? .fuel : .mileage

        return MileageParseResult(
            odometerReading: odometer,
            distanceKilometers: distanceKm,
            distanceMiles: distanceMi,
            routeDescription: route,
            fuelCost: fuelCost,
            deductionRatePerUnit: rate,
            estimatedDeduction: estimated,
            entryKind: kind,
            jurisdiction: jurisdiction,
            travelDeductionCategory: travelDeductionCategory,
            anomalyFlags: flags
        )
    }

    // MARK: - Format verification

    private static func verifyMileageLogFormat(_ corpus: String) -> Bool {
        let c = corpus.lowercased()
        let unitSignals = [
            #"\b\d+(?:\.\d+)?\s*km\b"#,
            #"\b\d+(?:\.\d+)?\s*mi(?:les)?\b"#,
            #"\bodo(?:meter)?\b"#,
            #"\b\d{4,7}\s*(?:km|mi)\b"#,
        ]
        if unitSignals.contains(where: { c.range(of: $0, options: .regularExpression) != nil }) {
            return true
        }
        if extractRoute(from: corpus) != nil {
            return true
        }
        return isTravelOrFuel(corpus)
    }

    private static func detectJurisdiction(corpus: String, currencyCode: String) -> MileageJurisdiction {
        let c = corpus.lowercased()
        let currency = currencyCode.uppercased()

        let canadaSignals = [
            "canada", "canadian", " cra ", "hst", " gst ", " pst ", " qst ",
            " ontario", " toronto", " vancouver", " alberta", " quebec ",
            " bc ", " km driven", " kilometres", " kilometre",
        ]
        let usSignals = [
            " irs ", " united states", " u.s.", " usa", " california", " texas",
            " new york", " mileage rate", " miles driven", " standard mileage",
        ]

        var canadaScore = currency == "CAD" ? 2 : 0
        var usScore = currency == "USD" ? 2 : 0
        for signal in canadaSignals where c.contains(signal.trimmingCharacters(in: .whitespaces)) {
            canadaScore += 1
        }
        for signal in usSignals where c.contains(signal.trimmingCharacters(in: .whitespaces)) {
            usScore += 1
        }
        if c.contains("km") || c.contains("kilomet") {
            canadaScore += 1
        }
        if c.range(of: #"\b\d+(?:\.\d+)?\s*mi(?:les)?\b"#, options: .regularExpression) != nil {
            usScore += 1
        }

        return usScore > canadaScore ? .unitedStatesIRS : .canadaCRA
    }

    private static func isTravelOrFuel(_ corpus: String) -> Bool {
        let c = corpus.lowercased()
        return c.contains("fuel") || c.contains("gas") || c.contains("petro")
            || c.contains("mileage") || c.contains("odometer") || c.contains("km")
            || c.contains("mile") || c.contains("parking") || c.contains("uber")
            || c.contains("lyft") || c.contains("vehicle") || c.contains("travel log")
    }

    private static func isFuel(_ corpus: String) -> Bool {
        let c = corpus.lowercased()
        return c.contains("fuel") || c.contains("gas") || c.contains("petro") || c.contains("diesel")
    }

    private static func mileageCorpus(_ receipt: Receipt) -> String {
        var parts = [
            receipt.merchant,
            receipt.notes ?? "",
            receipt.annotations ?? "",
            receipt.taxCategory ?? "",
            receipt.department ?? "",
            receipt.lineItems.map(\.lineDescription).joined(separator: " "),
        ]
        for image in receipt.images.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            if let ocr = image.ocrText {
                parts.append(ocr)
            }
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Extraction

    private static func extractOdometer(from corpus: String) -> Double? {
        let patterns = [
            #"odometer[:\s]*(\d{4,7})"#,
            #"odo[:\s]*(\d{4,7})"#,
            #"ending\s+odo[:\s]*(\d{4,7})"#,
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern: pattern, in: corpus), let reading = Double(value) {
                return reading
            }
        }
        return nil
    }

    private static func extractOdometerDeltaKilometers(from corpus: String) -> Double? {
        let startPatterns = [
            #"start(?:ing)?\s+odo[:\s]*(\d{4,7})"#,
            #"begin(?:ning)?\s+odo[:\s]*(\d{4,7})"#,
            #"from\s+odo[:\s]*(\d{4,7})"#,
        ]
        let endPatterns = [
            #"end(?:ing)?\s+odo[:\s]*(\d{4,7})"#,
            #"to\s+odo[:\s]*(\d{4,7})"#,
        ]
        var start: Double?
        var end: Double?
        for pattern in startPatterns {
            if let value = firstCapture(pattern: pattern, in: corpus.lowercased()) {
                start = Double(value)
                break
            }
        }
        for pattern in endPatterns {
            if let value = firstCapture(pattern: pattern, in: corpus.lowercased()) {
                end = Double(value)
                break
            }
        }
        if let start, let end, end > start {
            return end - start
        }
        return nil
    }

    private static func extractDistanceKilometers(from corpus: String) -> Double? {
        if let km = firstCapture(pattern: #"(\d+(?:\.\d+)?)\s*km"#, in: corpus.lowercased()) {
            return Double(km)
        }
        if let km = firstCapture(pattern: #"(\d+(?:\.\d+)?)\s*kilomet(?:re|er)s?"#, in: corpus.lowercased()) {
            return Double(km)
        }
        return nil
    }

    private static func extractDistanceMiles(from corpus: String) -> Double? {
        if let mi = firstCapture(pattern: #"(\d+(?:\.\d+)?)\s*mi(?:les)?"#, in: corpus.lowercased()) {
            return Double(mi)
        }
        return nil
    }

    private static func extractRoute(from corpus: String) -> String? {
        let lower = corpus.lowercased()
        if let route = firstCapture(pattern: #"route[:\s]+(.{3,80})"#, in: lower) {
            return route.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let from = firstCapture(pattern: #"from[:\s]+(.{2,40}?)\s+to[:\s]+(.{2,40})"#, in: lower) {
            return from.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let leg = firstCapture(pattern: #"([A-Za-z][A-Za-z\s\-]{2,30})\s*(?:→|->| to )\s*([A-Za-z][A-Za-z\s\-]{2,30})"#, in: corpus) {
            return leg.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        if match.numberOfRanges > 2,
           let from = Range(match.range(at: 1), in: text),
           let to = Range(match.range(at: 2), in: text)
        {
            return "\(text[from]) → \(text[to])"
        }
        if match.numberOfRanges > 1, let capture = Range(match.range(at: 1), in: text) {
            return String(text[capture])
        }
        return nil
    }
}
