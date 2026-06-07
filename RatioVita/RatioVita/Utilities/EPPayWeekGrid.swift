import Foundation

/// EP crew weekly grid: Sun–Sat columns with explicit calendar dates (split-sheet safe).
enum EPPayWeekGrid {
    static let weekdaySuffixes = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    /// Saturday that ends the pay week containing the latest crew day.
    static func weekEndingSaturday(for days: [CrewTimecardDay], calendar: Calendar = .current) -> Date? {
        guard let last = FraturdayCalendar.sortedForPayrollChain(days, calendar: calendar).last else {
            return nil
        }
        let anchor = FraturdayCalendar.payrollAnchorStartOfDay(for: last, calendar: calendar)
        let weekday = calendar.component(.weekday, from: anchor)
        let daysToSaturday = (7 - weekday) % 7
        return calendar.date(byAdding: .day, value: daysToSaturday, to: anchor)
    }

    /// Seven start-of-day dates: Sunday … Saturday for the pay week ending on `weekEndingSaturday`.
    static func weekDates(weekEndingSaturday: Date, calendar: Calendar = .current) -> [Date] {
        let sat = calendar.startOfDay(for: weekEndingSaturday)
        guard let sunday = calendar.date(byAdding: .day, value: -6, to: sat) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: sunday) }
    }

    static func suffix(for date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        guard weekday >= 1, weekday <= 7 else { return "SUN" }
        return weekdaySuffixes[weekday - 1]
    }

    /// Rows for the full pay week — always seven lines with calendar dates.
    static func weekRows(
        weekEndingSaturday: Date,
        calendar: Calendar = .current
    ) -> [(suffix: String, date: Date)] {
        weekDates(weekEndingSaturday: weekEndingSaturday, calendar: calendar).map { date in
            (suffix(for: date, calendar: calendar), date)
        }
    }

    /// Drops reference / out-of-cycle days (e.g. May 13 on a May 18–23 pay week).
    static func filterToPayWeek(_ days: [CrewTimecardDay], calendar: Calendar = .current) -> [CrewTimecardDay] {
        guard let weekEnd = weekEndingSaturday(for: days, calendar: calendar) else { return days }
        let allowed = Set(
            weekDates(weekEndingSaturday: weekEnd, calendar: calendar).map {
                calendar.startOfDay(for: $0)
            }
        )
        return days.filter { allowed.contains(calendar.startOfDay(for: $0.workDate)) }
    }

    static func crewDay(
        on calendarDate: Date,
        in days: [CrewTimecardDay],
        calendar: Calendar = .current
    ) -> CrewTimecardDay? {
        days.first { calendar.isDate($0.workDate, inSameDayAs: calendarDate) }
    }
}
