import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Production command deck — past / present / future shows and multi-channel onboarding (no auto popups).
struct ProductionWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID: String = ""

    @Query(sort: \ProductionProject.title) private var allProjects: [ProductionProject]
    @Query(sort: \CrewTimecardDay.workDate, order: .reverse) private var crewDays: [CrewTimecardDay]

    @State private var showIngestionHub = false
    @State private var pendingIngestion: ProductionIngestionMethod?
    @State private var showManualAdd = false
    @State private var showCallSheetScan = false
    @State private var showPortalPDFImporter = false
    @State private var portalImportMessage: String?

    private var presentProjects: [ProductionProject] {
        allProjects.filter { timelineBucket(for: $0) == .present }
    }

    private var futureProjects: [ProductionProject] {
        allProjects.filter { timelineBucket(for: $0) == .future }
    }

    private var pastProjects: [ProductionProject] {
        allProjects.filter { timelineBucket(for: $0) == .past }
    }

    private enum TimelineBucket {
        case past, present, future
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                headerBar
                if let portalImportMessage {
                    Text(portalImportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                timelineSection(
                    "Present",
                    subtitle: "Active shoots & current payroll cycles",
                    projects: presentProjects
                )
                timelineSection(
                    "Upcoming",
                    subtitle: "Registered shows awaiting first crew day",
                    projects: futureProjects
                )
                timelineSection("Archive", subtitle: "Retired or dormant productions", projects: pastProjects)
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Productions")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
            .sheet(isPresented: $showIngestionHub) {
                ProductionIngestionHubSheet(
                    onSelect: { method in
                        showIngestionHub = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            beginIngestion(method)
                        }
                    },
                    onCancel: { showIngestionHub = false }
                )
            }
            .sheet(isPresented: $showManualAdd) {
                ProductionProjectAddSheet(
                    onDismiss: { showManualAdd = false },
                    onCreated: { project in
                        forensicActiveProductionID = project.id.uuidString
                        showManualAdd = false
                    }
                )
            }
            .sheet(isPresented: $showCallSheetScan) {
                CallSheetScanSheet()
            }
            .fileImporter(
                isPresented: $showPortalPDFImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePortalPDFImport(result)
            }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Production workspace")
                    .font(DesignSystem.Typography.headline)
                Text("Manage shows across your timeline. Import portal PDFs, scan paper, or build manually.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .adaptiveDetailText()
            }
            Spacer(minLength: 8)
            Button {
                showIngestionHub = true
            } label: {
                Label("New production workspace", systemImage: "plus.rectangle.on.folder.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func timelineSection(
        _ title: String,
        subtitle: String,
        projects: [ProductionProject]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.bodyEmphasized)
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            if projects.isEmpty {
                Text("No shows in this bucket yet.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(projects) { project in
                    NavigationLink {
                        ProductionProjectRegistryDetailView(project: project)
                    } label: {
                        productionRow(project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func productionRow(_ project: ProductionProject) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Circle()
                .fill(swatchColor(for: project))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(DesignSystem.Typography.bodyEmphasized)
                Text(project.registryStatus.menuTitle)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if forensicActiveProductionID == project.id.uuidString {
                Text("Active")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func swatchColor(for project: ProductionProject) -> Color {
        if let hex = project.timelineColorHex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty {
            return Color(hex: hex)
        }
        return Color.accentColor.opacity(0.85)
    }

    private func timelineBucket(for project: ProductionProject) -> TimelineBucket {
        if project.registryStatus == .retired { return .past }
        let lastActivity = lastActivityDate(for: project)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = lastActivity {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 0
            if days > 120 { return .past }
            if days <= 45 { return .present }
        }
        if project.crewTimecardDays.isEmpty, project.receipts.isEmpty, project.workSessions.isEmpty {
            return .future
        }
        return .present
    }

    private func lastActivityDate(for project: ProductionProject) -> Date? {
        var candidates: [Date] = []
        if let d = crewDays.first(where: { $0.productionProject?.id == project.id })?.workDate {
            candidates.append(d)
        }
        if let d = project.receipts.map(\.createdAt).max() {
            candidates.append(d)
        }
        if let d = project.workSessions.map(\.workDate).max() {
            candidates.append(d)
        }
        return candidates.max()
    }

    private func beginIngestion(_ method: ProductionIngestionMethod) {
        pendingIngestion = method
        switch method {
            case .pdfImport:
                showPortalPDFImporter = true
            case .cameraOCR:
                showCallSheetScan = true
            case .manualEntry:
                showManualAdd = true
        }
    }

    private func handlePortalPDFImport(_ result: Result<[URL], Error>) {
        switch result {
            case let .failure(error):
                portalImportMessage = "Import failed: \(error.localizedDescription)"
            case let .success(urls):
                guard let url = urls.first else { return }
                portalImportMessage =
                    "Imported \(url.lastPathComponent). Link it to a show from Labor Sentinel or create a production manually — full portal PDF parsing ships next."
                FilingCoordinator.appendAudit(
                    context: modelContext,
                    kindRaw: "production.portalPDF.imported",
                    title: "Portal PDF staged",
                    detail: url.lastPathComponent
                )
                try? modelContext.save()
        }
        pendingIngestion = nil
    }
}

// MARK: - Ingestion hub

private struct ProductionIngestionHubSheet: View {
    let onSelect: (ProductionIngestionMethod) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: DesignSystem.Spacing.md
                ) {
                    ForEach(ProductionIngestionMethod.allCases) { method in
                        Button {
                            onSelect(method)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: method.systemImage)
                                    .font(.title2)
                                Text(method.rawValue)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                    .multilineTextAlignment(.leading)
                                Text(method.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                            .padding()
                            .background(Color.ratioVitaAdaptiveSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Initialize production")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 360)
        #endif
    }
}

// MARK: - Shared detail (extracted from registry)

struct ProductionProjectRegistryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: ProductionProject

    @Query(sort: \BusinessEntity.legalName) private var businessEntities: [BusinessEntity]

    @State private var parentField = ""
    @State private var colorField = ""
    @State private var confirmZeroLinkPurge = false

    var body: some View {
        Group {
            #if os(macOS)
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    identityMacSection
                    occupationMacSection
                    ProductionPayrollSettingsSection(project: project)
                    ProductionShowPositionsSection(project: project)
                    timelineMacSection
                    purgeMacSection
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(DesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            #else
            Form {
                identityIOSSection
                Section("Occupation") {
                    IATSE873OccupationPicker(occupationTitle: $project.crewOccupationTitle)
                }
                ProductionPayrollSettingsSection(project: project)
                ProductionShowPositionsSection(project: project)
                timelineIOSSection
                purgeIOSSection
            }
            #endif
        }
        .navigationTitle("Edit production")
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .confirmationDialog(
                "Purge “\(project.title)” permanently?",
                isPresented: $confirmZeroLinkPurge,
                titleVisibility: .visible
            ) {
                Button("Delete permanently", role: .destructive) {
                    guard project.hasZeroLinkedItems else {
                        confirmZeroLinkPurge = false
                        return
                    }
                    modelContext.delete(project)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {
                    confirmZeroLinkPurge = false
                }
            } message: {
                Text(
                    "This show has no linked receipts, work sessions, or crew data. It will be removed entirely with no tombstone."
                )
            }
            .onAppear {
                parentField = project.parentBusinessTitle ?? ""
                colorField = project.timelineColorHex ?? ""
            }
            .onChange(of: parentField) { _, new in
                let t = new.trimmingCharacters(in: .whitespacesAndNewlines)
                project.parentBusinessTitle = t.isEmpty ? nil : t
                project.updatedAt = .now
                try? modelContext.save()
            }
            .onChange(of: project.title) { _, _ in
                project.updatedAt = .now
                try? modelContext.save()
            }
    }

    #if os(macOS)
    private var identityMacSection: some View {
        LeftAlignedFormSection("Identity") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ProductionFormLabeledRow(label: "Show title") {
                    TextField("Project title", text: $project.title)
                        .textFieldStyle(.roundedBorder)
                }
                ProductionFormLabeledRow(label: "Parent business") {
                    TextField("Network / studio group", text: $parentField)
                        .textFieldStyle(.roundedBorder)
                }
                ProductionFormLabeledRow(label: "Billing mode") {
                    Picker("Billing mode", selection: contractKindBinding) {
                        ForEach(ProductionContractKind.allCases) { k in
                            Text(k.shortTitle).tag(k)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260, alignment: .leading)
                }
                ProductionFormLabeledRow(label: "Corporate entity") {
                    Picker("Corporate entity", selection: entityIDBinding) {
                        Text("None").tag(UUID?.none)
                        ForEach(businessEntities) { e in
                            Text(e.legalName).tag(Optional(e.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 360, alignment: .leading)
                }
                ProductionFormLabeledRow(label: "Status") {
                    Picker("Status", selection: Binding(
                        get: { project.registryStatus },
                        set: { project.registryStatus = $0 }
                    )) {
                        ForEach(ProductionRegistryStatus.allCases, id: \.self) { s in
                            Text(s.menuTitle).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280, alignment: .leading)
                }
            }
        }
    }

    private var occupationMacSection: some View {
        LeftAlignedFormSection(
            "Occupation",
            footer: "Default 873 classification for new crew days. Per-day roles and units are set on each timecard row and summarized on the PDF."
        ) {
            IATSE873OccupationPicker(occupationTitle: $project.crewOccupationTitle)
                .frame(maxWidth: 360, alignment: .leading)
        }
    }

    private var timelineMacSection: some View {
        LeftAlignedFormSection("Timeline") {
            ProductionFormLabeledRow(label: "Radar color") {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("RRGGBB", text: $colorField)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100, alignment: .leading)
                    Button("Apply color") {
                        applyTimelineColor()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var purgeMacSection: some View {
        if project.hasZeroLinkedItems {
            LeftAlignedFormSection("Danger zone") {
                Button("Purge production (no linked items)…", role: .destructive) {
                    confirmZeroLinkPurge = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    #endif

    private var identityIOSSection: some View {
        Section("Identity") {
            TextField("Show / project title", text: $project.title)
            TextField("Parent business", text: $parentField)
            Picker("Billing mode", selection: contractKindBinding) {
                ForEach(ProductionContractKind.allCases) { k in
                    Text(k.shortTitle).tag(k)
                }
            }
            Picker("Corporate entity", selection: entityIDBinding) {
                Text("None").tag(UUID?.none)
                ForEach(businessEntities) { e in
                    Text(e.legalName).tag(Optional(e.id))
                }
            }
            Picker("Status", selection: Binding(
                get: { project.registryStatus },
                set: { project.registryStatus = $0 }
            )) {
                ForEach(ProductionRegistryStatus.allCases, id: \.self) { s in
                    Text(s.menuTitle).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var timelineIOSSection: some View {
        Section("Timeline") {
            TextField("Radar color (RRGGBB)", text: $colorField)
            #if os(iOS)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            #endif
            Button("Apply color") {
                applyTimelineColor()
            }
        }
    }

    @ViewBuilder
    private var purgeIOSSection: some View {
        if project.hasZeroLinkedItems {
            Section {
                Button("Purge production (no linked items)…", role: .destructive) {
                    confirmZeroLinkPurge = true
                }
            } footer: {
                Text(
                    "Removes this title entirely when it has no receipts, sessions, crew days, kit rows, or rate segments."
                )
                .font(.footnote)
            }
        }
    }

    private func applyTimelineColor() {
        let h = colorField.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        project.timelineColorHex = h.isEmpty ? nil : h
        project.updatedAt = .now
        try? modelContext.save()
    }

    private var contractKindBinding: Binding<ProductionContractKind> {
        Binding(
            get: { project.productionContractKind },
            set: {
                project.productionContractKind = $0
                try? modelContext.save()
            }
        )
    }

    private var entityIDBinding: Binding<UUID?> {
        Binding(
            get: { project.businessEntity?.id },
            set: { newID in
                if let id = newID {
                    project.businessEntity = businessEntities.first { $0.id == id }
                } else {
                    project.businessEntity = nil
                }
                project.syncPayrollLoanoutFromCorporateEntityIfEmpty()
                project.updatedAt = .now
                try? modelContext.save()
            }
        )
    }
}
