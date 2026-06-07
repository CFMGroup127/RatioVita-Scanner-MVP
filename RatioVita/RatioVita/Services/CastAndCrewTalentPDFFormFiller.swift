import Foundation
import SwiftData

#if canImport(PDFKit)
import PDFKit
#endif

/// Fills **Cast & Crew — Talent Timecard (Toronto)** (`DATE.0` … `WRAP TIME.8` row widgets).
enum CastAndCrewTalentPDFFormFiller {
    #if canImport(PDFKit)
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
        let occ = resolvedOccupation(days: days, fallback: occupation, production: production)

        PDFFormFieldStyle.setValue(ctx.productionTitle, on: page, named: "SHOW TITLE")
        PDFFormFieldStyle.setValue(ctx.displayName, on: page, named: "NAME")
        if let loanout = ctx.loanoutCompany {
            PDFFormFieldStyle.setValue(loanout, on: page, named: "CORP NAME")
        }
        if !occ.isEmpty {
            PDFFormFieldStyle.setValue(occ, on: page, named: "CATEGORY")
        }
        if !ctx.unionID.isEmpty {
            PDFFormFieldStyle.setValue(ctx.unionID, on: page, named: "ACTRA")
        }

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
                named: "WEEK ENDING"
            )
        }

        for (row, day) in sorted.prefix(9).enumerated() {
            stampRow(on: page, day: day, row: row, production: production)
        }
    }

    private static func resolvedOccupation(
        days: [CrewTimecardDay],
        fallback: String?,
        production: ProductionProject?
    ) -> String {
        let fromDay = days.compactMap { $0.occupationTitle?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        if let fromDay { return fromDay }
        let fb = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fb.isEmpty { return fb }
        return production?.crewOccupationTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func stampRow(
        on page: PDFPage,
        day: CrewTimecardDay,
        row: Int,
        production: ProductionProject?
    ) {
        let cal = Calendar.current
        let effCall = SentinelEffectiveClock.effectiveCall(day: day, project: production)
        let wrap = FraturdayCalendar.normalizedWrapAfterCall(
            call: effCall,
            wrap: SentinelEffectiveClock.effectiveWrapRaw(day: day, project: production),
            workDateStart: cal.startOfDay(for: day.workDate),
            calendar: cal
        )
        let travelEnd = day.travelReturnHome ?? day.travelReturnLeaveSet

        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.matrixDateString(from: day.workDate),
            on: page,
            baseName: "DATE",
            index: row
        )
        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.militaryTimeString(from: effCall),
            on: page,
            baseName: "CALL TIME",
            index: row
        )
        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.militaryTimeString(from: day.meal1Start),
            on: page,
            baseName: "LUNCHOUT",
            index: row
        )
        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.militaryTimeString(from: day.meal1End),
            on: page,
            baseName: "LUNCHIN",
            index: row
        )
        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.militaryTimeString(from: day.meal2Start),
            on: page,
            baseName: "DINNEROUT",
            index: row
        )
        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.militaryTimeString(from: day.meal2End),
            on: page,
            baseName: "DINNERIN",
            index: row
        )
        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.militaryTimeString(from: wrap),
            on: page,
            baseName: "WRAP TIME",
            index: row
        )
        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.militaryTimeString(from: day.travelLeaveZoneStart),
            on: page,
            baseName: "TRAVEL",
            index: row
        )
        PDFFormFieldStyle.setIndexedGridValue(
            TimecardPayrollFormatters.militaryTimeString(from: travelEnd),
            on: page,
            baseName: "TURNAROUND",
            index: row
        )
    }
    #endif
}
