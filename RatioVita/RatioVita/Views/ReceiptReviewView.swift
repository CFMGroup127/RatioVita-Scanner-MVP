//
//  ReceiptReviewView.swift
//  RatioVita
//
//  Human review queue: receipts stay here until checked and filed into the main library.
//  Camera-origin receipts can be mirrored into Photos only at file time (imports skip Photos).
//

import SwiftData
import SwiftUI

struct ReceiptReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator
    @ObservedObject private var sovereignContext = SovereignContextManager.shared
    @ObservedObject private var reviewQueue = ReceiptReviewQueueStore.shared

    @AppStorage("mirrorScannedReceiptsToPhotoLibrary") private var mirrorScannedReceiptsToPhotoLibrary = true
    @AppStorage("receiptReviewSortRaw") private var sortRaw: String = ReceiptLibrarySort.dateAddedNewest.rawValue
    @AppStorage("receiptReviewViewModeRaw") private var viewModeRaw: String = ReceiptLibraryViewMode.list.rawValue
    @AppStorage("receiptReviewGroupByMerchant") private var groupByMerchant = false
    @AppStorage("receiptWorkbenchMultiPageOnly") private var multiPageOnly = false
    @AppStorage("receiptReviewFacilitatedCrewOnly") private var facilitatedCrewOnly = false

    /// Paginated slice — full queue count lives in `reviewQueue.totalCount`.
    private var pendingReceipts: [Receipt] { reviewQueue.loadedReceipts }

    @State private var isWorking = false
    @State private var confirmRejectAll = false
    @State private var confirmTrashChecked = false
    @State private var confirmMergeReviewed = false
    @State private var reviewBulkMode: ReceiptLibraryBulkMode = .off
    @State private var selection = Set<UUID>()
    @State private var searchText = ""
    @State private var selectedProjectColumn: String = "General"
    @State private var galleryFocusedId: UUID?
    @State private var navReceiptPath: [UUID] = []
    @State private var forwardReceiptPath: [UUID] = []
    @State private var splitSheetReceipt: Receipt?
    @State private var confirmBulkReanalyze = false
    @State private var bulkReanalyzeProgress: String?

    private var reviewQueueBase: [Receipt] {
        let base = if facilitatedCrewOnly {
            pendingReceipts.filter(\.facilitatedThirdPartyLabor)
        } else {
            pendingReceipts
        }
        return base.filter { receipt in
            if CrossEntityTriageEngine.needsTriage(receipt) {
                return SovereignScopeFilter.triageReceiptIsVisible(receipt, context: sovereignContext)
            }
            return sovereignContext.receiptIsVisible(receipt)
        }
    }

    var body: some View {
        let filtered = FinderReceiptSortEngine.filtered(
            reviewQueueBase,
            searchText: searchText,
            multiPageOnly: multiPageOnly
        )
        let librarySort = ReceiptLibrarySort(rawValue: sortRaw) ?? .dateAddedNewest
        let sorted = FinderReceiptSortEngine.sorted(filtered, by: librarySort)

        receiptReviewMain(sorted: sorted)
            .confirmationDialog(
                "Reject all \(reviewQueue.totalCount) receipt(s) in review?",
                isPresented: $confirmRejectAll,
                titleVisibility: .visible
            ) {
                Button("Move all to Trash", role: .destructive) {
                    rejectAllPending()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They will move to Trash. You can recover them from the Trash tab.")
            }
            .confirmationDialog(
                "Re-analyze all \(reviewQueue.totalCount) pending receipt(s) with Gemini?",
                isPresented: $confirmBulkReanalyze,
                titleVisibility: .visible
            ) {
                Button("Re-analyze all") {
                    Task { await bulkReanalyzePending() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Applies payee polarity, shadow registry, and R&D tagging to items already in Review.")
            }
            .confirmationDialog(
                "Move \(checkedCount) checked receipt(s) to Trash?",
                isPresented: $confirmTrashChecked,
                titleVisibility: .visible
            ) {
                Button("Move to Trash", role: .destructive) {
                    trashCheckedReceipts()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only receipts marked reviewed (checked) will be moved.")
            }
            .confirmationDialog(
                "Merge \(checkedCount) reviewed receipts?",
                isPresented: $confirmMergeReviewed,
                titleVisibility: .visible
            ) {
                Button("Merge into one document", role: .destructive) {
                    Task { await mergeReviewedReceipts() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "The oldest ingested receipt keeps its record id; all checked rows become pages on that record. Fields are re-extracted from combined OCR. This cannot be undone."
                )
            }
    }

    @ViewBuilder
    private func receiptReviewMain(sorted: [Receipt]) -> some View {
        NavigationStack(path: $navReceiptPath) {
            VStack(spacing: 0) {
                header
                if reviewQueue.totalCount == 0, !reviewQueue.isLoadingPage {
                    emptyState
                } else if groupByMerchant {
                    merchantGroupedReviewList(sorted: sorted)
                } else {
                    FinderReceiptSurfaceBrowser(
                        sortedReceipts: sorted,
                        viewMode: viewModeBinding,
                        bulkMode: $reviewBulkMode,
                        selection: $selection,
                        bulkInteractionEnabled: true,
                        selectedProjectColumn: $selectedProjectColumn,
                        galleryFocusedId: $galleryFocusedId,
                        onDelete: { idx, list in trashReceipts(at: idx, from: list) },
                        listRow: { receipt in
                            ReviewReceiptRow(
                                receipt: receipt,
                                selectionMode: reviewBulkMode != .off,
                                deleteReceipt: deleteReceipt,
                                onOpen: openReceiptInReview,
                                convertToAsset: convertReceiptToAsset,
                                onRequestSplitPages: { splitSheetReceipt = $0 }
                            )
                        }
                    )
                    .background(Color.ratioVitaAdaptiveBackground)
                }
            }
            .navigationTitle(finderNavTitle(sorted: sorted))
            .navigationDestination(for: UUID.self) { id in
                ReceiptDetailByIDView(receiptID: id)
            }
        }
        .sheet(isPresented: Binding(
            get: { splitSheetReceipt != nil },
            set: { if !$0 { splitSheetReceipt = nil } }
        )) {
            if let r = splitSheetReceipt {
                ReceiptPageSplitSheet(source: r)
            }
        }
        #if !os(macOS)
        .searchable(text: $searchText, placement: .automatic, prompt: "Search")
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItemGroup(placement: .navigation) {
                navBackForwardButtons
            }
            #endif

            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarLeading) {
                navBackForwardButtons
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                HStack(alignment: .center, spacing: 12) {
                    if navReceiptPath.isEmpty {
                        Button {
                            libraryNavigationCoordinator.queueImportFromReviewFlow()
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityHint("Switches to Receipts and opens capture or file import.")
                    }
                    if checkedCount > 0 {
                        reviewMultiSelectToolbarIcons
                    }
                    Toggle("By merchant", isOn: $groupByMerchant)
                        .toggleStyle(.button)
                        .tint(brandAccent)
                        .accessibilityLabel("Group by merchant")
                    Toggle("2+ pages", isOn: $multiPageOnly)
                        .toggleStyle(.button)
                        .tint(brandAccent)
                        .accessibilityLabel("Multi-page only")
                    Toggle("Crew invoices", isOn: $facilitatedCrewOnly)
                        .toggleStyle(.button)
                        .tint(brandAccent)
                        .accessibilityLabel("Facilitated crew invoices only")
                    reviewToolbarControls(placement: .compact)
                }
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(alignment: .center, spacing: 12) {
                    if checkedCount > 0 {
                        reviewMultiSelectToolbarIcons
                    }
                    Toggle("By merchant", isOn: $groupByMerchant)
                        .help("Group the review queue into vendor stacks")
                    reviewToolbarControls(placement: .regular)
                }
                .frame(minHeight: 28)
            }
            #if os(macOS)
            ToolbarItem(placement: .automatic) {
                HStack(alignment: .center, spacing: 0) {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                .frame(minHeight: 28)
            }
            #endif
            #endif
        }
        .onAppear {
            Task {
                await reviewQueue.resetAndLoadFirstPage(context: modelContext, container: modelContext.container)
            }
            FinderReceiptSortEngine.syncColumnSelection(selected: &selectedProjectColumn, sorted: sorted)
            FinderReceiptSortEngine.syncGalleryFocus(focused: &galleryFocusedId, sorted: sorted)
        }
        .onChange(of: sorted.count) { _, count in
            guard count > 0, count >= reviewQueue.loadedReceipts.count - 8, reviewQueue.hasMorePages else { return }
            Task {
                await reviewQueue.loadNextPage(context: modelContext, container: modelContext.container)
            }
        }
        .onChange(of: sorted.map(\.id)) { _, _ in
            Task { @MainActor in
                FinderReceiptSortEngine.syncColumnSelection(selected: &selectedProjectColumn, sorted: sorted)
                FinderReceiptSortEngine.syncGalleryFocus(focused: &galleryFocusedId, sorted: sorted)
            }
        }
        .onChange(of: navReceiptPath) { oldPath, newPath in
            if newPath.count > oldPath.count {
                forwardReceiptPath.removeAll()
            }
            if newPath.isEmpty {
                selection.removeAll()
                let f = FinderReceiptSortEngine.filtered(
                    pendingReceipts,
                    searchText: searchText,
                    multiPageOnly: multiPageOnly
                )
                let librarySort = ReceiptLibrarySort(rawValue: sortRaw) ?? .dateAddedNewest
                let sortedNow = FinderReceiptSortEngine.sorted(f, by: librarySort)
                FinderReceiptSortEngine.syncGalleryFocus(focused: &galleryFocusedId, sorted: sortedNow)
            }
        }
        .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
    }

    private var showsFinderChrome: Bool {
        // Review is the Finder workbench on every size class (including iPhone).
        true
    }

    private var viewModeBinding: Binding<ReceiptLibraryViewMode> {
        Binding(
            get: { ReceiptLibraryViewMode(rawValue: viewModeRaw) ?? .list },
            set: { viewModeRaw = $0.rawValue }
        )
    }

    private var sortBinding: Binding<ReceiptLibrarySort> {
        Binding(
            get: { ReceiptLibrarySort(rawValue: sortRaw) ?? .dateAddedNewest },
            set: { sortRaw = $0.rawValue }
        )
    }

    @ViewBuilder
    private var navBackForwardButtons: some View {
        Button {
            goBackNavigation()
        } label: {
            Image(systemName: "chevron.backward")
        }
        .disabled(navReceiptPath.isEmpty)
        #if os(macOS)
            .help("Back")
        #else
            .accessibilityLabel("Back")
        #endif

        Button {
            goForwardNavigation()
        } label: {
            Image(systemName: "chevron.forward")
        }
        .disabled(forwardReceiptPath.isEmpty)
        #if os(macOS)
            .help("Forward")
        #else
            .accessibilityLabel("Forward")
        #endif
    }

    private func finderNavTitle(sorted: [Receipt]) -> String {
        guard let last = navReceiptPath.last else { return "Review" }
        if let r = sorted.first(where: { $0.id == last })
            ?? pendingReceipts.first(where: { $0.id == last })
        {
            return r.merchant
        }
        return "Review"
    }

    private func goBackNavigation() {
        guard let last = navReceiptPath.popLast() else { return }
        forwardReceiptPath.append(last)
    }

    private func goForwardNavigation() {
        guard let route = forwardReceiptPath.popLast() else { return }
        navReceiptPath.append(route)
    }

    private func openReceiptInReview(_ receiptID: UUID) {
        navReceiptPath.append(receiptID)
    }

    private func bulkReanalyzePending() async {
        isWorking = true
        bulkReanalyzeProgress = "Starting…"
        defer {
            isWorking = false
            bulkReanalyzeProgress = nil
        }
        let allPending = await reviewQueue.fetchAllPending(context: modelContext)
        do {
            try await ReceiptBulkGeminiReanalysis.reanalyzePending(
                receipts: allPending,
                context: modelContext
            ) { progress in
                Task { @MainActor in
                    bulkReanalyzeProgress =
                        "\(progress.completed)/\(progress.total) — \(progress.currentMerchant ?? "")"
                }
            }
        } catch {
            UserMessageCenter.shared.present(
                title: "Re-analysis failed",
                message: error.ratioVitaUserDescription
            )
        }
    }

    private enum ToolbarPlacementKind {
        case compact
        case regular
    }

    @ViewBuilder
    private func reviewToolbarControls(placement: ToolbarPlacementKind) -> some View {
        #if os(macOS)
        reviewMacToolbarControls(placement: placement)
        #else
        if showsFinderChrome {
            Picker("View", selection: viewModeBinding) {
                ForEach(ReceiptLibraryViewMode.allCases) { mode in
                    Image(systemName: mode.systemImage)
                        .accessibilityLabel(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: placement == .regular ? 220 : 160)

            Menu {
                Picker("Sort", selection: sortBinding) {
                    ForEach(ReceiptLibrarySort.allCases) { option in
                        Text(option.menuTitle).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        } else {
            Menu {
                Picker("Sort", selection: sortBinding) {
                    ForEach(ReceiptLibrarySort.allCases) { option in
                        Text(option.menuTitle).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private func reviewMacToolbarControls(placement _: ToolbarPlacementKind) -> some View {
        if showsFinderChrome {
            Picker("View", selection: viewModeBinding) {
                ForEach(ReceiptLibraryViewMode.allCases) { mode in
                    Image(systemName: mode.systemImage)
                        .accessibilityLabel(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .fixedSize(horizontal: true, vertical: false)

            Menu {
                Picker("Sort", selection: sortBinding) {
                    ForEach(ReceiptLibrarySort.allCases) { option in
                        Text(option.menuTitle).tag(option)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .menuIndicator(.hidden)

            Toggle("By merchant", isOn: $groupByMerchant)
                .help("Group the review queue into vendor stacks")

            Toggle("2+ pages", isOn: $multiPageOnly)
                .help("Show only merged or multi-page items (decoupler targets)")

            Toggle("Crew invoices", isOn: $facilitatedCrewOnly)
                .help("Show only facilitated third-party labor invoices you issued for crew")
        }

        if checkedCount == 0 {
            Menu {
                Button("Email selection…") {
                    let picked = pendingReceipts.filter { selection.contains($0.id) }
                    ReceiptSelectionMailer.presentEmailComposer(for: picked)
                }
                .disabled(selection.isEmpty)
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .menuIndicator(.hidden)
            .help("Share")
        }

        Menu {
            if checkedCount == 0 {
                Button {
                    Task { await fileCheckedReceipts() }
                } label: {
                    Label("File & save checked (\(checkedCount))", systemImage: "tray.and.arrow.down.fill")
                }
                .disabled(checkedCount == 0 || isWorking)

                Divider()
            }

            Button("Reject all in review…", role: .destructive) {
                confirmRejectAll = true
            }
            .disabled(reviewQueue.totalCount == 0 || isWorking)

            Button("Re-analyze all pending…") {
                confirmBulkReanalyze = true
            }
            .disabled(reviewQueue.totalCount == 0 || isWorking)

            Button("Tag facilitated crew invoices…") {
                let count = FacilitatedThirdPartyInvoiceClassifier.retagPendingReview(context: modelContext)
                bulkReanalyzeProgress = "Tagged \(count) crew invoice(s) in Review."
            }
            .disabled(reviewQueue.totalCount == 0 || isWorking)

            Divider()

            Button(reviewBulkMode == .off ? "Select for Trash…" : "Done Selecting") {
                if reviewBulkMode == .off {
                    reviewBulkMode = .trash
                } else {
                    reviewBulkMode = .off
                    selection.removeAll()
                }
            }

            Button("Move selected to Trash") {
                moveSelectionToTrash()
            }
            .disabled(selection.isEmpty || reviewBulkMode == .off || isWorking)

            Divider()

            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
    }
    #endif

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                RatioVitaLabeledHint(title: "Accounts Receivable", term: .accountsReceivable)
                RatioVitaLabeledHint(title: "Accounts Payable", term: .accountsPayable)
                RatioVitaHint(term: .preIncorporationRD)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            #if os(macOS)
            HStack(alignment: .center, spacing: 10) {
                if checkedCount == 0 {
                    Button {
                        Task { await fileCheckedReceipts() }
                    } label: {
                        if isWorking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("File checked (\(checkedCount))")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(brandAccent)
                    .controlSize(.small)
                    .disabled(checkedCount == 0 || isWorking)
                }

                Text(
                    checkedCount > 0
                        ? "Use the toolbar to verify, delete, email, or merge checked items."
                        : "Verify each item, then file into the library."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            #else
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(
                    "OCR is complete for items listed here. Check each receipt you have verified, then file them into your library."
                )
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                Button {
                    Task { await fileCheckedReceipts() }
                } label: {
                    if isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("File & save checked (\(checkedCount))")
                            .font(DesignSystem.Typography.bodyEmphasized)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(brandAccent)
                .disabled(checkedCount == 0 || isWorking)

                HStack(spacing: DesignSystem.Spacing.md) {
                    Button("Reject all in review…", role: .destructive) {
                        confirmRejectAll = true
                    }
                    .disabled(reviewQueue.totalCount == 0 || isWorking)

                    Button(reviewBulkMode == .off ? "Select" : "Done") {
                        if reviewBulkMode == .off {
                            reviewBulkMode = .trash
                        } else {
                            reviewBulkMode = .off
                            selection.removeAll()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Move selected to Trash") {
                        moveSelectionToTrash()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection.isEmpty || reviewBulkMode == .off || isWorking)

                    Spacer()
                }
                .padding(.top, DesignSystem.Spacing.xs)

                Text(
                    "Remove mistakes: use Trash on a row, Reject all, Select + Move selected, row Delete, or recover from Trash."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            }
            .padding(DesignSystem.Spacing.md)
            #endif
        }
    }

    private var checkedCount: Int {
        pendingReceipts.filter(\.reviewChecklistDone).count
    }

    /// Merge refuses **Verified** rows so audit-linked documents are not silently combined.
    private var mergeReviewedDisabled: Bool {
        checkedCount < 2 || isWorking
            || pendingReceipts.filter(\.reviewChecklistDone).contains(where: \.isVerified)
    }

    private func convertReceiptToAsset(_ receipt: Receipt) {
        do {
            _ = try EquipmentInventoryService.createAsset(from: receipt, context: modelContext)
            try modelContext.save()
        } catch {
            UserMessageCenter.shared.present(
                title: "Could not create asset",
                message: error.ratioVitaUserDescription
            )
        }
    }

    private func reviewMerchantGroups(from sorted: [Receipt]) -> [MerchantReviewStack] {
        let dict = Dictionary(grouping: sorted) { r -> String in
            let m = r.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            return m.isEmpty ? "unknown" : m.lowercased()
        }
        return dict.keys.sorted().compactMap { key in
            guard let rows = dict[key] else { return nil }
            let title = rows.first?.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let display: String = {
                guard let title, !title.isEmpty else { return "Unknown merchant" }
                return title
            }()
            let ordered = rows.sorted { $0.createdAt > $1.createdAt }
            return MerchantReviewStack(id: key, displayTitle: display, receipts: ordered)
        }
    }

    @ViewBuilder
    private func merchantGroupedReviewList(sorted: [Receipt]) -> some View {
        let groups = reviewMerchantGroups(from: sorted)
        List {
            ForEach(groups) { g in
                DisclosureGroup {
                    ForEach(g.receipts) { receipt in
                        ReviewReceiptRow(
                            receipt: receipt,
                            selectionMode: reviewBulkMode != .off,
                            deleteReceipt: deleteReceipt,
                            onOpen: openReceiptInReview,
                            convertToAsset: convertReceiptToAsset,
                            onRequestSplitPages: { splitSheetReceipt = $0 }
                        )
                    }
                } label: {
                    HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                        Button("Mark reviewed") {
                            for r in g.receipts {
                                r.reviewChecklistDone = true
                            }
                            try? modelContext.save()
                            Task { @MainActor in
                                await DesignSystem.TouchFeedback.impactMediumBurst(count: min(g.receipts.count, 8))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.displayTitle)
                                .font(DesignSystem.Typography.headline)
                            Text("\(g.receipts.count) in stack")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var reviewMultiSelectToolbarIcons: some View {
        HStack(spacing: 8) {
            Button {
                Task { await fileCheckedReceipts() }
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .help("Verify — file checked receipts into the library")
            .disabled(checkedCount == 0 || isWorking)

            Button {
                confirmTrashChecked = true
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete — move checked receipts to Trash")
            .disabled(checkedCount == 0 || isWorking)

            Button {
                let picked = pendingReceipts.filter(\.reviewChecklistDone)
                ReceiptSelectionMailer.presentEmailComposer(for: picked)
            } label: {
                Image(systemName: "envelope")
            }
            .help("Email checked receipts")
            .disabled(checkedCount == 0)

            Button {
                confirmMergeReviewed = true
            } label: {
                Image(systemName: "link")
            }
            .help("Merge reviewed receipts into one multi-page document")
            .disabled(mergeReviewedDisabled)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundStyle(brandAccent.opacity(0.85))
            Text("Nothing in review")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text("New captures and imports appear here after you send them from the add-receipt sheet.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func moveSelectionToTrash() {
        let now = Date()
        for id in selection {
            guard let r = pendingReceipts.first(where: { $0.id == id }) else { continue }
            r.trashedAt = now
        }
        selection.removeAll()
        reviewBulkMode = .off
        try? modelContext.save()
    }

    private func trashCheckedReceipts() {
        Task {
            let now = Date()
            await reviewQueue.mutateAllPending(context: modelContext, container: modelContext.container) { r in
                if r.reviewChecklistDone {
                    r.trashedAt = now
                    r.reviewChecklistDone = false
                }
            }
        }
    }

    private func trashReceipts(at offsets: IndexSet, from list: [Receipt]) {
        let now = Date()
        for index in offsets {
            list[index].trashedAt = now
        }
        try? modelContext.save()
    }

    private func deleteReceipt(_ receipt: Receipt) {
        receipt.trashedAt = Date()
        try? modelContext.save()
    }

    private func rejectAllPending() {
        Task {
            let now = Date()
            await reviewQueue.mutateAllPending(context: modelContext, container: modelContext.container) { r in
                r.trashedAt = now
            }
        }
    }

    private func mergeReviewedReceipts() async {
        let targets = await reviewQueue.fetchAllPending(context: modelContext)
            .filter(\.reviewChecklistDone)
            .sorted { $0.createdAt < $1.createdAt }
        guard targets.count >= 2 else {
            UserMessageCenter.shared.present(
                title: "Nothing to merge",
                message: "Mark at least two receipts as reviewed, then try again."
            )
            return
        }
        guard !targets.contains(where: \.isVerified) else {
            UserMessageCenter.shared.present(
                title: "Verified receipts",
                message: "Un-verify protected receipts before merging."
            )
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await ReceiptMergerService.mergeReceipts(targets, context: modelContext)
            selection.removeAll()
            reviewBulkMode = .off
            await DesignSystem.TouchFeedback.impactMediumBurst(count: min(targets.count, 8))
            UserMessageCenter.shared.present(
                title: "Merged",
                message: "Combined \(targets.count) receipt(s). Review the merged document, then file it."
            )
        } catch {
            UserMessageCenter.shared.present(
                title: "Merge failed",
                message: error.ratioVitaUserDescription
            )
        }
    }

    private func fileCheckedReceipts() async {
        let targets = await reviewQueue.fetchAllPending(context: modelContext)
            .filter(\.reviewChecklistDone)
        guard !targets.isEmpty else {
            UserMessageCenter.shared.present(
                title: "Nothing selected",
                message: "Check at least one receipt you have reviewed, then try again."
            )
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            for receipt in targets {
                receipt.filingCabinetKindRaw = ReceiptCabinetRouting.suggestedCabinetKindRaw(
                    taxCategory: receipt.taxCategory,
                    merchant: receipt.merchant,
                    productionType: receipt.productionType
                )
                ReceiptWorkspaceBatchGuard.clearPinOnFile(receipt)
                receipt.pendingHumanReview = false
                if mirrorScannedReceiptsToPhotoLibrary, receipt.scannedViaCamera {
                    await ReceiptPhotosLibraryExporter.mirrorSavedReceipt(receipt)
                }
                receipt.reviewChecklistDone = false
            }
            try modelContext.save()
            await reviewQueue.refreshTotalCount(container: modelContext.container)
            await reviewQueue.resetAndLoadFirstPage(context: modelContext, container: modelContext.container)
            let burstCount = min(targets.count, 8)
            if burstCount > 1 {
                await DesignSystem.TouchFeedback.impactMediumBurst(count: burstCount)
            } else {
                DesignSystem.TouchFeedback.impactMedium()
            }
        } catch {
            UserMessageCenter.shared.present(
                title: "Couldn't file receipts",
                message: error.ratioVitaUserDescription
            )
        }
    }
}

private struct MerchantReviewStack: Identifiable {
    let id: String
    let displayTitle: String
    let receipts: [Receipt]
}

private struct ReviewReceiptRow: View {
    @ObservedObject private var sovereignContext = SovereignContextManager.shared
    @Environment(\.brandAccent) private var brandAccent
    @Bindable var receipt: Receipt
    var selectionMode: Bool
    var deleteReceipt: (Receipt) -> Void
    var onOpen: (UUID) -> Void
    var convertToAsset: (Receipt) -> Void
    var onRequestSplitPages: ((Receipt) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                #if os(macOS)
                Toggle("Reviewed", isOn: $receipt.reviewChecklistDone)
                    .toggleStyle(.checkbox)
                #else
                Button {
                    receipt.reviewChecklistDone.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: receipt.reviewChecklistDone ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(receipt.reviewChecklistDone ? brandAccent : Color.secondary)
                        Text("Reviewed")
                            .font(DesignSystem.Typography.subheadline.weight(.medium))
                            .foregroundStyle(Color.ratioVitaAdaptiveText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(receipt.reviewChecklistDone ? .isSelected : [])
                #endif

                Button {
                    onOpen(receipt.id)
                } label: {
                    HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                        reviewRowThumbnail

                        VStack(alignment: .leading, spacing: 2) {
                            Text(receipt.merchant)
                            #if os(macOS)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.primary)
                            #else
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(Color.ratioVitaAdaptiveText)
                            #endif
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text((receipt.transactionDate ?? receipt.createdAt).formatted(
                                date: .abbreviated,
                                time: .shortened
                            ))
                            #if os(macOS)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            #else
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                            #endif
                            .lineLimit(1)

                            Text("Filing: \(ReceiptVaultPathing.displayPath(for: receipt))")
                            #if os(macOS)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            #else
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(Color.ratioVitaTextSecondary.opacity(0.9))
                            #endif
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(formattedTotal(receipt))
                        #if os(macOS)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(totalColor(receipt))
                        #else
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(totalColor(receipt))
                        #endif
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)

                if !selectionMode {
                    Menu {
                        Button {
                            convertToAsset(receipt)
                        } label: {
                            Label("Convert to asset", systemImage: "shippingbox")
                        }
                        .disabled(receipt.sourceEquipmentAsset != nil)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)

                    Button {
                        deleteReceipt(receipt)
                    } label: {
                        Label("Trash", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .help("Move this receipt to Trash")
                }
            }
            .frame(minHeight: 56, alignment: .center)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Label("OCR ready", systemImage: "text.viewfinder")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                if receipt.scannedViaCamera {
                    StatusBadge.info("Camera")
                } else {
                    StatusBadge.info("Import")
                }
            }
            .padding(.leading, 4)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: DesignSystem.Spacing.xs,
            leading: DesignSystem.Spacing.md,
            bottom: DesignSystem.Spacing.xs,
            trailing: DesignSystem.Spacing.md
        ))
        .contextMenu {
            if receipt.images.count > 1, let onRequestSplitPages {
                Button("Split pages into new records…") {
                    onRequestSplitPages(receipt)
                }
            }
            Button(role: .destructive) {
                deleteReceipt(receipt)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var reviewRowThumbnail: some View {
        Group {
            if let firstImage = receipt.firstImage {
                Image(rvImage: firstImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipped()
                #if os(macOS)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                #else
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous))
                #endif
            } else {
                #if os(macOS)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "doc.text.image")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
                #else
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveBorder.opacity(0.35))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "doc.text.image")
                            .font(.title3)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                    )
                #endif
            }
        }
        #if os(macOS)
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
        #else
        .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                    .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.4), lineWidth: 1)
            )
        #endif
    }

    private func formattedTotal(_ receipt: Receipt) -> String {
        let docType = DocumentTypeOption.fromStored(receipt.documentType)
        let label = AccountingDisplayLabels.totalFieldTitle(documentType: docType)
        let amount = CurrencyFormatter.shared.format(
            sovereignContext.scopedDisplayTotal(for: receipt),
            currencyCode: receipt.currencyCode
        )
        return "\(label): \(amount)"
    }

    private func totalColor(_ receipt: Receipt) -> Color {
        switch AccountingAmountPolarity.signExpectation(
            for: DocumentTypeOption.fromStored(receipt.documentType)
        ) {
            case .mustBePositive:
                Color.ratioVitaSuccess
            case .mustBeNegative:
                .red
            case .unspecified:
                brandAccent
        }
    }
}

#Preview("ReceiptReviewView") {
    ReceiptReviewView()
        .environment(LibraryNavigationCoordinator())
        .modelContainer(SampleData.previewContainer)
}
