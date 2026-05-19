import Foundation

/// Flat / custom contract math — no IATSE penalty alarms; documents hours vs guarantee.
enum CustomNonUnionSentinelCalculator {
    static func estimate(
        day: CrewTimecardDay,
        calendar: Calendar = .current
    ) -> SentinelPayEstimate {
        let segment = day.productionProject?.activeRateSegment(
            for: day.workDate,
            occupation: day.occupationTitle,
            department: day.department,
            calendar: calendar
        )
        let ancillary = ancillaryTotal(day: day)
        let worked = workedHours(day: day, calendar: calendar)

        if let segment, segment.rateKind == .flatDaily, let flat = segment.flatDailyRateCAD {
            let guarantee = max(segment.flatGuaranteeHours ?? 14, 1)
            let impliedHourly = flat / Decimal(guarantee)
            var labor: Decimal
            if worked <= Double(guarantee) {
                labor = flat
            } else {
                let over = worked - Double(guarantee)
                labor = flat + impliedHourly * Decimal(over) * Decimal(1.5)
            }
            let total = labor + ancillary
            return SentinelPayEstimate(
                straightHours: min(worked, Double(guarantee)),
                overtime8To12Hours: max(0, min(worked - Double(guarantee), 4)),
                overtimeOver12Hours: max(0, worked - Double(guarantee) - 4),
                travelHours: 0,
                mealPenaltyHalfHours: 0,
                ancillaryCAD: ancillary,
                laborSubtotalCAD: labor,
                modelTotalCAD: total,
                turnaroundGoldMultiplier: 1,
                turnaroundInfringementApplied: false,
                laborBeforeDailyFloorCAD: nil,
                negotiatedDailyFloorCAD: flat,
                appliedDailyFloor: worked <= Double(guarantee)
            )
        }

        let hourly = decimalToDouble(
            day.overrideBaseHourlyRateCAD
                ?? day.productionProject?.effectiveLaborBaseRate(for: day.workDate, calendar: calendar)
                ?? 0
        )
        let straight = min(worked, 8)
        let ot812 = max(0, min(worked - 8, 4))
        let ot12 = max(0, worked - 12)
        let labor = Decimal(straight * hourly + ot812 * hourly * 1.5 + ot12 * hourly * 2)
        let total = labor + ancillary
        return SentinelPayEstimate(
            straightHours: straight,
            overtime8To12Hours: ot812,
            overtimeOver12Hours: ot12,
            travelHours: 0,
            mealPenaltyHalfHours: 0,
            ancillaryCAD: ancillary,
            laborSubtotalCAD: labor,
            modelTotalCAD: total,
            turnaroundGoldMultiplier: 1,
            turnaroundInfringementApplied: false,
            laborBeforeDailyFloorCAD: nil,
            negotiatedDailyFloorCAD: nil,
            appliedDailyFloor: false
        )
    }

    private static func workedHours(day: CrewTimecardDay, calendar _: Calendar) -> Double {
        guard let start = day.callOnSet ?? day.travelToSetArrive ?? day.generalCrewCall,
              let end = day.wrapOffSet ?? day.travelReturnLeaveSet else { return 0 }
        return max(end.timeIntervalSince(start) / 3600, 0)
    }

    private static func ancillaryTotal(day: CrewTimecardDay) -> Decimal {
        var t = Decimal.zero
        if let r = day.ancillaryPhoneRateCAD { t += r * Decimal(day.ancillaryPhoneDays) }
        if let r = day.ancillaryLaptopRateCAD { t += r * Decimal(day.ancillaryLaptopDays) }
        if let r = day.ancillaryTabletRateCAD { t += r * Decimal(day.ancillaryTabletDays) }
        return t
    }

    private static func decimalToDouble(_ d: Decimal) -> Double {
        (d as NSDecimalNumber).doubleValue
    }
}
