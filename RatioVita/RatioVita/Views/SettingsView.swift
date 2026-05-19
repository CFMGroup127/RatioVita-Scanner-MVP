import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Query(sort: \ProductionContact.name) private var productionContacts: [ProductionContact]
    @Query(filter: #Predicate<BusinessEntity> { $0.isOwnedCorporation }, sort: \BusinessEntity.legalName)
    private var ownedCorporations: [BusinessEntity]
    @Query(sort: \ProductionProject.title) private var productionProjects: [ProductionProject]
    @AppStorage("com.ratiovita.internalOwnerLegalName") private var internalOwnerLegalName = ""
    @AppStorage("com.ratiovita.payrollDisplayName") private var payrollDisplayName = ""
    @Query(sort: \BankTransaction.postedDate, order: .reverse) private var bankTransactions: [BankTransaction]
    @ObservedObject private var geminiConnectionStatus = GeminiConnectionStatusStore.shared
    @AppStorage("ocrEnabled") private var ocrEnabled = true
    @AppStorage("compressionEnabled") private var compressionEnabled = false
    @AppStorage("compressionQuality") private var compressionQuality = 0.8
    @AppStorage("mirrorScannedReceiptsToPhotoLibrary") private var mirrorScannedReceiptsToPhotoLibrary = true
    @AppStorage("geminiExtractionEnabled") private var geminiExtractionEnabled = true
    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("geminiModelId") private var geminiModelId = GeminiAPIKeyResolver.defaultGeminiModelId
    @AppStorage("financeAgentsPeriodicEnabled") private var financeAgentsPeriodicEnabled = true
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var showBankPolarityInvertConfirm = false
    @State private var showReceiptPolarityRefreshAlert = false
    @State private var receiptPolarityRefreshSummary = ""

    @State private var showMasterBackupSheet = false
    @State private var masterBackupShareItem: MasterBackupSharePayload?
    @State private var showMasterRestoreSheet = false
    @State private var showFactoryResetConfirm = false
    @State private var ownerVariancesField = ""
    #if DEBUG
    @State private var showFactoryResetFinalConfirm = false
    #endif

    @ViewBuilder
    private var geminiConnectionStatusRow: some View {
        switch geminiConnectionStatus.state {
            case .unknown:
                StatusBadge.info("Not checked")
            case .idleNoKey:
                StatusBadge.warning("No API key")
            case .disabled:
                StatusBadge.info("Parsing off")
            case .checking:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                    Text("Checking…")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                }
            case .connected:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.ratioVitaSuccess)
                    StatusBadge.success("Connected")
                }
            case .failed:
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.ratioVitaError)
                    Text("Invalid key or network error")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                        .lineLimit(2)
                }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Scanner Settings Section
                Section {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Enable OCR")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Extract text from receipts automatically")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $ocrEnabled)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Enable Compression")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Reduce file size for storage")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $compressionEnabled)
                                .labelsHidden()
                        }
                    
                        if compressionEnabled {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack {
                                    Text("Compression Quality")
                                        .font(DesignSystem.Typography.bodyEmphasized)
                                    
                                    Spacer()
                                    
                                    StatusBadge.info("\(Int(compressionQuality * 100))%")
                                }
                                
                                Slider(value: $compressionQuality, in: 0.1...1.0, step: 0.1)
                                    .tint(brandAccent)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "Scanner Settings",
                        subtitle: "Configure receipt scanning behavior"
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Save scans to Photos")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text(
                                    "After you file camera captures from the Review tab, RatioVita can copy those images into a Photos album (named by vendor and month). Imports are not duplicated into Photos."
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: $mirrorScannedReceiptsToPhotoLibrary)
                                .labelsHidden()
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "Photo library",
                        subtitle: "Optional mirror into Apple Photos"
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Gemini receipt parsing")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text(
                                    "Sends combined OCR text to Google Gemini and merges JSON fields with on-device heuristics. You can also set GEMINI_API_KEY in the run scheme environment (overrides the field below)."
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: $geminiExtractionEnabled)
                                .labelsHidden()
                        }

                        SecureField("Gemini API key", text: $geminiAPIKey)
                            .textContentType(.password)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        #endif

                        TextField("Model id", text: $geminiModelId)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        #endif
                        Text(
                            "Google’s REST id for `generateContent` (no `models/` prefix). Default is \(GeminiAPIKeyResolver.defaultGeminiModelId); change this if Google deprecates a version."
                        )
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                            geminiConnectionStatusRow
                            Spacer(minLength: 8)
                            Button("Verify") {
                                Task { await geminiConnectionStatus.refreshFromCurrentSettings() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(geminiConnectionStatus.state == .checking)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .task {
                        await geminiConnectionStatus.refreshFromCurrentSettings()
                    }
                } header: {
                    SectionHeader(
                        title: "Structured extraction",
                        subtitle: "Optional Gemini JSON over Vision OCR"
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Finance agents (foreground)")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text(
                                    "While RatioVita is open, runs a lightweight pass to suggest tax categories / GL codes on unverified receipts and to match imported bank rows to receipts (amount ± $0.02, date within ±3 days). True 24/7 background work requires separate server or BGTask setup."
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: $financeAgentsPeriodicEnabled)
                                .labelsHidden()
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "VitaLogic agents",
                        subtitle: "Tax + bank reconciliation (MVP heuristics)"
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right.circle")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Fix transaction polarity")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text(
                                    "Multiply every imported `BankTransaction.amount` by −1. Use once if debits and deposits were stored backwards. Canonical rule: credits (+) money in, debits (−) money out; income memos (e.g. payment received) and expense memos (e.g. POS purchase) are corrected at import when keywords match."
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                            Spacer()
                        }
                        Button("Invert all bank amounts (\(bankTransactions.count) rows)") {
                            showBankPolarityInvertConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(bankTransactions.isEmpty)
                    }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "Bank data repair",
                        subtitle: "One-time polarity correction for existing imports"
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "plus.forwardslash.minus")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Refresh receipt polarity")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text(
                                    "Re-applies signed totals for every unverified library receipt (income and outgoing invoices positive, purchases and fuel negative). Verified receipts are skipped so finalized books stay untouched."
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                            Spacer()
                        }
                        Button("Refresh polarity (unverified only)") {
                            receiptPolarityRefreshSummary = refreshUnverifiedReceiptPolaritySummary()
                            showReceiptPolarityRefreshAlert = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "Receipt accounting repair",
                        subtitle: "Align historical rows with current sign rules"
                    )
                }

                Section {
                    TextField("Your legal name (payee on personal cheques)", text: $internalOwnerLegalName)
                        .textContentType(.name)
                        .onChange(of: internalOwnerLegalName) { _, newValue in
                            InternalIdentityRegistry.ownerLegalName = newValue
                            InternalIdentityRegistry.syncOwnedEntities(context: modelContext)
                        }
                    TextField("Payroll display name (EP / Cast & Crew NAME line)", text: $payrollDisplayName)
                        .textContentType(.name)
                        .onChange(of: payrollDisplayName) { _, newValue in
                            InternalIdentityRegistry.payrollDisplayName = newValue
                        }
                    Text(
                        "Use one standard name on timecards (e.g. Collin Morris). OCR alias variants below are for matching receipts only—not printed on PDFs."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    TextField(
                        "Name variants (comma-separated)",
                        text: $ownerVariancesField,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .onChange(of: ownerVariancesField) { _, newValue in
                        let parts = newValue
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        InternalIdentityRegistry.ownerNameVariances = parts
                        InternalIdentityRegistry.syncOwnedEntities(context: modelContext)
                    }
                    Button("Re-scan contacts for owned corporations") {
                        InternalIdentityRegistry.syncOwnedEntities(context: modelContext)
                    }
                    .buttonStyle(.bordered)
                    Picker(
                        "EP timecard name line",
                        selection: Binding(
                            get: { PayrollComplianceProfileStore.namingPreference },
                            set: { PayrollComplianceProfileStore.namingPreference = $0 }
                        )
                    ) {
                        ForEach(PayrollComplianceProfile.NamingMaskTier.allCases) { tier in
                            Text(tier.label).tag(tier)
                        }
                    }
                    Text(
                        "Owned corporations are synced from **My corporations**. OCR typos like “Bespoke Graft… Tnc.” merge into your corp profiles and leave the vendor list."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                } header: {
                    SectionHeader(
                        title: "Internal identity registry",
                        subtitle: "Keep you and your corps out of the vendor contact list"
                    )
                }

                Section {
                    let externalContacts = productionContacts.filter {
                        ProductionContactsFilter.isExternalContact($0, ownedCorporations: ownedCorporations)
                    }
                    if externalContacts.isEmpty {
                        Text(
                            "Import Zoho Books contacts (CSV) or Zoho invoice PDFs from the vault inbox; contacts appear here with linked receipts."
                        )
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                        .padding(DesignSystem.Spacing.md)
                    } else {
                        ForEach(externalContacts) { person in
                            NavigationLink {
                                ProductionContactDetailView(contact: person)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(person.name)
                                        .font(DesignSystem.Typography.bodyEmphasized)
                                    if let company = person.companyName, !company.isEmpty {
                                        Text(company)
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(Color.ratioVitaTextSecondary)
                                    }
                                    Text(
                                        "\(person.linkedReceipts.filter { $0.trashedAt == nil }.count) linked receipts"
                                    )
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                                }
                            }
                        }
                    }
                } header: {
                    SectionHeader(
                        title: "Contacts",
                        subtitle: "CRM profiles from Zoho and manual graph"
                    )
                }

                Section {
                    if productionProjects.isEmpty {
                        Text(
                            "Create projects from Receipts → Review on Mac using “Show / project” or a work session’s production field."
                        )
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                        .padding(DesignSystem.Spacing.md)
                    } else {
                        ForEach(productionProjects) { project in
                            NavigationLink {
                                ProductionProjectRenameView(project: project)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.title)
                                        .font(DesignSystem.Typography.bodyEmphasized)
                                    Text("\(project.receipts.count) receipts · \(project.workSessions.count) work days")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(Color.ratioVitaTextSecondary)
                                }
                            }
                        }
                    }
                } header: {
                    SectionHeader(
                        title: "Production projects",
                        subtitle: "Rename a show; linked receipts update together"
                    )
                }

                // Theme Settings Section
                Section {
                    NavigationLink {
                        ThemePreview()
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Appearance")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Customize colors and themes")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(themeManager.customTheme.primaryColor)
                                    .frame(width: 14, height: 14)
                                    .shadow(color: themeManager.customTheme.primaryColor.opacity(0.45), radius: 2, y: 1)
                                Circle()
                                    .fill(themeManager.customTheme.secondaryColor)
                                    .frame(width: 14, height: 14)
                                    .shadow(
                                        color: themeManager.customTheme.secondaryColor.opacity(0.35),
                                        radius: 2,
                                        y: 1
                                    )
                                Circle()
                                    .fill(themeManager.customTheme.accentColor)
                                    .frame(width: 14, height: 14)
                                    .shadow(color: themeManager.customTheme.accentColor.opacity(0.35), radius: 2, y: 1)
                            }
                        }
                    }
                } header: {
                    SectionHeader(
                        title: "Appearance",
                        subtitle: "Customize the look and feel"
                    )
                }

                Section {
                    NavigationLink {
                        SovereignAuditLogListView()
                    } label: {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Sovereign audit")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Folder changes, filing rules, and receipt re-files.")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        showMasterBackupSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.doc")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Create master archive")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                                Text(
                                    "Packages the SwiftData store and receipt JPEGs into a passphrase-sealed .rvsovereign file for external drives or iCloud Drive."
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                                .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showMasterRestoreSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Restore from archive")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                                Text(
                                    "Decrypt a .rvsovereign backup and merge receipts plus merchant rules into this library. Existing receipts with the same ID are skipped."
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                                .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                } header: {
                    SectionHeader(
                        title: "Sovereign backup",
                        subtitle: "Off-device insurance for your library"
                    )
                }

                #if DEBUG
                Section {
                    Toggle(
                        "Allow destructive store reset on schema failure",
                        isOn: Binding(
                            get: {
                                UserDefaults.standard.bool(forKey: "com.ratiovita.allowDestructiveStoreReset")
                            },
                            set: { UserDefaults.standard.set($0, forKey: "com.ratiovita.allowDestructiveStoreReset") }
                        )
                    )
                    Button("Factory reset library…", role: .destructive) {
                        showFactoryResetConfirm = true
                    }
                } header: {
                    SectionHeader(
                        title: "Developer",
                        subtitle: "Destructive — for clean migration prep"
                    )
                } footer: {
                    Text(
                        "When off, a failed schema migration will not silently erase your library; the app stops with a clear error and your data stays on disk."
                    )
                }
                #endif
                
                // About Section
                Section {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Version")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("1.0.0")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(brandAccent)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Build")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("RatioVita v2")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "About",
                        subtitle: "App information and version"
                    )
                }
            }
            #if os(macOS)
            .listStyle(.inset(alternatesRowBackgrounds: true))
            #else
            .listStyle(.insetGrouped)
            #endif
            .scrollContentBackground(.hidden)
            .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .ratioVitaTheme()
            .onAppear {
                GeminiAPIKeyKeychain.migrateFromUserDefaultsIfNeeded()
                if internalOwnerLegalName.isEmpty {
                    internalOwnerLegalName = InternalIdentityRegistry.ownerLegalName
                }
                if payrollDisplayName.isEmpty {
                    payrollDisplayName = InternalIdentityRegistry.payrollDisplayName
                }
                if ownerVariancesField.isEmpty {
                    ownerVariancesField = InternalIdentityRegistry.ownerNameVariances.joined(separator: ", ")
                }
                InternalIdentityRegistry.syncOwnedEntities(context: modelContext)
            }
            .onChange(of: geminiAPIKey) { _, newValue in
                try? GeminiAPIKeyKeychain.saveTrimmed(newValue)
            }
            .alert("Invert all bank amounts?", isPresented: $showBankPolarityInvertConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Invert \(bankTransactions.count) rows", role: .destructive) {
                    invertAllBankTransactionAmounts()
                }
            } message: {
                Text("This cannot be undone automatically. Run again if you invert twice by mistake.")
            }
            .alert("Receipt polarity", isPresented: $showReceiptPolarityRefreshAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(receiptPolarityRefreshSummary)
            }
            .sheet(isPresented: $showMasterBackupSheet) {
                MasterBackupSheet { url in
                    masterBackupShareItem = MasterBackupSharePayload(url: url)
                }
            }
            .sheet(isPresented: $showMasterRestoreSheet) {
                MasterRestoreSheet()
            }
            .sheet(item: $masterBackupShareItem) { payload in
                ShareExportSheet(url: payload.url)
            }
            #if DEBUG
            .confirmationDialog(
                    "Factory reset will permanently delete all library data on this device (receipts, bank rows, productions, audit log, filing rules, Arctic folders, and sample items). This cannot be undone.",
                    isPresented: $showFactoryResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Cancel", role: .cancel) {}
                    Button("Continue…", role: .destructive) {
                        showFactoryResetFinalConfirm = true
                    }
                }
                .confirmationDialog(
                    "Last chance: erase the entire SwiftData library?",
                    isPresented: $showFactoryResetFinalConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Cancel", role: .cancel) {}
                    Button("Erase everything", role: .destructive) {
                        do {
                            try LibraryDeveloperReset.purgeEntirePersistentLibrary(modelContext: modelContext)
                            UserMessageCenter.shared.present(
                                title: "Library reset",
                                message: "All persistent library data was removed. Cabinet roots were re-seeded."
                            )
                        } catch {
                            UserMessageCenter.shared.present(
                                title: "Reset failed",
                                message: error.localizedDescription
                            )
                        }
                    }
                }
            #endif
        }
    }

    private func invertAllBankTransactionAmounts() {
        for tx in bankTransactions {
            tx.amount = -tx.amount
        }
        try? modelContext.save()
    }

    private func refreshUnverifiedReceiptPolaritySummary() -> String {
        let desc = FetchDescriptor<Receipt>(
            predicate: #Predicate<Receipt> { $0.trashedAt == nil && $0.isVerified == false }
        )
        guard let receipts = try? modelContext.fetch(desc) else {
            return "Could not read receipts from the library."
        }
        for r in receipts {
            let dt = DocumentTypeOption.fromStored(r.documentType)
            r.total = AccountingAmountPolarity.validateSign(documentType: dt, amount: r.total)
            r.subtotalAmount = AccountingAmountPolarity.canonicalOptionalAmount(
                documentType: dt,
                amount: r.subtotalAmount
            )
            r.taxAmount = AccountingAmountPolarity.canonicalOptionalAmount(documentType: dt, amount: r.taxAmount)
            ReceiptCabinetRouting.applyImplicitCabinetForDocumentType(receipt: r)
        }
        try? modelContext.save()
        return "Updated \(receipts.count) unverified receipt(s). Verified items were not changed."
    }
}

