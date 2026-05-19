import Foundation
import SwiftData

/// Phase 1 **digital inbox** for Zoho: watches `Vault/External/Zoho` for invoice PDFs and contact CSV exports.
/// Phase 2 (OAuth live bridge) can call the same persistence helpers later.
@MainActor
enum ZohoImportService {
    struct VaultZohoInvoiceImportResult: Equatable {
        var filesProcessed: Int
        var receiptsCreated: Int
        var failures: [String]
    }

    struct VaultZohoContactImportResult: Equatable {
        var filesProcessed: Int
        var contactsInserted: Int
        var contactsMerged: Int
        var failures: [String]
    }

    struct VaultZohoFullImportResult: Equatable {
        var invoices: VaultZohoInvoiceImportResult
        var contacts: VaultZohoContactImportResult
    }

    private static func zohoRootURL() -> URL {
        #if os(iOS)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Vault/External/Zoho", isDirectory: true)
        #else
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Vault/External/Zoho", isDirectory: true)
        #endif
    }

    static func vaultZohoInboxURL() -> URL {
        zohoRootURL().appendingPathComponent("Inbox", isDirectory: true)
    }

    static func vaultZohoImportedDirectory() -> URL {
        zohoRootURL().appendingPathComponent("Imported", isDirectory: true)
    }

    /// Drop Zoho Books **Contacts** CSV exports here (UTF-8 or UTF-16). Processed files move to `ContactsImported`.
    static func vaultZohoContactsInboxURL() -> URL {
        zohoRootURL().appendingPathComponent("ContactsInbox", isDirectory: true)
    }

    static func vaultZohoContactsImportedDirectory() -> URL {
        zohoRootURL().appendingPathComponent("ContactsImported", isDirectory: true)
    }

