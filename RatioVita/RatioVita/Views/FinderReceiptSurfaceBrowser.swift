import SwiftUI

/// Shared Finder-style browsing (list / icon / column / gallery) for library, review, and trash surfaces.
struct FinderReceiptSurfaceBrowser<ListRow: View>: View {
    @Environment(\.brandAccent) private var brandAccent
    @AppStorage("libraryIconThumbnailSize") private var libraryIconThumbnailSize: Double = 64

    let sortedReceipts: [Receipt]
    @Binding var viewMode: ReceiptLibraryViewMode
    @Binding var bulkMode: ReceiptLibraryBulkMode
    @Binding var selection: Set<UUID>
    /// When false, bulk selection UI is suppressed (always browse with links).
    var bulkInteractionEnabled: Bool

    @Binding var selectedProjectColumn: String
    @Binding var galleryFocusedId: UUID?

    @State private var pinchBaseLibraryIconSize: Double?

    @ViewBuilder let listRow: (Receipt) -> ListRow

    var onDelete: ((IndexSet, [Receipt]) -> Void)?

    init(
        sortedReceipts: [Receipt],
        viewMode: Binding<ReceiptLibraryViewMode>,
        bulkMode: Binding<ReceiptLibraryBulkMode>,
        selection: Binding<Set<UUID>>,
        bulkInteractionEnabled: Bool,
        selectedProjectColumn: Binding<String>,
        galleryFocusedId: Binding<UUID?>,
        onDelete: ((IndexSet, [Receipt]) -> Void)? = nil,
        @ViewBuilder listRow: @escaping (Receipt) -> ListRow
    ) {
        self.sortedReceipts = sortedReceipts
        _viewMode = viewMode
        _bulkMode = bulkMode
        _selection = selection
        self.bulkInteractionEnabled = bulkInteractionEnabled
        _selectedProjectColumn = selectedProjectColumn
        _galleryFocusedId = galleryFocusedId
        self.onDelete = onDelete
        self.listRow = listRow
    }

    var body: some View {
        Group {
            switch viewMode {
                case .list:
                    listSection
                case .icon:
                    iconSection
                case .column:
                    columnSection
                case .gallery:
                    gallerySection
            }
        }
    }

    private var effectiveBulk: ReceiptLibraryBulkMode {
        bulkInteractionEnabled ? bulkMode : .off
    }

