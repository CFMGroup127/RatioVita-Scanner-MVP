import Foundation

/// Pay week boundaries (Sun–Sat ending Saturday) for DTR / lock scheduler.
enum PayrollWeekCalendar {
    static var toronto: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Toronto") ?? .current
        return cal
    }

    /// Saturday end-of-week for the pay period containing `date`.
    static func weekEndingSaturday(for date: Date, calendar: Calendar = toronto) -> Date {
        let anchor = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: anchor)
        let daysToSaturday = (7 - weekday) % 7
        return calendar.date(byAdding: .day, value: daysToSaturday, to: anchor) ?? anchor
    }

    static func weekDates(endingSaturday: Date, calendar: Calendar = toronto) -> [Date] {
        let sat = calendar.startOfDay(for: endingSaturday)
        guard let sunday = calendar.date(byAdding: .day, value: -6, to: sat) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: sunday) }
    }

    static func isDate(_ date: Date, inWeekEnding saturday: Date, calendar: Calendar = toronto) -> Bool {
        let days = Set(weekDates(endingSaturday: saturday, calendar: calendar).map { calendar.startOfDay(for: $0) })
        return days.contains(calendar.startOfDay(for: date))
    }

    /// Tuesday 10:00 AM local — payroll lock instant for the week following that Saturday.
    static func payrollLockInstant(afterWeekEnding saturday: Date, calendar: Calendar = toronto) -> Date {
        let sat = calendar.startOfDay(for: saturday)
        guard let tuesday = calendar.date(byAdding: .day, value: 3, to: sat) else { return saturday }
        var components = calendar.dateComponents([.year, .month, .day], from: tuesday)
        components.hour = 10
        components.minute = 0
        return calendar.date(from: components) ?? tuesday
    }
}
