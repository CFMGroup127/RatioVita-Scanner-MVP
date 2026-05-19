import Foundation

/// Splits crew days for **department × unit** PDF twins (office roles consolidate to one sheet).
enum TimecardExportGrouping {
    struct ExportSlice: Identifiable, Sendable {
        let id: String
        let label: String
        let department: String
        let unit: String
        let days: [CrewTimecardDay]
        let workRecords: [WorkRecord]
    }

    static func slices(
        days: [CrewTimecardDay],
        workRecords: [WorkRecord]
    ) -> [ExportSlice] {
        guard !days.isEmpty else {
            return [
                ExportSlice(
                    id: "empty",
                    label: "No days",
                    department: "General",
                    unit: ProductionUnitType.mainUnit.rawValue,
                    days: [],
                    workRecords: workRecords
                ),
            ]
        }

        let grouped = Dictionary(grouping: days, by: { sliceKey(for: $0) })
        if grouped.count <= 1, let only = grouped.first {
            let (key, groupDays) = only
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            let dept = parts.first ?? "General"
            let unit = parts.count > 1 ? parts[1] : ProductionUnitType.mainUnit.rawValue
            return [
                ExportSlice(
                    id: key,
                    label: exportLabel(department: dept, unit: unit),
                    department: dept,
                    unit: unit,
                    days: groupDays,
                    workRecords: matchingWorkRecords(workRecords, department: dept, unit: unit)
                ),
            ]
        }

        return grouped.keys.sorted().map { key in
            let groupDays = grouped[key] ?? []
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            let dept = parts.first ?? "General"
            let unit = parts.count > 1 ? parts[1] : ProductionUnitType.mainUnit.rawValue
            return ExportSlice(
                id: key,
                label: exportLabel(department: dept, unit: unit),
                department: dept,
                unit: unit,
                days: groupDays,
                workRecords: matchingWorkRecords(workRecords, department: dept, unit: unit)
            )
        }
    }

    /// Office unit + same department → one approval chain; distinct units → separate PDFs.
    private static func sliceKey(for day: CrewTimecardDay) -> String {
        let dept = normalized(day.department) ?? "General"
        let unit = resolvedUnit(for: day)
        if isOfficeUnit(unit) {
            return "Office|\(dept)"
        }
        return "\(dept)|\(unit)"
    }

    private static func resolvedUnit(for day: CrewTimecardDay) -> String {
        if let stored = day.unitType?.trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
            return stored
        }
        if let fromEnum = ProductionUnitType.fromStored(day.unitType) {
            return fromEnum.rawValue
        }
        let dept = (day.department ?? "").lowercased()
        if dept.contains("office") || dept.contains("production office") {
            return ProductionUnitType.office.rawValue
        }
        return ProductionUnitType.mainUnit.rawValue
    }

    private static func isOfficeUnit(_ unit: String) -> Bool {
        unit.lowercased().contains("office")
    }

    private static func normalized(_ raw: String?) -> String? {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }

    private static func exportLabel(department: String, unit: String) -> String {
        if isOfficeUnit(unit) {
            return "Office · \(department)"
        }
        return "\(unit) · \(department)"
    }

    private static func matchingWorkRecords(
        _ records: [WorkRecord],
        department: String,
        unit: String
    ) -> [WorkRecord] {
        records.filter { wr in
            let d = normalized(wr.department) ?? "General"
            let u = normalized(wr.unitType) ?? ProductionUnitType.mainUnit.rawValue
            let wrKey = if isOfficeUnit(u) || isOfficeUnit(unit) {
                "Office|\(d)"
            } else {
                "\(d)|\(u)"
            }
            let target = if isOfficeUnit(unit) {
                "Office|\(department)"
            } else {
                "\(department)|\(unit)"
            }
            return wrKey == target
        }
    }
}
