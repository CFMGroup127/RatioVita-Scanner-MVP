import SwiftData
import SwiftUI

/// Sprint D: SwiftData-backed cabinet folders with breadcrumb copy and a flat outline of the tree (Finder-style list).
struct CabinetBrowserView: View {
    let cabinet: DocumentCabinet
    @Environment(\.brandAccent) private var brandAccent
    @Environment(\.modelContext) private var modelContext

    @Query private var allFolders: [CabinetFolder]

    #if os(macOS)
    @State private var finderViewMode: ReceiptLibraryViewMode = .list
    @State private var finderSort: ReceiptLibrarySort = .merchantAZ
    #endif

    private struct FolderOutlineRow: Identifiable {
        let id: UUID
        let folder: CabinetFolder
        let depth: Int
    }

    private var roots: [CabinetFolder] {
        allFolders
            .filter { $0.cabinetKindRaw == cabinet.rawValue && $0.parent == nil }
            .sorted { $0.sortIndex < $1.sortIndex || ($0.sortIndex == $1.sortIndex && $0.title < $1.title) }
    }

    private func outlineRows() -> [FolderOutlineRow] {
        var rows: [FolderOutlineRow] = []
        func visit(_ folder: CabinetFolder, depth: Int) {
            rows.append(FolderOutlineRow(id: folder.id, folder: folder, depth: depth))
            let sortedChildren = folder.children.sorted {
                $0.sortIndex < $1.sortIndex || ($0.sortIndex == $1.sortIndex && $0.title < $1.title)
            }
            for child in sortedChildren {
                visit(child, depth: depth + 1)
            }
        }
        for root in roots {
            visit(root, depth: 0)
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Cabinets › \(cabinet.title)")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.sm)

            List {
                if roots.isEmpty {
                    ContentUnavailableView(
                        "No folders yet",
                        systemImage: cabinet.systemImage,
                        description: Text("Folders will appear here after the library finishes seeding.")
                    )
                } else {
                    ForEach(outlineRows()) { row in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(brandAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.folder.title)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text(breadcrumb(for: row.folder))
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, CGFloat(row.depth) * 14)
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ratioVitaAdaptiveBackground)
        .navigationTitle(cabinet.title)
        .task {
            try? CabinetFolder.ensureRootFoldersSeeded(modelContext: modelContext)
        }
        #if os(macOS)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    /* drill-back reserved */
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(true)
                .help("Back")

                Button {
                    /* forward reserved */
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(true)
                .help("Forward")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Picker("View", selection: $finderViewMode) {
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
                    Picker("Sort", selection: $finderSort) {
                        ForEach(ReceiptLibrarySort.allCases) { option in
                            Text(option.menuTitle).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .menuIndicator(.hidden)

                Button {
                    addSubfolderUnderFirstRoot()
                } label: {
                    Label("New subfolder", systemImage: "folder.badge.plus")
                }
                .disabled(roots.isEmpty)
                .help("Adds a folder under the first top-level row for this cabinet.")
            }
        }
        #else
        .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        addSubfolderUnderFirstRoot()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .disabled(roots.isEmpty)
                    .accessibilityLabel("New subfolder")
                }
            }
        #endif
    }

    private func breadcrumb(for folder: CabinetFolder) -> String {
        var parts: [String] = ["Cabinets", cabinet.title]
        var chain: [String] = []
        var current: CabinetFolder? = folder
        while let c = current {
            chain.insert(c.title, at: 0)
            current = c.parent
        }
        parts.append(contentsOf: chain)
        return parts.joined(separator: " › ")
    }

    private func addSubfolderUnderFirstRoot() {
        guard let root = roots.first else { return }
        let next = (root.children.map(\.sortIndex).max() ?? -1) + 1
        let child = CabinetFolder(
            title: "New folder",
            sortIndex: next,
            cabinetKindRaw: root.cabinetKindRaw,
            parent: root
        )
        modelContext.insert(child)
        try? modelContext.save()
    }
}
