import Foundation

/// Regional vehicle deduction heuristics for fuel logs and mileage OCR payloads.
enum MileageLogTracker {
    struct MileageParseResult: Sendable {
        let odometerReading: Double?
        let distanceKilometers: Double?
        let routeDescription: String?
        let fuelCost: Decimal?
        let deductionRatePerUnit: Decimal
        let estimatedDeduction: Decimal?
        let entryKind: SovereignLedgerEntryKind
        let anomalyFlags: [String]
    }

    /// CRA first-tier automobile allowance (CAD / km) — 2024 reference rate.
    private static let craRatePerKm: Decimal = 0.70
    /// IRS standard mileage rate (USD / mile) — 2024 reference rate.
    private static let irsRatePerMile: Decimal = 0.67

    static func parse(receipt: Receipt, parsed: OperationalBookkeeperParser.ParsedExpense) -> MileageParseResult? {
        let corpus = mileageCorpus(receipt)
        guard isTravelOrFuel(corpus) else { return nil }

        let currency = parsed.currencyCode.uppercased()
        let isCanadian = currency == "CAD"
        let odometer = extractOdometer(from: corpus)
        let distanceKm = extractDistanceKilometers(from: corpus)
        let route = extractRoute(from: corpus)
        let fuelCost = isFuel(corpus) ? parsed.grossAmount : nil

        let rate = isCanadian ? craRatePerKm : irsRatePerMile
        var flags: [String] = []
        var estimated: Decimal?

        if let distanceKm, distanceKm > 0 {
            if isCanadian {
                estimated = rate * Decimal(distanceKm)
            } else {
                let miles = distanceKm / 1.60934
                estimated = rate * Decimal(miles)
            }
        } else if odometer == nil, distanceKm == nil, fuelCost == nil {
            flags.append("mileage_metadata_incomplete")
        }

        let kind: SovereignLedgerEntryKind = fuelCost != nil ? .fuel : .mileage

        return MileageParseResult(
            odometerReading: odometer,
            distanceKilometers: distanceKm,
            routeDescription: route,
            fuelCost: fuelCost,
            deductionRatePerUnit: rate,
            estimatedDeduction: estimated,
            entryKind: kind,
            anomalyFlags: flags
        )
    }

    private static func isTravelOrFuel(_ corpus: String) -> Bool {
        let c = corpus.lowercased()
        return c.contains("fuel") || c.contains("gas") || c.contains("petro")
            || c.contains("mileage") || c.contains("odometer") || c.contains("km")
            || c.contains("mile") || c.contains("parking") || c.contains("uber")
            || c.contains("lyft") || c.contains("vehicle")
    }

    private static func isFuel(_ corpus: String) -> Bool {
        let c = corpus.lowercased()
        return c.contains("fuel") || c.contains("gas") || c.contains("petro") || c.contains("diesel")
    }

    private static func mileageCorpus(_ receipt: Receipt) -> String {
        [
            receipt.merchant,
            receipt.notes ?? "",
            receipt.annotations ?? "",
            receipt.taxCategory ?? "",
            receipt.lineItems.map(\.lineDescription).joined(separator: " "),
        ].joined(separator: " ")
    }

    private static func extractOdometer(from corpus: String) -> Double? {
        let patterns = [
            #"odometer[:\s]*(\d{4,7})"#,
            #"odo[:\s]*(\d{4,7})"#,
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern: pattern, in: corpus) {
                return Double(value)
            }
        }
        return nil
    }

    private static func extractDistanceKilometers(from corpus: String) -> Double? {
        if let km = firstCapture(pattern: #"(\d+(?:\.\d+)?)\s*km"#, in: corpus.lowercased()) {
            return Double(km)
        }
        if let mi = firstCapture(pattern: #"(\d+(?:\.\d+)?)\s*mi(?:les)?"#, in: corpus.lowercased()) {
            guard let miles = Double(mi) else { return nil }
            return miles * 1.60934
        }
        return nil
    }

    private static func extractRoute(from corpus: String) -> String? {
        let patterns = [
            #"route[:\s]+(.{3,80})"#,
            #"from[:\s]+(.{3,40})\s+to[:\s]+(.{3,40})"#,
        ]
        if let route = firstCapture(pattern: patterns[0], in: corpus.lowercased()) {
            return route.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let match = corpus.lowercased().range(of: patterns[1], options: .regularExpression) {
            return String(corpus[match]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[capture])
    }
}
