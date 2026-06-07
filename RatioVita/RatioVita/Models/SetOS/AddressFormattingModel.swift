import Foundation

/// Dual-pass address: geolocator fills the structural lines; `unitSuiteNumber` is always
/// a distinct, manually editable field the geocoder may never overwrite (Sprint KKKK).
struct StandardizedAddress: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var streetAddress: String // e.g. "2927 Lakeshore Blvd W"
    var unitSuiteNumber: String // e.g. "Suite 248" — isolated, never auto-populated
    var city: String // "Toronto"
    var province: String // "ON"
    var postalCode: String // "M8V 1J3"

    init(
        id: UUID = UUID(),
        streetAddress: String = "",
        unitSuiteNumber: String = "",
        city: String = "",
        province: String = "",
        postalCode: String = ""
    ) {
        self.id = id
        self.streetAddress = streetAddress
        self.unitSuiteNumber = unitSuiteNumber
        self.city = city
        self.province = province
        self.postalCode = postalCode
    }

    var isEmpty: Bool {
        streetAddress.isEmpty && unitSuiteNumber.isEmpty && city.isEmpty
            && province.isEmpty && postalCode.isEmpty
    }

    /// Mailing layout exactly as requested:
    /// `2927 Lakeshore Blvd W` / `Suite 248` / `Toronto, ON` / `M8V 1J3`.
    var multiLineFormatted: String {
        var lines: [String] = []
        if !streetAddress.isEmpty { lines.append(streetAddress) }
        if !unitSuiteNumber.isEmpty { lines.append(unitSuiteNumber) }
        let locality = [city, province].filter { !$0.isEmpty }.joined(separator: ", ")
        if !locality.isEmpty { lines.append(locality) }
        if !postalCode.isEmpty { lines.append(postalCode) }
        return lines.joined(separator: "\n")
    }

    var singleLineSummary: String {
        multiLineFormatted.replacingOccurrences(of: "\n", with: ", ")
    }
}

/// Best-effort parsing of legacy single-string addresses + street-name variant normalization.
enum AddressComponentParser {
    /// Known street-name variants the geocoder may render inconsistently (e.g. "Lake Shore" → "Lakeshore").
    private static let streetVariants: [(pattern: String, canonical: String)] = [
        ("lake shore", "Lakeshore"),
    ]

    static func normalizeStreet(_ street: String) -> String {
        var output = street
        for variant in streetVariants {
            if let range = output.range(of: variant.pattern, options: .caseInsensitive) {
                output.replaceSubrange(range, with: variant.canonical)
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses a stored mailing string back into discrete fields, isolating any Suite/Unit token.
    static func parse(_ raw: String) -> StandardizedAddress {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return StandardizedAddress() }

        // Split on newlines or commas.
        let separators = CharacterSet(charactersIn: ",\n")
        var parts = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var address = StandardizedAddress()

        // Postal code (Canadian ANA NAN).
        if let postalIndex = parts.firstIndex(where: { isCanadianPostalCode($0) }) {
            address.postalCode = parts[postalIndex].uppercased()
            parts.remove(at: postalIndex)
        }

        // Suite / Unit / Apt token (isolated).
        if let unitIndex = parts.firstIndex(where: { isUnitToken($0) }) {
            address.unitSuiteNumber = parts[unitIndex]
            parts.remove(at: unitIndex)
        }

        // Province (2-letter Canadian) possibly attached to a locality token.
        if let provinceIndex = parts.lastIndex(where: { containsProvince($0) }) {
            let token = parts[provinceIndex]
            if let province = extractProvince(token) {
                address.province = province
                let locality = token
                    .replacingOccurrences(of: province, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
                if !locality.isEmpty {
                    address.city = locality
                    parts.remove(at: provinceIndex)
                } else {
                    parts.remove(at: provinceIndex)
                }
            }
        }

        if address.city.isEmpty, parts.count >= 2 {
            address.city = parts.removeLast()
        }

        address.streetAddress = normalizeStreet(parts.joined(separator: ", "))
        return address
    }

    static func isCanadianPostalCode(_ token: String) -> Bool {
        let pattern = "^[A-Za-z]\\d[A-Za-z]\\s?\\d[A-Za-z]\\d$"
        return token.range(of: pattern, options: .regularExpression) != nil
    }

    private static let provinces = [
        "ON", "QC", "BC", "AB", "MB", "SK", "NS", "NB", "NL", "PE", "NT", "NU", "YT",
    ]

    private static func isUnitToken(_ token: String) -> Bool {
        let lowered = token.lowercased()
        return lowered.hasPrefix("suite") || lowered.hasPrefix("unit")
            || lowered.hasPrefix("apt") || lowered.hasPrefix("#")
            || lowered.hasPrefix("ste") || lowered.hasPrefix("office")
    }

    private static func containsProvince(_ token: String) -> Bool {
        extractProvince(token) != nil
    }

    private static func extractProvince(_ token: String) -> String? {
        let upper = token.uppercased()
        return provinces.first { province in
            upper == province
                || upper.hasSuffix(" \(province)")
                || upper.hasPrefix("\(province) ")
                || upper.contains(" \(province) ")
        }
    }
}
