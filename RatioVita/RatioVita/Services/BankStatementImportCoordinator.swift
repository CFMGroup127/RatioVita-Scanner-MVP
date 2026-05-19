import Foundation
import SwiftData

enum BankStatementImportError: Error, LocalizedError {
    case missingGeminiKey
    case geminiFailed(String)
    case emptyImport

    var errorDescription: String? {
        switch self {
            case .missingGeminiKey:
                "Add a Gemini API key in Settings (or GEMINI_API_KEY) to parse bank PDFs."
            case let .geminiFailed(msg):
                msg
            case .emptyImport:
                "No bank rows could be parsed from this file."
        }
    }

    /// Bank import UI can offer “Open Settings” when this is true.
    var suggestsOpeningGeminiSettings: Bool {
        switch self {
            case .missingGeminiKey: true
            default: false
        }
    }
}

private enum BankStatementGeminiRuntime {
    static func resolveAPIKeyAndModel() -> (apiKey: String, modelId: String)? {
        let apiKey = GeminiAPIKeyResolver.resolveAPIKeyTrimmed()
        guard !apiKey.isEmpty else { return nil }
        let model = GeminiAPIKeyResolver.resolveModelId()
        return (apiKey, model)
    }

    static var geminiEnabled: Bool {
        GeminiAPIKeyResolver.isGeminiExtractionEnabled()
    }
}

@MainActor
enum BankStatementImportCoordinator {
    /// Imports `BankTransaction` rows from a dropped bank PDF or CSV. PDF path requires Gemini when enabled.
    /// - Parameter geminiProgress: Optional UI hook while Gemini retries transient **503 / 429 / 500** responses.
    static func importFile(
        at url: URL,
        modelContext: ModelContext,
        geminiProgress: (@MainActor (String) -> Void)? = nil
    ) async throws -> Int {
        let ext = url.pathExtension.lowercased()
        let defaultCurrency = ReceiptCurrency.defaultForLocale.code

        let text: String
        if ext == "pdf" {
            text = try BankStatementPDFTextExtractor.extractText(from: url)
        } else {
            let data = try Data(contentsOf: url)
            text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        }

        var parsed: [BankStatementParsedRow] = []
        if ext == "csv" || ext == "txt" {
            parsed = BankStatementCSVImporter.parseRows(from: text, defaultCurrency: defaultCurrency)
        }

        if parsed.isEmpty {
            guard BankStatementGeminiRuntime.geminiEnabled,
                  let cfg = BankStatementGeminiRuntime.resolveAPIKeyAndModel() else
            {
                if ext == "pdf" {
                    #if DEBUG
                    await MainActor.run {
                        GeminiAPIKeyResolver
                            .logGeminiKeyDiagnostics(context: "Bank PDF import blocked (Gemini required)")
                    }
                    #endif
                    throw BankStatementImportError.missingGeminiKey
                }
                throw BankStatementImportError.emptyImport
            }
            do {
                let payload = try await GeminiBankStatementExtractionService.extractStatementRows(
                    statementText: text,
                    apiKey: cfg.apiKey,
                    modelId: cfg.modelId,
                    onRetryScheduled: { seconds in
                        Task { @MainActor in
                            geminiProgress?(
                                "Gemini is temporarily busy. Retrying in \(seconds) second\(seconds == 1 ? "" : "s")…"
                            )
                        }
                    }
                )
                parsed = BankStatementRowParser.rows(from: payload, defaultCurrency: defaultCurrency)
            } catch {
                throw BankStatementImportError.geminiFailed(error.localizedDescription)
            }
        }

        guard !parsed.isEmpty else { throw BankStatementImportError.emptyImport }

        let inserted = insertTransactions(parsed, sourceLabel: url.lastPathComponent, modelContext: modelContext)
        guard inserted > 0 else { throw BankStatementImportError.emptyImport }
        try modelContext.save()
        return inserted
    }

    /// PDF/CSV/TXT files dropped into `Vault/BankStatements/Inbox` are imported on app launch and can be re-run from
    /// Bank import.
    struct VaultBankInboxImportResult: Equatable {
        var filesProcessed: Int
        var rowsInserted: Int
        var failures: [String]
    }

    /// Inbox folder (create parents as needed before listing).
    static func vaultBankStatementInboxURL() -> URL {
        #if os(iOS)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Vault/BankStatements/Inbox", isDirectory: true)
        #else
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Vault/BankStatements/Inbox", isDirectory: true)
        #endif
    }

