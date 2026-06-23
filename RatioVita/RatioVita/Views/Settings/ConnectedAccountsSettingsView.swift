import SwiftUI

/// Profile → Connected Accounts — OAuth2 / multi-inbox IMAP links for supplier receipt & production doc ingestion.
struct ConnectedAccountsSettingsView: View {
    @Environment(\.brandAccent) private var brandAccent
    @State private var secureInboxes: [SecureIngestionVaultStore.SecureInboxAccount] = []
    @State private var statusMessage: String?
    @State private var showAddInboxMenu = false
    @State private var pendingInboxKind: SecureIngestionVaultStore.SecureInboxKind?
    @State private var draftEmail = ""
    @State private var draftIMAPHost = ""
    @State private var draftAppPassword = ""

    var body: some View {
        List {
            Section {
                Text(
                    "Link every inbox that receives vendor receipts, call sheets, and fitting packets. "
                        + "Each account ingests independently — pause any slot without unlinking credentials."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Section {
                if secureInboxes.isEmpty {
                    Text("No secure inboxes linked yet.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                } else {
                    ForEach(secureInboxes) { inbox in
                        secureInboxRow(inbox)
                    }
                }

                Button {
                    showAddInboxMenu = true
                } label: {
                    Label("Add Secure Inbox", systemImage: "plus.circle.fill")
                        .font(DesignSystem.Typography.bodyEmphasized)
                }
            } header: {
                Text("Secure inboxes")
            } footer: {
                Text("Use app-specific passwords — never your primary email password.")
            }

            Section("OAuth2 providers") {
                providerRow(.gmailOAuth, subtitle: "Scan Gmail for supplier threads & attachments.")
                providerRow(.outlookOAuth, subtitle: "Microsoft 365 / Outlook business inboxes.")
            }

            Section("Ingestion filters") {
                Label("Approved vendors (Thunder Thighs, etc.)", systemImage: "checkmark.seal.fill")
                Label("Keywords: Receipt, Invoice, PO#, Fitting", systemImage: "text.magnifyingglass")
                Label("Private personal threads ignored on-device", systemImage: "hand.raised.fill")
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                }
            }
        }
        .navigationTitle("Connected Accounts")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { reloadInboxes() }
        .confirmationDialog("Add Secure Inbox", isPresented: $showAddInboxMenu, titleVisibility: .visible) {
            ForEach(SecureIngestionVaultStore.SecureInboxKind.allCases) { kind in
                Button(kind.title) {
                    beginAddInbox(kind)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $pendingInboxKind) { kind in
            addInboxSheet(kind: kind)
        }
    }

    @ViewBuilder
    private func secureInboxRow(_ inbox: SecureIngestionVaultStore.SecureInboxAccount) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: inbox.isIngestionEnabled ? "circle.fill" : "circle")
                .font(.caption2)
                .foregroundStyle(inbox.isIngestionEnabled ? Color.green : Color.ratioVitaTextSecondary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(inbox.displayLabel)
                    .font(DesignSystem.Typography.bodyEmphasized)
                Text(inbox.kind.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Spacer(minLength: 8)

            Toggle("Ingest", isOn: ingestionBinding(for: inbox))
                .labelsHidden()

            Button(role: .destructive) {
                removeInbox(inbox)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func ingestionBinding(for inbox: SecureIngestionVaultStore.SecureInboxAccount) -> Binding<Bool> {
        Binding(
            get: { inbox.isIngestionEnabled },
            set: { enabled in
                do {
                    try SecureIngestionVaultStore.setIngestionEnabled(id: inbox.id, enabled: enabled)
                    reloadInboxes()
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        )
    }

    @ViewBuilder
    private func addInboxSheet(kind: SecureIngestionVaultStore.SecureInboxKind) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email address", text: $draftEmail)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    #endif

                    if kind == .customIMAP {
                        TextField("IMAP host", text: $draftIMAPHost)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        #endif
                    } else {
                        LabeledContent("IMAP host", value: kind.defaultIMAPHost)
                    }

                    SecureField("App-specific password", text: $draftAppPassword)
                } header: {
                    Text(kind.title)
                } footer: {
                    Text("Credentials are stored in the device Keychain and never leave this device unencrypted.")
                }
            }
            .navigationTitle("Link Inbox")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        pendingInboxKind = nil
                        resetDraftFields()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveInbox(kind: kind)
                    }
                    .disabled(!canSaveInbox(kind: kind))
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    @ViewBuilder
    private func providerRow(_ provider: SecureIngestionVaultStore.Provider, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: provider.systemImage)
                .foregroundStyle(brandAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(provider.title)
                    .font(DesignSystem.Typography.bodyEmphasized)
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Spacer(minLength: 8)

            if SecureIngestionVaultStore.isConnected(provider) {
                Button("Disconnect") {
                    disconnect(provider)
                }
                .font(DesignSystem.Typography.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Connect") {
                    connectOAuth(provider)
                }
                .font(DesignSystem.Typography.caption)
                .buttonStyle(.borderedProminent)
                .tint(brandAccent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func beginAddInbox(_ kind: SecureIngestionVaultStore.SecureInboxKind) {
        draftIMAPHost = kind.defaultIMAPHost
        pendingInboxKind = kind
    }

    private func canSaveInbox(kind: SecureIngestionVaultStore.SecureInboxKind) -> Bool {
        !draftEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftAppPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (kind != .customIMAP || !draftIMAPHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func saveInbox(kind: SecureIngestionVaultStore.SecureInboxKind) {
        do {
            let host = kind == .customIMAP ? draftIMAPHost : kind.defaultIMAPHost
            let account = try SecureIngestionVaultStore.addSecureInbox(
                kind: kind,
                emailAddress: draftEmail,
                imapHost: host,
                appPassword: draftAppPassword
            )
            statusMessage = "\(account.displayLabel) linked to the secure vault."
            pendingInboxKind = nil
            resetDraftFields()
            reloadInboxes()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func removeInbox(_ inbox: SecureIngestionVaultStore.SecureInboxAccount) {
        do {
            try SecureIngestionVaultStore.removeSecureInbox(id: inbox.id)
            statusMessage = "\(inbox.displayLabel) removed."
            reloadInboxes()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func reloadInboxes() {
        secureInboxes = SecureIngestionVaultStore.allSecureInboxes()
    }

    private func resetDraftFields() {
        draftEmail = ""
        draftIMAPHost = ""
        draftAppPassword = ""
    }

    private func connectOAuth(_ provider: SecureIngestionVaultStore.Provider) {
        do {
            try SecureIngestionVaultStore.saveOAuthPlaceholderToken(
                for: provider,
                token: "oauth-pending-\(provider.rawValue)-\(UUID().uuidString.prefix(8))"
            )
            statusMessage = "\(provider.title) linked. Full OAuth redirect flow activates in the next build."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func disconnect(_ provider: SecureIngestionVaultStore.Provider) {
        do {
            try SecureIngestionVaultStore.disconnect(provider)
            statusMessage = "\(provider.title) disconnected."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
