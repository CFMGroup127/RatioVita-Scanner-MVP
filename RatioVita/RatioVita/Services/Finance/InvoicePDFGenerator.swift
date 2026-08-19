import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Renders outgoing client invoices (line items, tax, payments) to a shareable PDF.
@MainActor
enum InvoicePDFGenerator {
    enum GeneratorError: LocalizedError {
        case couldNotCreatePDF
        case couldNotWriteFile

        var errorDescription: String? {
            switch self {
            case .couldNotCreatePDF:
                "Could not create the invoice PDF."
            case .couldNotWriteFile:
                "Could not write the invoice PDF to disk."
            }
        }
    }

    static func generatePDF(for invoice: Invoice) throws -> URL {
        #if canImport(UIKit)
        try generatePDFUIKit(for: invoice)
        #elseif canImport(AppKit)
        try generatePDFAppKit(for: invoice)
        #else
        throw GeneratorError.couldNotCreatePDF
        #endif
    }

    // MARK: - Shared layout

    private static let pageWidth: CGFloat = 8.5 * 72.0
    private static let pageHeight: CGFloat = 11.0 * 72.0
    private static let margin: CGFloat = 54.0

    private static var sortedLineItems: (Invoice) -> [InvoiceLineItem] {
        { invoice in
            invoice.lineItems.sorted { $0.sortIndex < $1.sortIndex }
        }
    }

    private static var sortedPayments: (Invoice) -> [PaymentRecord] {
        { invoice in
            invoice.paymentRecords.sorted { $0.paymentDate > $1.paymentDate }
        }
    }

    private static func sanitizedFilename(for invoice: Invoice) -> String {
        let stem = invoice.invoiceNumber
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stem.isEmpty ? "Draft" : stem
    }

