import Foundation

/// **IATSE 411 Chef / catering** Sentinel: negotiated **daily floor** with OT / meal math built from
/// `negotiatedDailyMinimum ÷ guaranteedHours` (e.g. $600 ÷ 14h). Portal-to-portal hooks reuse
/// `SentinelEffectiveClock` + `FraturdayCalendar` (same as 873).
enum IATSE411SentinelCalculator {
    static func estimate(day: CrewTimecardDay, agreement: LaborAgreement, calendar: Calendar = .current)
        -> SentinelPayEstimate
    {
        estimateSingleDay411(day: day, agreement: agreement, calendar: calendar)
    }

    static func estimatesWithTurnaround(
        projectDays: [CrewTimecardDay],
        agreement: LaborAgreement,
        calendar: Calendar = .current
    ) -> [UUID: SentinelPayEstimate] {
        let sorted = FraturdayCalendar.sortedForPayrollChain(projectDays, calendar: calendar)
        let base = sorted.map { estimateSingleDay411(day: $0, agreement: agreement, calendar: calendar) }
        var out: [UUID: SentinelPayEstimate] = [:]
        let restSeconds = agreement.minimumRestHoursBetweenShootDays * 3600
        let gold = agreement.turnaroundGoldPayMultiplier

        for (idx, d) in sorted.enumerated() {
            var est = base[idx]
            var mult = 1.0
            var infringed = false
            if idx > 0 {
                let prev = sorted[idx - 1]
                let prevProj = prev.productionProject
                let prevCall = SentinelEffectiveClock.effectiveCall(day: prev, project: prevProj)
                let prevWrapRaw = SentinelEffectiveClock.effectiveWrapRaw(day: prev, project: prevProj)
                if let prevWrap = FraturdayCalendar.normalizedWrapAfterCall(
                    call: prevCall,
                    wrap: prevWrapRaw,
                    workDateStart: calendar.startOfDay(for: prev.workDate),
                    calendar: calendar
                ) {
                    let nextCall = SentinelEffectiveClock.effectiveCall(day: d, project: d.productionProject)
                        ?? calendar.startOfDay(for: d.workDate)
                    let gap = nextCall.timeIntervalSince(prevWrap)
                    if gap < restSeconds, gold > 1.000_1 {
                        mult = gold
                        infringed = true
                    }
                }
            }
            let labor = est.laborSubtotalCAD
            let anc = est.ancillaryCAD
            if infringed {
                let multDec = Decimal(string: String(format: "%.6f", mult)) ?? 1
                let newLabor = labor * multDec
                est = SentinelPayEstimate(
                    straightHours: est.straightHours,
                    overtime8To12Hours: est.overtime8To12Hours,
                    overtimeOver12Hours: est.overtimeOver12Hours,
                    travelHours: est.travelHours,
                    mealPenaltyHalfHours: est.mealPenaltyHalfHours,
                    ancillaryCAD: anc,
                    laborSubtotalCAD: labor,
                    modelTotalCAD: newLabor + anc,
                    turnaroundGoldMultiplier: mult,
                    turnaroundInfringementApplied: true,
                    laborBeforeDailyFloorCAD: est.laborBeforeDailyFloorCAD,
                    negotiatedDailyFloorCAD: est.negotiatedDailyFloorCAD,
                    appliedDailyFloor: est.appliedDailyFloor
                )
            } else {
                est = SentinelPayEstimate(
                    straightHours: est.straightHours,
                    overtime8To12Hours: est.overtime8To12Hours,
                    overtimeOver12Hours: est.overtimeOver12Hours,
                    travelHours: est.travelHours,
                    mealPenaltyHalfHours: est.mealPenaltyHalfHours,
                    ancillaryCAD: est.ancillaryCAD,
                    laborSubtotalCAD: est.laborSubtotalCAD,
                    modelTotalCAD: est.modelTotalCAD,
                    turnaroundGoldMultiplier: 1,
                    turnaroundInfringementApplied: false,
                    laborBeforeDailyFloorCAD: est.laborBeforeDailyFloorCAD,
                    negotiatedDailyFloorCAD: est.negotiatedDailyFloorCAD,
                    appliedDailyFloor: est.appliedDailyFloor
                )
            }
            out[d.id] = est
        }
        return out
    }

    static func estimate(
        for day: CrewTimecardDay,
        inProjectDays projectDays: [CrewTimecardDay],
        agreement: LaborAgreement,
        calendar: Calendar = .current
    ) -> SentinelPayEstimate {
        let map = estimatesWithTurnaround(projectDays: projectDays, agreement: agreement, calendar: calendar)
        return map[day.id] ?? estimateSingleDay411(day: day, agreement: agreement, calendar: calendar)
    }

