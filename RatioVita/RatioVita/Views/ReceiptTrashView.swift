//
//  ReceiptTrashView.swift
//  RatioVita
//
//  Soft-deleted receipts: recover to the library or erase permanently.
//

import SwiftData
import SwiftUI

struct ReceiptTrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("receiptTrashSortRaw") private var sortRaw: String = ReceiptLibrarySort.dateAddedNewest.rawValue
    @AppStorage("receiptTrashViewModeRaw") private var viewModeRaw: String = ReceiptLibraryViewMode.list.rawValue

    @Query(
        filter: #Predicate<Receipt> { $0.trashedAt != nil },
        sort: \Receipt.createdAt,
        order: .reverse,
        animation: .default
    )
    private var trashedReceipts: [Receipt]

    @State private var selection: Set<UUID> = []
    @State private var trashBulkMode: ReceiptLibraryBulkMode = .off
    @State private var confirmEmptyTrash = false
    @State private var searchText = ""
    @State private var selectedProjectColumn: String = "General"
    @State private var galleryFocusedId: UUID?
    @State private var navReceiptPath: [UUID] = []
    @State private var forwardReceiptPath: [UUID] = []

    @ViewBuilder
    private func trashMainColumn(sorted: [Receipt]) -> some View {
        VStack(spacing: 0) {
            header
            if trashedReceipts.isEmpty {
                emptyState
            } else {
                FinderReceiptSurfaceBrowser(
                    sortedReceipts: sorted,
                    viewMode: viewModeBinding,
                    bulkMode: $trashBulkMode,
                    selection: $selection,
                    bulkInteractionEnabled: true,
                    selectedProjectColumn: $selectedProjectColumn,
                    galleryFocusedId: $galleryFocusedId,
                    onDelete: { idx, list in deleteForever(at: idx, from: list) },
                    listRow: { receipt in
                        trashListRow(receipt: receipt)
                    }
                )
                .background(Color.ratioVitaAdaptiveBackground)
            }
        }
    }

    @ViewBuilder
    private func trashListRow(receipt: Receipt) -> some View {
        Group {
            if trashBulkMode == .off {
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
    }

    var body: some View {
        let filtered = FinderReceiptSortEngine.filtered(trashedReceipts, searchText: searchText)
        let librarySort = ReceiptLibrarySort(rawValue: sortRaw) ?? .dateAddedNewest
        let sorted = FinderReceiptSortEngine.sorted(filtered, by: librarySort)

        NavigationStack(path: $navReceiptPath) {
            trashMainColumn(sorted: sorted)
                .navigationTitle(finderNavTitle(sorted: sorted))
                .navigationDestination(for: UUID.self) { id in
                    ReceiptDetailByIDView(receiptID: id)
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
                trashToolbarControls(placement: .compact)
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                trashToolbarControls(placement: .regular)
            }
            #if os(macOS)
            ToolbarItem(placement: .automatic) {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            #endif
            #endif
        }
        .onAppear {
            FinderReceiptSortEngine.syncColumnSelection(selected: &selectedProjectColumn, sorted: sorted)
            FinderReceiptSortEngine.syncGalleryFocus(focused: &galleryFocusedId, sorted: sorted)
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
        .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
        .confirmationDialog(
            "Empty Trash (\(trashedReceipts.count) receipt(s))?",
            isPresented: $confirmEmptyTrash,
            titleVisibility: .visible
        ) {
            Button("Delete forever", role: .destructive) {
                emptyTrashPermanently()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every receipt in Trash. You cannot undo it.")
        }
    }

    private var showsFinderChrome: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass != .compact
        #endif
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
        guard let last = navReceiptPath.last else { return "Trash" }
        if let r = sorted.first(where: { $0.id == last }) ?? trashedReceipts.first(where: { $0.id == last }) {
            return r.merchant
        }
        return "Trash"
    }

    private func goBackNavigation() {
        guard let last = navReceiptPath.popLast() else { return }
        forwardReceiptPath.append(last)
    }

    private func goForwardNavigation() {
        guard let id = forwardReceiptPath.popLast() else { return }
        navReceiptPath.append(id)
    }

    private enum ToolbarPlacementKind {
        case compact
        case regular
    }

    @ViewBuilder
    private func trashToolbarControls(placement: ToolbarPlacementKind) -> some View {
        #if os(macOS)
        trashMacToolbarControls(placement: placement)
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
    private func trashMacToolbarControls(placement _: ToolbarPlacementKind) -> some View {
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
        }

        Menu {
            Button("Email selection…") {
                let picked = trashedReceipts.filter { selection.contains($0.id) }
                ReceiptSelectionMailer.presentEmailComposer(for: picked)
            }
            .disabled(selection.isEmpty)
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuIndicator(.hidden)

        Menu {
            Button("Assign Tags…") {}
                .disabled(true)
        } label: {
            Image(systemName: "tag")
        }
        .menuIndicator(.hidden)

        Menu {
            Button(trashBulkMode == .off ? "Select…" : "Done Selecting") {
                if trashBulkMode == .off {
                    trashBulkMode = .trash
                } else {
                    trashBulkMode = .off
                    selection.removeAll()
                }
            }

            Button("Recover selected (\(selection.count))") {
                recoverSelected()
            }
            .disabled(selection.isEmpty || trashBulkMode == .off)

            Button("Empty Trash…", role: .destructive) {
                confirmEmptyTrash = true
            }
            .disabled(trashedReceipts.isEmpty)

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
        #if os(macOS)
        HStack(spacing: 10) {
            Text("Deleted items stay here until you recover or erase them.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        #else
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Receipts you remove from the library or review land here. Recover them or delete forever.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(Color.ratioVitaTextSecondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                Button(trashBulkMode == .off ? "Select" : "Done") {
                    if trashBulkMode == .off {
                        trashBulkMode = .trash
                    } else {
                        trashBulkMode = .off
                        selection.removeAll()
                    }
                }
                .buttonStyle(.bordered)

                Button("Recover selected (\(selection.count))") {
                    recoverSelected()
                }
                .buttonStyle(.borderedProminent)
                .tint(brandAccent)
                .disabled(selection.isEmpty || trashBulkMode == .off)

                Spacer()

                Button("Empty Trash…", role: .destructive) {
                    confirmEmptyTrash = true
                }
                .disabled(trashedReceipts.isEmpty)
            }
        }
        .padding(DesignSystem.Spacing.md)
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "trash")
                .font(.system(size: 48))
                .foregroundStyle(brandAccent.opacity(0.85))
            Text("Trash is empty")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text("Deleted receipts will appear here so you can recover them if needed.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func recoverSelected() {
        for id in selection {
            guard let r = trashedReceipts.first(where: { $0.id == id }) else { continue }
            r.trashedAt = nil
        }
        selection.removeAll()
        trashBulkMode = .off
        try? modelContext.save()
    }

    private func deleteForever(at offsets: IndexSet, from list: [Receipt]) {
        for index in offsets {
            try? ReceiptPermanentDeletion.deletePermanently(
                list[index],
                modelContext: modelContext,
                verifiedReason: "Deleted from Trash",
                verifiedAuthorizedBy: "In-app trash action"
            )
        }
        selection.removeAll()
    }

    private func emptyTrashPermanently() {
        let snap = trashedReceipts
        for r in snap {
            try? ReceiptPermanentDeletion.deletePermanently(
                r,
                modelContext: modelContext,
                verifiedReason: "Empty Trash",
                verifiedAuthorizedBy: "In-app trash action"
            )
        }
        selection.removeAll()
        trashBulkMode = .off
    }
}

#Preview("ReceiptTrashView") {
    ReceiptTrashView()
        .modelContainer(SampleData.previewContainer)
}
