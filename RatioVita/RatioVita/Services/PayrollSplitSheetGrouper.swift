import Foundation

/// Composite key for isolated payroll PDF export (one sheet per department + unit).
struct PayrollSplitSheetKey: Hashable, Sendable, Identifiable {
    let department: String
    let unit: String

    var id: String { "\(department)|\(unit)" }

    var menuTitle: String {
        "\(department) — \(unit)"
    }

    var exportFileTag: String {
        let dept = department.replacingOccurrences(of: " ", with: "_")
        let u = unit.replacingOccurrences(of: " ", with: "_")
        return "\(dept)_\(u)"
    }

    static func from(day: CrewTimecardDay, project: ProductionProject?) -> PayrollSplitSheetKey {
        let deptRaw = day.department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let dept: String = {
            if !deptRaw.isEmpty { return deptRaw }
            let fallback = project?.payrollDepartment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return fallback.isEmpty ? "Unassigned" : fallback
        }()
        let unit = normalizedUnitLabel(day.unitType)
        return PayrollSplitSheetKey(department: dept, unit: unit)
    }

    static func normalizedUnitLabel(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return "Main Unit" }
        if let known = ProductionUnitType.fromStored(trimmed) {
            return known.rawValue
        }
        if trimmed.lowercased().contains("splinter") {
            if trimmed.lowercased().contains("2nd") { return "2nd Splinter" }
            if trimmed.lowercased().contains("main") { return "Main Splinter" }
            return "Splinter Unit"
        }
        return trimmed
    }
}

enum PayrollSplitSheetGrouper {
    static func keys(from days: [CrewTimecardDay], project: ProductionProject?) -> [PayrollSplitSheetKey] {
        let unique = Set(days.map { PayrollSplitSheetKey.from(day: $0, project: project) })
        return unique.sorted {
            if $0.department != $1.department { return $0.department < $1.department }
            return $0.unit < $1.unit
        }
    }

    static func days(
        in allDays: [CrewTimecardDay],
        matching key: PayrollSplitSheetKey,
        project: ProductionProject?
    ) -> [CrewTimecardDay] {
        allDays.filter { PayrollSplitSheetKey.from(day: $0, project: project) == key }
    }

    /// Suggested PDF layout — Performers / ACTRA BG rows use talent layout when available.
    static func suggestedFormat(
        for key: PayrollSplitSheetKey,
        defaultFormat: TimecardPDFFormatKind
    ) -> TimecardPDFFormatKind {
        let dept = key.department.lowercased()
        if dept.contains("performer") || dept.contains("actra") || dept.contains("background") {
            return .castAndCrewTalentToronto
        }
        return defaultFormat
    }
}
