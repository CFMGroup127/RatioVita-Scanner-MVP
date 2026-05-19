import Foundation

/// **Fraturday** + payroll anchoring: wraps past midnight (e.g. 24:06, 25:36 as next-day `Date`s) and “which calendar
/// day owns this work” for week / export grouping.
enum FraturdayCalendar {
    /// If `wrap` is on or before `call` (same ingestion day), advance wrap by 24h until it is strictly after call.
    /// Handles multi-day wraps by repeating (rare).
    static func normalizedWrapAfterCall(
        call: Date?,
        wrap: Date?,
        workDateStart: Date,
        calendar: Calendar
    ) -> Date? {
        guard let wrap else { return nil }
        guard let call else { return wrap }
        var w = wrap
        var iterations = 0
        while w <= call, iterations < 8 {
            w = w.addingTimeInterval(24 * 3600)
            iterations += 1
        }
        _ = workDateStart
        _ = calendar
        return w
    }

    /// Industry-style **payroll anchor** day: start-of-day of call when present, else `workDate` start-of-day.
    /// Keeps a Saturday-morning wrap that belongs to **Friday’s** cycle grouped under Friday when call was Friday
    /// night.
    static func payrollAnchorStartOfDay(for day: CrewTimecardDay, calendar: Calendar) -> Date {
        let workStart = calendar.startOfDay(for: day.workDate)
        let project = day.productionProject
        if let call = SentinelEffectiveClock.effectiveCall(day: day, project: project) {
            return calendar.startOfDay(for: call)
        }
        return workStart
    }

    static func sortedForPayrollChain(_ days: [CrewTimecardDay], calendar: Calendar) -> [CrewTimecardDay] {
        days.sorted { a, b in
            let ra = payrollAnchorStartOfDay(for: a, calendar: calendar)
            let rb = payrollAnchorStartOfDay(for: b, calendar: calendar)
            if ra != rb { return ra < rb }
            let ca = SentinelEffectiveClock.effectiveCall(day: a, project: a.productionProject) ?? ra
            let cb = SentinelEffectiveClock.effectiveCall(day: b, project: b.productionProject) ?? rb
            return ca < cb
        }
    }

    /// True when normalized wrap crosses local midnight relative to call’s calendar day (Fraturday / long turn).
    static func wrapsPastMidnight(day: CrewTimecardDay, calendar: Calendar) -> Bool {
        let project = day.productionProject
        let call = SentinelEffectiveClock.effectiveCall(day: day, project: project)
        let wrap = SentinelEffectiveClock.effectiveWrapRaw(day: day, project: project)
        guard let call, let wrap else { return false }
        guard let wn = normalizedWrapAfterCall(
            call: call,
            wrap: wrap,
            workDateStart: calendar.startOfDay(for: day.workDate),
            calendar: calendar
        ) else { return false }
        return !calendar.isDate(call, inSameDayAs: wn)
    }
}
