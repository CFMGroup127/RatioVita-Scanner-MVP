import SwiftData
import SwiftUI

/// Scrollable page thumbnails with inline checkboxes, context menus, and decoupler actions (Sprint S canvas).
struct ReceiptMultiPageCanvasStrip: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent

    @Bindable var receipt: Receipt
    @Binding var selectedPageIndices: Set<Int>
    @Binding var documentToolbarImageID: UUID?
    var onExpandPage: (ReceiptImage) -> Void
    var onDecoupleError: (String) -> Void
    var onDecoupleSuccess: (String) -> Void

    @State private var confirmExplodeChecked = false

    private var sortedImages: [ReceiptImage] {
        receipt.images.sorted { $0.pageIndex < $1.pageIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(
                "Check pages as you scroll, then **Extract** (one new record) or **Explode checked** (one record per page). Right-click a thumbnail for the same actions."
            )
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(Color.ratioVitaTextSecondary)

            if !selectedPageIndices.isEmpty {
                pageSelectionToolbar
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ForEach(sortedImages, id: \.id) { image in
                        pageThumbnail(image)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .frame(maxHeight: 520)
        }
    }

    @ViewBuilder
    private var pageSelectionToolbar: some View {
        let count = selectedPageIndices.count
        VStack(alignment: .leading, spacing: 8) {
            Text("\(count) page(s) selected")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(brandAccent)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    extractCheckedPages()
                } label: {
                    Label("Extract checked (\(count))", systemImage: "arrow.up.right.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(count < 1 || sortedImages.count < 2)

                Button {
                    confirmExplodeChecked = true
                } label: {
                    Label("Explode checked only", systemImage: "rectangle.split.3x1.fill")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(!canExplodeChecked)

                Button {
                    selectedPageIndices.removeAll()
                } label: {
                    Text("Clear")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .confirmationDialog(
            "Explode \(count) checked page(s)?",
            isPresented: $confirmExplodeChecked,
            titleVisibility: .visible
        ) {
            Button("Explode checked pages", role: .destructive) {
                explodeCheckedPages()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Each checked page becomes its own receipt. Unchecked pages stay on this record. Fields are re-parsed after the split."
            )
        }
    }

    private var canExplodeChecked: Bool {
        guard sortedImages.count >= 2, !selectedPageIndices.isEmpty else { return false }
        let all = Set(sortedImages.map(\.pageIndex))
        return selectedPageIndices.intersection(all).count < all.count
    }

    @ViewBuilder
    private func pageThumbnail(_ image: ReceiptImage) -> some View {
        let pageIdx = image.pageIndex
        let isChecked = selectedPageIndices.contains(pageIdx)
        let isToolbarTarget = documentToolbarImageID == image.id

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { isChecked },
                        set: { on in
                            if on {
                                selectedPageIndices.insert(pageIdx)
                            } else {
                                selectedPageIndices.remove(pageIdx)
                            }
                            documentToolbarImageID = image.id
                        }
                    )
                )
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
                .labelsHidden()
                .accessibilityLabel("Select page \(pageIdx + 1)")

                Spacer(minLength: 0)

                Text("Page \(pageIdx + 1)")
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(isToolbarTarget ? brandAccent : Color.ratioVitaTextSecondary)
            }

            Group {
                if let platformImage = image.platformImage {
                    Image(rvImage: platformImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
                        .shadow(DesignSystem.Shadow.small)
                        .onTapGesture {
                            documentToolbarImageID = image.id
                            onExpandPage(image)
                        }
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .fill(Color.ratioVitaAdaptiveSurface)
                        .frame(height: 160)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                        }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(
                        isChecked ? brandAccent : Color.ratioVitaAdaptiveBorder.opacity(0.45),
                        lineWidth: isChecked ? 2 : 1
                    )
            )
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface.opacity(isChecked ? 1.0 : 0.55))
        )
        .contextMenu {
            pageContextMenu(for: image)
        }
    }

    @ViewBuilder
    private func pageContextMenu(for image: ReceiptImage) -> some View {
        let bulk = !selectedPageIndices.isEmpty
        let count = bulk ? selectedPageIndices.count : 1

        if bulk {
            Button {
                extractCheckedPages()
            } label: {
                Label("Extract checked pages (\(count))", systemImage: "arrow.up.right.doc")
            }
            if canExplodeChecked {
                Button(role: .destructive) {
                    explodeCheckedPages()
                } label: {
                    Label("Explode checked pages only", systemImage: "rectangle.split.3x1.fill")
                }
            }
            Button {
                selectedPageIndices.removeAll()
            } label: {
                Label("Clear selection", systemImage: "xmark.circle")
            }
        } else {
            Button {
                selectedPageIndices = [image.pageIndex]
                extractCheckedPages()
            } label: {
                Label("Extract page \(image.pageIndex + 1)", systemImage: "arrow.up.right.doc")
            }
            if sortedImages.count >= 2 {
                Button(role: .destructive) {
                    selectedPageIndices = [image.pageIndex]
                    explodeCheckedPages()
                } label: {
                    Label("Explode page \(image.pageIndex + 1)", systemImage: "rectangle.split.3x1.fill")
                }
            }
            Button {
                image.applyRotationQuarterTurnsClockwise(1)
            } label: {
                Label("Rotate 90° right", systemImage: "rotate.right")
            }
            Button {
                image.applyFlipHorizontal()
            } label: {
                Label("Mirror horizontal", systemImage: "arrow.left.and.right")
            }
        }
    }

    private func extractCheckedPages() {
        guard sortedImages.count >= 2 else { return }
        let indices = selectedPageIndices
        guard !indices.isEmpty else {
            onDecoupleError("Select at least one page to extract.")
            return
        }
        do {
            let spawned = try ReceiptPageDecouplerService.splitSelectedPages(
                from: receipt,
                selectedPageIndices: indices,
                modelContext: modelContext
            )
            selectedPageIndices.removeAll()
            modelContext.processPendingChanges()
            onDecoupleSuccess(
                "Extracted \(indices.count) page(s) into a new record (\(spawned.merchant)). "
                    + "Both stay in Review until you file them—the parent batch is still pinned here."
            )
        } catch {
            onDecoupleError(error.localizedDescription)
        }
    }

    private func explodeCheckedPages() {
        let indices = selectedPageIndices
        guard !indices.isEmpty else { return }
        do {
            let spawned = try ReceiptPageDecouplerService.explodeSelectedPages(
                from: receipt,
                selectedPageIndices: indices,
                modelContext: modelContext
            )
            selectedPageIndices.removeAll()
            onDecoupleSuccess(
                "Exploded \(spawned.count) page(s) into separate records. Unchecked pages remain on this batch."
            )
        } catch {
            onDecoupleError(error.localizedDescription)
        }
    }
}
