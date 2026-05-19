//
//  CameraCaptureView.swift
//  RatioVita
//
//  iOS / visionOS: camera, Photos, Files, iPad drag-and-drop; multi-item prompts; post-capture “add another?”;
//  draft review then submit to the app Review queue (Photos only after Review filing for camera captures).
//  macOS: drag-and-drop + file import; same prompts and review queue behavior.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS) || os(visionOS)
import PhotosUI
import UIKit

private enum PadTrait {
    static var isPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
}

/// Receipt capture / import for iPhone, iPad, and visionOS.
struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let scanner: any ScannerService
    let ocrEnabled: Bool
    let compressionEnabled: Bool
    /// MainActor: `ScanResult` holds platform images (`UIImage` / `NSImage`), which must not cross arbitrary `async`
    /// isolation boundaries.
    let onSubmit: @MainActor (ScanResult, ReceiptIngestOptions) async -> Void

    @State private var draftPages: [ScannedPage] = []
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showImporter = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showReview = false
    @State private var confirmDiscard = false
    @State private var mergeSelectedPageIDs: Set<UUID> = []
    @State private var mergeEditMode: EditMode = .active

    @State private var usedCameraThisSession = false
    @State private var showAfterCapturePrompt = false

    @State private var pendingMultiURLs: [URL] = []
    @State private var showMultiURLPrompt = false

    @State private var pendingPhotoItems: [PhotosPickerItem] = []
    @State private var showMultiPhotoPrompt = false

    @State private var importStatus: String?

    /// Prevents overlapping “Send to review” work (double taps / duplicate actions).
    @State private var isSubmittingReview = false

    @AppStorage("libraryScanVaultPathPrefix") private var libraryScanVaultPathPrefix: String = ""

    @State private var dropHover = false

    private var scanTargetVaultPrefix: String? {
        let t = libraryScanVaultPathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return t.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func reviewQueueImportOptions(camera: Bool) -> ReceiptIngestOptions {
        ReceiptIngestOptions(
            pendingHumanReview: true,
            scannedViaCamera: camera,
            vaultPathPrefix: scanTargetVaultPrefix
        )
    }

    init(
        scanner: any ScannerService,
        ocrEnabled: Bool,
        compressionEnabled: Bool,
        onSubmit: @escaping @MainActor (ScanResult, ReceiptIngestOptions) async -> Void
    ) {
        self.scanner = scanner
        self.ocrEnabled = ocrEnabled
        self.compressionEnabled = compressionEnabled
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ratioVitaAdaptiveBackground.ignoresSafeArea()
                Group {
                    if showReview {
                        reviewContent
                    } else {
                        hubContent
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle(showReview ? "Merge pages" : "Add receipt")
            #if !os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .onChange(of: showReview) { _, isReview in
                    if isReview {
                        mergeSelectedPageIDs = ReceiptMergePageHeuristics.likelyBoilerplatePageIDs(in: draftPages)
                    } else {
                        mergeSelectedPageIDs = []
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            if draftPages.isEmpty {
                                dismiss()
                            } else {
                                confirmDiscard = true
                            }
                        }
                    }
                    if showReview {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button(role: .destructive) {
                                draftPages.removeAll { mergeSelectedPageIDs.contains($0.id) }
                                mergeSelectedPageIDs = []
                            } label: {
                                Label("Delete selected", systemImage: "trash")
                            }
                            .disabled(mergeSelectedPageIDs.isEmpty)
                            Button {
                                draftPages.removeAll { ReceiptMergePageHeuristics.isLikelyBoilerplatePage(for: $0) }
                                mergeSelectedPageIDs = mergeSelectedPageIDs.filter { id in
                                    draftPages.contains(where: { $0.id == id })
                                }
                            } label: {
                                Label("Strip boilerplate", systemImage: "text.badge.xmark")
                            }
                            .disabled(!draftPages
                                .contains(where: { ReceiptMergePageHeuristics.isLikelyBoilerplatePage(for: $0) }))
                            Button {
                                mergeSelectedPageIDs = ReceiptMergePageHeuristics
                                    .likelyBoilerplatePageIDs(in: draftPages)
                            } label: {
                                Label("Select conditions", systemImage: "checkmark.circle")
                            }
                            .disabled(!draftPages
                                .contains(where: { ReceiptMergePageHeuristics.isLikelyBoilerplatePage(for: $0) }))
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: [.image, .jpeg, .png, .heic, .tiff, .gif, .webP, .pdf],
                    allowsMultipleSelection: true
                ) { result in
                    Task { await importFromPickerResult(result) }
                }
                .alert("Discard all pages?", isPresented: $confirmDiscard) {
                    Button("Discard", role: .destructive) {
                        draftPages = []
                        dismiss()
                    }
                    Button("Keep editing", role: .cancel) {}
                } message: {
                    Text("You have \(draftPages.count) scanned page(s) that are not saved yet.")
                }
                .onChange(of: photoPickerItems) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    let batch = newValue
                    photoPickerItems = []
                    if batch.count > 1 {
                        pendingPhotoItems = batch
                        showMultiPhotoPrompt = true
                    } else {
                        Task { await loadPhotosMerged(batch) }
                    }
                }
                .confirmationDialog("Page captured", isPresented: $showAfterCapturePrompt, titleVisibility: .visible) {
                    Button("Add another page") {
                        Task { await captureFromCamera() }
                    }
                    Button("Continue", role: .cancel) {}
                } message: {
                    Text("Add another photo of this receipt, or continue importing.")
                }
                .confirmationDialog(
                    "Multiple photos",
                    isPresented: $showMultiPhotoPrompt,
                    titleVisibility: .visible
                ) {
                    Button("One multi-page receipt") {
                        Task {
                            await loadPhotosMerged(pendingPhotoItems)
                            pendingPhotoItems = []
                        }
                    }
                    Button("Separate receipts") {
                        Task {
                            await submitEachPhotoAsOwnReceipt(pendingPhotoItems)
                            pendingPhotoItems = []
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        pendingPhotoItems = []
                    }
                } message: {
                    Text(
                        "Treat the selection as a single receipt with multiple pages, or save each photo as its own receipt."
                    )
                }
                .confirmationDialog(
                    "Multiple files",
                    isPresented: $showMultiURLPrompt,
                    titleVisibility: .visible
                ) {
                    Button("One multi-page receipt") {
                        Task {
                            await appendImportedURLs(pendingMultiURLs)
                            pendingMultiURLs = []
                        }
                    }
                    Button("Separate receipts") {
                        Task {
                            await submitEachURLAsOwnReceipt(pendingMultiURLs)
                            pendingMultiURLs = []
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        pendingMultiURLs = []
                    }
                } message: {
                    Text("Combine every file into one draft receipt, or save each file as its own receipt in Review.")
                }
        }
    }

    private var hubContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if PadTrait.isPad {
                ipadDropZone
            }

            if !draftPages.isEmpty {
                draftSummaryCard
            }

            if let importStatus {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(importStatus)
                        .font(DesignSystem.Typography.footnote)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                }
            }

            Text("Choose how to add images. Combine sources, then review and send everything to the Review tab.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(Color.ratioVitaError)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    Task { await captureFromCamera() }
                } label: {
                    Label("Capture with camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ratioVitaPrimary)
                .controlSize(.large)
                .disabled(isBusy)

                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: 40,
                    matching: .images,
                    preferredItemEncoding: .automatic
                ) {
                    Label("Select from Photos", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isBusy)

                Button {
                    showImporter = true
                } label: {
                    Label("Select files…", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isBusy)
            }

            if !draftPages.isEmpty {
                Button {
                    showReview = true
                } label: {
                    Text(
                        draftPages.count > 1
                            ? "Merge \(draftPages.count) pages…"
                            : "Review & queue (1 page)"
                    )
                    .font(DesignSystem.Typography.bodyEmphasized)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ratioVitaPrimary)
            }

            Spacer(minLength: DesignSystem.Spacing.sm)
        }
    }

    private var ipadDropZone: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
            .strokeBorder(
                dropHover ? Color.ratioVitaPrimary : Color.ratioVitaAdaptiveBorder.opacity(0.65),
                style: StrokeStyle(lineWidth: dropHover ? 2 : 1, dash: [8, 6])
            )
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(dropHover ? Color.ratioVitaPrimary.opacity(0.08) : Color.ratioVitaAdaptiveSurface
                        .opacity(0.5))
            )
            .frame(height: 100)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title3)
                        .foregroundStyle(Color.ratioVitaPrimary)
                    Text("Drop files (iPad)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaAdaptiveText)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $dropHover) { providers in
                Task { await handleDropProviders(providers) }
                return true
            }
    }

    private var draftSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Label(
                "\(draftPages.count) page\(draftPages.count == 1 ? "" : "s") in this receipt",
                systemImage: "doc.on.doc"
            )
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text(isBusy ? "Processing…" : "OCR will run before this receipt appears under Review.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
        )
    }

    private var reviewContent: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Merge pages into one receipt")
                    .font(DesignSystem.Typography.headline)
                Text(
                    "Drag to reorder, select rows to delete in bulk, or strip pages flagged as boilerplate (terms / duplicate legalese) before Review."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            List(selection: $mergeSelectedPageIDs) {
                ForEach(Array(draftPages.enumerated()), id: \.element.id) { index, page in
                    iosMergePageRow(page: page, index: index)
                        .tag(page.id)
                }
                .onMove { indices, newOffset in
                    draftPages.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .frame(minHeight: 220)
            .environment(\.editMode, $mergeEditMode)
            .listStyle(.plain)

            Button {
                Task { await captureFromCamera() }
            } label: {
                Label("Add another page (camera)", systemImage: "plus.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Back") {
                    mergeSelectedPageIDs = []
                    showReview = false
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await saveDraft() }
                } label: {
                    if isBusy {
                        ProgressView()
                    } else {
                        Text(draftPages.count > 1 ? "Confirm merge & send to Review" : "Send to review")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ratioVitaPrimary)
                .frame(maxWidth: .infinity)
                .disabled(draftPages.isEmpty || isBusy || isSubmittingReview)
            }
        }
    }

    @ViewBuilder
    private func iosMergePageRow(page: ScannedPage, index: Int) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(uiImage: page.image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 88)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Page \(index + 1)")
                    .font(DesignSystem.Typography.subheadline.weight(.semibold))
                if let tag = ReceiptMergePageHeuristics.boilerplateTag(for: page) {
                    Text(tag)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.orange)
                }
                if ReceiptMergePageHeuristics.isLikelyBoilerplatePage(for: page) {
                    Text("Auto-delete candidate")
                        .font(DesignSystem.Typography.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 0)
            Button {
                draftPages.removeAll { $0.id == page.id }
                mergeSelectedPageIDs.remove(page.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.secondary, Color.ratioVitaAdaptiveSurface)
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove page \(index + 1)")
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func captureFromCamera() async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await scanner.scanReceipt(ocrEnabled: ocrEnabled, compressionEnabled: compressionEnabled)
            usedCameraThisSession = true
            draftPages.append(contentsOf: result.scannedPages)
            showAfterCapturePrompt = true
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func loadPhotosMerged(_ items: [PhotosPickerItem]) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        var failures = 0
        for (idx, item) in items.enumerated() {
            importStatus = "Photos \(idx + 1)/\(items.count)…"
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    failures += 1
                    continue
                }
                guard let uiImage = UIImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
                    failures += 1
                    continue
                }
                let scan = try await ReceiptScanPipeline.processImported(
                    image: uiImage,
                    ocrEnabled: ocrEnabled,
                    compressionEnabled: compressionEnabled
                )
                draftPages.append(contentsOf: scan.scannedPages)
            } catch {
                failures += 1
            }
        }
        importStatus = nil
        if failures > 0, failures == items.count {
            errorMessage = "Could not load the selected photo(s)."
        } else if failures > 0 {
            UserMessageCenter.shared.present(
                title: "Some photos were skipped",
                message: "\(failures) of \(items.count) could not be imported."
            )
        }
    }

    @MainActor
    private func submitEachPhotoAsOwnReceipt(_ items: [PhotosPickerItem]) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        for (idx, item) in items.enumerated() {
            importStatus = "Photos \(idx + 1)/\(items.count)…"
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                guard let uiImage = UIImage.rv_decodedNormalizingEXIFOrientation(from: data) else { continue }
                let scan = try await ReceiptScanPipeline.processImported(
                    image: uiImage,
                    ocrEnabled: ocrEnabled,
                    compressionEnabled: compressionEnabled
                )
                await onSubmit(scan, reviewQueueImportOptions(camera: false))
            } catch {
                /* skip */
            }
        }
        importStatus = nil
        dismiss()
    }

    @MainActor
    private func importFromPickerResult(_ result: Result<[URL], any Error>) async {
        switch result {
            case let .failure(error):
                errorMessage = error.ratioVitaUserDescription
            case let .success(urls):
                guard !urls.isEmpty else {
                    errorMessage = "No file selected."
                    return
                }
                if urls.count > 1 {
                    pendingMultiURLs = urls
                    showMultiURLPrompt = true
                } else {
                    await appendImportedURLs(urls)
                }
        }
    }

    @MainActor
    private func appendImportedURLs(_ urls: [URL]) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        var failures: [String] = []
        for (idx, url) in urls.enumerated() {
            importStatus = "Files \(idx + 1)/\(urls.count)…"
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                if url.pathExtension.lowercased() == "pdf" {
                    let scan = try await ReceiptScanPipeline.processImportedPDF(
                        at: url,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                    draftPages.append(contentsOf: scan.scannedPages)
                } else {
                    let data = try Data(contentsOf: url)
                    guard let image = UIImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
                        throw ScannerError.invalidImage
                    }
                    let scan = try await ReceiptScanPipeline.processImported(
                        image: image,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                    draftPages.append(contentsOf: scan.scannedPages)
                }
            } catch {
                failures.append(url.lastPathComponent)
            }
        }
        importStatus = nil
        if !failures.isEmpty {
            errorMessage = "Could not import: \(failures.prefix(3).joined(separator: ", "))"
        }
    }

    @MainActor
    private func submitEachURLAsOwnReceipt(_ urls: [URL]) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        for (idx, url) in urls.enumerated() {
            importStatus = "Files \(idx + 1)/\(urls.count)…"
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let scan: ScanResult
                if url.pathExtension.lowercased() == "pdf" {
                    scan = try await ReceiptScanPipeline.processImportedPDF(
                        at: url,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                } else {
                    let data = try Data(contentsOf: url)
                    guard let image = UIImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
                        throw ScannerError.invalidImage
                    }
                    scan = try await ReceiptScanPipeline.processImported(
                        image: image,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                }
                await onSubmit(scan, reviewQueueImportOptions(camera: false))
            } catch {
                /* skip */
            }
        }
        importStatus = nil
        dismiss()
    }

    @MainActor
    private func handleDropProviders(_ providers: [NSItemProvider]) async {
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        guard !urls.isEmpty else { return }
        if urls.count > 1 {
            pendingMultiURLs = urls
            showMultiURLPrompt = true
        } else {
            await appendImportedURLs(urls)
        }
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    @MainActor
    private func saveDraft() async {
        guard !draftPages.isEmpty else { return }
        guard !isSubmittingReview else { return }
        isSubmittingReview = true
        errorMessage = nil
        isBusy = true
        defer {
            isBusy = false
            isSubmittingReview = false
        }
        await Task.yield()
        let merged = ReceiptScanPipeline.mergedScanResult(
            fromPages: draftPages,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled
        )
        await onSubmit(merged, reviewQueueImportOptions(camera: usedCameraThisSession))
        await Task.yield()
        dismiss()
    }
}

