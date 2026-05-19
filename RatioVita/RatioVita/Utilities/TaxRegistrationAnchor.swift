import Foundation
import SwiftData

/// CRA Business Number (9-digit core) identity matching for owned corporations.
enum TaxRegistrationAnchor {
    /// Normalizes `76001212`, `76001212 RT0001`, `GST 760012120RT0001` → `76001212`.
    static func normalizedBusinessNumber(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let re = try? NSRegularExpression(pattern: #"(?i)(\d{8,9})\s*RT"#),
           let m = re.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let r = Range(m.range(at: 1), in: trimmed)
        {
            return String(trimmed[r])
        }
        let digits = trimmed.filter(\.isNumber)
        if digits.count == 9 { return String(digits) }
        if digits.count == 8 { return String(digits) }
        if digits.count > 9 { return String(digits.prefix(9)) }
        return nil
    }

    /// All 9-digit cores from owned entities (registration field + GST/HST field).
    static func ownedRegistrationCores(context: ModelContext) -> [(core: String, entity: BusinessEntity)] {
        let entities =
            (try? context.fetch(FetchDescriptor<BusinessEntity>()))?
                .filter(\.isOwnedCorporation) ?? []
        var out: [(String, BusinessEntity)] = []
        for e in entities {
            for raw in [e.taxRegistrationNumber, e.gstHstNumber] {
                if let core = normalizedBusinessNumber(from: raw) {
                    out.append((core, e))
                }
            }
        }
        return out
    }

    /// First owned entity whose BN appears in OCR (deal memos, CRA slips, invoices).
    static func matchOwnedEntity(in combinedOCR: String, context: ModelContext) -> BusinessEntity? {
        let hay = combinedOCR.filter(\.isNumber)
        guard hay.count >= 9 else { return nil }
        for pair in ownedRegistrationCores(context: context) {
            if combinedOCR.contains(pair.core) { return pair.entity }
            if hay.contains(pair.core) { return pair.entity }
        }
        return nil
    }

    /// True when a numeric token is a known corporate BN (not a purchase tax line).
    static func isKnownRegistrationNumber(_ amountDigits: String, context: ModelContext) -> Bool {
        guard let core = normalizedBusinessNumber(from: amountDigits) else { return false }
        return ownedRegistrationCores(context: context).contains { $0.core == core }
    }

    /// Strip registration tokens from deal-memo financial parsing.
    static func scrubRegistrationTokensFromFinancials(
        combinedOCR: String,
        context: ModelContext
    ) -> Bool {
        for pair in ownedRegistrationCores(context: context) where combinedOCR.contains(pair.core) {
            return true
        }
        return false
    }
}
