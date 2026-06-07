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
    static func fill(
        document: PDFDocument,
        productionTitle: String,
        occupation: String?,
        days: [CrewTimecardDay],
        production: ProductionProject?,
        compliance: PayrollComplianceProfile,
        estimateByDayID: [UUID: SentinelPayEstimate] = [:]
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

        let cal = Calendar.current
        let payWeekDays = EPPayWeekGrid.filterToPayWeek(days, calendar: cal)

        if let weekEnd = EPPayWeekGrid.weekEndingSaturday(for: payWeekDays, calendar: cal) {
            PDFFormFieldStyle.setValue(
                TimecardPayrollFormatters.weekEndingString(from: weekEnd),
                on: page,
                named: "WEEK ENDING"
            )
        }

        let schedule = EPOccupationWeekScheduleBuilder.build(
            days: payWeekDays,
            fallbackOccupation: fallbackOcc.isEmpty ? nil : fallbackOcc
        )

        if let dept = resolveDepartment(
            days: payWeekDays,
            production: production,
            occupation: schedule.occupationLine
        ) {
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
        stampDayGrid(on: page, days: payWeekDays, production: production, calendar: cal)
        let rateTiers = production?.laborPositionRates ?? []
        stampOtherRatesKitLines(on: page, days: payWeekDays, production: production, rateTiers: rateTiers)
        stampGrossTotals(
            on: page,
            days: payWeekDays,
            production: production,
            rateTiers: rateTiers,
            estimateByDayID: estimateByDayID
        )
        stampApprovals(on: page, ctx: ctx)
        lockPSTWidgetsReadOnly(on: page)
    }

    /// EP links **OTHER RATES** and **PST#** — keep both widgets empty and read-only after overlay stamp.
    private static func lockPSTWidgetsReadOnly(on page: PDFPage) {
        for ann in page.annotations where ann.fieldName == "PST" {
            ann.widgetStringValue = ""
            ann.isReadOnly = true
        }
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

        let dayDepartments = days.compactMap { cleaned($0.department) }
            .filter { occKey.isEmpty || $0.lowercased() != occKey }

        if let fromDays = dayDepartments.mostCommon() {
            return fromDays
        }

        if let production, let profileDept = cleaned(production.payrollDepartment) {
            return profileDept
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
        production: ProductionProject?,
        calendar: Calendar
    ) {
        guard let weekEnd = EPPayWeekGrid.weekEndingSaturday(for: days, calendar: calendar) else { return }

        for row in EPPayWeekGrid.weekRows(weekEndingSaturday: weekEnd, calendar: calendar) {
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.matrixDateString(from: row.date),
                on: page,
                named: "DATE\(row.suffix)"
            )

            guard let day = EPPayWeekGrid.crewDay(on: row.date, in: days, calendar: calendar) else { continue }

            let effCall = SentinelEffectiveClock.effectiveCall(day: day, project: production)
            let wrap = FraturdayCalendar.normalizedWrapAfterCall(
                call: effCall,
                wrap: SentinelEffectiveClock.effectiveWrapRaw(day: day, project: production),
                workDateStart: calendar.startOfDay(for: day.workDate),
                calendar: calendar
            )
            let travelEnd = day.travelReturnHome ?? day.travelReturnLeaveSet

            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.travelLeaveZoneStart),
                on: page,
                named: "TRAVEL START\(row.suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: effCall),
                on: page,
                named: "CALL TIME\(row.suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal1Start),
                on: page,
                named: "START\(row.suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal1End),
                on: page,
                named: "END\(row.suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal2Start),
                on: page,
                named: "START\(row.suffix)_2"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: day.meal2End),
                on: page,
                named: "END\(row.suffix)_2"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: wrap),
                on: page,
                named: "WRAP TIME\(row.suffix)"
            )
            PDFFormFieldStyle.setGridOverlayValue(
                TimecardPayrollFormatters.militaryTimeString(from: travelEnd),
                on: page,
                named: "TRAVEL END\(row.suffix)"
            )
        }
    }

    /// Kit allowances in **OTHER RATES** only.
    ///
    /// EP’s bundled PDF maps **OTHER RATES** and **PST#** to the same AcroForm name (`PST`) with two widgets —
    /// filling one mirrors the other. We draw an overlay in the upper (wide) widget and leave both widgets empty.
    private static func stampGrossTotals(
        on page: PDFPage,
        days: [CrewTimecardDay],
        production: ProductionProject?,
        rateTiers: [ShowLaborPositionRate],
        estimateByDayID: [UUID: SentinelPayEstimate]
    ) {
        let laborTotal = days.compactMap { estimateByDayID[$0.id]?.modelTotalCAD }.reduce(0, +)
        let kitTotal = EPKitOtherRatesAggregator.totalKitAllowanceCAD(
            from: days,
            project: production,
            rateTiers: rateTiers
        )
        let gross = laborTotal + kitTotal
        guard gross > 0 else { return }

        let text = String(format: "%.2f", NSDecimalNumber(decimal: gross).doubleValue)
        PDFFormFieldStyle.setValue(text, on: page, named: "TOTAL CALCULATED GROSS EARNINGS")
        PDFFormFieldStyle.setValue(text, on: page, named: "TOTAL")
    }

    private static func stampOtherRatesKitLines(
        on page: PDFPage,
        days: [CrewTimecardDay],
        production: ProductionProject?,
        rateTiers: [ShowLaborPositionRate]
    ) {
        let lines = EPKitOtherRatesAggregator.lines(from: days, project: production, rateTiers: rateTiers)
        guard !lines.isEmpty else { return }

        guard let otherRatesBox = page.annotations.first(where: {
            $0.fieldName == "PST" && $0.bounds.minY > 450
        }) else { return }

        // Break EP’s linked-field mirror (shared `PST` value across both widgets).
        for ann in page.annotations where ann.fieldName == "PST" {
            ann.widgetStringValue = ""
        }

        let text = lines.joined(separator: "  ")
        let clipped = clipForOtherRatesBox(text, bounds: otherRatesBox.bounds)
        PDFFormFieldStyle.stampTextOverlay(
            clipped,
            on: page,
            in: otherRatesBox.bounds,
            fontSize: PDFFormFieldStyle.gridFontSize,
            monospaced: true,
            lift: PDFFormFieldStyle.gridOverlayVerticalLift + 3
        )
    }

    private static func clipForOtherRatesBox(_ text: String, bounds: CGRect) -> String {
        let maxChars = max(12, Int(bounds.width / 4.2))
        if text.count <= maxChars { return text }
        return String(text.prefix(max(0, maxChars - 1))) + "…"
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
        let box = field.bounds
        #if canImport(AppKit)
        let inset = box.insetBy(dx: box.width * 0.08, dy: box.height * 0.08)
        PDFFormFieldStyle.stampTextOverlay(
            "X",
            on: page,
            in: inset,
            fontSize: 16,
            monospaced: true,
            lift: 0.5
        )
        #else
        let pad: CGFloat = 0.4
        let x0 = box.minX + pad
        let x1 = box.maxX - pad
        let y0 = box.minY + pad
        let y1 = box.maxY - pad
        for (start, end) in [
            (CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y1)),
            (CGPoint(x: x1, y: y0), CGPoint(x: x0, y: y1)),
        ] {
            let line = PDFAnnotation(bounds: box, forType: .line, withProperties: nil)
            line.startPoint = start
            line.endPoint = end
            let border = PDFBorder()
            border.lineWidth = 1.8
            line.border = border
            page.addAnnotation(line)
        }
        #endif
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
