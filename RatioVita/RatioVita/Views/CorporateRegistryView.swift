import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// **Corporate Registry** — legal entities (GST/HST, address, logo) linked to productions.
struct CorporateRegistryView: View {
    /// When true, only profiles you marked as **your corporations** (AR / internal).
    var ownedOnly: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BusinessEntity.legalName) private var entities: [BusinessEntity]

    private var displayedEntities: [BusinessEntity] {
        ownedOnly ? entities.filter(\.isOwnedCorporation) : entities
    }

    @State private var showAddSheet = false
    @State private var editingEntity: BusinessEntity?
    @State private var entityToPurge: BusinessEntity?
    @State private var pendingShadowMerge: PendingShadowMerge?

    private var locationVaultAddresses: [String] {
        Array(
            Set(
                entities.compactMap(\.businessAddress)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    var body: some View {
        List {
            if displayedEntities.isEmpty {
                ContentUnavailableView(
                    ownedOnly ? "No owned corporations" : "No entities yet",
                    systemImage: "building.2",
                    description: Text(
                        ownedOnly
                            ? "Mark entities as “My corporation” in the full registry, or add a new profile here."
                            : "Add your catering company, personal contractor profile, or other business identity."
                    )
                )
            } else {
                ForEach(displayedEntities) { entity in
                    NavigationLink {
                        BusinessEntityDetailView(entity: entity)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entity.legalName)
                                .font(.headline)
                            if !entity.displaySubtitle.isEmpty {
                                Text(entity.displaySubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(entity.productionProjects.count) linked show(s)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contextMenu {
                        Button("Edit") { editingEntity = entity }
                        if entity.hasZeroLinkedItems {
                            Button("Purge entity", role: .destructive) {
                                entityToPurge = entity
                            }
                        }
                    }
                }
                .onDelete(perform: deleteEntitiesIfAllowed)
            }
        }
        .navigationTitle(ownedOnly ? "My corporations" : "Corporate registry")
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
                        Label("Add entity", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                BusinessEntityEditorSheet(
                    savedAddresses: locationVaultAddresses,
                    defaultOwnedCorporation: ownedOnly,
                    onDismiss: { showAddSheet = false }
                )
            }
            .sheet(item: $editingEntity) { entity in
                BusinessEntityEditorSheet(
                    entity: entity,
                    savedAddresses: locationVaultAddresses,
                    defaultOwnedCorporation: ownedOnly,
                    onDismiss: { editingEntity = nil }
                )
            }
            .confirmationDialog(
                "Purge “\(entityToPurge?.legalName ?? "")”?",
                isPresented: Binding(
                    get: { entityToPurge != nil },
                    set: { if !$0 { entityToPurge = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete permanently", role: .destructive) {
                    if let e = entityToPurge, e.hasZeroLinkedItems {
                        modelContext.delete(e)
                        try? modelContext.save()
                    }
                    entityToPurge = nil
                }
                Button("Cancel", role: .cancel) {
                    entityToPurge = nil
                }
            } message: {
                Text("No productions are linked to this entity. It will be removed entirely.")
            }
            .confirmationDialog(
                pendingShadowMerge?.title ?? "Merge shadow profile?",
                isPresented: Binding(
                    get: { pendingShadowMerge != nil },
                    set: { if !$0 { pendingShadowMerge = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Merge \(pendingShadowMerge?.receiptCount ?? 0) receipt(s)") {
                    if let pending = pendingShadowMerge {
                        _ = try? ShadowRegistryService.mergeShadowProfile(
                            pending.shadow,
                            into: pending.official,
                            context: modelContext
                        )
                        try? modelContext.save()
                    }
                    pendingShadowMerge = nil
                }
                Button("Not now", role: .cancel) {
                    pendingShadowMerge = nil
                }
            } message: {
                if let pending = pendingShadowMerge {
                    Text(
                        "Found a shadow profile for “\(pending.shadow.detectedLegalName)” with "
                            + "\(pending.receiptCount) pre-sorted receipt(s). Merge into “\(pending.official.legalName)”?"
                    )
                }
            }
    }

    private func offerShadowMergeIfNeeded(for entity: BusinessEntity) {
        guard let shadow = ShadowRegistryService.matchingShadow(forLegalName: entity.legalName, context: modelContext),
              !shadow.linkedReceipts.isEmpty else { return }
        pendingShadowMerge = PendingShadowMerge(
            shadow: shadow,
            official: entity,
            receiptCount: shadow.linkedReceipts.count
        )
    }

    private func deleteEntitiesIfAllowed(at offsets: IndexSet) {
        for i in offsets {
            let e = displayedEntities[i]
            guard e.hasZeroLinkedItems else { continue }
            modelContext.delete(e)
        }
        try? modelContext.save()
    }
}

// MARK: - Entity drill-down

private struct BusinessEntityDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entity: BusinessEntity

    @State private var showEditor = false
    @State private var importMessage: String?
    @State private var showArticlesImporter = false

    var body: some View {
        List {
            Section("Profile") {
                LabeledContent("Legal name", value: entity.legalName)
                if let gst = entity.gstHstNumber, !gst.isEmpty {
                    LabeledContent("GST/HST", value: gst)
                }
                if let addr = entity.businessAddress, !addr.isEmpty {
                    LabeledContent("Address") {
                        Text(addr)
                            .multilineTextAlignment(.trailing)
                    }
                }
                LabeledContent("Forensic cadence", value: entity.paymentTerms.menuTitle)
                LabeledContent("My corporation") {
                    Text(entity.isOwnedCorporation ? "Yes — AR / internal" : "No — external profile")
                        .foregroundStyle(entity.isOwnedCorporation ? Color.green : Color.secondary)
                }
            }
            articlesSection
            Section("Linked productions") {
                if entity.productionProjects.isEmpty {
                    Text("No shows linked yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(
                        entity.productionProjects.sorted {
                            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                        }
                    ) { project in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.title)
                                .font(.headline)
                            Text(project.productionContractKind.shortTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(entity.legalName)
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditor = true }
                }
            }
            .sheet(isPresented: $showEditor) {
                BusinessEntityEditorSheet(entity: entity) {
                    showEditor = false
                }
            }
            .fileImporter(
                isPresented: $showArticlesImporter,
                allowedContentTypes: [.pdf, .jpeg, .png, .heic],
                allowsMultipleSelection: false
            ) { result in
                importArticles(from: result)
            }
    }

    @ViewBuilder
    private var articlesSection: some View {
        Section {
            if entity.articlesFullDocumentData != nil {
                LabeledContent("Full articles") {
                    Text(entity.articlesDocumentFilename ?? "On file")
                        .foregroundStyle(.secondary)
                }
            }
            if entity.articlesPageOneDocumentData != nil {
                LabeledContent("Page 1 (EP / production)") {
                    Text("Ready to share")
                        .foregroundStyle(.green)
                }
            }
            Button {
                showArticlesImporter = true
            } label: {
                Label("Import articles (PDF or photo)", systemImage: "doc.badge.plus")
            }
            if entity.articlesFullDocumentData != nil {
                Button("Extract page 1 for EP portal") {
                    extractPageOne()
                }
                Button("Suggest profile fields from document") {
                    suggestFromArticles()
                }
            }
            if let importMessage {
                Text(importMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Articles of incorporation")
        } footer: {
            Text(
                "Page 1 is what productions usually upload to EP / Cast & Crew. Keep the full package on file; share page 1 on demand when portal upload fails."
            )
        }
    }

    private func importArticles(from result: Result<[URL], Error>) {
        importMessage = nil
        switch result {
            case let .failure(error):
                importMessage = error.localizedDescription
            case let .success(urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let data = try? Data(contentsOf: url) else {
                    importMessage = "Could not read the file."
                    return
                }
                entity.articlesFullDocumentData = data
                entity.articlesDocumentFilename = url.lastPathComponent
                entity.articlesPageOneDocumentData = ArticlesOfIncorporationService.extractPageOnePDF(from: data)
                entity.updatedAt = .now
                try? modelContext.save()
                importMessage = "Articles stored. Page 1 \(entity.articlesPageOneDocumentData == nil ? "not extracted — use Extract page 1" : "ready")."
        }
    }

    private func extractPageOne() {
        guard let full = entity.articlesFullDocumentData else { return }
        entity.articlesPageOneDocumentData = ArticlesOfIncorporationService.extractPageOnePDF(from: full)
        entity.updatedAt = .now
        try? modelContext.save()
        importMessage = entity.articlesPageOneDocumentData == nil
            ? "Could not extract page 1 — ensure the file is a multi-page PDF."
            : "Page 1 PDF is ready for production / EP sharing."
    }

    private func suggestFromArticles() {
        let data = entity.articlesPageOneDocumentData ?? entity.articlesFullDocumentData
        guard let data else { return }
        let suggested = ArticlesOfIncorporationService.suggestFields(from: data)
        if let name = suggested.legalName, !name.isEmpty { entity.legalName = name }
        if let addr = suggested.businessAddress, !addr.isEmpty { entity.businessAddress = addr }
        entity.updatedAt = .now
        try? modelContext.save()
        importMessage = "Updated profile from document text where found. Review in Edit."
    }
}

private struct PendingShadowMerge {
    let shadow: PreliminaryBusinessEntity
    let official: BusinessEntity
    let receiptCount: Int

    var title: String { "Merge shadow profile?" }
}

// MARK: - Editor

private struct BusinessEntityEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    var entity: BusinessEntity?
    var savedAddresses: [String] = []
    var defaultOwnedCorporation: Bool = false
    var onDismiss: () -> Void
    var onCreated: ((BusinessEntity) -> Void)?

    @State private var legalName = ""
    @State private var gstHst = ""
    @State private var taxRegistrationBN = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var paymentTerms: PaymentTermsMode = .unspecified
    @State private var isOwnedCorporation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Legal name", text: $legalName)
                    TextField("GST / HST number", text: $gstHst)
                    TextField("CRA Business Number (9 digits)", text: $taxRegistrationBN)
                        .help("Core BN anchor — e.g. 76001212 for Bespoke. Used to route CRA forms and deal memos.")
                }
                LocationVaultAddressPicker(savedAddresses: savedAddresses, address: $address)
                Section("Address") {
                    StandardizedAddressStringEditor(rawAddress: $address, streetPlaceholder: "Street, city, province")
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Registry role") {
                    Toggle("My corporation (internal / AR)", isOn: $isOwnedCorporation)
                    Text(
                        "Owned corporations are excluded from external Contacts and drive green (+) invoice polarity."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Section("Forensic cadence") {
                    Picker("Default pay / AR terms", selection: $paymentTerms) {
                        ForEach(PaymentTermsMode.allCases) { mode in
                            Text(mode.menuTitle).tag(mode)
                        }
                    }
                    Text("Shows linked to this entity inherit these terms unless a production overrides them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button(entity == nil ? "Create entity" : "Save") {
                        save()
                    }
                    .disabled(legalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(entity == nil ? "New entity" : "Edit entity")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onDismiss)
                    }
                }
                .onAppear {
                    if let e = entity {
                        legalName = e.legalName
                        gstHst = e.gstHstNumber ?? ""
                        taxRegistrationBN = e.taxRegistrationNumber ?? e.normalizedTaxRegistrationCore ?? ""
                        address = e.businessAddress ?? ""
                        notes = e.notes ?? ""
                        paymentTerms = e.paymentTerms
                        isOwnedCorporation = e.isOwnedCorporation
                    } else {
                        isOwnedCorporation = defaultOwnedCorporation
                    }
                }
        }
    }

    private func save() {
        let name = legalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let gst = gstHst.trimmingCharacters(in: .whitespacesAndNewlines)
        let bnRaw = taxRegistrationBN.trimmingCharacters(in: .whitespacesAndNewlines)
        let bn = TaxRegistrationAnchor.normalizedBusinessNumber(from: bnRaw) ?? (bnRaw.isEmpty ? nil : bnRaw)
        let addr = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = entity {
            e.legalName = name
            e.gstHstNumber = gst.isEmpty ? nil : gst
            e.taxRegistrationNumber = bn
            e.businessAddress = addr.isEmpty ? nil : addr
            e.notes = n.isEmpty ? nil : n
            e.paymentTerms = paymentTerms
            e.isOwnedCorporation = isOwnedCorporation
            e.updatedAt = .now
        } else {
            let e = BusinessEntity(
                legalName: name,
                gstHstNumber: gst.isEmpty ? nil : gst,
                taxRegistrationNumber: bn,
                businessAddress: addr.isEmpty ? nil : addr,
                notes: n.isEmpty ? nil : n,
                paymentTermsRaw: paymentTerms == .unspecified ? "" : paymentTerms.rawValue,
                isOwnedCorporation: isOwnedCorporation
            )
            modelContext.insert(e)
            try? modelContext.save()
            onCreated?(e)
            onDismiss()
            return
        }
        try? modelContext.save()
        onDismiss()
    }
}
