import SwiftData
import SwiftUI

/// **Production registry** — active shows, networks, and shoot projects (grouped by billing entity when set).
struct ProductionRegistryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProductionProject.title) private var allProjects: [ProductionProject]
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var showAddSheet = false
    @State private var projectToRetire: ProductionProject?
    @State private var projectToDelete: ProductionProject?
    @State private var projectToPurge: ProductionProject?
    @State private var deleteReason = ""
    @State private var deleteAuthorizedBy = ""

    private var groupedAll: [(entity: String, rows: [ProductionProject])] {
        grouped(for: allProjects)
    }

    private func grouped(for projects: [ProductionProject]) -> [(entity: String, rows: [ProductionProject])] {
        let buckets = Dictionary(grouping: projects) { $0.parentBusinessGroupingTitle }
        return buckets.keys.sorted().map { key in
            let rows = (buckets[key] ?? []).sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return (entity: key, rows: rows)
        }
    }

    private var groupedActive: [(entity: String, rows: [ProductionProject])] {
        grouped(for: allProjects.filter { $0.registryStatus == .active })
    }

    private var groupedRetired: [(entity: String, rows: [ProductionProject])] {
        grouped(for: allProjects.filter { $0.registryStatus == .retired })
    }

    private var usePadRegistryColumns: Bool {
        #if os(iOS)
        horizontalSizeClass == .regular
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if usePadRegistryColumns {
                registryPadSplitView
            } else {
                registryListContent(groups: groupedAll)
            }
        }
        .navigationTitle("Production registry")
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ProductionProjectAddSheet(onDismiss: { showAddSheet = false })
            }
            .confirmationDialog(
                "Retire “\(projectToRetire?.title ?? "")”?",
                isPresented: Binding(
                    get: { projectToRetire != nil },
                    set: { if !$0 { projectToRetire = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Retire production") {
                    if let p = projectToRetire {
                        p.registryStatus = .retired
                        try? modelContext.save()
                    }
                    projectToRetire = nil
                }
                Button("Cancel", role: .cancel) {
                    projectToRetire = nil
                }
            } message: {
                Text(
                    "It disappears from daily pickers and the Timeline filter, but receipts and time sheets stay linked for your audit trail."
                )
            }
            .sheet(isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            )) {
                NavigationStack {
                    Form {
                        Section {
                            Text(
                                "Deleting a production is unusual. A tombstone will record this project and why it was removed. Linked receipts and sessions keep their data but lose this project link."
                            )
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                        }
                        Section("Audit") {
                            TextField("Reason", text: $deleteReason, axis: .vertical)
                                .lineLimit(2...5)
                            TextField("Authorized by (your name)", text: $deleteAuthorizedBy)
                        }
                        Section {
                            Button("Delete permanently", role: .destructive) {
                                performHardDelete()
                            }
                            .disabled(
                                deleteReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || deleteAuthorizedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                        }
                    }
                    .navigationTitle("Delete production")
                    #if os(iOS) || os(visionOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    projectToDelete = nil
                                    deleteReason = ""
                                    deleteAuthorizedBy = ""
                                }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
            .confirmationDialog(
                "Purge “\(projectToPurge?.title ?? "")”?",
                isPresented: Binding(
                    get: { projectToPurge != nil },
                    set: { if !$0 { projectToPurge = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete permanently", role: .destructive) {
                    performZeroLinkPurge()
                }
                Button("Cancel", role: .cancel) {
                    projectToPurge = nil
                }
            } message: {
                Text(
                    "This show has no receipts, work sessions, or crew days. It will be removed entirely with no tombstone."
                )
            }
    }

    private func performZeroLinkPurge() {
        guard let project = projectToPurge, project.hasZeroLinkedItems else {
            projectToPurge = nil
            return
        }
        modelContext.delete(project)
        try? modelContext.save()
        projectToPurge = nil
    }

    @ViewBuilder
    private func registryListContent(groups: [(entity: String, rows: [ProductionProject])]) -> some View {
        List {
            ForEach(groups, id: \.entity) { group in
                Section {
                    ForEach(group.rows) { project in
                        NavigationLink {
                            ProductionProjectRegistryDetailView(project: project)
                        } label: {
                            registryRow(project)
                        }
                    }
                } header: {
                    if group.entity.isEmpty || group.entity == "Unassigned" {
                        Text("Shows")
                    } else {
                        Text("Shows · \(group.entity)")
                    }
                } footer: {
                    if group.entity.isEmpty || group.entity == "Unassigned" {
                        EmptyView()
                    } else {
                        Text("Billing / parent entity — not the corporate GST registry.")
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private var registryPadSplitView: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Active")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(Color.ratioVitaAdaptiveSurface.opacity(0.95))
                registryListContent(groups: groupedActive)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text("Retired")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(Color.ratioVitaAdaptiveSurface.opacity(0.95))
                registryListContent(groups: groupedRetired)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func registryRow(_ project: ProductionProject) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Circle()
                .fill(swatchColor(for: project))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(DesignSystem.Typography.bodyEmphasized)
                Text(project.registryStatus.menuTitle)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(project.registryStatus == .active ? Color.secondary : Color.orange)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Retire…") {
                    projectToRetire = project
                }
                .disabled(project.registryStatus == .retired)
                if project.hasZeroLinkedItems {
                    Button("Purge (no linked items)…", role: .destructive) {
                        projectToPurge = project
                    }
                }
                Button("Delete with tombstone…", role: .destructive) {
                    projectToDelete = project
                    deleteReason = ""
                    deleteAuthorizedBy = ""
                }
                .disabled(project.hasZeroLinkedItems)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
            }
        }
    }

    private func swatchColor(for project: ProductionProject) -> Color {
        if let hex = project.timelineColorHex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty {
            return Color(hex: hex)
        }
        return Color.accentColor.opacity(0.85)
    }

    private func performHardDelete() {
        guard let project = projectToDelete else { return }
        let reason = deleteReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let actor = deleteAuthorizedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty, !actor.isEmpty else { return }
        let rc = project.receipts.count
        let ws = project.workSessions.count
        let tomb = ProductionProjectDeletionTombstone(
            removedProjectID: project.id,
            titleSnapshot: project.title,
            parentBusinessSnapshot: project.parentBusinessTitle,
            linkedReceiptCount: rc,
            linkedWorkSessionCount: ws,
            reason: reason,
            authorizedBy: actor
        )
        modelContext.insert(tomb)
        for r in project.receipts {
            r.productionProject = nil
        }
        for s in project.workSessions {
            s.productionProject = nil
        }
        modelContext.delete(project)
        try? modelContext.save()
        projectToDelete = nil
        deleteReason = ""
        deleteAuthorizedBy = ""
    }
}