    static func vaultZohoInboxDisplayPath() -> String {
        #if os(iOS)
        "Documents/Vault/External/Zoho/Inbox"
        #else
        let url = vaultZohoInboxURL()
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home), home.count > 1 {
            return "~" + path.dropFirst(home.count)
        }
        return path
        #endif
    }

    static func vaultZohoContactsInboxDisplayPath() -> String {
        #if os(iOS)
        "Documents/Vault/External/Zoho/ContactsInbox"
        #else
        let url = vaultZohoContactsInboxURL()
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home), home.count > 1 {
            return "~" + path.dropFirst(home.count)
        }
        return path
        #endif
    }

    /// PDFs in `Inbox` → **Outgoing Invoice** receipts (Review), files moved to `Imported`.
    static func processInvoicePDFInbox(modelContext: ModelContext) async -> VaultZohoInvoiceImportResult {
        let inbox = vaultZohoInboxURL()
        let importedDir = vaultZohoImportedDirectory()
        let fm = FileManager.default
        try? fm.createDirectory(at: inbox, withIntermediateDirectories: true)
        try? fm.createDirectory(at: importedDir, withIntermediateDirectories: true)

        guard let entries = try? fm.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return VaultZohoInvoiceImportResult(filesProcessed: 0, receiptsCreated: 0, failures: [])
        }

        let pdfs = entries.filter { $0.pathExtension.lowercased() == "pdf" }
        var created = 0
        var failures: [String] = []

        let projects = (try? modelContext.fetch(FetchDescriptor<ProductionProject>())) ?? []
        var contactWorking = (try? modelContext.fetch(FetchDescriptor<ProductionContact>())) ?? []

        for url in pdfs {
            let name = url.deletingPathExtension().lastPathComponent
            let merchant = name.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let matchedProject = projects.first { p in
                let t = p.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return false }
                return name.localizedCaseInsensitiveContains(t)
                    || t.localizedCaseInsensitiveContains(name)
            }

            let notes = "Zoho vault: \(url.lastPathComponent)"
            let receipt = Receipt(
                merchant: merchant.isEmpty ? "Zoho invoice" : merchant,
                total: 0,
                notes: notes,
                documentType: DocumentTypeOption.outgoingInvoice.rawValue,
                productionProject: matchedProject,
                counterpartyContact: upsertZohoInvoiceClientContact(
                    merchant: merchant.isEmpty ? "Zoho invoice" : merchant,
                    working: &contactWorking,
                    modelContext: modelContext
                ),
                pendingHumanReview: true,
                scannedViaCamera: false
            )
            modelContext.insert(receipt)
            do {
                if let thumb = try? ReceiptPDFRendering.firstPageImage(fromDocumentAt: url, maxPixelDimension: 900) {
                    let page = ReceiptImage(
                        pageIndex: 0,
                        image: thumb,
                        ocrText: nil,
                        receipt: receipt,
                        compressionQuality: 0.88
                    )
                    modelContext.insert(page)
                    receipt.images = [page]
                }
                try modelContext.save()
                created += 1
                let dest = importedDir.appendingPathComponent(url.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                try fm.moveItem(at: url, to: dest)
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                modelContext.delete(receipt)
                try? modelContext.save()
            }
        }

        return VaultZohoInvoiceImportResult(
            filesProcessed: pdfs.count,
            receiptsCreated: created,
            failures: failures
        )
    }

    /// CSV files from Zoho Books **Contacts** export → `ProductionContact` rows; processed files move to
    /// `ContactsImported`.
    static func processContactsCSVInbox(modelContext: ModelContext) async -> VaultZohoContactImportResult {
        let inbox = vaultZohoContactsInboxURL()
        let importedDir = vaultZohoContactsImportedDirectory()
        let fm = FileManager.default
        try? fm.createDirectory(at: inbox, withIntermediateDirectories: true)
        try? fm.createDirectory(at: importedDir, withIntermediateDirectories: true)

        guard let entries = try? fm.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return VaultZohoContactImportResult(
                filesProcessed: 0,
                contactsInserted: 0,
                contactsMerged: 0,
                failures: []
            )
        }

        let csvs = entries.filter { $0.pathExtension.lowercased() == "csv" }
        var inserted = 0
        var merged = 0
        var failures: [String] = []

        var workingContacts = (try? modelContext.fetch(FetchDescriptor<ProductionContact>())) ?? []

        for url in csvs {
            do {
                let data = try Data(contentsOf: url)
                let rows = ZohoContactCSVParser.parseRows(from: data)
                for row in rows {
                    let outcome = upsertContact(from: row, working: &workingContacts, modelContext: modelContext)
                    if outcome == .inserted { inserted += 1 }
                    if outcome == .merged { merged += 1 }
                }
                try modelContext.save()
                let dest = importedDir.appendingPathComponent(url.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                try fm.moveItem(at: url, to: dest)
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return VaultZohoContactImportResult(
            filesProcessed: csvs.count,
            contactsInserted: inserted,
            contactsMerged: merged,
            failures: failures
        )
    }

    private enum UpsertOutcome {
        case skipped
        case inserted
        case merged
    }

    private static func upsertContact(
        from row: ZohoContactCSVParser.ParsedRow,
        working: inout [ProductionContact],
        modelContext: ModelContext
    ) -> UpsertOutcome {
        let name = row.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .skipped }

        let emailKey = row.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let company = row.companyName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        if let emailKey, !emailKey.isEmpty {
            if let match = working
                .first(where: {
                    ($0.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == emailKey
                })
            {
                mergeTags(into: match, incoming: row.tags)
                match.name = preferLonger(match.name, name)
                if let company { match.companyName = match.companyName ?? company }
                match.updatedAt = .now
                return .merged
            }
        } else {
            let dup = working.first { c in
                c.name.caseInsensitiveCompare(name) == .orderedSame
                    && (c.companyName ?? "").caseInsensitiveCompare(company ?? "") == .orderedSame
            }
            if let dup {
                mergeTags(into: dup, incoming: row.tags)
                dup.updatedAt = .now
                return .merged
            }
        }

        let contact = ProductionContact(
            name: name,
            companyName: company,
            email: row.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            tags: row.tags,
            notes: "Zoho CSV import"
        )
        modelContext.insert(contact)
        working.append(contact)
        return .inserted
    }

    private static func preferLonger(_ a: String, _ b: String) -> String {
        b.count > a.count ? b : a
    }

    private static func mergeTags(into contact: ProductionContact, incoming: [String]) {
        guard !incoming.isEmpty else { return }
        var set = Set(contact.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        for t in incoming {
            let v = t.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { set.insert(v) }
        }
        contact.tags = set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func processVaultZohoInbox(modelContext: ModelContext) async -> VaultZohoFullImportResult {
        async let inv = processInvoicePDFInbox(modelContext: modelContext)
        async let con = processContactsCSVInbox(modelContext: modelContext)
        return await VaultZohoFullImportResult(invoices: inv, contacts: con)
    }

    /// Creates or updates a **client / payer** row from the Zoho invoice PDF filename (merchant string).
    private static func upsertZohoInvoiceClientContact(
        merchant: String,
        working: inout [ProductionContact],
        modelContext: ModelContext
    ) -> ProductionContact {
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? "Zoho client" : name
        if let existing = working.first(where: {
            $0.name.caseInsensitiveCompare(displayName) == .orderedSame
                && ($0.companyName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }) {
            mergeTags(into: existing, incoming: ["Zoho Invoice"])
            existing.updatedAt = .now
            return existing
        }
        let c = ProductionContact(
            name: displayName,
            tags: ["Zoho Invoice"],
            notes: "Auto-linked from Zoho vault PDF"
        )
        modelContext.insert(c)
        working.append(c)
        return c
    }
}

// MARK: - CSV

private enum ZohoContactCSVParser {
    struct ParsedRow: Equatable {
        var contactName: String
        var companyName: String?
        var email: String?
        var tags: [String]
    }

    static func parseRows(from data: Data) -> [ParsedRow] {
        guard let text = decodeText(data) else { return [] }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else { return [] }

        let headers = parseCSVLine(headerLine).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let nameIdx = headers.firstIndex(where: { $0 == "contact name" || $0 == "name" || $0 == "display name" })
        let companyIdx = headers.firstIndex(where: { $0 == "company name" || $0 == "organization" || $0 == "company" })
        let emailIdx = headers.firstIndex(where: { $0 == "email" || $0 == "email id" || $0 == "emailid" })
        let tagsIdx = headers.firstIndex(where: { $0 == "tags" || $0 == "tag" })
        guard let nameIdx else { return [] }

        var out: [ParsedRow] = []
        for line in lines.dropFirst() {
            let cols = parseCSVLine(line)
            guard nameIdx < cols.count else { continue }
            let rawName = cols[nameIdx].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawName.isEmpty else { continue }
            let company = companyIdx
                .flatMap { $0 < cols.count ? cols[$0].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil }
            let email = emailIdx
                .flatMap { $0 < cols.count ? cols[$0].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil }
            let tagStrings: [String] = {
                guard let tagsIdx, tagsIdx < cols.count else { return [] }
                let cell = cols[tagsIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cell.isEmpty else { return [] }
                return cell.split(whereSeparator: { $0 == "|" || $0 == ";" || $0 == "," })
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }()
            out.append(ParsedRow(contactName: rawName, companyName: company, email: email, tags: tagStrings))
        }
        return out
    }

    private static func decodeText(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return s
        }
        if data.count >= 2 {
            if data[0] == 0xFF, data[1] == 0xFE,
               let s = String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
            {
                return s
            }
            if data[0] == 0xFE, data[1] == 0xFF,
               let s = String(data: data.dropFirst(2), encoding: .utf16BigEndian)
            {
                return s
            }
        }
        if let s = String(data: data, encoding: .utf16LittleEndian) { return s }
        return String(data: data, encoding: .utf16)
    }

    /// Minimal CSV line split honoring double-quoted fields.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == ",", !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
