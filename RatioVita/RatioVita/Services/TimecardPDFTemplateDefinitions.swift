import CoreGraphics
import CoreText
import Foundation

#if canImport(AppKit)
import AppKit

typealias PDFRVFont = NSFont
typealias PDFRVColor = NSColor
#elseif canImport(UIKit)
import UIKit

typealias PDFRVFont = UIFont
typealias PDFRVColor = UIColor
#endif

#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Page geometry

enum PayrollTimesheetPage {
    /// Official bundled templates (EP / Cast & Crew) — landscape US Letter @ 72 dpi.
    static let landscapeLetter = CGSize(width: 792, height: 612)
}

/// Top-left overlay coordinates (design space 792×612). Used inside a flipped PDF graphics state so text is
/// right-side up — see `TimecardPDFOverlayDrawing`.
enum PDFTemplateCoordinateSpace {
    static let designSize = PayrollTimesheetPage.landscapeLetter

    /// Map design-space top-left point onto the destination page size.
    static func overlayPoint(
        x: CGFloat,
        yFromTop: CGFloat,
        designSize: CGSize = designSize,
        pageSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: x * (pageSize.width / designSize.width),
            y: yFromTop * (pageSize.height / designSize.height)
        )
    }
}

/// Applies the standard top-left overlay transform and runs stamping closures.
enum TimecardPDFOverlayDrawing {
    static func drawOverlay(on pageSize: CGSize, in ctx: CGContext, draw: () -> Void) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pageSize.height)
        ctx.scaleBy(x: 1, y: -1)
        draw()
        ctx.restoreGState()
    }

    static func point(
        x: CGFloat,
        yFromTop: CGFloat,
        pageSize: CGSize,
        designSize: CGSize = PDFTemplateCoordinateSpace.designSize
    ) -> CGPoint {
        PDFTemplateCoordinateSpace.overlayPoint(x: x, yFromTop: yFromTop, designSize: designSize, pageSize: pageSize)
    }
}

// MARK: - EP Canada (official underlay)

/// **EP Canada CREW WEEKLY TIMESHEET** — calibrated against bundled `EP_Crew_Weekly_Timesheet.pdf`.
enum EPCanadaTemplate {
    static let pageSize = PayrollTimesheetPage.landscapeLetter

    enum Header {
        /// Right column — production title / company (below PROD. TITLE / PROD. COMPANY labels).
        static let prodTitleX: CGFloat = 478
        static let prodTitleYFromTop: CGFloat = 38
        static let prodCompanyYFromTop: CGFloat = 52
        static let weekEndingX: CGFloat = 668
        static let weekEndingYFromTop: CGFloat = 38
        /// Left column — crew identity.
        static let departmentX: CGFloat = 92
        static let departmentYFromTop: CGFloat = 56
        static let occupationX: CGFloat = 248
        static let occupationYFromTop: CGFloat = 56
        static let employeeNameX: CGFloat = 92
        static let employeeNameYFromTop: CGFloat = 71
        static let loanoutCorpYFromTop: CGFloat = 86
    }

    enum Checkboxes {
        static let residentX: CGFloat = 718
        static let nonResidentX: CGFloat = 766
        static let residencyYFromTop: CGFloat = 69
        static let memberX: CGFloat = 718
        static let permitX: CGFloat = 766
        static let guildYFromTop: CGFloat = 84
        static let markSize: CGFloat = 8
    }

    enum Approvals {
        static let yFromTop: CGFloat = 562
        static let prodX: CGFloat = 522
        static let pmX: CGFloat = 568
        static let acctX: CGFloat = 614
        static let deptX: CGFloat = 660
        static let crewX: CGFloat = 706
    }

    enum OtherRates {
        static let x: CGFloat = 248
        static let firstLineYFromTop: CGFloat = 100
        static let lineStep: CGFloat = 13
        static let maxLines = 4
    }

    enum DayGrid {
        /// Baseline for **SUN** row inside the day matrix.
        static let firstRowYFromTop: CGFloat = 166
        static let rowHeight: CGFloat = 13.85
        static let maxRows = 7
        /// Column anchor X — Date through Travel End only (no ST/OT/MP on export).
        static let colDate: CGFloat = 104
        static let colTravelStart: CGFloat = 154
        static let colCall: CGFloat = 204
        static let colMeal1Out: CGFloat = 254
        static let colMeal1In: CGFloat = 304
        static let colMeal2Out: CGFloat = 354
        static let colMeal2In: CGFloat = 404
        static let colWrap: CGFloat = 454
        static let colTravelEnd: CGFloat = 504
        static let rowLabels = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    }
}

