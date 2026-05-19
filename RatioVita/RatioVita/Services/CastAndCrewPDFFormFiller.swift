import Foundation
import SwiftData

#if canImport(PDFKit)
import PDFKit
#endif

/// Fills Cast & Crew Canada crew timecard using native AcroForm fields.
enum CastAndCrewPDFFormFiller {
    #if canImport(PDFKit)
    private static let weekdayNames = ["Sun", "Mon", "Tues", "Wed", "Thurs", "Fri", "Sat"]

    static func fill(
        document: PDFDocument,
        productionTitle: String,
        occupation: String?,
        days: [CrewTimecardDay],
        production: ProductionProject?,
        compliance: PayrollComplianceProfile
    ) {
        guard let page = document.page(at: 0) else { return }
        let ctx = ProductionPayrollResolver.exportContext(
            production: production,
            productionTitle: productionTitle,
            globalCompliance: compliance
        )
        let occ = occupation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        PDFFormFieldStyle.setValue(ctx.productionTitle, on: page, named: "Project title")

        let sorted = FraturdayCalendar.sortedForPayrollChain(days, calendar: .current)
        if let last = sorted.last {
            let cal = Calendar.current
            let anchor = FraturdayCalendar.payrollAnchorStartOfDay(for: last, calendar: cal)
            let weekday = cal.component(.weekday, from: anchor)
            let daysToSaturday = (7 - weekday) % 7
            let end = cal.date(byAdding: .day, value: daysToSaturday, to: anchor) ?? anchor
            PDFFormFieldStyle.setValue(
                TimecardPayrollFormatters.weekEndingString(from: end),
                on: page,
                named: "Week Ending"
            )
        }

        PDFFormFieldStyle.setValue(ctx.displayName, on: page, named: "Name")
        if let loanout = ctx.loanoutCompany {
            PDFFormFieldStyle.setValue(loanout, on: page, named: "Corp Name")
        }

        if !occ.isEmpty {
            PDFFormFieldStyle.setValue(occ, on: page, named: "CTGY")
        }

        stampDayGrid(on: page, days: days, production: production)
    }

    private static func stampDayGrid(
        on page: PDFPage,
        days: [CrewTimecardDay],
        production: ProductionProject?
    ) {
        let cal = Calendar.current
        for day in days {
            let weekday = cal.component(.weekday, from: day.workDate)
            guard weekday >= 1, weekday <= 7 else { continue }
            let dayName = weekdayNames[weekday - 1]

            let effCall = SentinelEffectiveClock.effectiveCall(day: day, project: production)
            let wrap = FraturdayCalendar.normalizedWrapAfterCall(
                call: effCall,
                wrap: SentinelEffectiveClock.effectiveWrapRaw(day: day, project: production),
                workDateStart: cal.startOfDay(for: day.workDate),
                calendar: cal
            )

            PDFFormFieldStyle.setValue(
                TimecardPayrollFormatters.matrixDateString(from: day.workDate),
                on: page,
                named: "Date\(dayName)",
                style: .grid
            )
            PDFFormFieldStyle.setValue(
                TimecardPayrollFormatters.militaryTimeString(from: effCall),
                on: page,
                named: "Call time\(dayName)",
                style: .grid
            )
            PDFFormFieldStyle.setValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal1Start),
                on: page,
                named: "Meal Out\(dayName)",
                style: .grid
            )
            PDFFormFieldStyle.setValue(
                TimecardPayrollFormatters.militaryTimeString(from: wrap),
                on: page,
                named: "Wrap Time\(dayName)",
                style: .grid
            )
            PDFFormFieldStyle.setValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.travelLeaveZoneStart),
                on: page,
                named: "Travel\(dayName)",
                style: .grid
            )
            PDFFormFieldStyle.setValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.travelReturnHome ?? day.travelReturnLeaveSet),
                on: page,
                named: "Travel\(dayName)_2",
                style: .grid
            )
        }
    }
    #endif
}
