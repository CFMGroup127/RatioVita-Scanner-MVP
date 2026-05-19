import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Renders a transaction email body (no PDF attachment) into a vector PDF for the Review vault.
enum EmailReceiptCompilerEngine {
    struct CompiledEmailReceipt: Sendable {
        var pdfData: Data
        var suggestedMerchant: String
        var suggestedSubject: String
    }

    enum CompileError: LocalizedError {
        case emptyBody
        case pdfGenerationFailed

        var errorDescription: String? {
            switch self {
                case .emptyBody: "Email body is empty."
                case .pdfGenerationFailed: "Could not render email to PDF."
            }
        }
    }

    /// Blueprint: HTML or plain body → standardized PDF bytes for ingest.
    static func compile(
        subject: String?,
        fromAddress: String?,
        receivedAt: Date?,
        bodyHTML: String?,
        bodyPlain: String?
    ) throws -> CompiledEmailReceipt {
        let plain = bodyPlain?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let html = bodyHTML?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !plain.isEmpty || !html.isEmpty else { throw CompileError.emptyBody }

        let subj = subject?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Email receipt"
        let from = fromAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unknown sender"
        let dateLine = receivedAt.map {
            DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short)
        } ?? "—"

        let bodyBlock = !html.isEmpty ? html : plain.replacingOccurrences(of: "\n", with: "<br/>")
        let documentHTML = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"/>
        <style>
        body { font-family: -apple-system, Helvetica, sans-serif; font-size: 11pt; color: #111; margin: 36pt; }
        h1 { font-size: 14pt; margin-bottom: 4pt; }
        .meta { color: #444; font-size: 9pt; margin-bottom: 18pt; }
        .body { line-height: 1.45; }
        </style></head><body>
        <h1>\(escapeHTML(subj))</h1>
        <div class="meta">From: \(escapeHTML(from))<br/>Received: \(escapeHTML(dateLine))</div>
        <div class="body">\(bodyBlock)</div>
        </body></html>
        """

        let pdfData = try renderPDF(fromHTML: documentHTML)
        return CompiledEmailReceipt(
            pdfData: pdfData,
            suggestedMerchant: from,
            suggestedSubject: subj
        )
    }

    private static func escapeHTML(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func renderPDF(fromHTML html: String) throws -> Data {
        #if os(macOS)
        guard let text = try? NSAttributedString(
            data: Data(html.utf8),
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ],
            documentAttributes: nil
        ) else {
            throw CompileError.pdfGenerationFailed
        }
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
        view.textStorage?.setAttributedString(text)
        let pdfData = view.dataWithPDF(inside: view.bounds)
        guard !pdfData.isEmpty else { throw CompileError.pdfGenerationFailed }
        return pdfData
        #elseif canImport(UIKit)
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        let paper = CGRect(x: 0, y: 0, width: 612, height: 792)
        renderer.setValue(paper, forKey: "paperRect")
        renderer.setValue(paper.insetBy(dx: 36, dy: 36), forKey: "printableRect")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, paper, nil)
        for page in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        guard data.length > 0 else { throw CompileError.pdfGenerationFailed }
        return data as Data
        #else
        throw CompileError.pdfGenerationFailed
        #endif
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
