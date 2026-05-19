import Foundation

/// **Model-only** gross pay estimate from a `CrewTimecardDay` + `LaborAgreement` (not payroll net, not union legal
/// advice).
struct SentinelPayEstimate: Sendable {
    var straightHours: Double
    var overtime8To12Hours: Double
    var overtimeOver12Hours: Double
    var travelHours: Double
    var mealPenaltyHalfHours: Int
    var ancillaryCAD: Decimal
    /// Straight + OT + travel + meal (before turnaround gold). For 411 Chef this is **after** the daily floor max.
    var laborSubtotalCAD: Decimal
    /// Sentinel “gross-ish” model total in CAD (includes turnaround gold on labor when applicable).
    var modelTotalCAD: Decimal
    /// 1.0 or agreement’s `turnaroundGoldPayMultiplier` when the prior wrap → this call rest was short.
    var turnaroundGoldMultiplier: Double
    var turnaroundInfringementApplied: Bool

    /// Labor sum **before** applying the negotiated daily floor (411 Chef only); nil for pure 873 rows.
    var laborBeforeDailyFloorCAD: Decimal?
    /// Negotiated daily floor used for comparison (411 Chef only).
    var negotiatedDailyFloorCAD: Decimal?
    /// True when the **floor** beat the raw calculated labor (411 Chef).
    var appliedDailyFloor: Bool
}

/// IATSE **873 Sentinel** math: OT blocks, simplified meal penalty, zone travel hours, kit / phone flat days,
/// **Fraturday** wrap normalization, and **turnaround gold** on the day after a short rest.
enum IATSE873SentinelCalculator {
    /// Single-day estimate **without** cross-day turnaround (wrap still normalized past midnight).
    static func estimate(day: CrewTimecardDay, agreement: LaborAgreement, calendar: Calendar = .current)
        -> SentinelPayEstimate
    {
        estimateSingleDay(day: day, agreement: agreement, calendar: calendar)
    }

    /// Chain-aware estimates for **all** `projectDays` (same show), sorted by payroll anchor + call.
    static func estimatesWithTurnaround(
        projectDays: [CrewTimecardDay],
        agreement: LaborAgreement,
        calendar: Calendar = .current
    ) -> [UUID: SentinelPayEstimate] {
        let sorted = FraturdayCalendar.sortedForPayrollChain(projectDays, calendar: calendar)
        let base = sorted.map { estimateSingleDay(day: $0, agreement: agreement, calendar: calendar) }
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
            if infringed {
                let labor = est.laborSubtotalCAD
                let anc = est.ancillaryCAD
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
        return map[day.id] ?? estimateSingleDay(day: day, agreement: agreement, calendar: calendar)
    }

    /// Returns `true` when paycheck **gross** differs materially from summed Sentinel model for the ISO week of the
    /// pay date (uses **payroll anchor** days + turnaround chain across all crew days on that production).
    static func paycheckShowsVariance(
        paycheck: Receipt,
        allDays: [CrewTimecardDay],
        agreement: LaborAgreement,
        toleranceCAD: Decimal = 20,
        calendar: Calendar = .current
    ) -> Bool {
        guard DocumentTypeOption.fromStored(paycheck.documentType) == .paycheck else { return false }
        guard let project = paycheck.productionProject else { return false }
        let anchor = paycheck.transactionDate ?? paycheck.createdAt
        guard let week = calendar.dateInterval(of: .weekOfYear, for: anchor) else { return false }

        let projectDays = allDays.filter { $0.productionProject?.id == project.id }
        let chain = estimatesWithTurnaround(projectDays: projectDays, agreement: agreement, calendar: calendar)

        let relevant = projectDays.filter { day in
            let sod = FraturdayCalendar.payrollAnchorStartOfDay(for: day, calendar: calendar)
            return sod >= week.start && sod < week.end
        }
        guard !relevant.isEmpty else { return false }

        var model = Decimal.zero
        for d in relevant {
            if let e = chain[d.id] {
                model += e.modelTotalCAD
            } else {
                model += estimateSingleDay(day: d, agreement: agreement, calendar: calendar).modelTotalCAD
            }
        }

        let stub = abs(paycheck.total)
        return abs(stub - model) > toleranceCAD
    }

    private static func estimateSingleDay(
        day: CrewTimecardDay,
        agreement: LaborAgreement,
        calendar: Calendar
    ) -> SentinelPayEstimate {
        let project = day.productionProject
        let portal = SentinelEffectiveClock.portalToPortalEnabled(project: project)
        let base = resolveBaseHourly(day: day, agreement: agreement, calendar: calendar)
        let zone = decimalToDouble(agreement.zoneTravelHourlyCAD)
        let mealHalf = agreement.mealPenaltyHalfHourCAD

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
            let limitSec = limit * 3600
            let individualStart = day.travelLeaveZoneStart ?? call
            let crewCall = day.generalCrewCall ?? call
            var firstMealDeadline = individualStart.addingTimeInterval(limitSec)
            let crewDeadline = crewCall.addingTimeInterval(limitSec)
            if crewDeadline < firstMealDeadline {
                firstMealDeadline = crewDeadline
            }
            let firstMealEnd = day.meal1End ?? day.meal2End
            if firstMealEnd == nil || firstMealEnd! > firstMealDeadline {
                mealPenalties += 1
            }
            if day.meal2Start != nil, day.meal2End == nil, let wn = wrapN, hours(day.meal2Start, wn) > limit {
                mealPenalties += 1
            }
        }

        let straightPay = Decimal(straight * base)
        let otPay = Decimal(otMid * base * m8) + Decimal(otDeep * base * m12)
        let travelPay = Decimal(travelH * zone)
        let mealPay = mealHalf * Decimal(mealPenalties)

        var anc = Decimal.zero
        if let r = day.ancillaryPhoneRateCAD { anc += r * Decimal(max(0, day.ancillaryPhoneDays)) }
        if let r = day.ancillaryLaptopRateCAD { anc += r * Decimal(max(0, day.ancillaryLaptopDays)) }
        if let r = day.ancillaryTabletRateCAD { anc += r * Decimal(max(0, day.ancillaryTabletDays)) }

        let labor = straightPay + otPay + travelPay + mealPay
        let total = labor + anc

        return SentinelPayEstimate(
            straightHours: straight,
            overtime8To12Hours: otMid,
            overtimeOver12Hours: otDeep,
            travelHours: travelH,
            mealPenaltyHalfHours: mealPenalties,
            ancillaryCAD: anc,
            laborSubtotalCAD: labor,
            modelTotalCAD: total,
            turnaroundGoldMultiplier: 1,
            turnaroundInfringementApplied: false,
            laborBeforeDailyFloorCAD: nil,
            negotiatedDailyFloorCAD: nil,
            appliedDailyFloor: false
        )
    }

    private static func resolveBaseHourly(
        day: CrewTimecardDay,
        agreement: LaborAgreement,
        calendar: Calendar
    ) -> Double {
        if let o = day.overrideBaseHourlyRateCAD {
            return decimalToDouble(o)
        }
        let anchor = FraturdayCalendar.payrollAnchorStartOfDay(for: day, calendar: calendar)
        if let p = day.productionProject, let r = p.effectiveLaborBaseRate(for: anchor, calendar: calendar) {
            return decimalToDouble(r)
        }
        return decimalToDouble(agreement.baseHourlyRateCAD)
    }

    private static func decimalToDouble(_ d: Decimal) -> Double {
        (d as NSDecimalNumber).doubleValue
    }
}