    private static func estimateSingleDay411(
        day: CrewTimecardDay,
        agreement: LaborAgreement,
        calendar: Calendar
    ) -> SentinelPayEstimate {
        guard let floorDec = agreement.negotiatedDailyMinimumCAD,
              let gh = agreement.guaranteedHoursForDailyFloor,
              gh > 0.000_1 else
        {
            return IATSE873SentinelCalculator.estimate(day: day, agreement: agreement, calendar: calendar)
        }

        let project = day.productionProject
        let portal = SentinelEffectiveClock.portalToPortalEnabled(project: project)
        let floorD = (floorDec as NSDecimalNumber).doubleValue
        let hourlyDerived = floorD / gh
        let hourlyDec = Decimal(string: String(format: "%.6f", hourlyDerived)) ?? Decimal(floorD / gh)
        let mealHalf = hourlyDec * Decimal(0.5)

        let zone = (agreement.zoneTravelHourlyCAD as NSDecimalNumber).doubleValue

        func hours(_ a: Date?, _ b: Date?) -> Double {
            guard let a, let b, b > a else { return 0 }
            return b.timeIntervalSince(a) / 3600
        }

        var travelH = 0.0
        if !portal {
            travelH = hours(day.travelLeaveZoneStart, day.travelToSetArrive)
            travelH += hours(day.travelReturnLeaveSet, day.travelReturnHome)
        }

        let effCall = SentinelEffectiveClock.effectiveCall(day: day, project: project)
        let effWrapRaw = SentinelEffectiveClock.effectiveWrapRaw(day: day, project: project)

        let wrapN = FraturdayCalendar.normalizedWrapAfterCall(
            call: effCall,
            wrap: effWrapRaw,
            workDateStart: calendar.startOfDay(for: day.workDate),
            calendar: calendar
        )
        let onClock = hours(effCall, wrapN)
        var unpaidMealH = 0.0
        if let s = day.meal1Start, let e = day.meal1End, e > s {
            unpaidMealH += hours(s, e)
        }
        if let s = day.meal2Start, let e = day.meal2End, e > s {
            unpaidMealH += hours(s, e)
        }

        let workNet = max(0, onClock - unpaidMealH)
        let straight = min(workNet, 8)
        let otMid = min(max(0, workNet - 8), 4)
        let otDeep = max(0, workNet - 12)

        let m8 = agreement.overtimeMultiplierAfter8
        let m12 = agreement.overtimeMultiplierAfter12

        var mealPenalties = 0
        if workNet > 0, let call = effCall, wrapN != nil {
            let limit = agreement.maxWorkHoursBeforeMealRequired
            let firstMealEnd = day.meal1End ?? day.meal2End
            if firstMealEnd == nil || hours(call, firstMealEnd) > limit {
                mealPenalties += 1
            }
            if day.meal2Start != nil, day.meal2End == nil, let wn = wrapN, hours(day.meal2Start, wn) > limit {
                mealPenalties += 1
            }
        }

        let straightPay = Decimal(straight * hourlyDerived)
        let otPay = Decimal(otMid * hourlyDerived * m8) + Decimal(otDeep * hourlyDerived * m12)
        let travelPay = Decimal(travelH * zone)
        let mealPay = mealHalf * Decimal(mealPenalties)

        var anc = Decimal.zero
        if let r = day.ancillaryPhoneRateCAD { anc += r * Decimal(max(0, day.ancillaryPhoneDays)) }
        if let r = day.ancillaryLaptopRateCAD { anc += r * Decimal(max(0, day.ancillaryLaptopDays)) }
        if let r = day.ancillaryTabletRateCAD { anc += r * Decimal(max(0, day.ancillaryTabletDays)) }

        let laborCalc = straightPay + otPay + travelPay + mealPay
        let laborEff = max(floorDec, laborCalc)
        let appliedFloor = laborCalc < floorDec
        let total = laborEff + anc

        return SentinelPayEstimate(
            straightHours: straight,
            overtime8To12Hours: otMid,
            overtimeOver12Hours: otDeep,
            travelHours: travelH,
            mealPenaltyHalfHours: mealPenalties,
            ancillaryCAD: anc,
            laborSubtotalCAD: laborEff,
            modelTotalCAD: total,
            turnaroundGoldMultiplier: 1,
            turnaroundInfringementApplied: false,
            laborBeforeDailyFloorCAD: laborCalc,
            negotiatedDailyFloorCAD: floorDec,
            appliedDailyFloor: appliedFloor
        )
    }
}