private struct MasterBackupSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct MasterBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onComplete: (URL) -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Passphrase", text: $password)
                    SecureField("Confirm passphrase", text: $confirmPassword)
                } footer: {
                    Text(
                        "The archive is a ZIP of your SwiftData store plus every receipt JPEG, wrapped in AES-GCM and saved as .rvsovereign. Keep the passphrase with the file — it is not stored in the app."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.ratioVitaError)
                            .font(DesignSystem.Typography.caption)
                    }
                }
            }
            .navigationTitle("Master backup")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .disabled(isWorking)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isWorking {
                            ProgressView()
                        } else {
                            Button("Create") {
                                Task { await createBackup() }
                            }
                            .disabled(!canSubmit)
                        }
                    }
                }
        }
    }

    private var canSubmit: Bool {
        !password.isEmpty && password == confirmPassword
    }

    @MainActor
    private func createBackup() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let url = try SovereignMasterBackupService.makeEncryptedBackupFile(
                modelContext: modelContext,
                password: password
            )
            onComplete(url)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MasterRestoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var pickedURL: URL?
    @State private var showImporter = false
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var sovereignTypes: [UTType] {
        if let t = UTType(filenameExtension: "rvsovereign") {
            return [t, .data]
        }
        return [.data]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let pickedURL {
                        Text(pickedURL.lastPathComponent)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No file selected")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Choose .rvsovereign file…") {
                        showImporter = true
                    }
                }

                Section {
                    SecureField("Passphrase", text: $password)
                    SecureField("Confirm passphrase", text: $confirmPassword)
                } footer: {
                    Text(
                        "This decrypts the backup you created with **Create master archive** and merges its receipts into the open library."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.ratioVitaError)
                            .font(DesignSystem.Typography.caption)
                    }
                }
            }
            .navigationTitle("Restore archive")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: sovereignTypes,
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                        case let .success(urls):
                            pickedURL = urls.first
                        case let .failure(err):
                            errorMessage = err.localizedDescription
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .disabled(isWorking)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isWorking {
                            ProgressView()
                        } else {
                            Button("Merge") {
                                Task { await runRestore() }
                            }
                            .disabled(!canSubmit)
                        }
                    }
                }
        }
    }

    private var canSubmit: Bool {
        pickedURL != nil && !password.isEmpty && password == confirmPassword
    }

    @MainActor
    private func runRestore() async {
        errorMessage = nil
        guard let url = pickedURL else { return }
        isWorking = true
        defer { isWorking = false }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard url.pathExtension.lowercased() == "rvsovereign" else {
            errorMessage = "Choose a file whose extension is .rvsovereign."
            return
        }
        do {
            let summary = try SovereignMasterRestoreService.mergeArchive(
                fileURL: url,
                password: password,
                into: modelContext
            )
            UserMessageCenter.shared.present(
                title: "Restore complete",
                message:
                "Imported \(summary.receiptsImported) receipt(s), skipped \(summary.receiptsSkippedExisting) duplicate(s), merged \(summary.merchantRulesImported) merchant rule(s)."
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