#Preview("CameraCaptureView (iOS)") {
    CameraCaptureView(
        scanner: PreviewScannerService(),
        ocrEnabled: true,
        compressionEnabled: false,
        onSubmit: { @MainActor _, _ in }
    )
}

#elseif os(macOS)
import AppKit

/// macOS: file import and drag-and-drop only (no camera). Same review-queue behavior as iOS.
struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let scanner: any ScannerService
    let ocrEnabled: Bool
    let compressionEnabled: Bool
    /// MainActor: `ScanResult` holds platform images (`UIImage` / `NSImage`), which must not cross arbitrary `async`
    /// isolation boundaries.
    let onSubmit: @MainActor (ScanResult, ReceiptIngestOptions) async -> Void

    @State private var draftPages: [ScannedPage] = []
    @State private var showImporter = false
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showReview = false
    @State private var confirmDiscard = false
    @State private var dropHover = false

    @State private var mergeSelectedPageIDs: Set<UUID> = []

    @State private var usedCameraThisSession = false

    @State private var pendingMultiURLs: [URL] = []
    @State private var showMultiURLPrompt = false

    @State private var importStatus: String?

    /// Prevents overlapping “Send to review” work (double taps / duplicate actions).
    @State private var isSubmittingReview = false

    @AppStorage("libraryScanVaultPathPrefix") private var libraryScanVaultPathPrefix: String = ""

    private var scanTargetVaultPrefix: String? {
        let t = libraryScanVaultPathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return t.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func reviewQueueImportOptions(camera: Bool) -> ReceiptIngestOptions {
        ReceiptIngestOptions(
            pendingHumanReview: true,
            scannedViaCamera: camera,
            vaultPathPrefix: scanTargetVaultPrefix
        )
    }

    init(
        scanner: any ScannerService,
        ocrEnabled: Bool,
        compressionEnabled: Bool,
        onSubmit: @escaping @MainActor (ScanResult, ReceiptIngestOptions) async -> Void
    ) {
        self.scanner = scanner
        self.ocrEnabled = ocrEnabled
        self.compressionEnabled = compressionEnabled
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ratioVitaAdaptiveBackground.ignoresSafeArea()
                Group {
                    if showReview {
                        reviewContent
                    } else {
                        hubContent
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle(showReview ? "Merge pages" : "Import receipt")
            .onChange(of: showReview) { _, isReview in
                if isReview {
                    mergeSelectedPageIDs = ReceiptMergePageHeuristics.likelyBoilerplatePageIDs(in: draftPages)
                } else {
                    mergeSelectedPageIDs = []
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if draftPages.isEmpty {
                            dismiss()
                        } else {
                            confirmDiscard = true
                        }
                    }
                }
                if showReview {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(role: .destructive) {
                            draftPages.removeAll { mergeSelectedPageIDs.contains($0.id) }
                            mergeSelectedPageIDs = []
                        } label: {
                            Label("Delete selected", systemImage: "trash")
                        }
                        .disabled(mergeSelectedPageIDs.isEmpty)
                        Button {
                            draftPages.removeAll { ReceiptMergePageHeuristics.isLikelyBoilerplatePage(for: $0) }
                            mergeSelectedPageIDs = mergeSelectedPageIDs.filter { id in
                                draftPages.contains(where: { $0.id == id })
                            }
                        } label: {
                            Label("Strip boilerplate", systemImage: "text.badge.xmark")
                        }
                        .disabled(!draftPages
                            .contains(where: { ReceiptMergePageHeuristics.isLikelyBoilerplatePage(for: $0) }))
                        Button {
                            mergeSelectedPageIDs = ReceiptMergePageHeuristics.likelyBoilerplatePageIDs(in: draftPages)
                        } label: {
                            Label("Select conditions", systemImage: "checkmark.circle")
                        }
                        .disabled(!draftPages
                            .contains(where: { ReceiptMergePageHeuristics.isLikelyBoilerplatePage(for: $0) }))
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.image, .jpeg, .png, .heic, .tiff, .gif, .webP, .pdf],
                allowsMultipleSelection: true
            ) { result in
                Task { await importFromPickerResult(result) }
            }
            .alert("Discard all pages?", isPresented: $confirmDiscard) {
                Button("Discard", role: .destructive) {
                    draftPages = []
                    dismiss()
                }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("You have \(draftPages.count) page(s) that are not saved yet.")
            }
            .confirmationDialog(
                "Multiple files",
                isPresented: $showMultiURLPrompt,
                titleVisibility: .visible
            ) {
                Button("One multi-page receipt") {
                    Task {
                        await appendImportedURLs(pendingMultiURLs)
                        pendingMultiURLs = []
                    }
                }
                Button("Separate receipts") {
                    Task {
                        await submitEachURLAsOwnReceipt(pendingMultiURLs)
                        pendingMultiURLs = []
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingMultiURLs = []
                }
            } message: {
                Text("Combine every file into one draft receipt, or save each file as its own receipt in Review.")
            }
        }
    }

    private var hubContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            dropZone

            if !draftPages.isEmpty {
                draftSummaryCard
            }

            if let importStatus {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(importStatus)
                        .font(DesignSystem.Typography.footnote)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                }
            }

            Text(
                "Drop images or PDFs here, or use Choose files. Multiple files prompt for one receipt vs many."
            )
            .font(DesignSystem.Typography.subheadline)
            .foregroundStyle(Color.ratioVitaTextSecondary)
            .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(Color.ratioVitaError)
                    .multilineTextAlignment(.center)
            }

            Button {
                showImporter = true
            } label: {
                Label("Choose files…", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ratioVitaPrimary)
            .controlSize(.large)
            .disabled(isBusy)

            if !draftPages.isEmpty {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button("Clear pages") {
                        draftPages = []
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showReview = true
                    } label: {
                        Text(
                            draftPages.count > 1
                                ? "Merge \(draftPages.count) pages…"
                                : "Review & queue (1)"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ratioVitaPrimary)
                }
            }

            Spacer(minLength: DesignSystem.Spacing.sm)
        }
        .onAppear {
            _ = scanner.isCameraAvailable()
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
            .strokeBorder(
                dropHover ? Color.ratioVitaPrimary : Color.ratioVitaAdaptiveBorder.opacity(0.65),
                style: StrokeStyle(lineWidth: dropHover ? 2 : 1, dash: [8, 6])
            )
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(dropHover ? Color.ratioVitaPrimary.opacity(0.08) : Color.ratioVitaAdaptiveSurface
                        .opacity(0.5))
            )
            .frame(height: 120)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title2)
                        .foregroundStyle(Color.ratioVitaPrimary)
                    Text("Drop files to add pages")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(Color.ratioVitaAdaptiveText)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $dropHover) { providers in
                Task { await handleDropProviders(providers) }
                return true
            }
    }

    private var draftSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Label("\(draftPages.count) page\(draftPages.count == 1 ? "" : "s") ready", systemImage: "doc.on.doc")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text(isBusy ? "Processing…" : "OCR runs before items appear under Review.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
    }

    private var reviewContent: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Merge pages into one receipt")
                    .font(DesignSystem.Typography.headline)
                Text(
                    "Drag rows to reorder, select pages to delete in bulk, or strip pages flagged as boilerplate before Review (OCR runs on submit)."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            List(selection: $mergeSelectedPageIDs) {
                ForEach(Array(draftPages.enumerated()), id: \.element.id) { index, page in
                    macMergePageRow(page: page, index: index)
                        .tag(page.id)
                }
                .onMove { indices, newOffset in
                    draftPages.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .frame(minHeight: 240)
            .listStyle(.inset)

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Back") {
                    mergeSelectedPageIDs = []
                    showReview = false
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await saveDraft() }
                } label: {
                    if isBusy {
                        ProgressView()
                    } else {
                        Text(draftPages.count > 1 ? "Confirm merge & send to Review" : "Send to review")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ratioVitaPrimary)
                .frame(maxWidth: .infinity)
                .disabled(draftPages.isEmpty || isBusy || isSubmittingReview)
            }
        }
    }

    @ViewBuilder
    private func macMergePageRow(page: ScannedPage, index: Int) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(nsImage: page.image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 96)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Page \(index + 1)")
                    .font(DesignSystem.Typography.subheadline.weight(.semibold))
                if let tag = ReceiptMergePageHeuristics.boilerplateTag(for: page) {
                    Text(tag)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.orange)
                }
                if ReceiptMergePageHeuristics.isLikelyBoilerplatePage(for: page) {
                    Text("Auto-delete candidate")
                        .font(DesignSystem.Typography.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 0)
            Button {
                draftPages.removeAll { $0.id == page.id }
                mergeSelectedPageIDs.remove(page.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.secondary, Color.ratioVitaAdaptiveSurface)
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove page \(index + 1)")
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func handleDropProviders(_ providers: [NSItemProvider]) async {
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        guard !urls.isEmpty else { return }
        if urls.count > 1 {
            pendingMultiURLs = urls
            showMultiURLPrompt = true
        } else {
            await appendImportedURLs(urls)
        }
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    @MainActor
    private func importFromPickerResult(_ result: Result<[URL], any Error>) async {
        switch result {
            case let .failure(error):
                errorMessage = error.ratioVitaUserDescription
            case let .success(urls):
                guard !urls.isEmpty else {
                    errorMessage = "No file selected."
                    return
                }
                if urls.count > 1 {
                    pendingMultiURLs = urls
                    showMultiURLPrompt = true
                } else {
                    await appendImportedURLs(urls)
                }
        }
    }

    @MainActor
    private func appendImportedURLs(_ urls: [URL]) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        var failures: [String] = []
        for (idx, url) in urls.enumerated() {
            importStatus = "Files \(idx + 1)/\(urls.count)…"
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                if url.pathExtension.lowercased() == "pdf" {
                    let scan = try await ReceiptScanPipeline.processImportedPDF(
                        at: url,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                    draftPages.append(contentsOf: scan.scannedPages)
                } else {
                    let data = try Data(contentsOf: url)
                    guard let image = RVImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
                        throw ScannerError.invalidImage
                    }
                    let scan = try await ReceiptScanPipeline.processImported(
                        image: image,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                    draftPages.append(contentsOf: scan.scannedPages)
                }
            } catch {
                failures.append(url.lastPathComponent)
            }
        }
        importStatus = nil

        if !failures.isEmpty, draftPages.isEmpty {
            errorMessage = "Could not import: \(failures.prefix(3).joined(separator: ", "))"
        } else if !failures.isEmpty {
            UserMessageCenter.shared.present(
                title: "Some files were skipped",
                message: failures.joined(separator: ", ")
            )
        }
    }

    @MainActor
    private func submitEachURLAsOwnReceipt(_ urls: [URL]) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        for (idx, url) in urls.enumerated() {
            importStatus = "Files \(idx + 1)/\(urls.count)…"
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let scan: ScanResult
                if url.pathExtension.lowercased() == "pdf" {
                    scan = try await ReceiptScanPipeline.processImportedPDF(
                        at: url,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                } else {
                    let data = try Data(contentsOf: url)
                    guard let image = RVImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
                        throw ScannerError.invalidImage
                    }
                    scan = try await ReceiptScanPipeline.processImported(
                        image: image,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                }
                await onSubmit(scan, reviewQueueImportOptions(camera: false))
            } catch {
                /* skip */
            }
        }
        importStatus = nil
        dismiss()
    }

    @MainActor
    private func saveDraft() async {
        guard !draftPages.isEmpty else { return }
        guard !isSubmittingReview else { return }
        isSubmittingReview = true
        errorMessage = nil
        isBusy = true
        defer {
            isBusy = false
            isSubmittingReview = false
        }
        await Task.yield()
        let merged = ReceiptScanPipeline.mergedScanResult(
            fromPages: draftPages,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled
        )
        await onSubmit(merged, reviewQueueImportOptions(camera: usedCameraThisSession))
        await Task.yield()
        dismiss()
    }
}

#Preview("CameraCaptureView (macOS)") {
    CameraCaptureView(
        scanner: PreviewScannerService(),
        ocrEnabled: true,
        compressionEnabled: false,
        onSubmit: { @MainActor _, _ in }
    )
}
#endif
