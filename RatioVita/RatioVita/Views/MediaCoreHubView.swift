import SwiftData
import SwiftUI

private enum MediaCoreSection: String, CaseIterable, Identifiable {
    case assets
    case wisdom
    case maat
    case book
    case storyboard
    case tempoLab

    var id: String { rawValue }

    var title: String {
        switch self {
            case .assets: "Media assets"
            case .wisdom: "Wisdom cards"
            case .maat: "Ma'at confessions"
            case .book: "Book assembly"
            case .storyboard: "Production beats"
            case .tempoLab: "Wedding dance tempo"
        }
    }

    /// Compact label for menu picker (iPhone / iPad).
    var shortTitle: String {
        switch self {
            case .assets: "Assets"
            case .wisdom: "Wisdom"
            case .maat: "Ma'at"
            case .book: "Book"
            case .storyboard: "Beats"
            case .tempoLab: "Tempo"
        }
    }

    var systemImage: String {
        switch self {
            case .assets: "waveform.circle"
            case .wisdom: "rectangle.on.rectangle.angled"
            case .maat: "scalemass.fill"
            case .book: "book.closed.fill"
            case .storyboard: "film"
            case .tempoLab: "metronome.fill"
        }
    }
}

/// Songs of Solomon multimedia engine — assets, lyrical tiers, etymological flashcards, tempo profile lab.
struct MediaCoreHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent

    @Query(sort: \MediaAsset.title) private var mediaAssets: [MediaAsset]
    @Query(sort: \MetadataCard.sortIndex) private var wisdomCards: [MetadataCard]
    @Query(sort: \LyricSegment.sortIndex) private var lyricSegments: [LyricSegment]
    @Query(sort: \MaatDeclaration.declarationNumber) private var maatDeclarations: [MaatDeclaration]
    @Query(
        sort: \HistoricalKnowledgeNode.updatedAt,
        order: .reverse
    ) private var knowledgeNodes: [HistoricalKnowledgeNode]
    @Query(sort: \MediaProductionBeat.sortIndex) private var productionBeats: [MediaProductionBeat]
    @Query(
        filter: #Predicate<Receipt> { $0.documentKind == "project_manuscript" && $0.trashedAt == nil },
        sort: \Receipt.createdAt,
        order: .reverse
    ) private var manuscriptReceipts: [Receipt]

    @State private var section: MediaCoreSection = .assets
    @State private var selectedAssetID: UUID?
    @State private var selectedCardID: UUID?
    @State private var selectedMaatID: UUID?
    @State private var selectedNodeID: UUID?
    @State private var selectedBeatID: UUID?
    @State private var tempoProgress: Double = 0.35
    @State private var seedError: String?
    @State private var ingestTitle = ""
    @State private var ingestBody = ""
    @State private var ingestMessage: String?

    /// New Horizons / 176 Yonge imports surface first in Book assembly.
    private var sortedKnowledgeNodes: [HistoricalKnowledgeNode] {
        knowledgeNodes.sorted { lhs, rhs in
            let lhsNH = Self.isNewHorizonsNode(lhs)
            let rhsNH = Self.isNewHorizonsNode(rhs)
            if lhsNH != rhsNH { return lhsNH && !rhsNH }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private nonisolated static func isNewHorizonsNode(_ node: HistoricalKnowledgeNode) -> Bool {
        let tags = node.tags.map { $0.lowercased() }
        if tags.contains(where: { $0.contains("newhorizons") || $0.contains("176yonge") }) { return true }
        let title = node.title.lowercased()
        return title.contains("newhorizons") || title.contains("176") || title.contains("horizons")
    }

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            mediaCoreMacSidebar
                .frame(width: MediaCoreLayout.macSidebarWidth)
                .layoutPriority(0)
        } detail: {
            mediaCoreDetail
                .frame(minWidth: MediaCoreLayout.detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("Media Core")
        .onAppear {
            seedLibraryIfNeeded()
            focusBookAssemblyIfManuscriptsPresent()
        }
        .onChange(of: section) { _, _ in
            ensureDefaultSelectionForSection()
        }
        #else
        NavigationStack {
            mediaCoreSidebar
        }
        .safeAreaInset(edge: .bottom) {
            if section != .tempoLab {
                NavigationLink {
                    sectionDetail(section)
                } label: {
                    Text("Open \(section.title)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            } else {
                NavigationLink {
                    WeddingDanceTempoLabPanel(progress: $tempoProgress)
                } label: {
                    Text("Open tempo lab")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .onAppear {
            seedLibraryIfNeeded()
            focusBookAssemblyIfManuscriptsPresent()
        }
        #endif
    }

    private var showCreativityCompilePrompt: Bool {
        !manuscriptReceipts.isEmpty || sortedKnowledgeNodes.count >= 2
    }

    @ViewBuilder
    private var bookAssemblyListSections: some View {
        if showCreativityCompilePrompt {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Compile your book", systemImage: "sparkles")
                        .font(.headline)
                    Text(
                        "New manuscript material detected. Select a knowledge node and use Ingest, or import more chapters from Receipts → Import."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        if !manuscriptReceipts.isEmpty {
            Section("Manuscript vault (\(manuscriptReceipts.count))") {
                ForEach(manuscriptReceipts, id: \.id) { receipt in
                    Button {
                        if let match = sortedKnowledgeNodes.first(where: {
                            $0.title == receipt.merchant
                        }) {
                            selectedNodeID = match.id
                        }
                    } label: {
                        manuscriptReceiptRow(receipt)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        Section("Knowledge nodes (\(knowledgeNodes.count))") {
            if sortedKnowledgeNodes.isEmpty {
                Text("Import .md files via Receipts → Import.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedKnowledgeNodes, id: \.id) { node in
                    Button {
                        selectedNodeID = node.id
                    } label: {
                        knowledgeRow(node)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    #if os(macOS)
    /// Fixed-width sidebar: section menu + item list (avoids runaway first-column expansion).
    private var mediaCoreMacSidebar: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(MediaCoreSection.allCases) { sec in
                    Label(sec.title, systemImage: sec.systemImage)
                        .tag(sec)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            mediaCoreItemListBody
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Seed library") { seedLibraryIfNeeded() }
            }
        }
        .alert("Media Core", isPresented: Binding(
            get: { seedError != nil },
            set: { if !$0 { seedError = nil } }
        )) {
            Button("OK", role: .cancel) { seedError = nil }
        } message: {
            Text(seedError ?? "")
        }
    }

    private var mediaCoreItemListBody: some View {
        List {
            switch section {
                case .assets:
                    Section("Assets (\(mediaAssets.count))") {
                        ForEach(mediaAssets, id: \.id) { asset in
                            Button {
                                selectedAssetID = asset.id
                            } label: {
                                assetRow(asset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .wisdom:
                    Section("Cards (\(wisdomCards.count))") {
                        ForEach(wisdomCards, id: \.id) { card in
                            Button {
                                selectedCardID = card.id
                            } label: {
                                wisdomRow(card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .maat:
                    Section("Declarations (\(maatDeclarations.count))") {
                        ForEach(maatDeclarations, id: \.id) { decl in
                            Button {
                                selectedMaatID = decl.id
                            } label: {
                                maatRow(decl)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .storyboard:
                    Section("Beats (\(productionBeats.count))") {
                        ForEach(productionBeats, id: \.id) { beat in
                            Button {
                                selectedBeatID = beat.id
                            } label: {
                                beatRow(beat)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .book:
                    bookAssemblyListSections
                case .tempoLab:
                    Section {
                        Text("Tempo lab opens in the detail column →")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
    #endif

    private var mediaCoreSidebar: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(MediaCoreSection.allCases) { sec in
                    Text(sec.shortTitle).tag(sec)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                if section == .book {
                    bookAssemblyListSections
                } else {
                    mediaCoreItemListCompactContent
                }
            }
        }
        .navigationTitle("Media Core")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Seed library") { seedLibraryIfNeeded() }
            }
        }
        .alert("Media Core", isPresented: Binding(
            get: { seedError != nil },
            set: { if !$0 { seedError = nil } }
        )) {
            Button("OK", role: .cancel) { seedError = nil }
        } message: {
            Text(seedError ?? "")
        }
    }

    private var mediaCoreItemListCompactContent: some View {
        Group {
            switch section {
                case .assets:
                    Section("Assets (\(mediaAssets.count))") {
                        ForEach(mediaAssets, id: \.id) { asset in
                            Button {
                                selectedAssetID = asset.id
                            } label: {
                                assetRow(asset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .wisdom:
                    Section("Cards (\(wisdomCards.count))") {
                        ForEach(wisdomCards, id: \.id) { card in
                            Button {
                                selectedCardID = card.id
                            } label: {
                                wisdomRow(card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .maat:
                    Section("Declarations (\(maatDeclarations.count))") {
                        ForEach(maatDeclarations, id: \.id) { decl in
                            Button {
                                selectedMaatID = decl.id
                            } label: {
                                maatRow(decl)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .storyboard:
                    Section("Beats (\(productionBeats.count))") {
                        ForEach(productionBeats, id: \.id) { beat in
                            Button {
                                selectedBeatID = beat.id
                            } label: {
                                beatRow(beat)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .book:
                    EmptyView()
                case .tempoLab:
                    Section {
                        Text("Open the detail column for the wedding-dance tempo calculator and haptic phase map.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private func manuscriptReceiptRow(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(receipt.merchant)
                .font(.headline)
            if let prefix = receipt.vaultPathPrefix {
                Text(prefix)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func focusBookAssemblyIfManuscriptsPresent() {
        guard !manuscriptReceipts.isEmpty || sortedKnowledgeNodes.contains(where: Self.isNewHorizonsNode) else {
            return
        }
        section = .book
        if selectedNodeID == nil {
            selectedNodeID = sortedKnowledgeNodes.first?.id
        }
    }

    @ViewBuilder
    private var mediaCoreDetail: some View {
        sectionDetail(section)
    }

    @ViewBuilder
    private func sectionDetail(_ sec: MediaCoreSection) -> some View {
        switch sec {
            case .assets:
                if let asset = mediaAssets.first(where: { $0.id == selectedAssetID }) ?? mediaAssets.first {
                    MediaAssetDetailPanel(asset: asset, lyricSegments: lyricSegmentsFor(asset))
                } else {
                    ContentUnavailableView(
                        "No media assets",
                        systemImage: "waveform.circle",
                        description: Text("Seed the starter library or import masters into the Media Core vault.")
                    )
                }
            case .wisdom:
                if let card = wisdomCards.first(where: { $0.id == selectedCardID }) ?? wisdomCards.first {
                    MetadataCardDetailPanel(card: card)
                } else {
                    ContentUnavailableView(
                        "No wisdom cards",
                        systemImage: "rectangle.on.rectangle.angled",
                        description: Text("Flashcards power etymological deep-dives alongside ambient loops.")
                    )
                }
            case .maat:
                if let decl = maatDeclarations.first(where: { $0.id == selectedMaatID }) ?? maatDeclarations.first {
                    MaatDeclarationDetailPanel(declaration: decl)
                } else {
                    ContentUnavailableView(
                        "No Ma'at declarations",
                        systemImage: "scalemass.fill",
                        description: Text("Seed the library or add all 42 confessions for the vertical spine engine.")
                    )
                }
            case .storyboard:
                if let beat = productionBeats.first(where: { $0.id == selectedBeatID }) ?? productionBeats.first {
                    ProductionBeatDetailPanel(beat: beat)
                } else {
                    ContentUnavailableView(
                        "No production beats",
                        systemImage: "film",
                        description: Text(
                            "Seed the library for a sample Ma'at storyboard row (audio spec + visual prompt)."
                        )
                    )
                }
            case .book:
                BookAssemblyDetailPanel(
                    nodes: knowledgeNodes,
                    selectedNodeID: selectedNodeID,
                    ingestTitle: $ingestTitle,
                    ingestBody: $ingestBody,
                    ingestMessage: $ingestMessage,
                    onIngest: ingestKnowledgeNode
                )
            case .tempoLab:
                WeddingDanceTempoLabPanel(progress: $tempoProgress)
        }
    }

    private func lyricSegmentsFor(_ asset: MediaAsset) -> [LyricSegment] {
        lyricSegments.filter { $0.mediaAsset?.id == asset.id }.sorted { $0.sortIndex < $1.sortIndex }
    }

    private func assetRow(_ asset: MediaAsset) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(asset.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(asset.distributionFormat.menuTitle)
                Text("·")
                Text(asset.echoStream.menuTitle)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func wisdomRow(_ card: MetadataCard) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.frontPoeticVerse)
                .font(.subheadline)
                .lineLimit(2)
            Text(card.governance.menuTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let ref = card.scripturalReference {
                Text(ref)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func maatRow(_ decl: MaatDeclaration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("#\(decl.declarationNumber) — \(decl.ancientText)")
                .font(.subheadline)
                .lineLimit(2)
            Text(decl.presentationStyle.menuTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func beatRow(_ beat: MediaProductionBeat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(beat.timestampLabel)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(beat.audioSpec)
                .font(.subheadline)
                .lineLimit(1)
        }
    }

    private func knowledgeRow(_ node: HistoricalKnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.title)
                .font(.headline)
            Text(node.tags.map { "#\($0)" }.joined(separator: " "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func ingestKnowledgeNode() {
        do {
            let result = try HistoricalKnowledgeIngestService.ingest(
                title: ingestTitle,
                bodyMarkdown: ingestBody,
                context: modelContext
            )
            selectedNodeID = result.node.id
            ingestMessage = "Ingested with tags: \(result.parsedTags.map { "#\($0)" }.joined(separator: ", "))"
            ingestTitle = ""
            ingestBody = ""
        } catch {
            ingestMessage = error.localizedDescription
        }
    }

    private func seedLibraryIfNeeded() {
        do {
            try SolomonMediaSeedService.seedIfEmpty(context: modelContext)
        } catch {
            seedError = error.localizedDescription
        }
        ensureDefaultSelectionForSection()
    }

    private func ensureDefaultSelectionForSection() {
        switch section {
            case .assets:
                if selectedAssetID == nil { selectedAssetID = mediaAssets.first?.id }
            case .wisdom:
                if selectedCardID == nil { selectedCardID = wisdomCards.first?.id }
            case .maat:
                if selectedMaatID == nil { selectedMaatID = maatDeclarations.first?.id }
            case .storyboard:
                if selectedBeatID == nil { selectedBeatID = productionBeats.first?.id }
            case .book:
                if selectedNodeID == nil { selectedNodeID = sortedKnowledgeNodes.first?.id }
            case .tempoLab:
                break
        }
    }
}

// MARK: - Detail panels

private struct MediaAssetDetailPanel: View {
    let asset: MediaAsset
    let lyricSegments: [LyricSegment]

    var body: some View {
        Form {
            Section("Distribution") {
                LabeledContent("Format", value: asset.distributionFormat.menuTitle)
                if let range = asset.distributionFormat.suggestedDurationSeconds {
                    LabeledContent("Suggested duration", value: "\(Int(range.lowerBound))–\(Int(range.upperBound))s")
                }
                LabeledContent("Echo stream", value: asset.echoStream.menuTitle)
                LabeledContent("Kind", value: asset.assetKind.rawValue.capitalized)
            }

            Section("Analogue signal chain") {
                if asset.analogueCharacteristics.isEmpty {
                    Text("No tube-chain flags recorded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(asset.analogueCharacteristics, id: \.rawValue) { trait in
                        Label(trait.menuTitle, systemImage: "hifispeaker.2")
                    }
                }
            }

            if let path = asset.vaultRelativePath {
                Section("Vault") {
                    Text(path)
                        .font(.caption.monospaced())
                }
            }

            Section("Lyrical performance tiers") {
                if lyricSegments.isEmpty {
                    Text("No lyric segments linked.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(lyricSegments, id: \.id) { seg in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(seg.performanceDelivery.menuTitle)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(seg.lyricText)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(asset.title)
    }
}

private struct ProductionBeatDetailPanel: View {
    let beat: MediaProductionBeat

    var body: some View {
        ScrollView {
            Form {
                Section("Timeline") {
                    LabeledContent("Window", value: beat.timestampLabel)
                    LabeledContent("Stream", value: beat.governance.menuTitle)
                }
                Section("Audio / vocal (functional spec)") {
                    Text(beat.audioSpec)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section("Visual prompt (UI wireframe)") {
                    Text(beat.visualPrompt)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Beat \(beat.sortIndex + 1)")
    }
}

private struct MaatDeclarationDetailPanel: View {
    let declaration: MaatDeclaration

    var body: some View {
        Form {
            Section("Declaration #\(declaration.declarationNumber)") {
                Text(declaration.ancientText)
                LabeledContent("Presentation", value: declaration.presentationStyle.menuTitle)
                if let judge = declaration.judgeName {
                    LabeledContent("Judge", value: judge)
                }
                if let origin = declaration.judgeOrigin {
                    LabeledContent("Origin", value: origin)
                }
            }
            if let intro = declaration.metadataCard?.spokenIntroScript, !intro.isEmpty {
                Section("Scribe intro") { Text(intro) }
            }
            if let modern = declaration.modernExpansion, !modern.isEmpty {
                Section("Modern expansion") { Text(modern) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Ma'at #\(declaration.declarationNumber)")
    }
}

private struct BookAssemblyDetailPanel: View {
    let nodes: [HistoricalKnowledgeNode]
    let selectedNodeID: UUID?
    @Binding var ingestTitle: String
    @Binding var ingestBody: String
    @Binding var ingestMessage: String?
    var onIngest: () -> Void

    var body: some View {
        let node = nodes.first { $0.id == selectedNodeID } ?? nodes.first
        ScrollView {
            Form {
                Section("Ingest research / chat log") {
                    TextField("Title", text: $ingestTitle)
                    TextField("Markdown body (#tags auto-parsed)", text: $ingestBody, axis: .vertical)
                        .lineLimit(6...16)
                    Button("Ingest node", action: onIngest)
                        .disabled(ingestTitle.trimmingCharacters(in: .whitespaces).isEmpty
                            || ingestBody.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let ingestMessage {
                        Text(ingestMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let node {
                    Section("Selected node") {
                        Text(node.title).font(.headline)
                        Text(node.tags.map { "#\($0)" }.joined(separator: " "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(node.bodyMarkdown)
                            .textSelection(.enabled)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ContentUnavailableView(
                        "No knowledge nodes",
                        systemImage: "book.closed",
                        description: Text("Import manuscripts from Receipts → Import, then open Book assembly.")
                    )
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Book assembly")
    }
}

private struct MetadataCardDetailPanel: View {
    let card: MetadataCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(card.governance.menuTitle)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if let intro = card.spokenIntroScript, !intro.isEmpty {
                    flashcardFace(title: "Intro", body: intro, reference: nil)
                }
                flashcardFace(
                    title: "Front",
                    body: card.frontPoeticVerse,
                    reference: card.scripturalReference
                )
                flashcardFace(title: "Wisdom insight", body: card.backWisdomInsight, reference: nil)
                if let modern = card.modernExpansionScript, !modern.isEmpty {
                    flashcardFace(title: "Modern expansion", body: modern, reference: nil)
                }
                if let asset = card.linkedMediaAsset {
                    Label("Ambient loop: \(asset.title)", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("Wisdom card")
    }

    private func flashcardFace(title: String, body: String, reference: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(body)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
            if let reference {
                Text(reference)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WeddingDanceTempoLabPanel: View {
    @Binding var progress: Double

    var body: some View {
        let snap = WeddingDanceTempoProfile.snapshot(at: progress, previousProgress: progress - 0.02)

        Form {
            Section("Progress") {
                Slider(value: $progress, in: 0...1)
                LabeledContent("Phase", value: snap.phase.menuTitle)
                LabeledContent("Tempo", value: String(format: "%.1f BPM", snap.tempoBPM))
                LabeledContent("String swirl", value: String(format: "%.0f%%", snap.stringSwirlIntensity * 100))
                if snap.shouldPulseHaptic {
                    Label("Haptic pulse (climax)", systemImage: "iphone.radiowaves.left.and.right")
                        .foregroundStyle(.orange)
                }
            }

            Section("Phases") {
                ForEach(WeddingDanceTempoPhase.allCases, id: \.rawValue) { phase in
                    HStack {
                        Text(phase.menuTitle)
                        Spacer()
                        if snap.phase == phase {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Wedding dance tempo")
    }
}
