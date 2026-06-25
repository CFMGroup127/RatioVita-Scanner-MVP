import SwiftData
import SwiftUI

/// **Sovereign Launchpad** — module grid + Forensic Pulse for iPhone / iPad command deck.
struct RatioVitaHomeView: View {
    @Environment(\.brandAccent) private var brandAccent
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var sovereignContext = SovereignContextManager.shared
    @ObservedObject private var reviewQueue = ReceiptReviewQueueStore.shared

    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID: String = ""
    @AppStorage("forensicActiveCallSheetFirestoreID") private var forensicActiveCallSheetFirestoreID: String = ""
    @AppStorage("laborSentinelAgreementCode") private var laborSentinelAgreementCode: String = ""

    @Query(sort: \ProductionProject.title) private var productionProjects: [ProductionProject]
    @Query(sort: \LaborAgreement.title) private var laborAgreements: [LaborAgreement]
    @Query(sort: \CrewTimecardDay.workDate, order: .reverse) private var crewDays: [CrewTimecardDay]
    @Query(sort: \BankTransaction.postedDate, order: .reverse) private var bankTransactions: [BankTransaction]
    @Query private var equipmentAssets: [EquipmentAsset]

    @State private var showQuickAddProduction = false
    @State private var showCorporateRegistry = false
    @State private var showProductionWorkspace = false
    @State private var showSovereignAudit = false
    @State private var showInventory = false
    @State private var showInsurance = false
    @State private var showCallSheetScan = false
    @State private var showZeroLinkCleanup = false
    @State private var showEmergencyShuttle = false
    @State private var showProductionOperations = false
    @State private var showContinuityStyleVault = false
    @State private var showInboxTriage = false

