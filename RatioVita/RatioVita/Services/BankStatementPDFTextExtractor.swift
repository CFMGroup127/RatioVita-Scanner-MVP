import Foundation

#if canImport(PDFKit)
import PDFKit
#endif

enum BankStatementPDFTextExtractor {
    enum ExtractionError: Error, LocalizedError {
        case cannotOpenDocument

        var errorDescription: String? {
            switch self {
                case .cannotOpenDocument:
                    "Could not read PDF text from this file."
            }
        }
    }

    static func extractText(from url: URL) throws -> String {
        #if canImport(PDFKit)
        guard let doc = PDFDocument(url: url) else { throw ExtractionError.cannotOpenDocument }
        var chunks: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            chunks.append(page.string ?? "")
        }
        return chunks.joined(separator: "\n\n")
        #else
        throw ExtractionError.cannotOpenDocument
        #endif
    }
}
