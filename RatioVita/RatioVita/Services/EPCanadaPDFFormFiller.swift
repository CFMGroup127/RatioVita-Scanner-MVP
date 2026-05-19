import Foundation
import SwiftData

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Fills the bundled **EP Canada Crew Weekly Timesheet** using native AcroForm field positions (exact alignment).
enum EPCanadaPDFFormFiller {
    #if canImport(PDFKit)
    private static let weekdaySuffixes = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    static func fill(
        document: PDFDocument,
        productionTitle: String,
        occupation: String?,
        days: [CrewTimecardDay],
        production: ProductionProject?,
        compliance: PayrollComplianceProfile
    ) {
        guard let page = document.page(at: 0) else { return }
        let projectTitle = production?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let showTitle: String = {
            if !projectTitle.isEmpty { return projectTitle }
            let stripped = productionTitle.components(separatedBy: " — ").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return stripped.isEmpty ? productionTitle : stripped
        }()
        let ctx = ProductionPayrollResolver.exportContext(
            production: production,
            productionTitle: showTitle,
            globalCompliance: compliance
        )
        let fallbackOcc = occupation?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? production?.crewOccupationTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        PDFFormFieldStyle.setValue(showTitle, on: page, named: "PROD TITLE")
        if !ctx.productionCompany.isEmpty {
            PDFFormFieldStyle.setValue(ctx.productionCompany, on: page, named: "PROD COMPANY")
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

        let schedule = EPOccupationWeekScheduleBuilder.build(
            days: days,
            fallbackOccupation: fallbackOcc.isEmpty ? nil : fallbackOcc
        )

        if let dept = resolveDepartment(days: days, production: production, occupation: schedule.occupationLine) {
            PDFFormFieldStyle.setValue(dept, on: page, named: "DEPARTMENT")
        }
        if !schedule.occupationLine.isEmpty {
            PDFFormFieldStyle.setValue(schedule.occupationLine, on: page, named: "OCCUPATION")
        }

        stampNameBlock(on: page, ctx: ctx, scheduleOverflow: schedule.loanoutOverflowLine)

        if !ctx.unionName.isEmpty {
            PDFFormFieldStyle.setValue(ctx.unionName, on: page, named: "UNION")
        }
        if !ctx.unionID.isEmpty {
            PDFFormFieldStyle.setValue(ctx.unionID, on: page, named: "UNION ID")
        }

        stampResidencyAndGuild(on: page, compliance: ctx.compliance)
        stampDayGrid(on: page, days: days, production: production)
        stampOtherRatesKitLines(on: page, days: days, production: production)
        stampApprovals(on: page, ctx: ctx)
        PDFFormFieldStyle.lockGridWidgetsForDisplay(on: page)
    }

    private static func stampNameBlock(
        on page: PDFPage,
        ctx: ProductionPayrollResolver.ExportContext,
        scheduleOverflow: String?
    ) {
        PDFFormFieldStyle.setValue(ctx.displayName, on: page, named: "NAME")
        var loanoutLine: [String] = []
        if let corp = ctx.loanoutCompany { loanoutLine.append(corp) }
        if let overflow = scheduleOverflow?.trimmingCharacters(in: .whitespacesAndNewlines), !overflow.isEmpty {
            loanoutLine.append(overflow)
        }
        if !loanoutLine.isEmpty {
            PDFFormFieldStyle.setValue(loanoutLine.joined(separator: " · "), on: page, named: "LOANOUT")
        }
    }

    private static func stampResidencyAndGuild(on page: PDFPage, compliance: PayrollComplianceProfile) {
        var residentBox: PDFAnnotation?
        var nonResidentBox: PDFAnnotation?
        var memberBox: PDFAnnotation?
        var permitBox: PDFAnnotation?

        for ann in page.annotations {
            switch ann.fieldName ?? "" {
                case "Resid":
                    if ann.bounds.minX < 620 {
                        residentBox = ann
                    } else {
                        nonResidentBox = ann
                    }
                case "Union Mbr":
                    if ann.bounds.minX < 630 {
                        memberBox = ann
                    } else {
                        permitBox = ann
                    }
                default:
                    continue
            }
        }

        if let residentBox, let nonResidentBox {
            applyCheckbox(residentBox, on: page, on: compliance.residencyStatus == .resident, onValue: "YES")
            applyCheckbox(nonResidentBox, on: page, on: compliance.residencyStatus == .nonResident, onValue: "NON")
        }
        if let memberBox, let permitBox {
            applyCheckbox(memberBox, on: page, on: compliance.guildStatus == .member, onValue: "member")
            applyCheckbox(permitBox, on: page, on: compliance.guildStatus == .permit, onValue: "permittee")
        }
    }

    /// Department line (Costumes, Transport, …) — never the crew occupation title.
    private static func resolveDepartment(
        days: [CrewTimecardDay],
        production: ProductionProject?,
        occupation: String
    ) -> String? {
        let occKey = occupation.lowercased()

        func cleaned(_ raw: String?) -> String? {
            let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? nil : t
        }

        if let production, let profileDept = cleaned(production.payrollDepartment) {
            return profileDept
        }

        let dayDepartments = days.compactMap { cleaned($0.department) }
            .filter { occKey.isEmpty || $0.lowercased() != occKey }

        if let fromDays = dayDepartments.mostCommon() {
            return fromDays
        }

        if let production {
            for day in days {
                if let seg = production.activeRateSegment(
                    for: day.workDate,
                    occupation: day.occupationTitle,
                    department: nil
                ), let dept = cleaned(seg.department) {
                    return dept
                }
            }
        }

        return cleaned(days.first?.department)
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
            let suffix = weekdaySuffixes[weekday - 1]

            let effCall = SentinelEffectiveClock.effectiveCall(day: day, project: production)
            let wrap = FraturdayCalendar.normalizedWrapAfterCall(
                call: effCall,
                wrap: SentinelEffectiveClock.effectiveWrapRaw(day: day, project: production),
                workDateStart: cal.startOfDay(for: day.workDate),
                calendar: cal
            )
            let travelEnd = day.travelReturnHome ?? day.travelReturnLeaveSet

            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.matrixDateString(from: day.workDate),
                on: page,
                named: "DATE\(suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.travelLeaveZoneStart),
                on: page,
                named: "TRAVEL START\(suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: effCall),
                on: page,
                named: "CALL TIME\(suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal1Start),
                on: page,
                named: "START\(suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal1End),
                on: page,
                named: "END\(suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal2Start),
                on: page,
                named: "START\(suffix)_2"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal2End),
                on: page,
                named: "END\(suffix)_2"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: wrap),
                on: page,
                named: "WRAP TIME\(suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: travelEnd),
                on: page,
                named: "TRAVEL END\(suffix)"
            )
        }
    }

    /// Kit allowances in **OTHER RATES** only.
    ///
    /// EP’s bundled PDF maps **OTHER RATES** and **PST#** to the same AcroForm name (`PST`) with two widgets —
    /// filling one mirrors the other. We draw an overlay in the upper (wide) widget and leave both widgets empty.
    private static func stampOtherRatesKitLines(
        on page: PDFPage,
        days: [CrewTimecardDay],
        production: ProductionProject?
    ) {
        let lines = EPKitOtherRatesAggregator.lines(from: days, project: production)
        guard !lines.isEmpty else { return }

        guard let otherRatesBox = page.annotations.first(where: {
            $0.fieldName == "PST" && $0.bounds.minY > 450
        }) else { return }

        // Break EP’s linked-field mirror (shared `PST` value across both widgets).
        for ann in page.annotations where ann.fieldName == "PST" {
            ann.widgetStringValue = ""
        }

        PDFFormFieldStyle.stampTextOverlay(
            lines.joined(separator: "  "),
            on: page,
            in: otherRatesBox.bounds,
            fontSize: PDFFormFieldStyle.gridFontSize,
            lift: PDFFormFieldStyle.gridOverlayVerticalLift + 1
        )
    }

    private static func stampApprovals(on page: PDFPage, ctx: ProductionPayrollResolver.ExportContext) {
        if ctx.autoStampCrewInitials || !ctx.compliance.approvalInitialsCrew.isEmpty {
            let crew = ctx.compliance.approvalInitialsCrew.isEmpty
                ? ctx.crewInitialsForExport
                : ctx.compliance.approvalInitialsCrew
            PDFFormFieldStyle.setValue(crew, on: page, named: "CREW")
        }
        CrewInitialsStampHelper.stampImageInitialsIfNeeded(on: page, fieldName: "CREW")
    }

    /// AcroForm checkbox state does not survive `PDFDocument.write` reliably — stamp a visible **X** when checked.
    private static func applyCheckbox(
        _ ann: PDFAnnotation,
        on page: PDFPage,
        on: Bool,
        onValue: String
    ) {
        if on {
            ann.buttonWidgetState = .onState
            ann.widgetStringValue = onValue
            stampCheckboxX(on: page, over: ann)
        } else {
            ann.buttonWidgetState = .offState
            ann.widgetStringValue = "Off"
        }
    }

    private static func stampCheckboxX(on page: PDFPage, over field: PDFAnnotation) {
        // Line-drawn X stays centered in the ~8pt box; freeText “X” sat on the top edge.
        let box = field.bounds
        let pad: CGFloat = 1.2
        let yLift: CGFloat = 2.2
        let x0 = box.minX + pad
        let x1 = box.maxX - pad
        let y0 = box.minY + pad + yLift
        let y1 = box.maxY - pad + yLift - 0.5
        let segments: [(CGPoint, CGPoint)] = [
            (CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y1)),
            (CGPoint(x: x1, y: y0), CGPoint(x: x0, y: y1)),
        ]
        for (start, end) in segments {
            let line = PDFAnnotation(bounds: box, forType: .line, withProperties: nil)
            line.startPoint = start
            line.endPoint = end
            #if canImport(AppKit)
            line.color = .black
            #endif
            let border = PDFBorder()
            border.lineWidth = 1.1
            line.border = border
            page.addAnnotation(line)
        }
    }
    #endif
}

#if canImport(PDFKit)
extension [String] {
    fileprivate func mostCommon() -> String? {
        guard !isEmpty else { return nil }
        let counts = Dictionary(grouping: self, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
#endif
