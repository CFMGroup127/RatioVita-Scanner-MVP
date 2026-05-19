import Foundation

/// Builds EP **OTHER RATES** lines from crew days (cell, laptop, iPad, vehicle).
enum EPKitOtherRatesAggregator {
    static func lines(from days: [CrewTimecardDay], project: ProductionProject?) -> [String] {
        var lines: [String] = []
        let phone = aggregate(
            days: days,
            days: \.ancillaryPhoneDays,
            rate: \.ancillaryPhoneRateCAD,
            fallback: project?.defaultKitPhoneRateCAD
        )
        let laptop = aggregate(
            days: days,
            days: \.ancillaryLaptopDays,
            rate: \.ancillaryLaptopRateCAD,
            fallback: project?.defaultKitLaptopRateCAD
        )
        let tablet = aggregate(
            days: days,
            days: \.ancillaryTabletDays,
            rate: \.ancillaryTabletRateCAD,
            fallback: project?.defaultKitTabletRateCAD
        )
        let vehicle = aggregateOptionalDays(
            days: days,
            days: \.ancillaryVehicleDays,
            rate: \.ancillaryVehicleRateCAD,
            fallback: project?.defaultKitVehicleRateCAD
        )

        if phone.count > 0 || phone.rate != nil {
            lines.append("Cell \(phone.count)d @ \(phone.rateText)")
        }
        if laptop.count > 0 || laptop.rate != nil {
            lines.append("Laptop \(laptop.count)d @ \(laptop.rateText)")
        }
        if tablet.count > 0 || tablet.rate != nil {
            lines.append("iPad \(tablet.count)d @ \(tablet.rateText)")
        }
        let vehicleOn = project?.payrollVehicleKitEnabled ?? true
        if vehicleOn, vehicle.count > 0 || vehicle.rate != nil {
            lines.append("Vehicle \(vehicle.count)d @ \(vehicle.rateText)")
        }
        return lines
    }

    private struct KitAggregate {
        var count: Int
        var rate: Decimal?
        var rateText: String { rate.map { "\($0)" } ?? "—" }
    }

    private static func aggregate(
        days: [CrewTimecardDay],
        days daysKey: KeyPath<CrewTimecardDay, Int>,
        rate rateKey: KeyPath<CrewTimecardDay, Decimal?>,
        fallback: Decimal?
    ) -> KitAggregate {
        let billedDayCount = days.filter { $0[keyPath: daysKey] > 0 }.count
        let totalUnits = days.map { $0[keyPath: daysKey] }.reduce(0, +)
        let count = max(billedDayCount, totalUnits > 0 ? totalUnits : 0)
        let rate = days.compactMap { $0[keyPath: rateKey] }.first(where: { $0 > 0 }) ?? fallback
        return KitAggregate(count: count, rate: rate)
    }

    private static func aggregateOptionalDays(
        days: [CrewTimecardDay],
        days daysKey: KeyPath<CrewTimecardDay, Int?>,
        rate rateKey: KeyPath<CrewTimecardDay, Decimal?>,
        fallback: Decimal?
    ) -> KitAggregate {
        let billedDayCount = days.filter { ($0[keyPath: daysKey] ?? 0) > 0 }.count
        let totalUnits = days.compactMap { $0[keyPath: daysKey] }.reduce(0, +)
        let count = max(billedDayCount, totalUnits > 0 ? totalUnits : 0)
        let rate = days.compactMap { $0[keyPath: rateKey] }.first(where: { $0 > 0 }) ?? fallback
        return KitAggregate(count: count, rate: rate)
    }
}
