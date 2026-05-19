import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Builds a **printable EP-style timecard** PDF from `CrewTimecardDay` rows (RatioVita layout; not an official EP
/// form).
enum TimecardExportService {
    enum ExportError: Error {
        case couldNotCreatePDF
    }

    /// Writes a PDF into a **temporary file** for sharing.
    static func writeEPCanadaStylePDF(
        days: [CrewTimecardDay],
        agreement: LaborAgreement,
        productionTitle: String
    ) throws -> URL {
        let sorted = days.sorted { $0.workDate < $1.workDate }
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { throw ExportError.couldNotCreatePDF }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw ExportError.couldNotCreatePDF }

        let title = "EP-style timecard — \(productionTitle)"
        let subtitle =
            "Sentinel template · \(agreement.title) · Base \(agreement.baseHourlyRateCAD) CAD/hr (model only, not legal payroll advice)."

        let chunks: [[CrewTimecardDay]] = sorted.isEmpty
            ? [[]]
            : sorted.chunked(maxPerPage: 14)

        for (idx, chunk) in chunks.enumerated() {
            ctx.beginPDFPage(nil)
            drawPage(
                context: ctx,
                pageRect: pageRect,
                title: idx == 0 ? title : "\(title) (cont.)",
                subtitle: subtitle,
                rows: chunk,
                agreement: agreement
            )
            ctx.endPDFPage()
        }

        ctx.closePDF()

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("EP_Timecard_\(stamp).pdf")
        try (data as Data).write(to: url, options: .atomic)
        return url
    }

    private static func drawPage(
        context ctx: CGContext,
        pageRect: CGRect,
        title: String,
        subtitle: String,
        rows: [CrewTimecardDay],
        agreement: LaborAgreement
    ) {
        ctx.saveGState()
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(pageRect)

        let attrsTitle: [NSAttributedString.Key: Any] = [
            .font: PDFRVFont.boldSystemFont(ofSize: 14),
            .foregroundColor: PDFRVColor.black,
        ]
        let attrsSub: [NSAttributedString.Key: Any] = [
            .font: PDFRVFont.systemFont(ofSize: 9),
            .foregroundColor: PDFRVColor.darkGray,
        ]
        let attrsCell: [NSAttributedString.Key: Any] = [
            .font: PDFRVFont.monospacedSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: PDFRVColor.black,
        ]

        let y0 = pageRect.height - 48
        (title as NSString).draw(at: CGPoint(x: 36, y: y0), withAttributes: attrsTitle)
        (subtitle as NSString).draw(at: CGPoint(x: 36, y: y0 - 18), withAttributes: attrsSub)

        var y = y0 - 52
        if rows.isEmpty {
            ("No crew days in this export." as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: attrsCell)
            ctx.restoreGState()
            return
        }

        let header =
            "Date       Call      Wrap      Work h    Model CAD  Notes"
        (header as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: attrsCell)
        y -= 14

        for d in rows {
            let est = SentinelPayrollEngine.estimate(day: d, agreement: agreement)
            let df = DateFormatter()
            df.dateStyle = .short
            let workH = est.straightHours + est.overtime8To12Hours + est.overtimeOver12Hours
            let proj = d.productionProject
            let effCall = SentinelEffectiveClock.effectiveCall(day: d, project: proj)
            let effWrapRaw = SentinelEffectiveClock.effectiveWrapRaw(day: d, project: proj)
            let wrapN = FraturdayCalendar.normalizedWrapAfterCall(
                call: effCall,
                wrap: effWrapRaw,
                workDateStart: Calendar.current.startOfDay(for: d.workDate),
                calendar: .current
            )
            let line = String(
                format: "%@  %@  %@  %5.2f   %@  %@",
                df.string(from: d.workDate),
                shortTime(effCall),
                shortTime(wrapN),
                workH,
                "\(est.modelTotalCAD)",
                String((d.notes ?? "").prefix(24))
            )
            (line as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: attrsCell)
            y -= 12
            if y < 48 { break }
        }

        ctx.restoreGState()
    }

    private static func shortTime(_ d: Date?) -> String {
        guard let d else { return "—     " }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        let s = f.string(from: d)
        return (s as NSString).padding(toLength: 8, withPad: " ", startingAt: 0)
    }
}

extension [CrewTimecardDay] {
    fileprivate func chunked(maxPerPage: Int) -> [[CrewTimecardDay]] {
        stride(from: 0, to: count, by: maxPerPage).map {
            Array(self[$0..<Swift.min($0 + maxPerPage, count)])
        }
    }
}
