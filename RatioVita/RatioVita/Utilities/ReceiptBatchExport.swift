import Foundation
import PDFKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ReceiptBatchExportError: LocalizedError {
    case noImages
    case pdfWriteFailed

    var errorDescription: String? {
        switch self {
            case .noImages: "None of the selected receipts have images to include in a PDF."
            case .pdfWriteFailed: "Could not write the PDF to a temporary file."
        }
    }
}

enum ReceiptBatchExport {
    /// One PDF; each receipt page becomes a PDF page in order.
    static func makeCombinedPDF(receipts: [Receipt]) throws -> URL {
        let sortedReceipts = receipts.sorted { $0.createdAt < $1.createdAt }
        let doc = PDFDocument()
        var inserted = 0
        for receipt in sortedReceipts {
            let pages = receipt.images.sorted { $0.pageIndex < $1.pageIndex }
            for img in pages {
                guard let plat = img.platformImage else { continue }
                #if canImport(UIKit)
                if let page = PDFPage(image: plat) {
                    doc.insert(page, at: doc.pageCount)
                    inserted += 1
                }
                #elseif canImport(AppKit)
                if let page = PDFPage(image: plat) {
                    doc.insert(page, at: doc.pageCount)
                    inserted += 1
                }
                #endif
            }
        }
        guard inserted > 0 else { throw ReceiptBatchExportError.noImages }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RatioVita-Receipts-\(UUID().uuidString).pdf")
        guard doc.write(to: url) else { throw ReceiptBatchExportError.pdfWriteFailed }
        return url
    }

    /// Tax-prep friendly CSV (merchant, dates, totals, document type, project).
    static func makeCSV(receipts: [Receipt]) throws -> URL {
        let sorted = receipts.sorted { $0.createdAt < $1.createdAt }
        var lines: [String] = [
            "merchant,created_at_iso,transaction_date_iso,total,currency,document_type,project_title,verified",
        ]
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        for r in sorted {
            let merchant = escapeCSV(r.merchant)
            let created = fmt.string(from: r.createdAt)
            let tx = r.transactionDate.map { fmt.string(from: $0) } ?? ""
            let total = "\(r.total as NSDecimalNumber)"
            let cur = escapeCSV(r.currencyCode)
            let dtype = escapeCSV(r.documentType)
            let proj = escapeCSV(r.libraryColumnGroupTitle)
            let ver = r.isVerified ? "true" : "false"
            lines.append("\(merchant),\(created),\(tx),\(total),\(cur),\(dtype),\(proj),\(ver)")
        }
        let data = Data(lines.joined(separator: "\n").utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RatioVita-Receipts-\(UUID().uuidString).csv")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func escapeCSV(_ s: String) -> String {
        let needsQuotes = s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        if needsQuotes {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
