import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Professional **contractor invoice** PDF using Sentinel totals and corporate letterhead.
enum ContractorInvoicePDFGenerator {
    enum InvoiceError: Error {
        case couldNotCreatePDF
    }

    static func writeInvoicePDF(
        production: ProductionProject,
        entity: BusinessEntity?,
        occupation: String?,
        days: [CrewTimecardDay],
        agreement: LaborAgreement,
        estimateByDayID: [UUID: SentinelPayEstimate]
    ) throws -> URL {
        let pageSize = CGSize(width: 612, height: 792)
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { throw InvoiceError.couldNotCreatePDF }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw InvoiceError.couldNotCreatePDF
        }

        ctx.beginPDFPage(nil)
        ctx.saveGState()
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(pageRect)

        let titleAttr = TimecardPDFDrawUtils.makeAttrs(size: 14, bold: true)
        let bodyAttr = TimecardPDFDrawUtils.makeAttrs(size: 10, bold: false)
        let mono = TimecardPDFDrawUtils.makeMonoAttrs(size: 9)

        var y: CGFloat = 740
        let left: CGFloat = 54

        let fromName = entity?.legalName ?? production.parentBusinessGroupingTitle
        TimecardPDFDrawUtils.draw(fromName, at: CGPoint(x: left, y: y), attributes: titleAttr, in: ctx)
        y -= 16
        if let addr = entity?.businessAddress, !addr.isEmpty {
            for line in addr.components(separatedBy: .newlines).prefix(4) {
                TimecardPDFDrawUtils.draw(line, at: CGPoint(x: left, y: y), attributes: bodyAttr, in: ctx)
                y -= 12
            }
        }
        if let gst = entity?.gstHstNumber, !gst.isEmpty {
            TimecardPDFDrawUtils.draw("GST/HST: \(gst)", at: CGPoint(x: left, y: y), attributes: bodyAttr, in: ctx)
            y -= 14
        }

        TimecardPDFDrawUtils.draw("INVOICE", at: CGPoint(x: 420, y: 740), attributes: titleAttr, in: ctx)
        let df = DateFormatter()
        df.dateStyle = .medium
        TimecardPDFDrawUtils.draw(
            "Date: \(df.string(from: Date()))",
            at: CGPoint(x: 420, y: 722),
            attributes: bodyAttr,
            in: ctx
        )

        y -= 24
        TimecardPDFDrawUtils.draw("Bill to:", at: CGPoint(x: left, y: y), attributes: bodyAttr, in: ctx)
        y -= 14
        TimecardPDFDrawUtils.draw(production.title, at: CGPoint(x: left, y: y), attributes: titleAttr, in: ctx)
        y -= 14
        if let occ = occupation, !occ.isEmpty {
            TimecardPDFDrawUtils.draw("Services: \(occ)", at: CGPoint(x: left, y: y), attributes: bodyAttr, in: ctx)
            y -= 18
        }

        y -= 8
        TimecardPDFDrawUtils.draw(
            "Professional labour per Sentinel (\(agreement.title)) — not legal or tax advice.",
            at: CGPoint(x: left, y: y),
            attributes: bodyAttr,
            in: ctx
        )
        y -= 22

        let sorted = FraturdayCalendar.sortedForPayrollChain(days, calendar: .current)
        let dfShort = DateFormatter()
        dfShort.dateStyle = .short
        var grandTotal = Decimal.zero

        for d in sorted.prefix(21) {
            let est = estimateByDayID[d.id]
            let total = est?.modelTotalCAD ?? SentinelPayrollEngine.estimate(day: d, agreement: agreement).modelTotalCAD
            grandTotal += total
            let occLine = d.occupationTitle ?? production.effectiveOccupationFromRateSheet(for: d.workDate) ?? "Labour"
            let line = "\(dfShort.string(from: d.workDate))  \(occLine)  \(total) CAD"
            TimecardPDFDrawUtils.draw(line, at: CGPoint(x: left, y: y), attributes: mono, in: ctx)
            y -= 14
            if y < 120 { break }
        }

        y -= 12
        TimecardPDFDrawUtils.draw(
            "Total due (CAD): \(grandTotal)",
            at: CGPoint(x: left, y: y),
            attributes: titleAttr,
            in: ctx
        )

        ctx.restoreGState()
        ctx.endPDFPage()
        ctx.closePDF()

        let stem = production.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RV-Invoice-\(stem)-\(UUID().uuidString.prefix(8)).pdf")
        try data.write(to: url)
        return url
    }
}
