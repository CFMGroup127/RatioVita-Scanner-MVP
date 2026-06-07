//
//  ManuscriptVaultImportService.swift
//  RatioVita
//
//  Routes markdown / plain-text project manuscripts into the Manuscript Vault (not receipt OCR).
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

@MainActor
enum ManuscriptVaultImportService {
    static let defaultVaultPrefix = NewHorizonsZoneCatalog.vaultPrefix + "/Project-Manuscripts-Historical-Vault"

    struct ImportSummary: Sendable {
        var knowledgeNodeID: UUID
        var receiptID: UUID
        var title: String
    }

    /// Imports a `.md`, `.txt`, or `.markdown` file into `HistoricalKnowledgeNode` plus a zero-total library anchor
    /// receipt.
    static func importManuscriptFile(
        at url: URL,
        vaultPathPrefix: String? = nil,
        extraTags: [String] = ["NewHorizons", "176Yonge", "ManuscriptVault"],
        context: ModelContext
    ) throws -> ImportSummary {
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8)
            ?? String(decoding: data, as: UTF8.self)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.emptyFile
        }

        let title = url.deletingPathExtension().lastPathComponent
        let prefix = vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? vaultPathPrefix!.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            : defaultVaultPrefix

        let ingest = try HistoricalKnowledgeIngestService.ingest(
            title: title,
            bodyMarkdown: text,
            extraTags: extraTags,
            governance: .forensicHistory,
            context: context
        )
        ingest.node.updatedAt = .now

        let receipt = Receipt(
            merchant: title,
            total: 0,
            currencyCode: ReceiptCurrency.defaultForLocale.code,
            notes: "Manuscript vault · \(text.count) characters · see Media Core → Book assembly.",
            extractionSource: "manuscript",
            documentKind: "project_manuscript",
            documentType: DocumentTypeOption.manuscript.rawValue,
            vaultPathPrefix: prefix,
            pendingHumanReview: false,
            scannedViaCamera: false
        )
        context.insert(receipt)

        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: "manuscript.vault.ingested",
            title: "Manuscript vault import",
            detail: "file:\(url.lastPathComponent)·node:\(ingest.node.id.uuidString)·vault:\(prefix)"
        )
        try ModelContextMainActorSave.saveThrows(context)

        return ImportSummary(
            knowledgeNodeID: ingest.node.id,
            receiptID: receipt.id,
            title: title
        )
    }

    static func isManuscriptFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown" || ext == "txt"
    }

    /// File types for Receipts → Import (camera sheet / Files). Includes images, PDF, and manuscripts.
    static var libraryFileImporterContentTypes: [UTType] {
        var types: [UTType] = [
            .image, .jpeg, .png, .heic, .tiff, .gif, .pdf, .plainText, .text,
        ]
        if let webP = UTType(filenameExtension: "webp") {
            types.append(webP)
        }
        for ext in ["md", "markdown", "txt"] {
            if let t = UTType(filenameExtension: ext) {
                types.append(t)
            }
        }
        for identifier in ["net.daringfireball.markdown", "public.markdown"] {
            if let t = UTType(identifier) {
                types.append(t)
            }
        }
        var seen = Set<String>()
        return types.filter { seen.insert($0.identifier).inserted }
    }

    /// True when every URL is a manuscript (skip receipt merge prompt).
    static func urlsAreAllManuscripts(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy(isManuscriptFile)
    }

    enum ImportError: Error, LocalizedError {
        case emptyFile

        var errorDescription: String? {
            switch self {
                case .emptyFile: "The manuscript file is empty."
            }
        }
    }
}