    @Query(
        filter: #Predicate<Receipt> { $0.trashedAt == nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var activeReceipts: [Receipt]

    @AppStorage(SovereignFeatureFlags.transportRunnerRoutingKey) private var transportRunnerRouting = false
    @AppStorage(SovereignFeatureFlags.craftLogisticsMeshKey) private var craftLogisticsMesh = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var activeProject: ProductionProject? {
        guard let uuid = UUID(uuidString: forensicActiveProductionID) else { return nil }
        return productionProjects.first { $0.id == uuid }
    }

    private var agreement: LaborAgreement? {
        let trimmed = laborSentinelAgreementCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let match = laborAgreements.first(where: { $0.code == trimmed }) {
            return match
        }
        let def = LaborSentinelBootstrap.defaultAgreementCode
        return laborAgreements.first { $0.code == def } ?? laborAgreements.first
    }

    private var overdueShortFormatInvoices: Int {
        guard let p = activeProject else { return 0 }
        return ForensicPulsePaymentSentinel.fifteenDayOverdueInvoiceCount(
            projectID: p.id,
            receipts: p.receipts
        )
    }

    private var longFormatPayDepositAmber: Bool {
        guard let p = activeProject, p.effectivePaymentTerms.isLongFormatCanada else { return false }
        return ForensicPulsePaymentSentinel.longFormatThursdayDepositLooksMissing(
            bankTransactions: bankTransactions
        )
    }

    private var zeroLinkProductions: [ProductionProject] {
        productionProjects.filter(\.hasZeroLinkedItems)
    }

    private var forensicPulseAttention: Bool {
        overdueShortFormatInvoices > 0 || longFormatPayDepositAmber
    }

    private var activeProjectIsDormant: Bool {
        activeProject?.isDormantUnused == true
    }

    private var callSheetFirestoreIdOrNil: String? {
        let trimmed = forensicActiveCallSheetFirestoreID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                SovereignContextSwitcherBar()
                forensicPulseCard
                if !forensicActiveProductionID.isEmpty {
                    CrewTransitGuardianBanner(
                        productionId: forensicActiveProductionID,
                        activeCallSheetId: callSheetFirestoreIdOrNil
                    )
                }
                if transportRunnerRouting || craftLogisticsMesh {
                    productionLogisticsCard
                }
                SetOSAppShellView(
                    department: SetOSOnboardingCoordinator.shared.activeIndustryScope,
                    tier: nil
                ) { intent in
                    NativeLauncherShortcutManager.launch(intent)
                }
                moduleGrid
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
        .navigationTitle("RatioVita")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showQuickAddProduction = true
                    } label: {
                        Label("Quick add production", systemImage: "plus.circle.fill")
                    }
                    .accessibilityHint("Create a new show from the launchpad.")
                }
            }
            .sheet(isPresented: $showQuickAddProduction) {
                ProductionProjectAddSheet(
                    onDismiss: { showQuickAddProduction = false },
                    onCreated: { p in
                        forensicActiveProductionID = p.id.uuidString
                    },
                    triggerSuccessHaptic: true
                )
            }
            .sheet(isPresented: $showCorporateRegistry) {
                NavigationStack {
                    CorporateRegistryView()
                }
            }
            .sheet(isPresented: $showProductionWorkspace) {
                NavigationStack {
                    ProductionWorkspaceView()
                }
            }
            .sheet(isPresented: $showSovereignAudit) {
                NavigationStack {
                    SovereignAuditLogListView()
                }
            }
            .sheet(isPresented: $showInventory) {
                InventoryModuleView()
            }
            .sheet(isPresented: $showInsurance) {
                NavigationStack {
                    InsuranceWarrantiesPlaceholderView()
                }
            }
            .sheet(isPresented: $showCallSheetScan) {
                CallSheetScanSheet()
            }
            .sheet(isPresented: $showEmergencyShuttle) {
                EmergencyShuttleRequestSheet()
            }
            .sheet(isPresented: $showProductionOperations) {
                NavigationStack {
                    ProductionOperationsHubView()
                }
            }
            .sheet(isPresented: $showZeroLinkCleanup) {
                ZeroLinkProductionCleanupSheet(
                    activeProductionIDString: $forensicActiveProductionID
                )
                #if os(macOS)
                .frame(minWidth: 520, idealWidth: 560, minHeight: 420, idealHeight: 560)
                #endif
            }
            .sheet(isPresented: $showContinuityStyleVault) {
                NavigationStack {
                    ContinuityStyleVaultView()
                }
            }
            .sheet(isPresented: $showInboxTriage) {
                NavigationStack {
                    InboxTriageFeedView()
                }
            }
            .onChange(of: libraryNavigationCoordinator.homeNavigationSignal) { _, _ in
                handleHomeNavigation()
            }
            .onAppear {
                handleHomeNavigation()
            }
    }

    private var scopedPendingReviewCount: Int {
        reviewQueue.totalCount
    }

    private var scopedTriageCount: Int {
        activeReceipts.filter {
            CrossEntityTriageEngine.needsTriage($0)
                && SovereignScopeFilter.triageReceiptIsVisible($0, context: sovereignContext)
        }.count
    }

    private var forensicPulseCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Today's Forensic Pulse")
                .font(DesignSystem.Typography.title3.weight(.semibold))
            if let p = activeProject {
                LabeledContent("Active production") {
                    Text(p.title)
                        .multilineTextAlignment(.trailing)
                }
                if let occ = p.crewOccupationTitle ?? p.effectiveOccupationFromRateSheet(for: Date()) {
                    LabeledContent("Position") {
                        Text(occ)
                    }
                }
                LabeledContent("Contract") {
                    Text(p.productionContractKind.shortTitle)
                }
                if let pulse = sentinelPulse(for: p) {
                    LabeledContent("Sentinel today") {
                        Text(pulse)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if overdueShortFormatInvoices > 0 {
                    LabeledContent("15-day AR vigilance") {
                        Text("\(overdueShortFormatInvoices) overdue (no bank link)")
                            .foregroundStyle(Color.orange)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if longFormatPayDepositAmber {
                    LabeledContent("Long-format pay watch") {
                        Text("No Thursday payroll credit detected yet — confirm the bank feed.")
                            .foregroundStyle(Color.orange)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if p.isDormantUnused {
                    LabeledContent("Workspace hygiene") {
                        Text("Dormant — no linked receipts or crew days in 30+ days.")
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } else {
                Text("Select a show in Labor Sentinel to pin your active production here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Vault") {
                Text(
                    scopedPendingReviewCount == 0
                        ? "Review queue clear"
                        : "\(scopedPendingReviewCount) pending review"
                )
                .foregroundStyle(scopedPendingReviewCount == 0 ? Color.ratioVitaSuccess : Color.orange)
            }
            LabeledContent("Ledger scope") {
                Text(sovereignContext.isolationScopeLabel)
                    .font(.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .multilineTextAlignment(.trailing)
            }
            Button {
                showCallSheetScan = true
            } label: {
                Label("Scan call sheet (crew call + set)", systemImage: "doc.text.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            .disabled(activeProject == nil)
            .accessibilityHint(
                "OCR page one of the daily call sheet, then open the matching work day in Labor Sentinel to apply crew call and location."
            )
            if !zeroLinkProductions.isEmpty {
                Button {
                    showZeroLinkCleanup = true
                } label: {
                    Label("Purge zero-link productions (\(zeroLinkProductions.count))", systemImage: "trash.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .stroke(
                    forensicPulseAttention
                        ? Color.orange.opacity(0.9)
                        : (activeProjectIsDormant ? Color.secondary.opacity(0.55) : brandAccent.opacity(0.35)),
                    lineWidth: forensicPulseAttention ? 2 : (activeProjectIsDormant ? 2 : 1)
                )
        )
    }

    private var productionLogisticsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Production logistics", systemImage: "car.2.fill")
                .font(DesignSystem.Typography.bodyEmphasized)
            Text("Request a wrap shuttle when walkies are out of range, or open the transport board.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if transportRunnerRouting {
                    Button {
                        showEmergencyShuttle = true
                    } label: {
                        Label("Request shuttle", systemImage: "location.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button {
                    showProductionOperations = true
                } label: {
                    Label("Operations hub", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 12) {
                NavigationLink {
                    ApprovalsInboxView()
                } label: {
                    Label("Approvals inbox", systemImage: "checkmark.seal")
                }
                .buttonStyle(.bordered)
                #if os(iOS)
                Button {
                    LiveFeedbackManager.shared.presentFeedback(context: "Home launchpad")
                } label: {
                    Label("Feedback", systemImage: "hand.raised")
                }
                .buttonStyle(.bordered)
                #endif
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
    }

    private var moduleGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(HomeModuleDestination.allCases) { module in
                Button {
                    openModule(module)
                } label: {
                    HomeModuleTile(
                        module: module,
                        badgeCount: badgeCount(for: module)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func openModule(_ module: HomeModuleDestination) {
        switch module {
            case .productions:
                #if os(macOS)
                libraryNavigationCoordinator.navigateFromHome(.productions)
                #else
                if horizontalSizeClass == .regular {
                    libraryNavigationCoordinator.navigateFromHome(.productions)
                } else {
                    showProductionWorkspace = true
                }
                #endif
            case .corporateRegistry:
                showCorporateRegistry = true
            case .inventory:
                showInventory = true
            case .insurance:
                showInsurance = true
            case .sovereignAudit:
                showSovereignAudit = true
            case .contacts, .finances, .arcticVault, .laborSentinel:
                libraryNavigationCoordinator.navigateFromHome(module)
            case .continuityStyleVault:
                showContinuityStyleVault = true
            case .inboxTriage:
                #if os(macOS)
                libraryNavigationCoordinator.navigateFromHome(.inboxTriage)
                #else
                if horizontalSizeClass == .regular {
                    libraryNavigationCoordinator.navigateFromHome(.inboxTriage)
                } else {
                    showInboxTriage = true
                }
                #endif
        }
    }

    private func badgeCount(for module: HomeModuleDestination) -> Int? {
        switch module {
            case .inboxTriage:
                return scopedTriageCount > 0 ? scopedTriageCount : nil
            case .insurance:
                let n = equipmentAssets.filter(\.isWarrantyExpiringSoon).count
                return n > 0 ? n : nil
            default:
                return nil
        }
    }

    private func handleHomeNavigation() {
        if libraryNavigationCoordinator.consumeCorporateRegistryPresentationIfNeeded() {
            showCorporateRegistry = true
            return
        }
        if libraryNavigationCoordinator.consumeProductionRegistryPresentationIfNeeded() {
            openProductionsModule()
            return
        }
        if libraryNavigationCoordinator.consumeSovereignAuditPresentationIfNeeded() {
            showSovereignAudit = true
            return
        }
        guard let dest = libraryNavigationCoordinator.consumeHomeDestination() else { return }
        switch dest {
            case .productions:
                openProductionsModule()
            case .inboxTriage:
                showInboxTriage = true
            default:
                break
        }
    }

    private func openProductionsModule() {
        #if os(macOS)
        libraryNavigationCoordinator.navigateFromHome(.productions)
        #else
        if horizontalSizeClass == .regular {
            libraryNavigationCoordinator.navigateFromHome(.productions)
        } else {
            showProductionWorkspace = true
        }
        #endif
    }

    private func sentinelPulse(for project: ProductionProject) -> String? {
        guard let agr = agreement else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayDays = crewDays.filter {
            $0.productionProject?.id == project.id && cal.startOfDay(for: $0.workDate) == today
        }
        guard !todayDays.isEmpty else { return "No crew day logged for today" }
        let projectDays = crewDays.filter { $0.productionProject?.id == project.id }
        let chain = SentinelPayrollEngine.estimatesWithTurnaround(projectDays: projectDays, agreement: agr)
        var hours = 0.0
        var mealUnits = 0
        for d in todayDays {
            let est = chain[d.id] ?? SentinelPayrollEngine.estimate(day: d, agreement: agr)
            hours += est.straightHours + est.overtime8To12Hours + est.overtimeOver12Hours + est.travelHours
            mealUnits += est.mealPenaltyHalfHours
        }
        var parts = [String(format: "%.1f h on clock", hours)]
        if mealUnits > 0 {
            parts.append("\(mealUnits)× meal ½h")
        }
        return parts.joined(separator: " · ")
    }
}

private struct HomeModuleTile: View {
    let module: HomeModuleDestination
    var badgeCount: Int?
    @Environment(\.brandAccent) private var brandAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: module.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(brandAccent)
                if let badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 10, y: -8)
                }
            }
            Text(module.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ratioVitaAdaptiveText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(module.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if module == .finances {
                HStack(spacing: 8) {
                    RatioVitaLabeledHint(title: "AR", term: .accountsReceivable)
                    RatioVitaLabeledHint(title: "AP", term: .accountsPayable)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct ZeroLinkProductionCleanupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProductionProject.title) private var allProjects: [ProductionProject]
    @Binding var activeProductionIDString: String

    @State private var locallyHiddenIDs: Set<UUID> = []
    @State private var showBatchConfirm = false
    @State private var lastPurgeSummary: String?

    private var purgeCandidates: [ProductionProject] {
        allProjects.filter { $0.hasZeroLinkedItems && !locallyHiddenIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if purgeCandidates.isEmpty {
                    ContentUnavailableView(
                        locallyHiddenIDs.isEmpty ? "No empty productions" : "Purge complete",
                        systemImage: "checkmark.circle",
                        description: Text(
                            locallyHiddenIDs.isEmpty
                                ? "Every show in your library has receipts, sessions, crew days, kit rows, or rate segments."
                                : "Removed \(locallyHiddenIDs.count) zero-link production(s) from your local library."
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(
                                "These \(purgeCandidates.count) title(s) have zero linked forensic rows (including auto rate segments). Purging removes them locally right away — no cloud round-trip required."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let lastPurgeSummary {
                                Text(lastPurgeSummary)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            LazyVStack(spacing: 0) {
                                ForEach(purgeCandidates) { project in
                                    purgeRow(project)
                                    if project.id != purgeCandidates.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.ratioVitaAdaptiveSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Zero-link productions")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Purge all (\(purgeCandidates.count))", role: .destructive) {
                            showBatchConfirm = true
                        }
                        .disabled(purgeCandidates.isEmpty)
                    }
                }
                .confirmationDialog(
                    "Purge all \(purgeCandidates.count) zero-link productions?",
                    isPresented: $showBatchConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Purge all locally", role: .destructive) {
                        purgeAllLocally()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(
                        "Deletes every listed show from the local SwiftData store immediately. Firestore quota limits will not block this cleanup."
                    )
                }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    @ViewBuilder
    private func purgeRow(_ project: ProductionProject) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title.isEmpty ? "Untitled production" : project.title)
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No linked receipts, sessions, crew days, kit rows, or rate segments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Purge", role: .destructive) {
                purgeOne(project)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func purgeOne(_ project: ProductionProject) {
        locallyHiddenIDs.insert(project.id)
        let removed = ZeroLinkProductionPurgeService.purgeOne(
            project,
            modelContext: modelContext,
            activeProductionIDString: &activeProductionIDString
        )
        if removed {
            lastPurgeSummary = "Removed “\(project.title)” locally."
        } else {
            locallyHiddenIDs.remove(project.id)
        }
    }

    private func purgeAllLocally() {
        let snapshot = purgeCandidates
        locallyHiddenIDs.formUnion(snapshot.map(\.id))
        let result = ZeroLinkProductionPurgeService.batchPurgeLocal(
            candidates: snapshot,
            modelContext: modelContext,
            activeProductionIDString: &activeProductionIDString
        )
        lastPurgeSummary = "Removed \(result.purgedCount) zero-link production(s) locally."
        if result.purgedCount == snapshot.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                dismiss()
            }
        }
    }
}

private struct InsuranceWarrantiesPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EquipmentAsset.displayName) private var assets: [EquipmentAsset]

    private var expiring: [EquipmentAsset] {
        assets.filter(\.isWarrantyExpiringSoon)
    }

    var body: some View {
        List {
            if !expiring.isEmpty {
                Section("Warranty expiry radar") {
                    ForEach(expiring) { asset in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(asset.displayName)
                                .font(.headline)
                            if let d = asset.warrantyExpiryDate {
                                Text("Expires \(d.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            Section {
                ContentUnavailableView(
                    "Policy scans",
                    systemImage: "shield.checkered",
                    description: Text(
                        "File insurance policies and warranties from Review. Equipment warranties from Inventory appear above."
                    )
                )
            }
        }
        .navigationTitle("Insurance")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
    }
}

#Preview {
    NavigationStack {
        RatioVitaHomeView()
    }
    .environment(LibraryNavigationCoordinator())
    .modelContainer(SampleData.previewContainer)
}
