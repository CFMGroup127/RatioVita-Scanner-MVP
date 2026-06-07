import Foundation

/// Builds EP **OTHER RATES** lines from crew days (cell, laptop, iPad, vehicle) and rate-tier allowances.
enum EPKitOtherRatesAggregator {
    static func lines(
        from days: [CrewTimecardDay],
        project: ProductionProject?,
        rateTiers: [ShowLaborPositionRate] = []
    ) -> [String] {
        var lines = crewDayKitLines(from: days, project: project)
        let tierLines = tierAllowanceLines(from: rateTiers, days: days)
        for line in tierLines where !lines.contains(line) {
            lines.append(line)
        }
        return lines
    }

    /// Kit rental dollars (crew-day counters × rates + tier daily allowances × billed days).
    static func totalKitAllowanceCAD(
        from days: [CrewTimecardDay],
        project: ProductionProject?,
        rateTiers: [ShowLaborPositionRate] = []
    ) -> Decimal {
        var total: Decimal = 0
        for day in days {
            total += kitLineTotal(
                units: day.ancillaryPhoneDays,
                rate: day.ancillaryPhoneRateCAD ?? project?.defaultKitPhoneRateCAD
            )
            total += kitLineTotal(
                units: day.ancillaryLaptopDays,
                rate: day.ancillaryLaptopRateCAD ?? project?.defaultKitLaptopRateCAD
            )
            total += kitLineTotal(
                units: day.ancillaryTabletDays,
                rate: day.ancillaryTabletRateCAD ?? project?.defaultKitTabletRateCAD
            )
            let vehicleUnits = day.ancillaryVehicleDays ?? 0
            if project?.payrollVehicleKitOn == true {
                total += kitLineTotal(
                    units: vehicleUnits,
                    rate: day.ancillaryVehicleRateCAD ?? project?.defaultKitVehicleRateCAD
                )
            }
        }
        let tierOnly = tierAllowanceLines(from: rateTiers, days: days)
        if crewDayKitLines(from: days, project: project).isEmpty, !tierOnly.isEmpty {
            for line in tierOnly {
                total += parseTierLineAmount(line, dayCount: days.count)
            }
        }
        return total
    }

    private static func kitLineTotal(units: Int, rate: Decimal?) -> Decimal {
        guard units > 0, let rate else { return 0 }
        return Decimal(units) * rate
    }

    private static func crewDayKitLines(from days: [CrewTimecardDay], project: ProductionProject?) -> [String] {
        var lines: [String] = []
        let phone = aggregate(
            days: days,
            days: \.ancillaryPhoneDays,
            rate: \.ancillaryPhoneRateCAD,
            fallback: project?.defaultKitPhoneRateCAD,
            label: "Cell"
        )
        let laptop = aggregate(
            days: days,
            days: \.ancillaryLaptopDays,
            rate: \.ancillaryLaptopRateCAD,
            fallback: project?.defaultKitLaptopRateCAD,
            label: "Laptop"
        )
        let tablet = aggregate(
            days: days,
            days: \.ancillaryTabletDays,
            rate: \.ancillaryTabletRateCAD,
            fallback: project?.defaultKitTabletRateCAD,
            label: "iPad"
        )
        let vehicle = aggregateOptionalDays(
            days: days,
            days: \.ancillaryVehicleDays,
            rate: \.ancillaryVehicleRateCAD,
            fallback: project?.defaultKitVehicleRateCAD,
            label: "Vehicle"
        )

        if phone.count > 0, phone.rate != nil {
            lines.append("\(phone.label) \(phone.count)d @ \(phone.rateText)")
        }
        if laptop.count > 0, laptop.rate != nil {
            lines.append("\(laptop.label) \(laptop.count)d @ \(laptop.rateText)")
        }
        if tablet.count > 0, tablet.rate != nil {
            lines.append("\(tablet.label) \(tablet.count)d @ \(tablet.rateText)")
        }
        let vehicleOn = project?.payrollVehicleKitEnabled ?? true
        if vehicleOn, vehicle.count > 0, vehicle.rate != nil {
            lines.append("\(vehicle.label) \(vehicle.count)d @ \(vehicle.rateText)")
        }
        return lines
    }

