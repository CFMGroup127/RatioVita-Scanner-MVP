import Foundation

struct PageOneHarvestResult: Sendable {
    var hourlyRate: Double
    var kitAllowance: Double
    var unionTier: String
    var corporateEntity: String
}

/// Targets deal memo page 1 — rates, kits, tiers (OCR heuristic until PDF parser ships).
@MainActor
enum PageOneHarvestService {
    static func harvest(from ocrText: String) -> PageOneHarvestResult {
        var hourly: Double = 0
        var kit: Double = 0
        var tier = "IATSE Tier 1"
        var corp = ""

        for line in ocrText.split(whereSeparator: \.isNewline) {
            let t = String(line).lowercased()
            if t.contains("/hr") || t.contains("hourly") {
                hourly = extractMoney(from: line) ?? hourly
            }
            if t.contains("kit") || t.contains("box rental") {
                kit = extractMoney(from: line) ?? kit
            }
            if t.contains("tier") {
                tier = String(line).trimmingCharacters(in: .whitespaces)
            }
            if t.contains("corp") || t.contains("ltd") {
                corp = String(line).trimmingCharacters(in: .whitespaces)
            }
        }

        if hourly == 0 { hourly = 62.5 }
        if kit == 0 { kit = 50 }

        return PageOneHarvestResult(
            hourlyRate: hourly,
            kitAllowance: kit,
            unionTier: tier,
            corporateEntity: corp
        )
    }

    private static func extractMoney(from line: Substring) -> Double? {
        let pattern = #"\$?\s*([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: String(line),
                  range: NSRange(String(line).startIndex..., in: String(line))
              ),
              let range = Range(match.range(at: 1), in: String(line)) else { return nil }
        return Double(String(line)[range])
    }
}
