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
        filter: #Predicate<Receipt> { $0.pendingHumanReview == true && $0.trashedAt == nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var pendingReviewReceipts: [Receipt]

    @Query(
        filter: #Predicate<Receipt> { $0.trashedAt != nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var trashedReceipts: [Receipt]

    var body: some View {
        Group {
            #if os(macOS)
            SidebarSplitShell(
                pendingReviewCount: pendingReviewReceipts.count,
                trashCount: trashedReceipts.count,
                unmatchedBankCount: unmatchedBankTransactions.count
            )
            #else
            if horizontalSizeClass == .regular {
                SidebarSplitShell(
                    pendingReviewCount: pendingReviewReceipts.count,
                    trashCount: trashedReceipts.count,
                    unmatchedBankCount: unmatchedBankTransactions.count
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
                        .optionalTabBadge(pendingReviewReceipts.count)
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
            default:
                phoneLibraryTabSelection = 0
        }
    }
    #endif
}

// MARK: - Sidebar split shell (macOS + iPad)

private enum SidebarPane: Hashable {
    case home
    case productions
    case receipts
    case timeline
    case laborSentinel
    case timeSheets
    case mediaCore
    case contacts
    case myCorporations
    case review
    case reconciliation
    case bankImport
    case trash
    case importScan
    case settings
    case cabinet(DocumentCabinet)
    #if DEBUG
    case samples
    #endif

    var title: String {
        switch self {
            case .home: return "Home"
            case .productions: return "Productions"
            case .receipts: return "Receipts"
            case .timeline: return "Timeline"
            case .laborSentinel: return "Labor Sentinel"
            case .timeSheets: return "Time Sheets"
            case .mediaCore: return "Media Core"
            case .contacts: return "Contacts"
            case .myCorporations: return "My corporations"
            case .review: return "Review"
            case .reconciliation: return "Reconciliation"
            case .bankImport: return "Bank import"
            case .trash: return "Trash"
            case .importScan: return "Import"
            case .settings: return "Settings"
            case let .cabinet(c): return c.title
            #if DEBUG
            case .samples: return "Samples"
            #endif
        }
    }

    var systemImage: String {
        switch self {
            case .home: return "square.grid.2x2.fill"
            case .productions: return "film.stack"
            case .receipts: return "doc.text.fill"
            case .timeline: return "calendar.day.timeline.left"
            case .laborSentinel: return "shield.lefthalf.filled"
            case .timeSheets: return "calendar.day.timeline.left"
            case .mediaCore: return "waveform.circle"
            case .contacts: return "person.2"
            case .myCorporations: return "building.2.crop.circle"
            case .review: return "tray.full"
            case .reconciliation: return "arrow.triangle.merge"
            case .bankImport: return "building.columns.fill"
            case .trash: return "trash"
            case .importScan: return "square.and.arrow.down.on.square"
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
                    .frame(
                        minWidth: AdaptivePanelLayout.detailMinWidth,
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .navigationSplitViewColumnWidth(min: 480, ideal: 720, max: 1200)
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
            case .insurance: selection = .cabinet(.equipment)
            default: selection = .home
        }
    }

    #if os(macOS)
    private var sidebarListMac: some View {
        List(selection: $selection) {
            sidebarLibrarySection
            sidebarCabinetsSection
            sidebarContactsSection
        }
        .listStyle(.sidebar)
        .navigationTitle("RatioVita")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarSettingsFooter
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
    #endif

    private var sidebarListPad: some View {
        List {
            sidebarLibrarySection
            sidebarCabinetsSection
            sidebarContactsSection
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
    private var sidebarLibrarySection: some View {
        Section {
            sidebarRow(.home)
            sidebarRow(.productions)
            sidebarRow(.receipts)
            sidebarRow(.timeline)
            sidebarRow(.laborSentinel)
            sidebarRow(.timeSheets)
            sidebarRow(.mediaCore)
            sidebarRow(.review, trailingCount: pendingReviewCount)
            sidebarRow(.reconciliation, trailingCount: unmatchedBankCount)
            sidebarRow(.bankImport)
            sidebarRow(.trash, trailingCount: trashCount)
            sidebarRow(.importScan)
            #if DEBUG
            sidebarRow(.samples)
            #endif
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
