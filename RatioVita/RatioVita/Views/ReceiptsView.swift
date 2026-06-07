import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ReceiptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator

    private let cabinetFilter: DocumentCabinet?

    @Query private var receipts: [Receipt]

    @Query(
        filter: #Predicate<Receipt> { $0.pendingHumanReview && $0.trashedAt == nil },
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

    @StateObject private var viewModel: ReceiptsViewModel

    @AppStorage("ocrEnabled") private var ocrEnabled: Bool = true
    @AppStorage("compressionEnabled") private var compressionEnabled: Bool = false
    @AppStorage("receiptLibrarySortRaw") private var sortRaw: String = ReceiptLibrarySort.dateAddedNewest.rawValue
    @AppStorage("receiptLibraryViewModeRaw") private var viewModeRaw: String = ReceiptLibraryViewMode.list.rawValue
    @AppStorage("libraryIconThumbnailSize") private var libraryIconThumbnailSize: Double = 64
    @AppStorage("receiptLibraryTaxUseFilterRaw") private var taxUseFilterRaw: String = ReceiptLibraryTaxUseFilter.all
        .rawValue
    @AppStorage("receiptLibraryArcticExplorerEnabled") private var arcticExplorerEnabled = true
    @AppStorage("libraryScanVaultPathPrefix") private var libraryScanVaultPathPrefix: String = ""
    @AppStorage("receiptWorkbenchMultiPageOnly") private var multiPageOnly = false

    @Query(
        filter: #Predicate<ArcticVaultFolder> { $0.parent == nil },
        sort: \ArcticVaultFolder.sortIndex
    )
    private var arcticRootFolders: [ArcticVaultFolder]

    @State private var arcticPhase: ArcticVaultLibraryPhase = .vendorRoot
    @State private var showNewArcticFolderSheet = false
    @State private var browsingCustomFolder: ArcticVaultFolder?

    @State private var searchText: String = ""
    @State private var bulkMode: ReceiptLibraryBulkMode = .off
    @State private var selection = Set<UUID>()
    @State private var selectedProjectColumn: String = "General"
    @State private var galleryFocusedId: UUID?
    @State private var exportShareItem: ExportSharePayload?
    @State private var navReceiptPath: [UUID] = []
    @State private var forwardReceiptPath: [UUID] = []
    init(cabinetFilter: DocumentCabinet? = nil) {
        self.cabinetFilter = cabinetFilter
        if let cabinet = cabinetFilter {
            let raw = cabinet.rawValue
            _receipts = Query(
                filter: #Predicate<Receipt> { receipt in
                    !receipt.pendingHumanReview && receipt.trashedAt == nil && receipt.filingCabinetKindRaw == raw
                },
                sort: \Receipt.createdAt,
                order: .reverse,
                animation: .default
            )
        } else {
            _receipts = Query(
                filter: #Predicate<Receipt> { !$0.pendingHumanReview && $0.trashedAt == nil },
                sort: \Receipt.createdAt,
                order: .reverse,
                animation: .default
            )
        }

        let schema = LibrarySwiftDataSchema.makeSchema()
        let container = try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        _viewModel = StateObject(wrappedValue: ReceiptsViewModel(
            scanner: PreviewScannerService(),
            context: ModelContext(container)
        ))
    }

    private var librarySort: ReceiptLibrarySort {
        ReceiptLibrarySort(rawValue: sortRaw) ?? .dateAddedNewest
    }

    private var activeViewMode: ReceiptLibraryViewMode {
        ReceiptLibraryViewMode(rawValue: viewModeRaw) ?? .list
    }

    /// Icon grid and gallery strip honor `libraryIconThumbnailSize` (48…128 pt).
    private var usesResizableThumbnails: Bool {
        activeViewMode == .icon || activeViewMode == .gallery
    }

    private var clampedIconThumbnailBinding: Binding<Double> {
        Binding(
            get: { min(128, max(48, libraryIconThumbnailSize)) },
            set: { libraryIconThumbnailSize = min(128, max(48, $0)) }
        )
    }

    private var showsFinderChrome: Bool {
        true
    }

    /// iPhone can report `regular` width in landscape; keep Scan/Capture in the leading cluster for **all** phones.
    private var prefersLeadingScanToolbarLayout: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var receiptsForLibraryList: [Receipt] {
        guard let cid = libraryNavigationCoordinator.receiptsContactFilterContactID else { return receipts }
        return receipts.filter { $0.counterpartyContact?.id == cid }
    }

    private var showsContactFilterBanner: Bool {
        libraryNavigationCoordinator.receiptsContactFilterContactID != nil
    }

    /// Merchant-first Arctic hierarchy (main library only — not cabinet-scoped or CRM-filtered).
    private var showsArcticVaultChrome: Bool {
        arcticExplorerEnabled && cabinetFilter == nil && !showsContactFilterBanner
    }

    private func receiptCount(withVaultPrefix prefix: String, in list: [Receipt]) -> Int {
        let p = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !p.isEmpty else { return 0 }
        return list.filter { r in
            let rp = (r.vaultPathPrefix ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return rp == p || rp.hasPrefix(p + "/")
        }.count
    }

    @ViewBuilder
    private func receiptsMainColumn(sorted: [Receipt]) -> some View {
        VStack(spacing: 0) {
            if showsContactFilterBanner, let name = libraryNavigationCoordinator.receiptsContactFilterDisplayName {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(brandAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Filtered by contact")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                        Text(name)
                            .font(DesignSystem.Typography.bodyEmphasized)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button("Clear") {
                        libraryNavigationCoordinator.clearReceiptsContactFilter()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, 8)
                .background(Color.ratioVitaAdaptiveSurface)
            }
            #if !os(macOS)
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        brandAccent.opacity(0.14),
                        brandAccent.opacity(0.04),
                        Color.ratioVitaAdaptiveBackground,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        SectionHeader(
                            title: "Receipts",
                            subtitle: "\(sorted.count) receipt\(sorted.count == 1 ? "" : "s")"
                        )
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.sm)
                }
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [brandAccent, brandAccent.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .frame(minHeight: DesignSystem.Layout.receiptsHeaderMinHeight)
            .background(Color.ratioVitaAdaptiveBackground)
            #endif

            Group {
                if showsArcticVaultChrome {
                    arcticMainLibraryColumn(sorted: sorted)
                } else {
                    FinderReceiptSurfaceBrowser(
                        sortedReceipts: sorted,
                        viewMode: viewModeBinding,
                        bulkMode: $bulkMode,
                        selection: $selection,
                        bulkInteractionEnabled: true,
                        selectedProjectColumn: $selectedProjectColumn,
                        galleryFocusedId: $galleryFocusedId,
                        onDelete: { idx, list in delete(at: idx, from: list) },
                        listRow: { receipt in
                            receiptNavigationRow(receipt)
                        }
                    )
                    .background(Color.ratioVitaAdaptiveBackground)
                    #if !os(macOS)
                        .searchable(text: $searchText, placement: .automatic, prompt: "Search")
                    #endif
                        .overlay {
                            if sorted.isEmpty {
                                if receipts.isEmpty {
                                    emptyLibraryOverlay
                                } else if showsContactFilterBanner, receiptsForLibraryList.isEmpty {
                                    emptyContactFilterOverlay
                                } else {
                                    emptyScopeFilterOverlay
                                }
                            }
                        }
                }
            }
        }
    }

    var body: some View {
        let filtered = FinderReceiptSortEngine.filtered(
            receiptsForLibraryList,
            searchText: searchText,
            multiPageOnly: multiPageOnly
        )
        let scoped = filtered.filter { passesTaxUseFilter($0) }
        let sorted = FinderReceiptSortEngine.sorted(scoped, by: librarySort)

        NavigationStack(path: $navReceiptPath) {
            receiptsMainColumn(sorted: sorted)
                .navigationTitle(navigationChromeTitle)
                .navigationDestination(for: UUID.self) { id in
                    ReceiptDetailByIDView(receiptID: id)
                }
        }
        .toolbar {
            if showsCabinetPrincipalToolbar, let c = cabinetFilter {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: c.systemImage)
                            .foregroundStyle(brandAccent)
                            .imageScale(.medium)
                        Text(c.title)
                            .font(.headline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(c.title) cabinet filter")
                }
            }
            #if os(macOS)
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    goBackNavigation()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(navReceiptPath.isEmpty)
                .help("Back")

                Button {
                    goForwardNavigation()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(forwardReceiptPath.isEmpty)
                .help("Forward")
            }
            #endif

            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    goBackNavigation()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(navReceiptPath.isEmpty)
                .accessibilityLabel("Back")

                Button {
                    goForwardNavigation()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(forwardReceiptPath.isEmpty)
                .accessibilityLabel("Forward")

                if prefersLeadingScanToolbarLayout {
                    scanCaptureToolbarButton()
                }
            }
            #endif

            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                HStack(alignment: .center, spacing: 12) {
                    toolbarControls(
                        sorted: sorted,
                        placement: .compact,
                        includeScanButton: !prefersLeadingScanToolbarLayout
                    )
                }
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(alignment: .center, spacing: 12) {
                    toolbarControls(sorted: sorted, placement: .regular)
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

            #if DEBUG
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                samplesMenu
            }
            #else
            ToolbarItem(placement: .automatic) {
                samplesMenu
            }
            #endif
            #endif
        }
        .onAppear {
            #if os(iOS)
            #if targetEnvironment(simulator)
            let scanner: ScannerService = PreviewScannerService()
            #else
            let scanner: ScannerService = RealScannerService()
            #endif
            #elseif os(visionOS)
            #if targetEnvironment(simulator)
            let scanner: ScannerService = PreviewScannerService()
            #else
            let scanner: ScannerService = RealScannerService()
            #endif
            #elseif os(macOS)
            let scanner: ScannerService = MacAVScannerService()
            #else
            let scanner: ScannerService = PreviewScannerService()
            #endif

            viewModel.updateDependencies(scanner: scanner, context: modelContext)
            FinderReceiptSortEngine.syncColumnSelection(selected: &selectedProjectColumn, sorted: sorted)
            FinderReceiptSortEngine.syncGalleryFocus(focused: &galleryFocusedId, sorted: sorted)
            syncImportRequestWithScannerIfNeeded()
            openImportIfQueuedFromReview()
        }
        .onChange(of: libraryNavigationCoordinator.focusReceiptsLibrarySignal) { _, _ in
            openImportIfQueuedFromReview()
        }
        .onChange(of: libraryNavigationCoordinator.importSheetSignal) { _, _ in
            syncImportRequestWithScannerIfNeeded()
        }
        .onChange(of: viewModel.showScanner) { _, isPresented in
            if !isPresented {
                syncImportRequestWithScannerIfNeeded()
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
        }
        .sheet(isPresented: $viewModel.showScanner) {
            #if os(iOS) || os(visionOS)
            CameraCaptureView(
                scanner: viewModel.scanner,
                ocrEnabled: ocrEnabled,
                compressionEnabled: compressionEnabled,
                onSubmit: { scanResult, options in
                    await viewModel.handleScanResult(scanResult, options: options)
                },
                onManuscriptFile: { url in
                    await viewModel.importManuscriptFile(at: url, vaultPathPrefix: libraryScanVaultPathPrefix)
                }
            )
            #elseif os(macOS)
            CameraCaptureView(
                scanner: viewModel.scanner,
                ocrEnabled: ocrEnabled,
                compressionEnabled: compressionEnabled,
                onSubmit: { scanResult, options in
                    await viewModel.handleScanResult(scanResult, options: options)
                },
                onManuscriptFile: { url in
                    await viewModel.importManuscriptFile(at: url, vaultPathPrefix: libraryScanVaultPathPrefix)
                }
            )
            #else
            Text("Scanning is not available on this platform.")
            #endif
        }
        .sheet(item: $exportShareItem) { payload in
            ShareExportSheet(url: payload.url)
        }
        .sheet(isPresented: $showNewArcticFolderSheet) {
            NewArcticVaultFolderSheet()
        }
        .onChange(of: arcticExplorerEnabled) { _, enabled in
            if !enabled {
                arcticPhase = .vendorRoot
                browsingCustomFolder = nil
            }
        }
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

    /// Detail push uses the merchant title; library root uses **Receipts** or an empty title when the cabinet
    /// principal toolbar row shows the icon + name.
    private var navigationChromeTitle: String {
        if let last = navReceiptPath.last,
           let r = receipts.first(where: { $0.id == last })
        {
            return r.merchant
        }
        if cabinetFilter != nil {
            return ""
        }
        return "Receipts"
    }

    private var showsCabinetPrincipalToolbar: Bool {
        navReceiptPath.isEmpty && cabinetFilter != nil
    }

    private func goBackNavigation() {
        guard let last = navReceiptPath.popLast() else { return }
        forwardReceiptPath.append(last)
    }

    private func goForwardNavigation() {
        guard let id = forwardReceiptPath.popLast() else { return }
        navReceiptPath.append(id)
    }

    /// Opens the import sheet once per sidebar bump; skips while the capture sheet is already up so a bump is not
    /// lost, then retries when the sheet closes (`onChange` of `showScanner`).
    private func syncImportRequestWithScannerIfNeeded() {
        guard !viewModel.showScanner else { return }
        guard libraryNavigationCoordinator.consumeImportSheetIfNeeded() else { return }
        viewModel.showScannerUI()
    }

    /// **Review** tab queues import + library focus so capture opens only after `ReceiptsView` is active.
    private func openImportIfQueuedFromReview() {
        guard libraryNavigationCoordinator.consumePendingImportWhenReceiptsTabActiveIfNeeded() else { return }
        guard !viewModel.showScanner else { return }
        viewModel.showScannerUI()
    }

    /// Prominent camera / capture entry — hoisted to the **leading** bar on compact iPhone so it is never crowded
    /// out by segmented controls in the trailing group.
    @ViewBuilder
    private func scanCaptureToolbarButton() -> some View {
        Button {
            viewModel.showScannerUI()
        } label: {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 22, height: 22)
            } else {
                Label("Scan", systemImage: "camera.fill")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(brandAccent)
        .controlSize(.regular)
        .disabled(viewModel.isScanning)
        .accessibilityLabel("Scan or capture receipt")
        .accessibilityHint("Opens the camera and import sheet.")
    }

    private func delete(at offsets: IndexSet, from list: [Receipt]) {
        let now = Date()
        for index in offsets {
            list[index].trashedAt = now
        }
        try? modelContext.save()
    }

    private func moveSelectionToTrash(from sorted: [Receipt]) {
        let now = Date()
        for receipt in sorted where selection.contains(receipt.id) {
            receipt.trashedAt = now
        }
        selection.removeAll()
        bulkMode = .off
        try? modelContext.save()
    }

    private func emptyLibraryBodyCopy(isMac: Bool) -> String {
        if let c = cabinetFilter {
            return "No receipts are filed to \(c.title) yet. File items from Review, or choose another cabinet."
        }
        return isMac
            ? "Tap Import to add your first receipt (drag-and-drop in the import window). Use Review when you are ready to file items into your library."
            : "Tap Scan to add your first receipt, then open the Review tab to file it into your library."
    }

    private var emptyLibraryOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 64))
                .foregroundStyle(brandAccent.opacity(0.9))

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(cabinetFilter.map { "No \($0.title) receipts" } ?? "No Receipts")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(Color.ratioVitaAdaptiveText)

                Group {
                    #if os(macOS)
                    Text(emptyLibraryBodyCopy(isMac: true))
                    #else
                    Text(emptyLibraryBodyCopy(isMac: false))
                    #endif
                }
                .font(DesignSystem.Typography.body)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }

    private var emptyScopeFilterOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 48))
                .foregroundStyle(brandAccent.opacity(0.85))
            Text("No receipts match this view")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text(
                "Try setting the Business / Personal filter to All, clear the search field, or pick another cabinet."
            )
            .font(DesignSystem.Typography.body)
            .foregroundStyle(Color.ratioVitaTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(DesignSystem.Spacing.xl)
    }

    private var emptyContactFilterOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 48))
                .foregroundStyle(brandAccent.opacity(0.85))
            Text("No receipts for this contact")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text("Nothing in the library is linked to this contact yet, or this cabinet excludes those items.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            Button("Clear contact filter") {
                libraryNavigationCoordinator.clearReceiptsContactFilter()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignSystem.Spacing.xl)
    }

    private func passesTaxUseFilter(_ receipt: Receipt) -> Bool {
        let mode = ReceiptLibraryTaxUseFilter(rawValue: taxUseFilterRaw) ?? .all
        switch mode {
            case .all: return true
            case .business:
                if receipt.productionProject != nil { return true }
                if let p = receipt.businessUsePercent, p > 0 { return true }
                return false
            case .personal:
                let hasBusinessContext = receipt.productionProject != nil
                    || ((receipt.businessUsePercent ?? 0) > 0)
                return !hasBusinessContext
        }
    }

    @ViewBuilder
    private func toolbarControls(
        sorted: [Receipt],
        placement: ToolbarPlacementKind,
        includeScanButton: Bool = true
    ) -> some View {
        #if os(macOS)
        macOSToolbarControls(sorted: sorted, placement: placement)
        #else
        legacyNonMacToolbarControls(sorted: sorted, placement: placement, includeScanButton: includeScanButton)
        #endif
    }

    #if os(macOS)
    /// Finder-style trailing toolbar: view modes, group/sort, share, tags, overflow (per Apple HIG toolbars).
    @ViewBuilder
    private func macOSToolbarControls(sorted: [Receipt], placement _: ToolbarPlacementKind) -> some View {
        if showsFinderChrome {
            if navReceiptPath.isEmpty {
                Picker("Library scope", selection: $taxUseFilterRaw) {
                    ForEach(ReceiptLibraryTaxUseFilter.allCases) { mode in
                        Text(mode.menuTitle).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 228)
                .help("Business: production project or business-use % > 0. Personal: neither.")
            }

            if navReceiptPath.isEmpty, showsArcticVaultChrome {
                Toggle("Arctic", isOn: $arcticExplorerEnabled)
                    .help("Merchant-first folders in the main library")
                Button {
                    showNewArcticFolderSheet = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New Arctic folder")
                Menu {
                    Button("Clear scan target") { libraryScanVaultPathPrefix = "" }
                    ForEach(arcticRootFolders, id: \.id) { f in
                        Button("Scan into \(f.title)") {
                            libraryScanVaultPathPrefix = f.canonicalVaultPrefix
                        }
                    }
                } label: {
                    Image(systemName: "camera.viewfinder")
                }
                .help("Where new captures file")
            }

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
            .accessibilityHint("Show items as icons, in a list, in columns, or in a gallery.")

            if usesResizableThumbnails {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: clampedIconThumbnailBinding, in: 48...128, step: 4)
                        .frame(width: 140)
                    Image(systemName: "photo.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Thumbnail size")
            }

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
            .accessibilityLabel("Group and sort")
            .accessibilityHint("Sort receipts")
        }

        Button {
            if bulkMode == .export {
                bulkMode = .off
                selection.removeAll()
            } else {
                selection.removeAll()
                bulkMode = .export
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help("Select multiple receipts to export as PDF or CSV")

        Menu {
            NavigationLink {
                ReceiptReviewView()
            } label: {
                Group {
                    if pendingReviewReceipts.isEmpty {
                        Label("Review", systemImage: "tray.full")
                    } else {
                        Label("Review", systemImage: "tray.full")
                            .badge(pendingReviewReceipts.count)
                    }
                }
            }

            NavigationLink {
                ReceiptsArcticZoomView()
            } label: {
                Label("Arctic archive", systemImage: "square.grid.3x3.fill")
            }

            NavigationLink {
                ReceiptTrashView()
            } label: {
                Group {
                    if trashedReceipts.isEmpty {
                        Label("Trash", systemImage: "trash")
                    } else {
                        Label("Trash", systemImage: "trash")
                            .badge(trashedReceipts.count)
                    }
                }
            }

            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            if bulkMode == .export, !selection.isEmpty {
                Button("Export PDF…") { exportPDFSelected(from: sorted) }
                Button("Export CSV…") { exportCSVSelected(from: sorted) }
                Button("Email selection…") {
                    let picked = sorted.filter { selection.contains($0.id) }
                    ReceiptSelectionMailer.presentEmailComposer(for: picked)
                }
                Divider()
            }

            Button(bulkMode == .trash ? "Done Selecting" : "Select for Trash…") {
                if bulkMode == .trash {
                    bulkMode = .off
                    selection.removeAll()
                } else {
                    selection.removeAll()
                    bulkMode = .trash
                }
            }

            Button("Move Selected to Trash") {
                moveSelectionToTrash(from: sorted)
            }
            .disabled(selection.isEmpty || bulkMode != .trash)

            Divider()

            Button {
                viewModel.showScannerUI()
            } label: {
                Label("Import…", systemImage: "square.and.arrow.down.on.square")
            }
            .disabled(viewModel.isScanning)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
        .help("More actions")
    }
    #endif

    @ViewBuilder
    private func legacyNonMacToolbarControls(
        sorted: [Receipt],
        placement: ToolbarPlacementKind,
        includeScanButton: Bool = true
    ) -> some View {
        if showsFinderChrome {
            #if os(iOS) || os(visionOS)
            if includeScanButton {
                Button {
                    viewModel.showScannerUI()
                } label: {
                    if viewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 20, height: 20)
                    } else {
                        Label("Scan", systemImage: "camera.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(brandAccent)
                .controlSize(placement == .compact ? .regular : .regular)
                .disabled(viewModel.isScanning)
                .accessibilityHint("Capture with camera or import files")
            }
            #endif
            if navReceiptPath.isEmpty {
                Picker("Library scope", selection: $taxUseFilterRaw) {
                    ForEach(ReceiptLibraryTaxUseFilter.allCases) { mode in
                        Text(mode.menuTitle).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: placement == .regular ? 228 : 200)
                .help("Business: production project or business-use % > 0. Personal: neither.")
            }

            if navReceiptPath.isEmpty, showsArcticVaultChrome {
                Menu {
                    Toggle("Arctic explorer", isOn: $arcticExplorerEnabled)
                    Button("New folder…") { showNewArcticFolderSheet = true }
                    Divider()
                    Button("Clear scan target") { libraryScanVaultPathPrefix = "" }
                    ForEach(arcticRootFolders, id: \.id) { f in
                        Button("Scan into \(f.title)") {
                            libraryScanVaultPathPrefix = f.canonicalVaultPrefix
                        }
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .accessibilityLabel("Arctic vault folders")
            }

            Picker("View", selection: viewModeBinding) {
                ForEach(ReceiptLibraryViewMode.allCases) { mode in
                    Image(systemName: mode.systemImage)
                        .accessibilityLabel(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: placement == .regular ? 220 : 160)
            .accessibilityHint("Show items as icons, in a list, in columns, or in a gallery.")

            if usesResizableThumbnails {
                Slider(value: clampedIconThumbnailBinding, in: 48...128, step: 4)
                    .frame(maxWidth: placement == .regular ? 160 : 120)
            }

            Menu {
                Picker("Sort", selection: sortBinding) {
                    ForEach(ReceiptLibrarySort.allCases) { option in
                        Text(option.menuTitle).tag(option)
                    }
                }
                Divider()
                Toggle("2+ pages only", isOn: $multiPageOnly)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .accessibilityHint("Sort receipts")
        }

        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "gearshape")
        }
        .help("Settings")

        NavigationLink {
            ReceiptTrashView()
        } label: {
            Group {
                if trashedReceipts.isEmpty {
                    Label("Trash", systemImage: "trash")
                } else {
                    Label("Trash", systemImage: "trash")
                        .badge(trashedReceipts.count)
                }
            }
        }
        .help("Recover or permanently delete items")

        Button {
            if bulkMode == .export {
                bulkMode = .off
                selection.removeAll()
            } else {
                selection.removeAll()
                bulkMode = .export
            }
        } label: {
            Label(bulkMode == .export ? "Done" : "Share", systemImage: "square.and.arrow.up")
        }
        .help("Select multiple receipts to export as PDF or CSV")

        if bulkMode == .export, !selection.isEmpty {
            Menu {
                Button("Export PDF…") { exportPDFSelected(from: sorted) }
                Button("Export CSV…") { exportCSVSelected(from: sorted) }
                Button("Email selection…") {
                    let picked = sorted.filter { selection.contains($0.id) }
                    ReceiptSelectionMailer.presentEmailComposer(for: picked)
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.down.on.square")
            }
        }

        Button(bulkMode == .trash ? "Done" : "Select") {
            if bulkMode == .trash {
                bulkMode = .off
                selection.removeAll()
            } else {
                selection.removeAll()
                bulkMode = .trash
            }
        }

        Button("Move to Trash") {
            moveSelectionToTrash(from: sorted)
        }
        .disabled(selection.isEmpty || bulkMode != .trash)

        NavigationLink {
            ReceiptReviewView()
        } label: {
            Group {
                if pendingReviewReceipts.isEmpty {
                    Label("Review", systemImage: "tray.full")
                } else {
                    Label("Review", systemImage: "tray.full")
                        .badge(pendingReviewReceipts.count)
                }
            }
        }
        .help("Receipts waiting for review")

        NavigationLink {
            ReceiptsArcticZoomView()
        } label: {
            Label("Arctic archive", systemImage: "square.grid.3x3.fill")
        }
        .help("Browse filed receipts by year, month, and day")

        Button {
            viewModel.showScannerUI()
        } label: {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 20, height: 20)
            } else {
                Label("Import", systemImage: "square.and.arrow.down.on.square")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(brandAccent)
        .controlSize(.regular)
        .disabled(viewModel.isScanning)
        .help("Import or drop receipt images and PDFs")
    }

    private enum ToolbarPlacementKind {
        case compact
        case regular
    }

    private var samplesMenu: some View {
        Menu {
            Button("Seed random samples") {
                SampleSeed.insertSamples(into: modelContext)
            }
            Menu("Import 2020 bundle") {
                Button("Smoke (10 files)") {
                    Task { await viewModel.importBundledHistoricalArchive(limit: 10) }
                }
                Button("All (every synced file)") {
                    Task { await viewModel.importBundledHistoricalArchive(limit: nil) }
                }
            }
        } label: {
            Label("Samples", systemImage: "square.stack.3d.down.right")
        }
    }

    // MARK: - Arctic Vault (merchant → year → month)

    @ViewBuilder
    private func arcticVaultScanTargetBanner() -> some View {
        let t = libraryScanVaultPathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(brandAccent)
                (
                    Text("Next capture files to ") +
                        Text("/\(t.trimmingCharacters(in: CharacterSet(charactersIn: "/")))").fontWeight(.semibold) +
                        Text(" (Arctic prefix).")
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
                Spacer(minLength: 8)
                Button("Clear") {
                    libraryScanVaultPathPrefix = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 8)
            .background(Color.ratioVitaAdaptiveSurface)
        }
    }

    private func arcticBreadcrumbTapped(_ index: Int) {
        let titles = arcticPhase.breadcrumbTitles
        if index == titles.count - 1, titles.count > 1 {
            switch arcticPhase {
                case .vendorRoot:
                    return
                case .merchantYears:
                    return
                case let .merchantYear(key, display, _):
                    arcticPhase = .merchantYears(merchantKey: key, displayMerchant: display)
                    return
                case let .merchantYearMonth(key, display, year, _):
                    arcticPhase = .merchantYear(merchantKey: key, displayMerchant: display, year: year)
                    return
            }
        }

        switch arcticPhase {
            case .vendorRoot:
                break
            case .merchantYears:
                if index == 0 { arcticPhase = .vendorRoot }
            case let .merchantYear(key, display, _):
                if index == 0 { arcticPhase = .vendorRoot }
                else if index == 1 { arcticPhase = .merchantYears(merchantKey: key, displayMerchant: display) }
            case let .merchantYearMonth(key, display, year, _):
                if index == 0 { arcticPhase = .vendorRoot }
                else if index == 1 { arcticPhase = .merchantYears(merchantKey: key, displayMerchant: display) }
                else if index == 2 {
                    arcticPhase = .merchantYear(merchantKey: key, displayMerchant: display, year: year)
                }
        }
    }

    @ViewBuilder
    private func receiptNavigationRow(_ receipt: Receipt) -> some View {
        Group {
            if bulkMode == .off {
                NavigationLink(value: receipt.id) {
                    ReceiptRowView(receipt: receipt)
                }
            } else {
                NavigationLink(value: receipt.id) {
                    ReceiptRowView(receipt: receipt)
                }
                .tag(receipt.id)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: DesignSystem.Spacing.xs,
            leading: DesignSystem.Spacing.md,
            bottom: DesignSystem.Spacing.xs,
            trailing: DesignSystem.Spacing.md
        ))
        .frame(minHeight: 52, alignment: .center)
        .contextMenu {
            if showsArcticVaultChrome {
                Button("Clear Arctic path prefix") {
                    receipt.vaultPathPrefix = nil
                    try? modelContext.save()
                }
                if !arcticRootFolders.isEmpty {
                    Menu("Set Arctic prefix…") {
                        ForEach(arcticRootFolders, id: \.id) { folder in
                            Button(folder.title) {
                                receipt.vaultPathPrefix = folder.canonicalVaultPrefix
                                FilingCoordinator.appendAudit(
                                    context: modelContext,
                                    kindRaw: FilingCoordinator.auditKindReceiptRefiled,
                                    title: "Receipt filing path updated",
                                    detail: "rid:\(receipt.id.uuidString)"
                                )
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func finderLibrarySurface(sortedReceipts: [Receipt], emptyUsesLibrary: Bool) -> some View {
        FinderReceiptSurfaceBrowser(
            sortedReceipts: sortedReceipts,
            viewMode: viewModeBinding,
            bulkMode: $bulkMode,
            selection: $selection,
            bulkInteractionEnabled: true,
            selectedProjectColumn: $selectedProjectColumn,
            galleryFocusedId: $galleryFocusedId,
            onDelete: { idx, list in delete(at: idx, from: list) },
            listRow: { receipt in
                receiptNavigationRow(receipt)
            }
        )
        .background(Color.ratioVitaAdaptiveBackground)
        .overlay {
            if sortedReceipts.isEmpty {
                if emptyUsesLibrary, receipts.isEmpty {
                    emptyLibraryOverlay
                } else if showsContactFilterBanner, receiptsForLibraryList.isEmpty {
                    emptyContactFilterOverlay
                } else if emptyUsesLibrary {
                    emptyScopeFilterOverlay
                } else {
                    ContentUnavailableView(
                        "No receipts",
                        systemImage: "tray",
                        description: Text("Nothing filed in this slice yet.")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func customArcticFolderColumn(folder: ArcticVaultFolder, sorted: [Receipt]) -> some View {
        let prefix = folder.canonicalVaultPrefix
        let subset = sorted.filter { r in
            let rp = (r.vaultPathPrefix ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let p = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return rp == p || rp.hasPrefix(p + "/")
        }
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                browsingCustomFolder = nil
            } label: {
                Label("Back", systemImage: "chevron.backward")
            }
            .buttonStyle(.bordered)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.title)
                    .font(DesignSystem.Typography.headline)
                Text(folder.canonicalVaultPrefix)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Menu {
                Button("Use as scan target") {
                    libraryScanVaultPathPrefix = prefix
                }
                Button("Clear scan target") {
                    libraryScanVaultPathPrefix = ""
                }
            } label: {
                Label("Scan", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, 8)
        finderLibrarySurface(sortedReceipts: subset, emptyUsesLibrary: true)
    }

    @ViewBuilder
    private func arcticVendorRootGrid(sorted: [Receipt]) -> some View {
        let buckets = ArcticVaultExplorerModel.vendorBuckets(from: sorted)
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                    ForEach(buckets) { bucket in
                        Button {
                            arcticPhase = .merchantYears(
                                merchantKey: bucket.merchantKey,
                                displayMerchant: bucket.displayTitle
                            )
                        } label: {
                            ArcticVendorFolderTile(
                                title: bucket.displayTitle,
                                count: bucket.receipts.count,
                                systemImage: "building.2.crop.circle"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !arcticRootFolders.isEmpty {
                    Text("Your folders")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(Color.ratioVitaAdaptiveText)
                        .padding(.top, 4)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                        ForEach(arcticRootFolders, id: \.id) { folder in
                            Button {
                                browsingCustomFolder = folder
                            } label: {
                                ArcticVendorFolderTile(
                                    title: folder.title,
                                    count: receiptCount(withVaultPrefix: folder.canonicalVaultPrefix, in: sorted),
                                    systemImage: folder.sfSymbolName ?? "folder.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    @ViewBuilder
    private func arcticYearGrid(merchantKey: String, displayMerchant: String, sorted: [Receipt]) -> some View {
        let years = ArcticVaultExplorerModel.years(for: merchantKey, receipts: sorted)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(years, id: \.self) { y in
                    Button {
                        arcticPhase = .merchantYear(
                            merchantKey: merchantKey,
                            displayMerchant: displayMerchant,
                            year: y
                        )
                    } label: {
                        Text(String(y))
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.ratioVitaAdaptiveSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    @ViewBuilder
    private func arcticMonthGrid(
        merchantKey: String,
        displayMerchant: String,
        year: Int,
        sorted: [Receipt]
    ) -> some View {
        let months = ArcticVaultExplorerModel.monthSymbols(for: merchantKey, year: year, receipts: sorted)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(months, id: \.self) { mo in
                    Button {
                        arcticPhase = .merchantYearMonth(
                            merchantKey: merchantKey,
                            displayMerchant: displayMerchant,
                            year: year,
                            monthSymbol: mo
                        )
                    } label: {
                        Text(mo)
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.ratioVitaAdaptiveSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    @ViewBuilder
    private func arcticMainLibraryColumn(sorted: [Receipt]) -> some View {
        VStack(spacing: 0) {
            arcticVaultScanTargetBanner()
            if let folder = browsingCustomFolder {
                customArcticFolderColumn(folder: folder, sorted: sorted)
            } else {
                ArcticVaultBreadcrumbBar(phase: arcticPhase) { idx in
                    arcticBreadcrumbTapped(idx)
                }
                Group {
                    switch arcticPhase {
                        case .vendorRoot:
                            arcticVendorRootGrid(sorted: sorted)
                        case let .merchantYears(key, display):
                            arcticYearGrid(merchantKey: key, displayMerchant: display, sorted: sorted)
                        case let .merchantYear(key, display, year):
                            arcticMonthGrid(merchantKey: key, displayMerchant: display, year: year, sorted: sorted)
                        case let .merchantYearMonth(key, _, year, mo):
                            finderLibrarySurface(
                                sortedReceipts: ArcticVaultExplorerModel.receipts(
                                    merchantKey: key,
                                    year: year,
                                    monthSymbol: mo,
                                    in: sorted
                                ),
                                emptyUsesLibrary: false
                            )
                    }
                }
            }
        }
        #if !os(macOS)
        .searchable(text: $searchText, placement: .automatic, prompt: "Search")
        #endif
    }

    private func exportPDFSelected(from sorted: [Receipt]) {
        let picked = sorted.filter { selection.contains($0.id) }
        Task {
            do {
                let url = try ReceiptBatchExport.makeCombinedPDF(receipts: picked)
                await MainActor.run {
                    exportShareItem = ExportSharePayload(url: url)
                }
            } catch {
                await MainActor.run {
                    UserMessageCenter.shared.present(
                        title: "Export failed",
                        message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    )
                }
            }
        }
    }

    private func exportCSVSelected(from sorted: [Receipt]) {
        let picked = sorted.filter { selection.contains($0.id) }
        Task {
            do {
                let url = try ReceiptBatchExport.makeCSV(receipts: picked)
                await MainActor.run {
                    exportShareItem = ExportSharePayload(url: url)
                }
            } catch {
                await MainActor.run {
                    UserMessageCenter.shared.present(
                        title: "Export failed",
                        message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    )
                }
            }
        }
    }
}

// MARK: - Share payload

private struct ExportSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Icon cell (Finder-style density)

struct ReceiptIconCellView: View {
    @Environment(\.brandAccent) private var brandAccent
    @AppStorage("libraryIconThumbnailSize") private var libraryIconThumbnailSize: Double = 64
    let receipt: Receipt

    private var thumbDimension: CGFloat {
        CGFloat(min(128, max(48, libraryIconThumbnailSize)))
    }

    var body: some View {
        let tw = thumbDimension
        let th = thumbDimension
        VStack(spacing: 3) {
            thumbnail(width: tw, height: th)
            Text(receipt.merchant)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.ratioVitaAdaptiveText)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text(formattedTotal(receipt))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(brandAccent)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: tw, alignment: .top)
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func thumbnail(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let firstImage = receipt.firstImage {
                Image(rvImage: firstImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveBorder.opacity(0.35))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "doc.text.image")
                            .font(.caption2)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.4), lineWidth: 1)
        )
    }

    private func formattedTotal(_ receipt: Receipt) -> String {
        CurrencyFormatter.shared.format(receipt.total, currencyCode: receipt.currencyCode)
    }
}

// MARK: - Receipt Row View

struct ReceiptRowView: View {
    @Environment(\.brandAccent) private var brandAccent
    let receipt: Receipt

    var body: some View {
        #if os(macOS)
        macOSRow
        #else
        iOSPadRow
        #endif
    }

    private var macOSRow: some View {
        HStack(alignment: .center, spacing: 10) {
            macOSThumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchant)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text((receipt.transactionDate ?? receipt.createdAt).formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(formattedTotal(receipt))
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.ratioVitaSignedCurrencyAmount(receipt.total))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .frame(minHeight: 56, alignment: .center)
    }

    @ViewBuilder
    private var macOSThumbnail: some View {
        Group {
            if let firstImage = receipt.firstImage {
                Image(rvImage: firstImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "doc.text.image")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var iOSPadRow: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [brandAccent, brandAccent.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 56)
                .accessibilityHidden(true)

            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(receipt.merchant)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)

                Text((receipt.transactionDate ?? receipt.createdAt).formatted(date: .abbreviated, time: .shortened))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .lineLimit(1)

                if let notes = receipt.notes, !notes.isEmpty {
                    Text(notes)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(Color.ratioVitaTextSecondary.opacity(0.95))
                        .lineLimit(1)
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    if receipt.isLedgerLinked {
                        StatusBadge.info("Linked")
                    } else if receipt.isVerified {
                        StatusBadge.success("Verified")
                    }
                    if receipt.images.count > 1 {
                        StatusBadge.info("\(receipt.images.count) pages")
                    }
                    if receipt.images.contains(where: { !($0.ocrText ?? "").isEmpty }) {
                        StatusBadge.success("OCR")
                    }
                    if receipt.businessUseVerifiedByTimeSheet {
                        StatusBadge.info("Time sheet")
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTotal(receipt))
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.ratioVitaSignedCurrencyAmount(receipt.total))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(receipt.currencyCode)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 56, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.55), lineWidth: 1)
        )
        .shadow(DesignSystem.Shadow.small)
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let firstImage = receipt.firstImage {
                Image(rvImage: firstImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveBorder.opacity(0.35))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "doc.text.image")
                            .font(.title3)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }

    private func formattedTotal(_ receipt: Receipt) -> String {
        let formatter = CurrencyFormatter.shared
        return formatter.format(receipt.total, currencyCode: receipt.currencyCode)
    }
}

#Preview("ReceiptsView") {
    NavigationStack {
        ReceiptsView()
    }
    .environment(LibraryNavigationCoordinator())
    .modelContainer(SampleData.previewContainer)
}
