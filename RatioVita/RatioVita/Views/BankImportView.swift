import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Drag-and-drop bank statement import (PDF or CSV) for macOS and iPad.
struct BankImportView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isImporting = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var showGeminiSettingsHint = false
    @State private var showSettingsSheet = false
    @State private var dropHover = false
    @State private var inboxBusy = false
    @State private var inboxSummary: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Bank import")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(Color.ratioVitaAdaptiveText)

                Text(
                    "Drop a bank or card statement PDF (parsed with Gemini) or a CSV export. Rows become `BankTransaction` records for reconciliation."
                )
                .font(DesignSystem.Typography.body)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

                zohoVaultHelp

                vaultInboxHelp

                Button {
                    Task { await processVaultInboxTapped() }
                } label: {
                    Label(
                        inboxBusy ? "Processing Vault…" : "Process Vault inbox now",
                        systemImage: "folder.badge.gearshape"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(inboxBusy)

                if let inboxSummary {
                    Text(inboxSummary)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                }

                dropZone

                if let statusMessage {
                    Text(statusMessage)
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(Color.ratioVitaAdaptiveText)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(.red)
                }
                if showGeminiSettingsHint {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("PDF parsing needs a Gemini API key (or GEMINI_API_KEY in the run scheme).")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                        Button {
                            showSettingsSheet = true
                        } label: {
                            Label("Open Settings", systemImage: "gearshape")
                                .frame(maxWidth: 280, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.ratioVitaAdaptiveBackground)
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showSettingsSheet = false
                            }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 520)
            #endif
        }
    }

    private var zohoVaultHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Zoho / external invoices (auto on launch)")
                .font(DesignSystem.Typography.bodyEmphasized)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text(
                "PDF invoices: \(ZohoImportService.vaultZohoInboxDisplayPath()) → Outgoing Invoice receipts in Review (moved to Imported). Zoho Books **Contacts** CSV: \(ZohoImportService.vaultZohoContactsInboxDisplayPath()) → contact graph (moved to ContactsImported). Both run on launch."
            )
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(Color.ratioVitaTextSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await processZohoVaultInboxTapped() }
            } label: {
                Label("Process Zoho inbox now", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .disabled(inboxBusy)
        }
    }

    @MainActor
    private func processZohoVaultInboxTapped() async {
        errorMessage = nil
        inboxBusy = true
        defer { inboxBusy = false }
        let zoho = await ZohoVaultInvoiceCoordinator.processVaultZohoInbox(modelContext: modelContext)
        var parts: [String] = []
        if zoho.receiptsCreated > 0 {
            parts.append("Invoices: \(zoho.receiptsCreated) receipt(s) from \(zoho.filesProcessed) PDF(s).")
        }
        if zoho.contactsInserted > 0 || zoho.contactsMerged > 0 {
            parts.append(
                "Contacts: \(zoho.contactsInserted) new, \(zoho.contactsMerged) updated from \(zoho.contactFilesProcessed) CSV(s)."
            )
        }
        if !parts.isEmpty {
            inboxSummary = "Zoho: " + parts.joined(separator: " ")
        } else if zoho.failures.isEmpty {
            inboxSummary = "Zoho vault: no PDFs in Inbox and no CSVs in ContactsInbox."
        } else {
            errorMessage = zoho.failures.joined(separator: "\n")
        }
    }

    private var vaultInboxHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vault inbox (auto on launch)")
                .font(DesignSystem.Typography.bodyEmphasized)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text(
                "Place statement files in \(BankStatementImportCoordinator.vaultBankStatementInboxDisplayPath()). Each launch imports them into bank transactions and moves successful files to Imported (same Vault folder)."
            )
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(Color.ratioVitaTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @MainActor
    private func processVaultInboxTapped() async {
        errorMessage = nil
        inboxSummary = nil
        inboxBusy = true
        defer { inboxBusy = false }
        let result = await BankStatementImportCoordinator.processVaultBankStatementInbox(
            modelContext: modelContext,
            geminiProgress: { msg in
                errorMessage = msg
            }
        )
        if result.rowsInserted > 0 {
            errorMessage = nil
            inboxSummary =
                "Vault: imported \(result.rowsInserted) row\(result.rowsInserted == 1 ? "" : "s") from \(result.filesProcessed) file\(result.filesProcessed == 1 ? "" : "s")."
        } else if result.failures.isEmpty {
            errorMessage = nil
            inboxSummary = "Vault inbox was empty (no PDF/CSV/TXT to import)."
        } else {
            inboxSummary = nil
            errorMessage = result.failures.joined(separator: "\n")
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
            .strokeBorder(
                Color.ratioVitaAdaptiveBorder.opacity(dropHover ? 0.9 : 0.45),
                style: StrokeStyle(lineWidth: dropHover ? 2 : 1, dash: [8, 6])
            )
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveSurface.opacity(dropHover ? 0.55 : 0.35))
            )
            .frame(minHeight: 160)
            .overlay {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: isImporting ? "arrow.triangle.2.circlepath" : "arrow.down.doc")
                        .font(.system(size: 36))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.ratioVitaPrimary)
                    Text(isImporting ? "Importing…" : "Drop PDF or CSV here")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(Color.ratioVitaAdaptiveText)
                    Text("CSV uses simple date + amount detection; PDF uses extracted text + Gemini.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .padding()
            }
            .onDrop(of: [.fileURL], isTargeted: $dropHover) { providers in
                Task { await handleDropProviders(providers) }
                return true
            }
    }

    @MainActor
    private func handleDropProviders(_ providers: [NSItemProvider]) async {
        errorMessage = nil
        statusMessage = nil
        showGeminiSettingsHint = false
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        guard let url = urls.first else { return }
        let ext = url.pathExtension.lowercased()
        guard ext == "pdf" || ext == "csv" || ext == "txt" else {
            errorMessage = "Supported types: PDF, CSV, or plain text exports."
            return
        }
        isImporting = true
        defer { isImporting = false }
        do {
            let count = try await BankStatementImportCoordinator.importFile(
                at: url,
                modelContext: modelContext,
                geminiProgress: { msg in
                    errorMessage = msg
                }
            )
            errorMessage = nil
            statusMessage = "Imported \(count) bank row\(count == 1 ? "" : "s") from \(url.lastPathComponent)."
        } catch {
            errorMessage = error.localizedDescription
            if let bankErr = error as? BankStatementImportError, bankErr.suggestsOpeningGeminiSettings {
                showGeminiSettingsHint = true
            }
        }
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