    private static func outputURL(for invoice: Invoice) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Invoice-\(sanitizedFilename(for: invoice)).pdf")
    }

    private static func decimalString(_ value: Decimal, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    private static func moneyString(_ amount: Decimal, currencyCode: String) -> String {
        CurrencyFormatter.shared.format(amount, currencyCode: currencyCode)
    }

    private static func mediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    #if canImport(UIKit)
    private static func generatePDFUIKit(for invoice: Invoice) throws -> URL {
        let pdfMetaData: [String: Any] = [
            kCGPDFContextCreator as String: "RatioVita",
            kCGPDFContextAuthor as String: "RatioVita Operator",
            kCGPDFContextTitle as String: "Invoice #\(invoice.invoiceNumber)",
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let lineItems = sortedLineItems(invoice)
        let payments = sortedPayments(invoice)

        let data = renderer.pdfData { context in
            var cursorY = margin
            let contentWidth = pageWidth - (margin * 2)

            func beginPageIfNeeded(minRemaining: CGFloat) {
                if cursorY > pageHeight - minRemaining {
                    context.beginPage()
                    cursorY = margin
                }
            }

            func drawDivider() {
                context.cgContext.setStrokeColor(UIColor.separator.cgColor)
                context.cgContext.setLineWidth(1.0)
                context.cgContext.move(to: CGPoint(x: margin, y: cursorY))
                context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: cursorY))
                context.cgContext.strokePath()
                cursorY += 16
            }

            context.beginPage()

            // Header
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label,
            ]
            "INVOICE".draw(at: CGPoint(x: margin, y: cursorY), withAttributes: titleAttributes)

            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            let metaString = "No. \(invoice.invoiceNumber) · \(invoice.status.displayTitle.uppercased())"
            let metaSize = metaString.size(withAttributes: metaAttributes)
            metaString.draw(
                at: CGPoint(x: pageWidth - margin - metaSize.width, y: cursorY + 4),
                withAttributes: metaAttributes
            )
            cursorY += 40

            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label,
            ]
            let boldBodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.label,
            ]
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel,
            ]

            "BILLED TO".draw(at: CGPoint(x: margin, y: cursorY), withAttributes: boldBodyAttributes)
            let clientName = invoice.clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Client Name"
                : invoice.clientName
            clientName.draw(at: CGPoint(x: margin, y: cursorY + 18), withAttributes: bodyAttributes)

            let rightColumnX = pageWidth - margin - 190
            "Issue Date: \(mediumDate(invoice.issueDate))".draw(
                at: CGPoint(x: rightColumnX, y: cursorY),
                withAttributes: bodyAttributes
            )
            "Due Date: \(mediumDate(invoice.dueDate))".draw(
                at: CGPoint(x: rightColumnX, y: cursorY + 18),
                withAttributes: bodyAttributes
            )
            "Currency: \(invoice.currencyCode)".draw(
                at: CGPoint(x: rightColumnX, y: cursorY + 36),
                withAttributes: bodyAttributes
            )

            cursorY += 58

            if let projectTitle = invoice.productionProject?.title, !projectTitle.isEmpty {
                "Production: \(projectTitle)".draw(
                    at: CGPoint(x: margin, y: cursorY),
                    withAttributes: captionAttributes
                )
                cursorY += 16
            }

            drawDivider()

            func drawLineItemTableHeader() {
                "DESCRIPTION".draw(at: CGPoint(x: margin, y: cursorY), withAttributes: headerAttributes)
                "QTY".draw(at: CGPoint(x: pageWidth - margin - 220, y: cursorY), withAttributes: headerAttributes)
                "PRICE".draw(at: CGPoint(x: pageWidth - margin - 150, y: cursorY), withAttributes: headerAttributes)
                "TOTAL".draw(at: CGPoint(x: pageWidth - margin - 72, y: cursorY), withAttributes: headerAttributes)
                cursorY += 18
            }

            drawLineItemTableHeader()

            if lineItems.isEmpty {
                "No line items.".draw(at: CGPoint(x: margin, y: cursorY), withAttributes: captionAttributes)
                cursorY += 22
            } else {
                for item in lineItems {
                    beginPageIfNeeded(minRemaining: 160)
                    if cursorY == margin {
                        drawLineItemTableHeader()
                    }

                    let descriptionRect = CGRect(x: margin, y: cursorY, width: contentWidth - 250, height: 36)
                    item.itemDescription.draw(in: descriptionRect, withAttributes: bodyAttributes)

                    decimalString(item.quantity, fractionDigits: 1).draw(
                        at: CGPoint(x: pageWidth - margin - 220, y: cursorY),
                        withAttributes: bodyAttributes
                    )
                    moneyString(item.unitPrice, currencyCode: invoice.currencyCode).draw(
                        at: CGPoint(x: pageWidth - margin - 150, y: cursorY),
                        withAttributes: bodyAttributes
                    )
                    moneyString(item.lineTotal, currencyCode: invoice.currencyCode).draw(
                        at: CGPoint(x: pageWidth - margin - 72, y: cursorY),
                        withAttributes: bodyAttributes
                    )

                    cursorY += 18

                    if item.sourceReceipt != nil {
                        "Bundled from receipt".draw(
                            at: CGPoint(x: margin + 8, y: cursorY),
                            withAttributes: captionAttributes
                        )
                        cursorY += 14
                    }

                    if item.taxRate > .zero {
                        let taxPercent = (item.taxRate as NSDecimalNumber).doubleValue * 100
                        let taxLabel = String(format: "%.1f", taxPercent)
                        "Tax \(taxLabel)% · \(moneyString(item.taxAmount, currencyCode: invoice.currencyCode))".draw(
                            at: CGPoint(x: margin + 8, y: cursorY),
                            withAttributes: captionAttributes
                        )
                        cursorY += 14
                    }

                    cursorY += 4
                }
            }

            cursorY += 8
            beginPageIfNeeded(minRemaining: 180)
            drawDivider()

            let totalsX = pageWidth - margin - 230
            "Subtotal: \(moneyString(invoice.subtotal, currencyCode: invoice.currencyCode))".draw(
                at: CGPoint(x: totalsX, y: cursorY),
                withAttributes: bodyAttributes
            )
            cursorY += 18
            "Tax: \(moneyString(invoice.totalTax, currencyCode: invoice.currencyCode))".draw(
                at: CGPoint(x: totalsX, y: cursorY),
                withAttributes: bodyAttributes
            )
            cursorY += 18

            let totalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.label,
            ]
            "Grand Total: \(moneyString(invoice.grandTotal, currencyCode: invoice.currencyCode))".draw(
                at: CGPoint(x: totalsX, y: cursorY),
                withAttributes: totalAttributes
            )
            cursorY += 24

            if invoice.totalPaid > .zero {
                "Total Paid: \(moneyString(invoice.totalPaid, currencyCode: invoice.currencyCode))".draw(
                    at: CGPoint(x: totalsX, y: cursorY),
                    withAttributes: bodyAttributes
                )
                cursorY += 18
                "Balance Due: \(moneyString(invoice.balanceDue, currencyCode: invoice.currencyCode))".draw(
                    at: CGPoint(x: totalsX, y: cursorY),
                    withAttributes: totalAttributes
                )
                cursorY += 24
            }

            if !payments.isEmpty {
                beginPageIfNeeded(minRemaining: 120)
                "PAYMENTS".draw(at: CGPoint(x: margin, y: cursorY), withAttributes: boldBodyAttributes)
                cursorY += 20

                for payment in payments {
                    beginPageIfNeeded(minRemaining: 80)
                    let paymentLine = "\(mediumDate(payment.paymentDate)) · \(payment.paymentMethod) · \(moneyString(payment.amountPaid, currencyCode: invoice.currencyCode))"
                    paymentLine.draw(at: CGPoint(x: margin, y: cursorY), withAttributes: bodyAttributes)
                    cursorY += 16
                    if let note = payment.referenceNote, !note.isEmpty {
                        note.draw(at: CGPoint(x: margin + 8, y: cursorY), withAttributes: captionAttributes)
                        cursorY += 14
                    }
                }
                cursorY += 8
            }

            if let notes = invoice.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                beginPageIfNeeded(minRemaining: 80)
                "NOTES".draw(at: CGPoint(x: margin, y: cursorY), withAttributes: boldBodyAttributes)
                cursorY += 18
                let notesRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 80)
                notes.draw(in: notesRect, withAttributes: bodyAttributes)
                cursorY += 84
            }

            beginPageIfNeeded(minRemaining: 40)
            "Generated by RatioVita".draw(
                at: CGPoint(x: margin, y: pageHeight - margin),
                withAttributes: captionAttributes
            )
        }

        let url = outputURL(for: invoice)
        do {
            try data.write(to: url)
            return url
        } catch {
            throw GeneratorError.couldNotWriteFile
        }
    }
    #endif

    #if canImport(AppKit)
    private static func generatePDFAppKit(for invoice: Invoice) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw GeneratorError.couldNotCreatePDF
        }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw GeneratorError.couldNotCreatePDF
        }

        let titleAttr = TimecardPDFDrawUtils.makeAttrs(size: 24, bold: true)
        let metaAttr = TimecardPDFDrawUtils.makeAttrs(size: 14, bold: true)
        let bodyAttr = TimecardPDFDrawUtils.makeAttrs(size: 12, bold: false)
        let boldBodyAttr = TimecardPDFDrawUtils.makeAttrs(size: 12, bold: true)
        let captionAttr = TimecardPDFDrawUtils.makeAttrs(size: 10, bold: false)
        let headerAttr = TimecardPDFDrawUtils.makeAttrs(size: 11, bold: true)
        let totalAttr = TimecardPDFDrawUtils.makeAttrs(size: 14, bold: true)

        let lineItems = sortedLineItems(invoice)
        let payments = sortedPayments(invoice)

        func drawPageHeader(at y: inout CGFloat) {
            TimecardPDFDrawUtils.draw("INVOICE", at: CGPoint(x: margin, y: y), attributes: titleAttr, in: ctx)
            let meta = "No. \(invoice.invoiceNumber) · \(invoice.status.displayTitle.uppercased())"
            TimecardPDFDrawUtils.draw(meta, at: CGPoint(x: pageWidth - margin - 220, y: y), attributes: metaAttr, in: ctx)
            y -= 36

            TimecardPDFDrawUtils.draw("BILLED TO", at: CGPoint(x: margin, y: y), attributes: boldBodyAttr, in: ctx)
            let client = invoice.clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Client Name"
                : invoice.clientName
            TimecardPDFDrawUtils.draw(client, at: CGPoint(x: margin, y: y - 16), attributes: bodyAttr, in: ctx)

            let rightX = pageWidth - margin - 190
            TimecardPDFDrawUtils.draw(
                "Issue Date: \(mediumDate(invoice.issueDate))",
                at: CGPoint(x: rightX, y: y),
                attributes: bodyAttr,
                in: ctx
            )
            TimecardPDFDrawUtils.draw(
                "Due Date: \(mediumDate(invoice.dueDate))",
                at: CGPoint(x: rightX, y: y - 16),
                attributes: bodyAttr,
                in: ctx
            )
            TimecardPDFDrawUtils.draw(
                "Currency: \(invoice.currencyCode)",
                at: CGPoint(x: rightX, y: y - 32),
                attributes: bodyAttr,
                in: ctx
            )
            y -= 52
        }

        ctx.beginPDFPage(nil)
        var y = pageHeight - margin
        drawPageHeader(at: &y)

        for item in lineItems {
            if y < margin + 120 {
                ctx.endPDFPage()
                ctx.beginPDFPage(nil)
                y = pageHeight - margin
            }
            TimecardPDFDrawUtils.draw(item.itemDescription, at: CGPoint(x: margin, y: y), attributes: bodyAttr, in: ctx)
            TimecardPDFDrawUtils.draw(
                moneyString(item.lineTotal, currencyCode: invoice.currencyCode),
                at: CGPoint(x: pageWidth - margin - 100, y: y),
                attributes: bodyAttr,
                in: ctx
            )
            y -= 18
        }

        y -= 12
        TimecardPDFDrawUtils.draw(
            "Grand Total: \(moneyString(invoice.grandTotal, currencyCode: invoice.currencyCode))",
            at: CGPoint(x: pageWidth - margin - 220, y: y),
            attributes: totalAttr,
            in: ctx
        )
        y -= 20

        for payment in payments {
            let line = "\(mediumDate(payment.paymentDate)) · \(payment.paymentMethod) · \(moneyString(payment.amountPaid, currencyCode: invoice.currencyCode))"
            TimecardPDFDrawUtils.draw(line, at: CGPoint(x: margin, y: y), attributes: bodyAttr, in: ctx)
            y -= 16
        }

        TimecardPDFDrawUtils.draw(
            "Generated by RatioVita",
            at: CGPoint(x: margin, y: margin),
            attributes: captionAttr,
            in: ctx
        )

        ctx.endPDFPage()
        ctx.closePDF()

        let url = outputURL(for: invoice)
        do {
            try data.write(to: url)
            return url
        } catch {
            throw GeneratorError.couldNotWriteFile
        }
    }
    #endif
}
