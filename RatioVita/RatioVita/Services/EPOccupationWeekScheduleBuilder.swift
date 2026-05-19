import Foundation

/// Builds EP **OCCUPATION** + **LOANOUT** overflow lines for multi-position / multi-unit weeks.
enum EPOccupationWeekScheduleBuilder {
    struct ScheduleLines: Sendable {
        /// Primary line in the OCCUPATION field (to the right of department).
        var occupationLine: String
        /// Continuation on the LOANOUT row (below NAME) when the week does not fit on one line.
        var loanoutOverflowLine: String?
    }

    private static let weekdayAbbrevs = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let occupationFieldLimit = 52
    private static let loanoutFieldLimit = 58

    static func build(
        days: [CrewTimecardDay],
        fallbackOccupation: String?,
        calendar: Calendar = .current
    ) -> ScheduleLines {
        let sorted = days.sorted { $0.workDate < $1.workDate }
        guard !sorted.isEmpty else {
            let occ = fallbackOccupation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return ScheduleLines(occupationLine: occ, loanoutOverflowLine: nil)
        }

        var segments: [(occ: String, unit: String, weekdays: [Int])] = []
        for day in sorted {
            let occ = resolvedOccupation(for: day, fallback: fallbackOccupation)
            let unit = shortUnitLabel(for: day.unitType)
            let wd = calendar.component(.weekday, from: day.workDate)
            if let last = segments.last, last.occ == occ, last.unit == unit {
                segments[segments.count - 1].weekdays.append(wd)
            } else {
                segments.append((occ, unit, [wd]))
            }
        }

        let parts = segments.map { formatSegment(occupation: $0.occ, unit: $0.unit, weekdays: $0.weekdays) }
        let full = parts.joined(separator: "; ")
        let split = splitForEPFields(full, occupationLimit: occupationFieldLimit, loanoutLimit: loanoutFieldLimit)
        return ScheduleLines(occupationLine: split.primary, loanoutOverflowLine: split.overflow)
    }

    private static func resolvedOccupation(for day: CrewTimecardDay, fallback: String?) -> String {
        let fromDay = day.occupationTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromDay.isEmpty { return fromDay }
        let fb = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fb.isEmpty ? "—" : fb
    }

    private static func shortUnitLabel(for raw: String?) -> String {
        if let unit = ProductionUnitType.fromStored(raw) {
            return unit.epAbbreviation
        }
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if t.isEmpty { return "MAIN" }
        if t.lowercased().contains("splinter") { return "SPL" }
        if t.lowercased().contains("2nd") || t.lowercased().contains("second") { return "2ND" }
        if t.lowercased().contains("office") { return "OFF" }
        return String(t.prefix(6)).uppercased()
    }

    private static func formatSegment(occupation: String, unit: String, weekdays: [Int]) -> String {
        let daysLabel = weekdayRangeLabel(weekdays)
        return "\(occupation) — \(daysLabel) (\(unit))"
    }

    private static func weekdayRangeLabel(_ weekdays: [Int]) -> String {
        let unique = Array(Set(weekdays)).sorted()
        guard !unique.isEmpty else { return "" }
        if unique.count == 1 {
            return weekdayAbbrevs[unique[0] - 1]
        }
        if isContiguous(unique), let first = unique.first, let last = unique.last, last > first {
            return "\(weekdayAbbrevs[first - 1])–\(weekdayAbbrevs[last - 1])"
        }
        return unique.map { weekdayAbbrevs[$0 - 1] }.joined(separator: " & ")
    }

    private static func isContiguous(_ weekdays: [Int]) -> Bool {
        guard weekdays.count >= 2 else { return true }
        for i in 1..<weekdays.count where weekdays[i] != weekdays[i - 1] + 1 {
            return false
        }
        return true
    }

    private static func splitForEPFields(
        _ text: String,
        occupationLimit: Int,
        loanoutLimit: Int
    ) -> (primary: String, overflow: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > occupationLimit else {
            return (trimmed, nil)
        }
        if let idx = trimmed.lastIndex(where: { $0 == ";" }) {
            let splitIdx = trimmed.distance(from: trimmed.startIndex, to: idx)
            if splitIdx > 0, splitIdx <= occupationLimit + 8 {
                let primary = String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces)
                var overflow = String(trimmed[trimmed.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                if overflow.count > loanoutLimit {
                    overflow = String(overflow.prefix(loanoutLimit - 1)) + "…"
                }
                return (String(primary.prefix(occupationLimit)), overflow.isEmpty ? nil : overflow)
            }
        }
        let primary = String(trimmed.prefix(occupationLimit - 1)) + "…"
        let overflow = String(trimmed.dropFirst(occupationLimit - 1)).prefix(loanoutLimit)
        return (primary, overflow.isEmpty ? nil : String(overflow))
    }
}
