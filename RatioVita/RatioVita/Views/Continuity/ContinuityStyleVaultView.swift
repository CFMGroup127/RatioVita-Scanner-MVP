import SwiftUI

/// Continuity & Style Vault — tag-grouped look boards for set costumers and BG agents.
struct ContinuityStyleVaultView: View {
    @Environment(\.brandAccent) private var brandAccent
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID: String = ""
    @ObservedObject private var vaultStream = LookBoardVaultStreamService.shared

    @State private var selectedTag: String?
    @State private var selectedAsset: LookBoardAsset?
    @State private var sharePayload: LookBoardSharePayload?

    private var groupedSections: [(tag: String, items: [LookBoardAsset])] {
        vaultStream.groupedAssets(filterTag: selectedTag)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                headerCard
                tagFilterStrip
                ForEach(groupedSections, id: \.tag) { section in
                    lookBoardSection(section)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
        .navigationTitle("Continuity & Style")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(item: $selectedAsset) { asset in
            LookBoardDetailSheet(asset: asset) { payload in
                sharePayload = payload
            }
        }
        .sheet(item: $sharePayload) { payload in
            LookBoardShareSheet(payload: payload)
        }
        .onAppear {
            vaultStream.startListening(productionId: forensicActiveProductionID)
        }
        .onDisappear {
            vaultStream.stopListening()
        }
        .onChange(of: forensicActiveProductionID) { _, newValue in
            vaultStream.startListening(productionId: newValue)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Continuity & Style Vault", systemImage: "photo.on.rectangle.angled")
                .font(DesignSystem.Typography.title3)
            if let summary = vaultStream.lastSyncSummary {
                Text(summary)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
            if !vaultStream.isFirebaseLinked {
                StatusBadge.warning("Offline preview")
            } else {
                StatusBadge.success("Live sync")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(Color.ratioVitaAdaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
    }

    private var tagFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagChip(label: "All", tag: nil, isSelected: selectedTag == nil)
                ForEach(vaultStream.allTags, id: \.self) { tag in
                    tagChip(label: "#\(tag)", tag: tag, isSelected: selectedTag == tag)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func tagChip(label: String, tag: String?, isSelected: Bool) -> some View {
        Button {
            selectedTag = tag
        } label: {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? brandAccent.opacity(0.18) : Color.ratioVitaAdaptiveSurface)
                .foregroundStyle(isSelected ? brandAccent : Color.ratioVitaAdaptiveText)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func lookBoardSection(_ section: (tag: String, items: [LookBoardAsset])) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(section.tag)
                .font(DesignSystem.Typography.bodyEmphasized)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
                spacing: 12
            ) {
                ForEach(section.items) { asset in
                    LookBoardTile(asset: asset, accent: brandAccent) {
                        selectedAsset = asset
                    } onShare: {
                        sharePayload = LookBoardSharePayload(asset: asset)
                    }
                }
            }
        }
    }
}

private struct LookBoardTile: View {
    let asset: LookBoardAsset
    let accent: Color
    let onOpen: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                LookBoardThumbnailView(asset: asset, accent: accent)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(asset.title)
                .font(DesignSystem.Typography.bodyEmphasized)
                .lineLimit(2)

            Text(asset.displayTags.prefix(3).joined(separator: " "))
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .lineLimit(2)

            Button(action: onShare) {
                Label("Share to BG agent", systemImage: "square.and.arrow.up")
                    .font(DesignSystem.Typography.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.ratioVitaAdaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
    }
}

private struct LookBoardThumbnailView: View {
    let asset: LookBoardAsset
    let accent: Color

    var body: some View {
        ZStack {
            if let url = asset.thumbnailURL ?? asset.fullImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        ProgressView()
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.35), accent.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(accent)
                Text(asset.sourceFilename)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
}

private struct LookBoardDetailSheet: View {
    let asset: LookBoardAsset
    let onShare: (LookBoardSharePayload) -> Void
    @Environment(\.brandAccent) private var brandAccent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    LookBoardThumbnailView(asset: asset, accent: brandAccent)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 280, maxHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))

                    Text(asset.title)
                        .font(DesignSystem.Typography.title2)

                    if let notes = asset.notes, !notes.isEmpty {
                        Text(notes)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                    }

                    FlowTagWrap(tags: asset.displayTags)

                    ShareLink(item: LookBoardSharePayload(asset: asset).primaryShareText) {
                        Label("Share look parameters", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("Look board")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onShare(LookBoardSharePayload(asset: asset))
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

private struct FlowTagWrap: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VitaLogic tags")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            WrapLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(DesignSystem.Typography.caption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.ratioVitaAdaptiveSurface)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

/// Simple horizontal-flow layout for hashtag chips.
private struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct LookBoardSharePayload: Identifiable {
    let id: String
    let title: String
    let primaryShareText: String
    let imageURL: URL?

    init(asset: LookBoardAsset) {
        id = asset.id
        title = asset.title
        let tagLine = asset.displayTags.joined(separator: " ")
        let constraintLine = asset.tags.contains(where: { $0.caseInsensitiveCompare("NoLogos") == .orderedSame })
            ? "\nRequirements: No logos or graphics on wardrobe."
            : ""
        primaryShareText = """
        RatioVita Look Board — \(asset.title)
        Source: \(asset.sourceFilename)
        Tags: \(tagLine)\(constraintLine)
        """
        imageURL = asset.fullImageURL ?? asset.thumbnailURL
    }
}

private struct LookBoardShareSheet: View {
    let payload: LookBoardSharePayload
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text(payload.primaryShareText)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ShareLink(item: payload.primaryShareText) {
                    Label("Share look parameters", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let imageURL = payload.imageURL {
                    ShareLink(item: imageURL) {
                        Label("Share image file", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(DesignSystem.Spacing.xl)
            .navigationTitle("Share look board")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
