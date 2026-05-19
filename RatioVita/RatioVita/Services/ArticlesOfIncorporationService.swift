import Foundation

#if canImport(PDFKit)
import PDFKit
#endif

/// Stores and splits **Articles of Incorporation** for corporate registry + EP portal sharing.
///
/// **Deferred:** General credentials vault (Food Handler, WHMIS, DZ, CRA assessments, etc.) —
/// see `Docs/CREDENTIALS_COMPLIANCE_VAULT_BACKLOG.md`.
enum ArticlesOfIncorporationService {
    struct SuggestedFields: Sendable {
        var legalName: String?
        var businessAddress: String?
    }

    #if canImport(PDFKit)
    /// Copies page 1 of a multi-page PDF into a standalone one-page PDF.
    static func extractPageOnePDF(from fullPDF: Data) -> Data? {
        guard let source = PDFDocument(data: fullPDF), let page = source.page(at: 0) else { return nil }
        let out = PDFDocument()
        out.insert(page, at: 0)
        return out.dataRepresentation()
    }

    /// Best-effort text harvest from page 1 (no cloud OCR).
    static func suggestFields(from documentData: Data) -> SuggestedFields {
        guard let doc = PDFDocument(data: documentData),
              let page = doc.page(at: 0),
              let raw = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else
        {
            return SuggestedFields()
        }
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var legalName: String?
        for line in lines.prefix(8) {
            let lower = line.lowercased()
            if lower.contains("inc.") || lower.contains("incorporated") || lower.contains("ltd") {
                legalName = line
                break
            }
        }
        if legalName == nil { legalName = lines.first }

        let addressLines = lines.filter {
            $0.range(of: #"\d"#, options: .regularExpression) != nil
                && ($0.contains(",") || $0.localizedCaseInsensitiveContains("ON ")
                    || $0.localizedCaseInsensitiveContains("BC "))
        }
        let address = addressLines.isEmpty ? nil : addressLines.prefix(3).joined(separator: ", ")

        return SuggestedFields(legalName: legalName, businessAddress: address)
    }
    #else
    static func extractPageOnePDF(from _: Data) -> Data? { nil }

    static func suggestFields(from _: Data) -> SuggestedFields {
        SuggestedFields()
    }
    #endif
}
