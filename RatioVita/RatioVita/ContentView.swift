//
//  ContentView.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @ObservedObject private var userMessages = UserMessageCenter.shared
    @ObservedObject private var feedbackManager = LiveFeedbackManager.shared
    @ObservedObject private var sovereignContext = SovereignContextManager.shared
    @ObservedObject private var reviewQueue = ReceiptReviewQueueStore.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator

    @State private var phoneLibraryTabSelection: Int = 0
    @State private var showCorporateRegistryFromShell = false
    @State private var showProductionRegistryFromShell = false
    @State private var showSovereignAuditFromShell = false
    @State private var showContactsFromShell = false

    @Query(
        filter: #Predicate<BankTransaction> {
            $0.matchedReceipt == nil && $0.manuallyClearedForReconciliation == false
        },
        sort: \BankTransaction.postedDate,
        order: .reverse
    )
    private var unmatchedBankTransactions: [BankTransaction]

    @Query(
        filter: #Predicate<Receipt> { $0.trashedAt != nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var trashedReceipts: [Receipt]

    @Query(
        filter: #Predicate<Receipt> { $0.trashedAt == nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var activeReceiptsForScope: [Receipt]

    private var scopedPendingReviewCount: Int {
        reviewQueue.totalCount
    }

    private var scopedOpenReceiptsForBank: [Receipt] {
        SovereignScopeFilter.filterReceipts(
            activeReceiptsForScope.filter { !$0.isLedgerLinked },
            context: sovereignContext
        )
    }

    private var scopedUnmatchedBankCount: Int {
        unmatchedBankTransactions.filter {
            SovereignScopeFilter.bankTransactionIsVisible(
                $0,
                context: sovereignContext,
                openReceipts: scopedOpenReceiptsForBank
            )
        }.count
    }

    var body: some View {
        Group {
            #if os(macOS)
            SidebarSplitShell(
                pendingReviewCount: scopedPendingReviewCount,
                trashCount: trashedReceipts.count,
                unmatchedBankCount: scopedUnmatchedBankCount
            )
            #else
            if horizontalSizeClass == .regular {
                SidebarSplitShell(
                    pendingReviewCount: scopedPendingReviewCount,
                    trashCount: trashedReceipts.count,
                    unmatchedBankCount: scopedUnmatchedBankCount
                )
            } else {
                TabView(selection: $phoneLibraryTabSelection) {
                    NavigationStack {
                        RatioVitaHomeView()
                    }
                    .tabItem {
                        Label("Home", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(0)

                    ReceiptsView()
                        .tabItem {
                            Label("Receipts", systemImage: "doc.text.fill")
                        }
                        .tag(1)

                    NavigationStack {
                        ProductionTimelineView()
                    }
                    .tabItem {
                        Label("Timeline", systemImage: "calendar.day.timeline.left")
                    }
                    .tag(2)

                    ReceiptReviewView()
                        .tabItem {
                            Label("Review", systemImage: "tray.full")
                        }
                        .optionalTabBadge(reviewQueue.totalCount)
                        .tag(3)

                    ReconciliationReviewView()
                        .tabItem {
                            Label("Reconcile", systemImage: "arrow.triangle.merge")
                        }
                        .optionalTabBadge(unmatchedBankTransactions.count)
                        .tag(4)

                    BankImportView()
                        .tabItem {
                            Label("Bank import", systemImage: "building.columns.fill")
                        }
                        .tag(5)

                    ReceiptTrashView()
                        .tabItem {
                            Label("Trash", systemImage: "trash")
                        }
                        .optionalTabBadge(trashedReceipts.count)
                        .tag(6)

                    NavigationStack {
                        LaborSentinelHubView()
                    }
                    .tabItem {
                        Label("Labor", systemImage: "shield.lefthalf.filled")
                    }
                    .tag(7)

                    NavigationStack {
                        TimeSheetsHubView()
                    }
                    .tabItem {
                        Label("Time Sheets", systemImage: "calendar.day.timeline.left")
                    }
                    .tag(8)

                    NavigationStack {
                        MediaCoreHubView()
                    }
                    .tabItem {
                        Label("Media Core", systemImage: "waveform.circle")
                    }
                    .tag(9)
                }
                .onChange(of: libraryNavigationCoordinator.focusReceiptsLibrarySignal) { _, _ in
                    if libraryNavigationCoordinator.consumeFocusReceiptsLibraryIfNeeded() {
                        phoneLibraryTabSelection = 1
                    }
                }
                .onChange(of: libraryNavigationCoordinator.homeNavigationSignal) { _, _ in
                    applyHomeNavigationPhone()
                }
                .sheet(isPresented: $showCorporateRegistryFromShell) {
                    NavigationStack { CorporateRegistryView() }
                }
                .sheet(isPresented: $showProductionRegistryFromShell) {
                    NavigationStack { ProductionWorkspaceView() }
                }
                .sheet(isPresented: $showSovereignAuditFromShell) {
                    NavigationStack { SovereignAuditLogListView() }
                }
                .sheet(isPresented: $showContactsFromShell) {
                    NavigationStack { ProductionContactsLibraryView() }
                }
            }
            #endif
        }
        .swiftDataCloudKitRemoteMergeRefresh()
        .shakeToFeedback(context: "RatioVita")
        .sheet(isPresented: $feedbackManager.showOverlay) {
            CrewFeedbackOverlayView()
        }
        .alert(userMessages.title, isPresented: $userMessages.isPresented) {
            Button("OK", role: .cancel) {
                userMessages.dismiss()
            }
        } message: {
            Text(userMessages.message)
        }
    }

    #if !os(macOS)
    private func applyHomeNavigationPhone() {
        if libraryNavigationCoordinator.consumeCorporateRegistryPresentationIfNeeded() {
            showCorporateRegistryFromShell = true
            return
        }
        if libraryNavigationCoordinator.consumeProductionRegistryPresentationIfNeeded() {
            showProductionRegistryFromShell = true
            return
        }
        if libraryNavigationCoordinator.consumeSovereignAuditPresentationIfNeeded() {
            showSovereignAuditFromShell = true
            return
        }
        guard let dest = libraryNavigationCoordinator.consumeHomeDestination() else { return }
        switch dest {
            case .arcticVault:
                phoneLibraryTabSelection = 1
            case .laborSentinel:
                phoneLibraryTabSelection = 7
            case .productions:
                showProductionRegistryFromShell = true
            case .finances:
                phoneLibraryTabSelection = 4
            case .contacts:
                showContactsFromShell = true
            case .inboxTriage:
                phoneLibraryTabSelection = 0
            default:
                phoneLibraryTabSelection = 0
        }
    }
    #endif
}

// MARK: - Sidebar split shell (macOS + iPad)

private enum SidebarPane: Hashable {
    case operationsCommand
    case expertProgram
    case home
    case productions
    case receipts
    case timeline
    case laborSentinel
    case timeSheets
    case mediaCore
    case fieldOps
    case contacts
    case myCorporations
    case review
    case reconciliation
    case bankImport
    case trash
    case importScan
    case inboxTriage
    case inventory
    case settings
    case cabinet(DocumentCabinet)
    #if DEBUG
    case samples
    #endif

    var title: String {
        switch self {
            case .operationsCommand: return "Dispatch & approvals"
            case .expertProgram: return "Expert program"
            case .home: return "Home"
            case .productions: return "Productions"
            case .receipts: return "Receipts"
            case .timeline: return "Timeline"
            case .laborSentinel: return "Labor Sentinel"
            case .timeSheets: return "Time Sheets"
            case .mediaCore: return "Media Core"
            case .fieldOps: return "Field ops"
            case .contacts: return "Contacts"
            case .myCorporations: return "My corporations"
            case .review: return "Review"
            case .reconciliation: return "Reconciliation"
            case .bankImport: return "Bank import"
            case .trash: return "Trash"
            case .importScan: return "Import"
            case .inboxTriage: return "Inbox Triage"
            case .inventory: return "Inventory & kit"
            case .settings: return "Settings"
            case let .cabinet(c): return c.title
            #if DEBUG
            case .samples: return "Samples"
            #endif
        }
    }

    var systemImage: String {
        switch self {
            case .operationsCommand: return "checkmark.seal.fill"
            case .expertProgram: return "person.badge.shield.checkmark.fill"
            case .home: return "square.grid.2x2.fill"
            case .productions: return "film.stack"
            case .receipts: return "doc.text.fill"
            case .timeline: return "calendar.day.timeline.left"
            case .laborSentinel: return "shield.lefthalf.filled"
            case .timeSheets: return "calendar.day.timeline.left"
            case .mediaCore: return "waveform.circle"
            case .fieldOps: return "car.2.fill"
            case .contacts: return "person.2"
            case .myCorporations: return "building.2.crop.circle"
            case .review: return "tray.full"
            case .reconciliation: return "arrow.triangle.merge"
            case .bankImport: return "building.columns.fill"
            case .trash: return "trash"
            case .importScan: return "square.and.arrow.down.on.square"
            case .inboxTriage: return "tray.2.fill"
            case .inventory: return "shippingbox.fill"
            case .settings: return "gearshape"
            case let .cabinet(c): return c.systemImage
            #if DEBUG
            case .samples: return "square.stack.3d.down.right"
            #endif
        }
    }
}

private struct SidebarSplitShell: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator
    @EnvironmentObject private var sovereignContext: SovereignContextManager
    @ObservedObject private var feedbackManager = LiveFeedbackManager.shared

    let pendingReviewCount: Int
    let trashCount: Int
    let unmatchedBankCount: Int

    @Query(
        filter: #Predicate<Receipt> { !$0.pendingHumanReview && $0.trashedAt == nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var filedLibraryReceipts: [Receipt]

    @Query(sort: \ProductionContact.name) private var productionContacts: [ProductionContact]
    @Query(filter: #Predicate<BusinessEntity> { $0.isOwnedCorporation }) private var ownedCorporations: [BusinessEntity]

    private var externalContactCount: Int {
        productionContacts.filter {
            ProductionContactsFilter.isExternalContact($0, ownedCorporations: ownedCorporations)
        }.count
    }

    @State private var selection: SidebarPane = .home
    @State private var showCorporateRegistryFromShell = false
    @State private var showProductionRegistryFromShell = false
    @State private var showSovereignAuditFromShell = false
    @State private var showInventoryFromShell = false
    @State private var ledgerCatalogRevision = 0

    #if os(macOS)
    /// Show the library sidebar by default (Finder-style). Widen the window if the outer detail column feels tight.
    @State private var splitColumnVisibility = NavigationSplitViewVisibility.all
    #endif

    var body: some View {
        Group {
            #if os(macOS)
            NavigationSplitView(columnVisibility: $splitColumnVisibility) {
                sidebarListMac
            } detail: {
                libraryColumn
                    .boundedDetailContent()
                    .navigationSplitViewColumnWidth(
                        min: 480,
                        ideal: 720,
                        max: SafeLayoutBounds.maxWorkspaceContentWidth
                    )
            }
            .resetsNavigationSplitColumnsOnLaunch()
            #else
            NavigationSplitView {
                sidebarListPad
            } detail: {
                libraryColumn
                    .boundedDetailContent()
                    .navigationSplitViewColumnWidth(min: 380, ideal: 520, max: 800)
            }
            #endif
        }
        .tint(brandAccent)
        .onChange(of: selection) { _, newValue in
            if newValue == .importScan {
                libraryNavigationCoordinator.requestImportFromSidebar()
                selection = .receipts
            }
        }
        .onChange(of: libraryNavigationCoordinator.focusReceiptsLibrarySignal) { _, _ in
            if libraryNavigationCoordinator.consumeFocusReceiptsLibraryIfNeeded() {
                selection = .receipts
            }
        }
        .onChange(of: libraryNavigationCoordinator.homeNavigationSignal) { _, _ in
            applyHomeNavigationSplit()
        }
        .onChange(of: sovereignContext.activeHub) { _, _ in
            DispatchQueue.main.async {
                reconcileSelectionForActiveHub()
            }
        }
        .onChange(of: ledgerCatalogRevision) { _, _ in
            DispatchQueue.main.async {
                reconcileSelectionForActiveHub()
            }
        }
        .sheet(isPresented: $showCorporateRegistryFromShell) {
            NavigationStack { CorporateRegistryView() }
        }
        .sheet(isPresented: $showProductionRegistryFromShell) {
            NavigationStack { ProductionWorkspaceView() }
        }
        .sheet(isPresented: $showSovereignAuditFromShell) {
            NavigationStack { SovereignAuditLogListView() }
        }
        .sheet(isPresented: $showInventoryFromShell) {
            InventoryModuleView()
        }
        .onAppear {
            InternalIdentityRegistry.syncOwnedEntities(context: modelContext)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            TestingMissionBannerView()
        }
        .shakeToFeedback(context: "Sidebar · \(selection.title)")
        .sheet(isPresented: $feedbackManager.showOverlay) {
            CrewFeedbackOverlayView()
        }
    }

    private func applyHomeNavigationSplit() {
        if libraryNavigationCoordinator.consumeCorporateRegistryPresentationIfNeeded() {
            showCorporateRegistryFromShell = true
            return
        }
        if libraryNavigationCoordinator.consumeProductionRegistryPresentationIfNeeded() {
            showProductionRegistryFromShell = true
            return
        }
        if libraryNavigationCoordinator.consumeSovereignAuditPresentationIfNeeded() {
            showSovereignAuditFromShell = true
            return
        }
        guard let dest = libraryNavigationCoordinator.consumeHomeDestination() else { return }
        switch dest {
            case .arcticVault: selection = .receipts
            case .laborSentinel: selection = .laborSentinel
            case .productions: selection = .productions
            case .finances: selection = .reconciliation
            case .contacts: selection = .contacts
            case .inventory: showInventoryFromShell = true
            case .inboxTriage: selection = .inboxTriage
            case .insurance: selection = .cabinet(.equipment)
            default: selection = .home
        }
    }

    private var sidebarSettingsFooter: some View {
        Button {
            selection = .settings
        } label: {
            Label("Settings", systemImage: "gearshape")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.ratioVitaAdaptiveSurface.opacity(0.95))
    }

    #if os(macOS)
    private var sidebarListMac: some View {
        List(selection: $selection) {
            sovereignContextHeaderSection
            sidebarLibrarySection
            progressiveLedgerSection
            if SovereignSidebarCatalog.showsCabinetsSection(for: sovereignContext.activeHub) {
                sidebarCabinetsSection
            }
            if SovereignSidebarCatalog.showsContactsSection(for: sovereignContext.activeHub) {
                sidebarContactsSection
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("RatioVita")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarSettingsFooter
        }
    }
    #endif

    private var sidebarListPad: some View {
        List {
            sovereignContextHeaderSection
            sidebarLibrarySection
            progressiveLedgerSection
            if SovereignSidebarCatalog.showsCabinetsSection(for: sovereignContext.activeHub) {
                sidebarCabinetsSection
            }
            if SovereignSidebarCatalog.showsContactsSection(for: sovereignContext.activeHub) {
                sidebarContactsSection
            }
        }
        .navigationTitle("RatioVita")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarSettingsFooter
        }
    }

    @ViewBuilder
    private var libraryColumn: some View {
        Group {
            switch selection {
                case .operationsCommand:
                    NavigationStack {
                        OperationsCommandCenterView()
                    }
                case .expertProgram:
                    NavigationStack {
                        ExpertOnboardingHubView()
                    }
                case .home:
                    NavigationStack {
                        RatioVitaHomeView()
                    }
                case .productions:
                    NavigationStack {
                        ProductionWorkspaceView()
                    }
                case .receipts:
                    ReceiptsView()
                case .timeline:
                    NavigationStack {
                        ProductionTimelineView()
                    }
                case .laborSentinel:
                    NavigationStack {
                        LaborSentinelHubView()
                    }
                case .timeSheets:
                    TimeSheetsHubView()
                case .mediaCore:
                    MediaCoreHubView()
                case .fieldOps:
                    NavigationStack {
                        ProductionOperationsHubView()
                    }
                case .contacts:
                    NavigationStack {
                        ProductionContactsLibraryView()
                    }
                case .myCorporations:
                    NavigationStack {
                        CorporateRegistryView(ownedOnly: true)
                    }
                case .review:
                    ReceiptReviewView()
                case .reconciliation:
                    ReconciliationReviewView()
                case .bankImport:
                    BankImportView()
                case .trash:
                    ReceiptTrashView()
                case .importScan:
                    ReceiptsView()
                case .inboxTriage:
                    NavigationStack {
                        InboxTriageFeedView()
                    }
                case .inventory:
                    NavigationStack {
                        InventoryModuleView()
                    }
                case .settings:
                    NavigationStack {
                        SettingsView()
                    }
                case let .cabinet(cabinet):
                    ReceiptsView(cabinetFilter: cabinet)
                #if DEBUG
                case .samples:
                    SamplesLibraryView()
                #endif
            }
        }
    }

    @ViewBuilder
    private var sovereignContextHeaderSection: some View {
        Section {
            SovereignContextSwitcherBar()
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var sidebarLibrarySection: some View {
        Section(hubSectionTitle) {
            ForEach(SovereignSidebarCatalog.visibleItems(for: sovereignContext.activeHub)) { item in
                sidebarCatalogRow(item)
            }
            #if DEBUG
            sidebarRow(.samples)
            #endif
        }
        .id(ledgerCatalogRevision)
    }

    private var hubSectionTitle: String {
        switch sovereignContext.activeHub {
            case .personal: "Personal Hub"
            case .ventures: "Ventures Hub"
            case .production: "Production Mode"
        }
    }

    @ViewBuilder
    private var progressiveLedgerSection: some View {
        let enabled = SovereignLedgerExtensionStore.enabled(for: sovereignContext.activeHub)
        if !enabled.isEmpty {
            Section("Active ledger sections") {
                ForEach(enabled) { ext in
                    HStack {
                        Label(ext.title, systemImage: ext.systemImage)
                        Spacer()
                        Button("Remove") {
                            SovereignLedgerExtensionStore.setEnabled(ext, enabled: false)
                            ledgerCatalogRevision += 1
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }
            }
        }

        let available = SovereignLedgerExtension.options(for: sovereignContext.activeHub)
            .filter { !SovereignLedgerExtensionStore.isEnabled($0) }
        if !available.isEmpty {
            Section {
                Menu {
                    ForEach(available) { ext in
                        Button {
                            SovereignLedgerExtensionStore.setEnabled(ext, enabled: true)
                            ledgerCatalogRevision += 1
                        } label: {
                            VStack(alignment: .leading) {
                                Text(ext.title)
                                Text(ext.subtitle)
                                    .font(.caption)
                            }
                        }
                    }
                } label: {
                    Label("Add Active Ledger Section", systemImage: "plus.rectangle.on.rectangle")
                }
            }
        }
    }

    private func reconcileSelectionForActiveHub() {
        let visible = Set(SovereignSidebarCatalog.visibleItems(for: sovereignContext.activeHub).map(sidebarPane(for:)))
        if case .cabinet = selection {
            if !SovereignSidebarCatalog.showsCabinetsSection(for: sovereignContext.activeHub) {
                selection = .home
            }
            return
        }
        if !visible.contains(selection) {
            selection = .home
        }
    }

    private func sidebarPane(for item: SovereignSidebarCatalog.Item) -> SidebarPane {
        switch item {
            case .operationsCommand: .operationsCommand
            case .expertProgram: .expertProgram
            case .home: .home
            case .productions: .productions
            case .receipts: .receipts
            case .timeline: .timeline
            case .laborSentinel: .laborSentinel
            case .timeSheets: .timeSheets
            case .mediaCore: .mediaCore
            case .fieldOps: .fieldOps
            case .contacts: .contacts
            case .myCorporations: .myCorporations
            case .review: .review
            case .reconciliation: .reconciliation
            case .bankImport: .bankImport
            case .trash: .trash
            case .importScan: .importScan
            case .inboxTriage: .inboxTriage
            case .inventory: .inventory
            case .insuranceVault: .cabinet(.equipment)
        }
    }

    private func trailingCount(for item: SovereignSidebarCatalog.Item) -> Int {
        switch item {
            case .review: pendingReviewCount
            case .reconciliation: unmatchedBankCount
            case .trash: trashCount
            case .contacts: externalContactCount
            case .myCorporations: ownedCorporations.count
            default: 0
        }
    }

    @ViewBuilder
    private func sidebarCatalogRow(_ item: SovereignSidebarCatalog.Item) -> some View {
        let pane = sidebarPane(for: item)
        switch pane {
            case .cabinet:
                sidebarCabinetRow(.equipment, count: cabinetReceiptCount(.equipment))
            default:
                sidebarRow(pane, trailingCount: trailingCount(for: item))
        }
    }

    @ViewBuilder
    private var sidebarCabinetsSection: some View {
        Section("Cabinets") {
            ForEach(DocumentCabinet.allCases) { cabinet in
                sidebarCabinetRow(cabinet, count: cabinetReceiptCount(cabinet))
            }
        }
    }

    @ViewBuilder
    private var sidebarContactsSection: some View {
        Section("Contacts") {
            sidebarRow(.myCorporations, trailingCount: ownedCorporations.count)
            sidebarRow(.contacts, trailingCount: externalContactCount)
        }
    }

    private func cabinetReceiptCount(_ cabinet: DocumentCabinet) -> Int {
        filedLibraryReceipts.filter { $0.filingCabinetKindRaw == cabinet.rawValue }.count
    }

    @ViewBuilder
    private func sidebarRow(_ pane: SidebarPane, trailingCount: Int = 0) -> some View {
        switch pane {
            case .cabinet:
                EmptyView()
            default:
                Button {
                    selection = pane
                } label: {
                    HStack {
                        Label(pane.title, systemImage: pane.systemImage)
                        Spacer()
                        if trailingCount > 0 {
                            Text("\(trailingCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #if os(macOS)
                .tag(pane)
                #endif
        }
    }

    @ViewBuilder
    private func sidebarCabinetRow(_ cabinet: DocumentCabinet, count: Int) -> some View {
        let pane = SidebarPane.cabinet(cabinet)
        Button {
            selection = pane
        } label: {
            HStack {
                Label(cabinet.title, systemImage: cabinet.systemImage)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        #if os(macOS)
        .tag(pane)
        #endif
    }
}

#Preview {
    ContentView()
        .environment(LibraryNavigationCoordinator())
        .environmentObject(SovereignContextManager.shared)
        .modelContainer(SampleData.previewContainer)
}

extension View {
    @ViewBuilder
    fileprivate func optionalTabBadge(_ count: Int) -> some View {
        if count > 0 {
            badge(count)
        } else {
            self
        }
    }
}