    @ViewBuilder
    private var listSection: some View {
        if effectiveBulk == .off {
            if let onDelete {
                List {
                    ForEach(sortedReceipts) { receipt in
                        listRow(receipt)
                    }
                    .onDelete { idx in
                        onDelete(idx, sortedReceipts)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                List {
                    ForEach(sortedReceipts) { receipt in
                        listRow(receipt)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        } else {
            List(selection: $selection) {
                ForEach(sortedReceipts) { receipt in
                    listRow(receipt)
                        .tag(receipt.id)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var iconCellPoints: CGFloat {
        RatioVitaWindowSizing.clampedDimension(
            CGFloat(libraryIconThumbnailSize),
            min: 48,
            max: 128,
            fallback: 64
        )
    }

    private var iconGridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: iconCellPoints, maximum: iconCellPoints), spacing: 16, alignment: .center),
        ]
    }

    @ViewBuilder
    private var iconSection: some View {
        ScrollView {
            LazyVGrid(columns: iconGridColumns, spacing: 16) {
                ForEach(sortedReceipts) { receipt in
                    Group {
                        if effectiveBulk == .off {
                            NavigationLink(value: receipt.id) {
                                ReceiptIconCellView(receipt: receipt)
                                    .frame(width: iconCellPoints, height: iconCellPoints + 24, alignment: .top)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                toggleSelection(receipt.id)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    ReceiptIconCellView(receipt: receipt)
                                        .frame(width: iconCellPoints, height: iconCellPoints + 24, alignment: .top)
                                    if selection.contains(receipt.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, brandAccent)
                                            .padding(4)
                                            .font(.caption)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .simultaneousGesture(libraryPinchToZoomThumbnailGesture())
    }

    private func libraryPinchToZoomThumbnailGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchBaseLibraryIconSize == nil {
                    pinchBaseLibraryIconSize = libraryIconThumbnailSize
                }
                guard let start = pinchBaseLibraryIconSize else { return }
                let scaled = start * Double(value.magnification)
                let next = min(128, max(48, scaled))
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    libraryIconThumbnailSize = next
                }
            }
            .onEnded { _ in
                pinchBaseLibraryIconSize = nil
                let stepped = (libraryIconThumbnailSize / 4).rounded() * 4
                let clamped = min(128, max(48, stepped))
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    libraryIconThumbnailSize = clamped
                }
            }
    }

    @ViewBuilder
    private var columnSection: some View {
        let titles = columnTitles(from: sortedReceipts)
        HStack(alignment: .top, spacing: 0) {
            List {
                ForEach(titles, id: \.self) { title in
                    Button {
                        selectedProjectColumn = title
                    } label: {
                        HStack {
                            Text(title)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            if title == selectedProjectColumn {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(brandAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 128, idealWidth: 168, maxWidth: 220)

            let inGroup = sortedReceipts.filter { $0.libraryColumnGroupTitle == selectedProjectColumn }
            Group {
                if effectiveBulk == .off {
                    if let onDelete {
                        List {
                            ForEach(inGroup) { receipt in
                                listRow(receipt)
                            }
                            .onDelete { idx in
                                onDelete(idx, inGroup)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    } else {
                        List {
                            ForEach(inGroup) { receipt in
                                listRow(receipt)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    List(selection: $selection) {
                        ForEach(inGroup) { receipt in
                            listRow(receipt)
                                .tag(receipt.id)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(
                maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth,
                maxHeight: SafeLayoutBounds.maxWindowHeight
            )
        }
    }

    @ViewBuilder
    private var gallerySection: some View {
        if sortedReceipts.isEmpty {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if let id = galleryFocusedId, let receipt = sortedReceipts.first(where: { $0.id == id }) {
                    NavigationLink(value: receipt.id) {
                        galleryHero(receipt: receipt)
                    }
                    .buttonStyle(.plain)
                    .frame(maxHeight: .infinity)

                    galleryStrip
                        .frame(height: max(72, iconCellPoints + 20))
                } else {
                    ContentUnavailableView("No selection", systemImage: "photo.on.rectangle.angled")
                }
            }
        }
    }

    @ViewBuilder
    private func galleryHero(receipt: Receipt) -> some View {
        ZStack {
            Color.ratioVitaAdaptiveSurface
            if let img = receipt.firstImage {
                Image(rvImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(DesignSystem.Spacing.sm)
            } else {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var galleryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sortedReceipts) { receipt in
                    Button {
                        galleryFocusedId = receipt.id
                    } label: {
                        galleryThumb(receipt: receipt, isSelected: receipt.id == galleryFocusedId)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .background(Color.ratioVitaAdaptiveBackground.opacity(0.98))
        .simultaneousGesture(libraryPinchToZoomThumbnailGesture())
    }

    @ViewBuilder
    private func galleryThumb(receipt: Receipt, isSelected: Bool) -> some View {
        let side = iconCellPoints
        ZStack(alignment: .bottomLeading) {
            if let img = receipt.firstImage {
                Image(rvImage: img)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveBorder.opacity(0.35))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: side, height: side)
                    .overlay(
                        Image(systemName: "doc.text.image")
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(
                    isSelected ? brandAccent : Color.ratioVitaAdaptiveBorder.opacity(0.45),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }

    private func columnTitles(from list: [Receipt]) -> [String] {
        Array(Set(list.map(\.libraryColumnGroupTitle))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}

enum FinderReceiptSortEngine {
    static func sorted(_ receipts: [Receipt], by sort: ReceiptLibrarySort) -> [Receipt] {
        switch sort {
            case .dateAddedNewest:
                receipts.sorted { $0.createdAt > $1.createdAt }
            case .merchantAZ:
                receipts.sorted {
                    let c = $0.merchant.localizedCaseInsensitiveCompare($1.merchant)
                    if c != .orderedSame { return c == .orderedAscending }
                    return $0.createdAt > $1.createdAt
                }
            case .totalHighToLow:
                receipts.sorted {
                    let cmp = ($0.total as NSDecimalNumber).compare($1.total as NSDecimalNumber)
                    if cmp != .orderedSame { return cmp == .orderedDescending }
                    return $0.createdAt > $1.createdAt
                }
            case .projectTitleAZ:
                receipts.sorted {
                    let p = $0.libraryColumnGroupTitle.localizedCaseInsensitiveCompare($1.libraryColumnGroupTitle)
                    if p != .orderedSame { return p == .orderedAscending }
                    return $0.createdAt > $1.createdAt
                }
        }
    }

    static func filtered(
        _ receipts: [Receipt],
        searchText: String,
        multiPageOnly: Bool = false
    ) -> [Receipt] {
        var r = receipts
        if multiPageOnly {
            r = r.filter { $0.images.count > 1 }
        }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return r
        }
        let term = searchText.lowercased()
        return r.filter { receipt in
            if receipt.merchant.lowercased().contains(term) { return true }
            if receipt.notes?.lowercased().contains(term) == true { return true }
            if receipt.images.contains(where: { ($0.ocrText?.lowercased().contains(term) ?? false) }) { return true }
            return false
        }
    }

    static func syncColumnSelection(selected: inout String, sorted: [Receipt]) {
        let titles = Array(Set(sorted.map(\.libraryColumnGroupTitle))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard !titles.isEmpty else { return }
        if !titles.contains(selected) {
            selected = titles[0]
        }
    }

    static func syncGalleryFocus(focused: inout UUID?, sorted: [Receipt]) {
        guard !sorted.isEmpty else {
            focused = nil
            return
        }
        if let id = focused, sorted.contains(where: { $0.id == id }) { return }
        focused = sorted[0].id
    }

    /// Compact list fingerprint — avoids `onChange(of: [UUID])` feedback loops during pagination.
    static func listIdentitySignature(for sorted: [Receipt]) -> String {
        guard let first = sorted.first, let last = sorted.last else { return "empty" }
        if sorted.count == 1 { return "1-\(first.id.uuidString)" }
        return "\(sorted.count)-\(first.id.uuidString)-\(last.id.uuidString)"
    }

    /// Defers column/gallery chrome sync to the next run-loop turn (prevents per-frame mutation warnings).
    static func scheduleFinderChromeSync(
        selectedProjectColumn: Binding<String>,
        galleryFocusedId: Binding<UUID?>,
        sorted: [Receipt]
    ) {
        let snapshot = sorted
        DispatchQueue.main.async {
            var column = selectedProjectColumn.wrappedValue
            var focus = galleryFocusedId.wrappedValue
            let beforeColumn = column
            let beforeFocus = focus
            syncColumnSelection(selected: &column, sorted: snapshot)
            syncGalleryFocus(focused: &focus, sorted: snapshot)
            if column != beforeColumn {
                selectedProjectColumn.wrappedValue = column
            }
            if focus != beforeFocus {
                galleryFocusedId.wrappedValue = focus
            }
        }
    }
}
