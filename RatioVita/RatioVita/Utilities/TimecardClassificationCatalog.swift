import Foundation

/// Department / unit picker options for crew-day classification (always includes the stored value).
enum TimecardClassificationCatalog {
    static let departmentPresets: [String] = [
        "Costumes",
        "Transport",
        "Performers",
        "Locations",
        "Assistant Directors",
        "Set Dec",
        "Grip & Electric",
        "Hair & Makeup",
        "Production Office",
    ]

    static let unitPresets: [String] = [
        "Main Unit",
        "2nd Unit",
        "Splinter Unit",
        "Main Splinter",
        "2nd Splinter",
        "2nd Splinter · U of T Mississauga",
        "Office",
    ]

    static func departmentOptions(stored: String?) -> [String] {
        mergePresets(departmentPresets, stored: stored)
    }

    static func unitOptions(stored: String?) -> [String] {
        mergePresets(unitPresets, stored: stored)
    }

    private static func mergePresets(_ presets: [String], stored: String?) -> [String] {
        let trimmed = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return presets }
        if presets.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return presets
        }
        return presets + [trimmed]
    }
}
