import Foundation
import SwiftData

#if canImport(PDFKit)
import PDFKit
#endif

/// Reads AcroForm values from a filled **EP Canada Crew Weekly Timesheet** back into `CrewTimecardDay` rows.
enum EPCanadaPDFFormImporter {
    struct ParsedDay: Sendable {
        var weekday: Int
        var workDate: Date?
        var travelLeaveZoneStart: Date?
        var callOnSet: Date?
        var meal1Start: Date?
        var meal1End: Date?
        var meal2Start: Date?
        var meal2End: Date?
        var wrapOffSet: Date?
        var travelReturnHome: Date?
    }

    struct ParsedForm: Sendable {
        var productionTitle: String?
        var department: String?
        var occupationLine: String?
        var loanoutLine: String?
        var displayName: String?
        var days: [ParsedDay]
    }

    enum ImportError: Error, LocalizedError {
        case notEPForm
        case noDaysMatched

        var errorDescription: String? {
            switch self {
                case .notEPForm: "This PDF does not look like an EP Canada crew weekly timesheet."
                case .noDaysMatched: "No grid rows matched crew days in this pay week."
            }
        }
    }

    #if canImport(PDFKit)
    private static let weekdaySuffixes = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    static func parse(document: PDFDocument) -> ParsedForm? {
        guard let page = document.page(at: 0) else { return nil }
        guard page.annotations.contains(where: { $0.fieldName == "PROD TITLE" }) else { return nil }

        var days: [ParsedDay] = []
        for (index, suffix) in weekdaySuffixes.enumerated() {
            let weekday = index + 1
            let dateStr = fieldValue(on: page, named: "DATE\(suffix)")
            let workDate = TimecardPayrollFormatters.parseMatrixDate(dateStr)
            let parsed = ParsedDay(
                weekday: weekday,
                workDate: workDate,
                travelLeaveZoneStart: parseTime(fieldValue(on: page, named: "TRAVEL START\(suffix)"), on: workDate),
                callOnSet: parseTime(fieldValue(on: page, named: "CALL TIME\(suffix)"), on: workDate),
                meal1Start: parseTime(fieldValue(on: page, named: "START\(suffix)"), on: workDate),
                meal1End: parseTime(fieldValue(on: page, named: "END\(suffix)"), on: workDate),
                meal2Start: parseTime(fieldValue(on: page, named: "START\(suffix)_2"), on: workDate),
                meal2End: parseTime(fieldValue(on: page, named: "END\(suffix)_2"), on: workDate),
                wrapOffSet: parseTime(fieldValue(on: page, named: "WRAP TIME\(suffix)"), on: workDate),
                travelReturnHome: parseTime(fieldValue(on: page, named: "TRAVEL END\(suffix)"), on: workDate)
            )
            if parsed.hasAnyTime {
                days.append(parsed)
            }
        }

        return ParsedForm(
            productionTitle: fieldValue(on: page, named: "PROD TITLE"),
            department: fieldValue(on: page, named: "DEPARTMENT"),
            occupationLine: fieldValue(on: page, named: "OCCUPATION"),
            loanoutLine: fieldValue(on: page, named: "LOANOUT"),
            displayName: fieldValue(on: page, named: "NAME"),
            days: days
        )
    }

    /// Applies parsed grid values onto existing crew days (matched by calendar weekday + pay-week anchor).
    @discardableResult
    static func apply(
        parsed: ParsedForm,
        to crewDays: [CrewTimecardDay],
        calendar: Calendar = .current
    ) throws -> Int {
        guard !parsed.days.isEmpty else { throw ImportError.noDaysMatched }

        var updated = 0
        for row in parsed.days {
            let target: CrewTimecardDay? = {
                if let d = row.workDate {
                    return crewDays.first {
                        calendar.isDate($0.workDate, inSameDayAs: d)
                    }
                }
                return crewDays.first {
                    calendar.component(.weekday, from: $0.workDate) == row.weekday
                }
            }()
            guard let target else { continue }

            if let d = row.workDate {
                target.workDate = calendar.startOfDay(for: d)
            }
            target.travelLeaveZoneStart = row.travelLeaveZoneStart ?? target.travelLeaveZoneStart
            target.callOnSet = row.callOnSet ?? target.callOnSet
            target.meal1Start = row.meal1Start ?? target.meal1Start
            target.meal1End = row.meal1End ?? target.meal1End
            target.meal2Start = row.meal2Start ?? target.meal2Start
            target.meal2End = row.meal2End ?? target.meal2End
            target.wrapOffSet = row.wrapOffSet ?? target.wrapOffSet
            target.travelReturnHome = row.travelReturnHome ?? target.travelReturnHome
            target.updatedAt = .now
            appendImportNote(on: target, source: "EP PDF import \(ISO8601DateFormatter().string(from: Date()))")
            updated += 1
        }

        guard updated > 0 else { throw ImportError.noDaysMatched }
        return updated
    }

    private static func fieldValue(on page: PDFPage, named name: String) -> String? {
        PDFFormFieldStyle.readGridFieldValue(on: page, named: name)
    }

    private static func parseTime(_ raw: String?, on workDate: Date?) -> Date? {
        guard let raw, !raw.isEmpty, let workDate else { return nil }
        return TimecardPayrollFormatters.parseMilitaryTime(raw, on: workDate)
    }

    private static func appendImportNote(on day: CrewTimecardDay, source: String) {
        let tag = "[\(source)]"
        if let notes = day.notes, notes.contains(tag) { return }
        if let notes = day.notes, !notes.isEmpty {
            day.notes = notes + "\n" + tag
        } else {
            day.notes = tag
        }
    }
    #endif
}

#if canImport(PDFKit)
extension EPCanadaPDFFormImporter.ParsedDay {
    fileprivate var hasAnyTime: Bool {
        travelLeaveZoneStart != nil || callOnSet != nil || meal1Start != nil || meal1End != nil
            || meal2Start != nil || meal2End != nil || wrapOffSet != nil || travelReturnHome != nil
            || workDate != nil
    }
}
#endif
