import SwiftUI

/// Profile → Connected Accounts — OAuth2 / IMAP links for supplier receipt & production doc ingestion.
struct ConnectedAccountsSettingsView: View {
    @Environment(\.brandAccent) private var brandAccent
    @State private var imapHost = SecureIngestionVaultStore.imapHost
    @State private var imapUsername = SecureIngestionVaultStore.imapUsername
    @State private var imapAppPassword = ""
    @State private var statusMessage: String?
    @State private var showIMAPForm = false

    var body: some View {
        List {
            Section {
                Text(
                    "Link only the inboxes that receive vendor receipts, call sheets, and fitting packets. "
                        + "RatioVita scans on-device and ignores unrelated personal mail."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Section("OAuth2 providers") {
                providerRow(.gmailOAuth, subtitle: "Scan Gmail for supplier threads & attachments.")
                providerRow(.outlookOAuth, subtitle: "Microsoft 365 / Outlook business inboxes.")
            }

            Section {
                DisclosureGroup(isExpanded: $showIMAPForm) {
                    TextField("IMAP host", text: $imapHost)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif
                    TextField("Username", text: $imapUsername)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif
                    SecureField("App-specific password", text: $imapAppPassword)
                    Button("Save IMAP credentials") {
                        saveIMAP()
                    }
                    .disabled(imapHost.isEmpty || imapUsername.isEmpty || imapAppPassword.isEmpty)
                } label: {
                    HStack {
                        Label("Custom IMAP supplier", systemImage: SecureIngestionVaultStore.Provider.customIMAP.systemImage)
                        Spacer()
                        connectionBadge(for: .customIMAP)
                    }
                }
            } header: {
                Text("Custom IMAP")
            } footer: {
                Text("Use an app-specific password — never your primary email password.")
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

    @ViewBuilder
    private func connectionBadge(for provider: SecureIngestionVaultStore.Provider) -> some View {
        if SecureIngestionVaultStore.isConnected(provider) {
            StatusBadge.success("Linked")
        } else {
            StatusBadge.info("Not linked")
        }
    }

    private func connectOAuth(_ provider: SecureIngestionVaultStore.Provider) {
        // OAuth2 web flow ships in Build 78 — store a scoped placeholder until ASWebAuthenticationSession wiring lands.
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

    private func saveIMAP() {
        do {
            try SecureIngestionVaultStore.saveIMAPCredentials(
                host: imapHost,
                username: imapUsername,
                appPassword: imapAppPassword
            )
            imapAppPassword = ""
            statusMessage = "IMAP credentials saved to the secure vault."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