    /// Short path for UI copy (tilde on macOS when under the app home).
    static func vaultBankStatementInboxDisplayPath() -> String {
        #if os(iOS)
        return "Documents/Vault/BankStatements/Inbox"
        #else
        let url = vaultBankStatementInboxURL()
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home), home.count > 1 {
            return "~" + path.dropFirst(home.count)
        }
        return path
        #endif
    }

    /// Successful Vault inbox imports are moved here (`Vault/BankStatements/Imported`).
    static func vaultBankStatementsImportedDirectory() -> URL {
        vaultBankStatementInboxURL().deletingLastPathComponent().appendingPathComponent("Imported", isDirectory: true)
    }

    /// `BankTransaction.externalReference` is `"\(sourceFileName)|\(dedupeKey)"` for rows inserted by this coordinator.
    /// Returns the original statement filename when it was a PDF (so the file can be shown in reconciliation).
    static func sourceStatementPDFFilename(fromExternalReference ref: String?) -> String? {
        guard let ref, !ref.isEmpty else { return nil }
        guard let pipe = ref.firstIndex(of: "|") else { return nil }
        let name = String(ref[..<pipe])
        guard name.lowercased().hasSuffix(".pdf") else { return nil }
        return name
    }

    /// Source import file name (PDF, CSV, etc.) from `externalReference` prefix before `|`.
    static func sourceImportFilename(fromExternalReference ref: String?) -> String? {
        guard let ref, !ref.isEmpty else { return nil }
        guard let pipe = ref.firstIndex(of: "|") else { return nil }
        let name = String(ref[..<pipe]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// Resolves a bank statement PDF previously imported via the Vault inbox (Imported first, then Inbox).
    static func resolvedStatementPDFURL(for transaction: BankTransaction) -> URL? {
        guard let name = sourceStatementPDFFilename(fromExternalReference: transaction.externalReference) else {
            return nil
        }
        let fm = FileManager.default
        for dir in [vaultBankStatementsImportedDirectory(), vaultBankStatementInboxURL()] {
            let candidate = dir.appendingPathComponent(name)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Processes every supported file in the Vault inbox: inserts `BankTransaction` rows, then moves successful imports
    /// to `Vault/BankStatements/Imported`.
    static func processVaultBankStatementInbox(
        modelContext: ModelContext,
        geminiProgress: (@MainActor (String) -> Void)? = nil
    ) async -> VaultBankInboxImportResult {
        let inbox = vaultBankStatementInboxURL()
        let importedDir = vaultBankStatementsImportedDirectory()
        let fm = FileManager.default
        try? fm.createDirectory(at: inbox, withIntermediateDirectories: true)
        try? fm.createDirectory(at: importedDir, withIntermediateDirectories: true)

        guard let entries = try? fm.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return VaultBankInboxImportResult(filesProcessed: 0, rowsInserted: 0, failures: [])
        }

        let urls = entries.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "pdf" || ext == "csv" || ext == "txt"
        }
        .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var filesProcessed = 0
        var rowsInserted = 0
        var failures: [String] = []

        var didEvaluatePDFNetwork = false
        var pdfNetworkSatisfied = false

        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf",
               BankStatementGeminiRuntime.geminiEnabled,
               BankStatementGeminiRuntime.resolveAPIKeyAndModel() != nil
            {
                if !didEvaluatePDFNetwork {
                    pdfNetworkSatisfied = await NetworkConnectivityGate.pathSatisfiesInternet()
                    didEvaluatePDFNetwork = true
                }
                if !pdfNetworkSatisfied {
                    failures.append(
                        "\(url.lastPathComponent): No network connection. PDF bank imports require internet for Gemini."
                    )
                    continue
                }
            }

            do {
                let n = try await importFile(at: url, modelContext: modelContext, geminiProgress: geminiProgress)
                filesProcessed += 1
                rowsInserted += n
                let dest = importedDir.appendingPathComponent(url.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                try fm.moveItem(at: url, to: dest)
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return VaultBankInboxImportResult(
            filesProcessed: filesProcessed,
            rowsInserted: rowsInserted,
            failures: failures
        )
    }

    private static func insertTransactions(
        _ rows: [BankStatementParsedRow],
        sourceLabel: String,
        modelContext: ModelContext
    ) -> Int {
        var seen = Set<String>()
        var count = 0
        for row in rows {
            let memo = row.memo ?? ""
            let key = "\(row.postedDate.timeIntervalSince1970)|\(NSDecimalNumber(decimal: row.amount).stringValue)|\(memo)"
            guard seen.insert(key).inserted else { continue }
            let ref = "\(sourceLabel)|\(key)".prefix(480)
            let tx = BankTransaction(
                postedDate: row.postedDate,
                amount: row.amount,
                currencyCode: row.currencyCode,
                memo: row.memo,
                externalReference: String(ref)
            )
            modelContext.insert(tx)
            count += 1
        }
        return count
    }
}