// MARK: - Cast & Crew (official underlay)

enum CastAndCrewTemplate {
    static let pageSize = PayrollTimesheetPage.landscapeLetter

    enum Header {
        static let projectTitleX: CGFloat = 118
        static let projectTitleYFromTop: CGFloat = 48
        static let nameX: CGFloat = 72
        static let nameYFromTop: CGFloat = 78
        static let corpNameYFromTop: CGFloat = 94
        static let weekEndingX: CGFloat = 648
        static let weekEndingYFromTop: CGFloat = 48
        static let occupationX: CGFloat = 72
        static let occupationYFromTop: CGFloat = 110
    }

    enum DayGrid {
        static let firstRowYFromTop: CGFloat = 176
        static let rowHeight: CGFloat = 14.5
        static let maxRows = 7
        static let colDate: CGFloat = 76
        static let colCall: CGFloat = 226
        static let colMeal1Out: CGFloat = 280
        static let colMeal1In: CGFloat = 334
        static let colMeal2Out: CGFloat = 388
        static let colMeal2In: CGFloat = 442
        static let colWrap: CGFloat = 496
        static let colTravelEnd: CGFloat = 550
        static let rowLabels = ["S", "M", "T", "W", "T", "F", "S"]
    }
}

// MARK: - Shared drawing

enum TimecardPDFDrawUtils {
    static func makeAttrs(
        size: CGFloat,
        bold: Bool = false,
        color: PDFRVColor = PDFRVColor.black
    ) -> [NSAttributedString.Key: Any] {
        let font: PDFRVFont = bold ? PDFRVFont.boldSystemFont(ofSize: size) : PDFRVFont.systemFont(ofSize: size)
        return [
            .font: font,
            .foregroundColor: color,
        ]
    }

    static func makeMonoAttrs(size: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: PDFRVFont.monospacedSystemFont(ofSize: size, weight: .regular),
            .foregroundColor: PDFRVColor.black,
        ]
    }

    static func draw(
        _ text: String,
        at point: CGPoint,
        attributes: [NSAttributedString.Key: Any],
        in context: CGContext
    ) {
        guard !text.isEmpty else { return }
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        // Baseline sits slightly below the box top (top-left overlay coordinates).
        context.textPosition = CGPoint(x: point.x, y: point.y - 2)
        CTLineDraw(line, context)
    }

    static func drawCheckboxMark(at point: CGPoint, size: CGFloat, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(PDFRVColor.black.cgColor)
        context.setLineWidth(1.2)
        let s = size
        context.move(to: CGPoint(x: point.x + 1, y: point.y + 1))
        context.addLine(to: CGPoint(x: point.x + s - 1, y: point.y + s - 1))
        context.move(to: CGPoint(x: point.x + s - 1, y: point.y + 1))
        context.addLine(to: CGPoint(x: point.x + 1, y: point.y + s - 1))
        context.strokePath()
        context.restoreGState()
    }

    static func truncate(_ text: String, maxLength: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > maxLength else { return t }
        return String(t.prefix(maxLength - 1)) + "…"
    }
}

// MARK: - Payroll display formatters

enum TimecardPayrollFormatters {
    private static let weekEndingFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_CA")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    private static let matrixDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_CA")
        f.dateFormat = "MMM d"
        return f
    }()

    private static let militaryTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func weekEndingString(from date: Date) -> String {
        weekEndingFormatter.string(from: date)
    }

    static func matrixDateString(from date: Date) -> String {
        matrixDateFormatter.string(from: date)
    }

    static func militaryTimeString(from date: Date?) -> String {
        guard let date else { return "" }
        return militaryTimeFormatter.string(from: date)
    }

    static func parseMatrixDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return matrixDateFormatter.date(from: t)
            ?? matrixDateFormatter.date(from: t.capitalized)
    }

    static func parseMilitaryTime(_ raw: String, on workDate: Date, calendar: Calendar = .current) -> Date? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let normalized: String = {
            let parts = t.split(separator: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                return String(format: "%02d:%02d", h, m)
            }
            return t
        }()
        guard let timeOnly = militaryTimeFormatter.date(from: normalized) else { return nil }
        let comps = calendar.dateComponents([.hour, .minute], from: timeOnly)
        var dayComps = calendar.dateComponents([.year, .month, .day], from: workDate)
        dayComps.hour = comps.hour
        dayComps.minute = comps.minute
        dayComps.second = 0
        return calendar.date(from: dayComps)
    }
}
