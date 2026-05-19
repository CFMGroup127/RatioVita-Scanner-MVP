import Foundation
import SwiftData

/// Phase 1 Zoho lane: thin wrapper over `ZohoImportService` so existing call sites keep working.
@MainActor
enum ZohoVaultInvoiceCoordinator {
    struct VaultZohoInboxImportResult: Equatable {
        var filesProcessed: Int
        var receiptsCreated: Int
        /// Zoho Books **Contacts** CSV rows processed on the same pass.
        var contactFilesProcessed: Int
        var contactsInserted: Int
        var contactsMerged: Int
        var failures: [String]
    }

    static func vaultZohoInboxURL() -> URL { ZohoImportService.vaultZohoInboxURL() }

    static func vaultZohoImportedDirectory() -> URL { ZohoImportService.vaultZohoImportedDirectory() }

    static func vaultZohoInboxDisplayPath() -> String { ZohoImportService.vaultZohoInboxDisplayPath() }

    /// PDF invoices in `Inbox` plus **Contacts** CSV in `ContactsInbox` (see `ZohoImportService`).
    static func processVaultZohoInbox(modelContext: ModelContext) async -> VaultZohoInboxImportResult {
        let full = await ZohoImportService.processVaultZohoInbox(modelContext: modelContext)
        var failures = full.invoices.failures
        failures.append(contentsOf: full.contacts.failures)
        return VaultZohoInboxImportResult(
            filesProcessed: full.invoices.filesProcessed,
            receiptsCreated: full.invoices.receiptsCreated,
            contactFilesProcessed: full.contacts.filesProcessed,
            contactsInserted: full.contacts.contactsInserted,
            contactsMerged: full.contacts.contactsMerged,
            failures: failures
        )
    }
}