    private static func tierAllowanceLines(
        from tiers: [ShowLaborPositionRate],
        days: [CrewTimecardDay]
    ) -> [String] {
        guard !days.isEmpty else { return [] }
        let cal = Calendar.current
        let departments = Set(
            days.compactMap { $0.department?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        var lines: [String] = []
        var seen = Set<String>()

        for tier in tiers {
            let tierDept = tier.department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !departments.isEmpty, !tierDept.isEmpty, !departments.contains(tierDept) {
                continue
            }
            let activeOnAnyDay = days.contains { day in
                cal.startOfDay(for: tier.effectiveFromDate) <= cal.startOfDay(for: day.workDate)
            }
            guard activeOnAnyDay else { continue }
            for line in parseAllowanceNotes(tier.allowanceNotes) where !seen.contains(line) {
                seen.insert(line)
                lines.append(line)
            }
        }
        return lines
    }

    private static func parseAllowanceNotes(_ notes: String?) -> [String] {
        guard let notes, !notes.isEmpty else { return [] }
        return notes.split(separator: "\n").compactMap { raw -> String? in
            let parts = raw.split(separator: "|", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { return nil }
            let kind = String(parts[0]).lowercased()
            let rate = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rate.isEmpty else { return nil }
            switch kind {
                case "cell": return "CELL @ \(rate)"
                case "tablet": return "IPAD @ \(rate)"
                case "laptop": return "COMPUTER @ \(rate)"
                case "vehicle": return "VEHICLE @ \(rate)"
                case "kit": return "KIT @ \(rate)"
                default: return "\(kind.uppercased()) @ \(rate)"
            }
        }
    }

    private static func parseTierLineAmount(_ line: String, dayCount: Int) -> Decimal {
        guard let atRange = line.range(of: "@") else { return 0 }
        let rateText = line[atRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rate = Decimal(string: rateText.replacingOccurrences(of: ",", with: ".")) else { return 0 }
        return rate * Decimal(max(dayCount, 1))
    }

    private struct KitAggregate {
        var count: Int
        var rate: Decimal?
        var label: String
        var rateText: String { rate.map { "\($0)" } ?? "—" }
    }

    private static func aggregate(
        days: [CrewTimecardDay],
        days dayKey: KeyPath<CrewTimecardDay, Int>,
        rate rateKey: KeyPath<CrewTimecardDay, Decimal?>,
        fallback: Decimal?,
        label: String
    ) -> KitAggregate {
        let billedDayCount = days.filter { $0[keyPath: dayKey] > 0 }.count
        let totalUnits = days.map { $0[keyPath: dayKey] }.reduce(0, +)
        let count = max(billedDayCount, totalUnits > 0 ? totalUnits : 0)
        let rate = days.compactMap { $0[keyPath: rateKey] }.first(where: { $0 > 0 }) ?? fallback
        return KitAggregate(count: count, rate: rate, label: label)
    }

    private static func aggregateOptionalDays(
        days: [CrewTimecardDay],
        days dayKey: KeyPath<CrewTimecardDay, Int?>,
        rate rateKey: KeyPath<CrewTimecardDay, Decimal?>,
        fallback: Decimal?,
        label: String
    ) -> KitAggregate {
        let billedDayCount = days.filter { ($0[keyPath: dayKey] ?? 0) > 0 }.count
        let totalUnits = days.compactMap { $0[keyPath: dayKey] }.reduce(0, +)
        let count = max(billedDayCount, totalUnits > 0 ? totalUnits : 0)
        let rate = days.compactMap { $0[keyPath: rateKey] }.first(where: { $0 > 0 }) ?? fallback
        return KitAggregate(count: count, rate: rate, label: label)
    }
}
