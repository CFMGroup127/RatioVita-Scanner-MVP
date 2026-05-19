import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

private enum ReceiptEditHaptics {
    static func verifiedSave() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

private struct ReceiptImageExpandedToken: Identifiable, Hashable {
    let id: UUID
}

#if os(iOS)
private struct PerspectiveCropTarget: Identifiable {
    let id: UUID
}
#endif

struct ReceiptDetailView: View {
    private enum Layout {
        /// ~15% more than legacy 20pt (Monday Ignition spacing note).
        static let sectionSpacing: CGFloat = 23
        static let innerSpacing: CGFloat = 12
    }

    @Environment(\.brandAccent) private var brandAccent
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let receipt: Receipt
    @State private var confirmMoveToTrash = false
    @State private var confirmPermanentDelete = false
    @State private var expandedImageToken: ReceiptImageExpandedToken?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showVerifiedEraseSheet = false
    @State private var tombReason = ""
    @State private var tombActor = ""
    @State private var documentToolbarImageID: UUID?
    @State private var confirmExplodeAllPages = false
    @State private var explodeErrorMessage: String?
    @State private var selectedPageIndices: Set<Int> = []
    @State private var decoupleSuccessMessage: String?
    @State private var decoupleErrorMessage: String?
    #if os(iOS)
    @State private var perspectiveCropTarget: PerspectiveCropTarget?
    #endif
    @State private var regionCropTarget: ReceiptPageRegionCropToken?
    @State private var showReplacePageImporter = false
    @State private var rescanErrorMessage: String?

    /// **Side-car** on every **iPad** (`regular` width), portrait or landscape. iPhone: stacked layout with pinned
    /// document strip (see `iphoneDocumentStrip`).
    private var useSplitEditChrome: Bool {
        #if os(iOS) || os(visionOS)
        horizontalSizeClass == .regular
        #else
        false
        #endif
    }

    private var isIPhoneCompactStack: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    /// Split from `body` so the macOS compiler can type-check the heavy modifier chain.
    @ViewBuilder
    private var receiptDetailNavigationChrome: some View {
        if useSplitEditChrome {
            NavigationSplitView {
                forensicSourceColumn(r: receipt)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 420, max: 640)
            } detail: {
                NavigationStack {
                    EditReceiptView(receipt: receipt, chrome: .sideCarColumn, onBackFromSideCar: { dismiss() })
                        .id(receipt.persistentModelID)
                }
            }
        } else {
            #if os(iOS)
            if isIPhoneCompactStack {
                GeometryReader { proxy in
                    let stripH = max(140, proxy.size.height * 0.30)
                    VStack(spacing: 0) {
                        iphoneDocumentStrip(r: receipt, height: stripH)
                            .frame(height: stripH)
                            .frame(maxWidth: .infinity)
                            .background(Color.ratioVitaAdaptiveSurface.opacity(0.35))
                        Divider()
                        ScrollView {
                            iphoneForensicScrollContent(r: receipt)
                        }
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            } else {
                stackedReceiptEditor(r: receipt)
            }
            #else
            stackedReceiptEditor(r: receipt)
            #endif
        }
    }

    var body: some View {
        @Bindable var r = receipt
        receiptDetailLayerImportAndAlerts(
            receiptDetailLayerSheetsAndExplode(
                receiptDetailLayerTrashDialogs(
                    receiptDetailNavigationFrame(r: r)
                )
            )
        )
    }

    @ViewBuilder
    private func receiptDetailNavigationFrame(r: Receipt) -> some View {
        receiptDetailNavigationChrome
            .id(receipt.persistentModelID)
            .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
        #if os(iOS) || os(visionOS)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        #endif
            .navigationTitle(r.merchant)
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { receiptDetailToolbar(r: r) }
    }

    @ToolbarContentBuilder
    private func receiptDetailToolbar(r: Receipt) -> some ToolbarContent {
        #if os(iOS) || os(visionOS)
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if r.trashedAt == nil, r.images.count > 1 {
                Button {
                    confirmExplodeAllPages = true
                } label: {
                    Image(systemName: "rectangle.split.3x1.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.orange)
                }
                .accessibilityLabel("Explode all pages into separate records")
            }
            if r.trashedAt != nil {
                Button("Recover") {
                    recoverFromTrash()
                }
                Button("Erase", role: .destructive) {
                    confirmPermanentDelete = true
                }
            } else {
                Button(role: .destructive) {
                    confirmMoveToTrash = true
                } label: {
                    Label("Trash", systemImage: "trash")
                }
            }
        }
        #else
        if r.trashedAt == nil, r.images.count > 1 {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    confirmExplodeAllPages = true
                } label: {
                    Label("Explode stack", systemImage: "rectangle.split.3x1.fill")
                }
                .help("Explode every page into its own forensic record")
            }
        }
        if r.trashedAt != nil {
            ToolbarItem(placement: .destructiveAction) {
                Button("Erase", role: .destructive) {
                    confirmPermanentDelete = true
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Recover") {
                    recoverFromTrash()
                }
                .fontWeight(.semibold)
            }
        } else {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    confirmMoveToTrash = true
                } label: {
                    Label("Trash", systemImage: "trash")
                }
            }
        }
        #endif
    }

    private func receiptDetailLayerTrashDialogs(_ content: some View) -> some View {
        content
            .confirmationDialog(
                "Move this receipt to Trash?",
                isPresented: $confirmMoveToTrash,
                titleVisibility: .visible
            ) {
                Button("Move to Trash", role: .destructive) {
                    moveReceiptToTrash()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can recover it later from the Trash tab.")
            }
            .confirmationDialog(
                "Permanently erase this receipt?",
                isPresented: $confirmPermanentDelete,
                titleVisibility: .visible
            ) {
                Button("Erase forever", role: .destructive) {
                    if receipt.isVerified {
                        showVerifiedEraseSheet = true
                    } else {
                        performPermanentDeleteUnverified()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    receipt.isVerified
                        ? "This receipt is marked Verified. You will be asked for a reason and who authorized removal; a tombstone remains on your timeline."
                        : "This cannot be undone."
                )
            }
    }

    private func receiptDetailPostExpandedSheets(_ content: some View) -> some View {
        content
            .sheet(isPresented: $showVerifiedEraseSheet) {
                verifiedPermanentEraseSheet
            }
            .confirmationDialog(
                "Explode every page into its own record?",
                isPresented: $confirmExplodeAllPages,
                titleVisibility: .visible
            ) {
                Button("Explode all pages", role: .destructive) {
                    performExplodeAllPages()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Each page becomes a separate receipt. Shadow links point back to this batch for forensic traceability."
                )
            }
            .alert(
                "Could not explode pages",
                isPresented: Binding(
                    get: { explodeErrorMessage != nil },
                    set: { if !$0 { explodeErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { explodeErrorMessage = nil }
            } message: {
                Text(explodeErrorMessage ?? "")
            }
            .alert(
                "Page extract / explode",
                isPresented: Binding(
                    get: { decoupleErrorMessage != nil },
                    set: { if !$0 { decoupleErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { decoupleErrorMessage = nil }
            } message: {
                Text(decoupleErrorMessage ?? "")
            }
            .alert(
                "Pages updated",
                isPresented: Binding(
                    get: { decoupleSuccessMessage != nil },
                    set: { if !$0 { decoupleSuccessMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { decoupleSuccessMessage = nil }
            } message: {
                Text(decoupleSuccessMessage ?? "")
            }
        #if os(iOS)
            .sheet(item: $perspectiveCropTarget) { target in
                if let img = receipt.images.first(where: { $0.id == target.id }) {
                    ReceiptPerspectiveCropSheet(image: img)
                }
            }
        #endif
            .sheet(item: $regionCropTarget) { target in
                if let img = receipt.images.first(where: { $0.id == target.id }) {
                    ReceiptRegionCropSheet(image: img)
                }
            }
    }

    private func receiptDetailLayerSheetsAndExplode(_ content: some View) -> some View {
        #if os(iOS)
        receiptDetailPostExpandedSheets(
            content.fullScreenCover(item: $expandedImageToken) { token in
                if let img = receipt.images.first(where: { $0.id == token.id }) {
                    ReceiptImageFullScreenSheet(image: img) {
                        expandedImageToken = nil
                    }
                }
            }
        )
        #else
        receiptDetailPostExpandedSheets(
            content.sheet(item: $expandedImageToken) { token in
                if let img = receipt.images.first(where: { $0.id == token.id }) {
                    ReceiptImageFullScreenSheet(image: img) {
                        expandedImageToken = nil
                    }
                }
            }
        )
        #endif
    }

    private func receiptDetailLayerImportAndAlerts(_ content: some View) -> some View {
        content
            .fileImporter(
                isPresented: $showReplacePageImporter,
                allowedContentTypes: [.jpeg, .png, .heic, .tiff],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                    case let .success(urls):
                        guard let url = urls.first,
                              let tid = documentToolbarImageID,
                              let img = receipt.images.first(where: { $0.id == tid }) else { return }
                        Task { @MainActor in
                            do {
                                try await ReceiptImageRescanSupport.replacePageRasterFromFile(
                                    receiptImage: img,
                                    fileURL: url,
                                    modelContext: modelContext
                                )
                                ReceiptEditHaptics.verifiedSave()
                            } catch {
                                rescanErrorMessage = error.localizedDescription
                            }
                        }
                    case let .failure(err):
                        rescanErrorMessage = err.localizedDescription
                }
            }
            .alert(
                "Replace page image",
                isPresented: Binding(
                    get: { rescanErrorMessage != nil },
                    set: { if !$0 { rescanErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { rescanErrorMessage = nil }
            } message: {
                Text(rescanErrorMessage ?? "")
            }
    }

    @ViewBuilder
    private func stackedReceiptEditor(r: Receipt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                forensicSourceColumn(r: r)
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.xs)
                Text("Receipt fields")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(brandAccent)
                EditReceiptView(receipt: r, chrome: .inlineScrollStack)
                    .id(receipt.persistentModelID)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        #if os(iOS) || os(visionOS)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        #endif
    }

    @ViewBuilder
    private func forensicSourceInner(r: Receipt, showsDocumentImages: Bool) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            summaryStrip
            productionProjectCard
            if !useSplitEditChrome {
                businessUseCard
            }

            if showsDocumentImages, !r.images.isEmpty {
                imagesSection
            }

            if let notes = r.notes, !notes.isEmpty {
                notesSection(notes)
            }

            if !combinedOCRText.isEmpty {
                let ocrParsed = OCRParsing.extractData(from: combinedOCRText)
                let display = r.displayExtractedData(fallbackFromOCR: ocrParsed)
                structuredOCRSummarySection(display, extractionSource: r.extractionSource)
                ocrSection(combinedOCRText)
            }
        }
    }

    @ViewBuilder
    private func forensicSourceColumn(r: Receipt, showsDocumentImages: Bool = true) -> some View {
        ScrollView {
            forensicSourceInner(r: r, showsDocumentImages: showsDocumentImages)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }

    #if os(iOS)
    @ViewBuilder
    private func iphoneDocumentStrip(r: Receipt, height: CGFloat) -> some View {
        let imgs = r.images.sorted(by: { $0.pageIndex < $1.pageIndex })
        if imgs.isEmpty {
            ContentUnavailableView("No scan", systemImage: "doc.text", description: Text("Import or capture pages."))
                .frame(maxHeight: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(imgs, id: \.id) { image in
                        ReceiptDetailImageRow(
                            image: image,
                            showsInlineImageTools: true,
                            onExpand: { expandedImageToken = ReceiptImageExpandedToken(id: image.id) }
                        )
                        .frame(height: max(96, height - 28))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
        }
    }

    @ViewBuilder
    private func iphoneForensicScrollContent(r: Receipt) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            forensicSourceInner(r: r, showsDocumentImages: false)
            Divider()
                .padding(.vertical, DesignSystem.Spacing.xs)
            Text("Receipt fields")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(brandAccent)
            EditReceiptView(receipt: r, chrome: .inlineScrollStack)
                .id(receipt.persistentModelID)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }
    #endif

    private var verifiedPermanentEraseSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Verified documents require an audit trail. A tombstone will appear on the Timeline with this reason."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                }
                Section("Audit") {
                    TextField("Reason for removal", text: $tombReason, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Authorized by (your name)", text: $tombActor)
                }
            }
            .navigationTitle("Erase verified receipt")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showVerifiedEraseSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Erase forever", role: .destructive) {
                            performVerifiedPermanentDelete()
                        }
                        .disabled(
                            tombReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || tombActor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }
        }
    }

    private var sortedImages: [ReceiptImage] {
        receipt.images.sorted(by: { $0.pageIndex < $1.pageIndex })
    }

    private var documentToolbarImage: ReceiptImage? {
        if let tid = documentToolbarImageID, let m = sortedImages.first(where: { $0.id == tid }) {
            return m
        }
        return sortedImages.first
    }

    /// All pages’ OCR joined for parsing and display (multi-page receipts).
    private var combinedOCRText: String {
        sortedImages.compactMap(\.ocrText).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    @ViewBuilder
    private func structuredOCRSummarySection(_ data: ExtractedData, extractionSource: String) -> some View {
        let hasLineItems = !(data.lineItems ?? []).isEmpty
        let hasAny = data.merchant != nil || data.vendorAddress != nil || data.documentNumber != nil
            || data.date != nil || data.total != nil || data.subtotal != nil || data.taxAmount != nil
            || data.paymentMethodSummary != nil || data.documentKind != nil || hasLineItems
        if hasAny {
            VStack(alignment: .leading, spacing: Layout.innerSpacing) {
                Text("Key fields")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(brandAccent)
                Text(extractionSourceBlurb(extractionSource))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    if let m = data.merchant {
                        labeledOCRRow("Merchant / company", m)
                    }
                    if let a = data.vendorAddress {
                        labeledOCRRow("Address", a)
                    }
                    if let d = data.documentNumber {
                        labeledOCRRow("Receipt / invoice #", d)
                    }
                    if let k = data.documentKind {
                        labeledOCRRow("Document kind", k)
                    }
                    if let d = data.date {
                        labeledOCRRow("Date (on receipt)", d.formatted(date: .abbreviated, time: .omitted))
                    }
                    if let s = data.subtotal {
                        labeledOCRRow("Subtotal", s.formatted(.number.precision(.fractionLength(2))))
                    }
                    if let t = data.taxAmount {
                        labeledOCRRow("Tax", t.formatted(.number.precision(.fractionLength(2))))
                    }
                    if let t = data.total {
                        let code = data.currency ?? receipt.currencyCode
                        labeledOCRRow("Total", t.formatted(.currency(code: code)))
                    }
                    if let p = data.paymentMethodSummary {
                        labeledOCRRow("Payment", p)
                    }
                    if hasLineItems {
                        lineItemsSummary(data.lineItems ?? [])
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                        .fill(Color.ratioVitaAdaptiveSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                        .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
                )
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveBackground.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private func extractionSourceBlurb(_ source: String) -> String {
        switch source {
            case "gemini":
                "Gemini JSON extraction from raw OCR (with on-device fallback). Invoice ↔ payment linking is planned for a later release."
            case "manual":
                "Fields edited manually. Invoice ↔ payment linking is planned for a later release."
            default:
                "On-device heuristic extraction from OCR. Add a Gemini API key in Settings for structured JSON parsing. Invoice ↔ payment linking is planned for a later release."
        }
    }

    @ViewBuilder
    private func lineItemsSummary(_ items: [LineItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Line items (persisted)")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            ForEach(Array(items.prefix(12).enumerated()), id: \.offset) { _, item in
                let qty = item.quantity.map { "\($0)× " } ?? ""
                let price = item.totalPrice ?? item.unitPrice
                let priceText = price.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—"
                let serial = item.serialNumber.map { " · SN: \($0)" } ?? ""
                Text("\(qty)\(item.description) — \(priceText)\(serial)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                    .textSelection(.enabled)
            }
            if items.count > 12 {
                Text("… and \(items.count - 12) more")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
        }
    }

    private func labeledOCRRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
                .textSelection(.enabled)
        }
    }

    private func moveReceiptToTrash() {
        receipt.trashedAt = Date()
        try? modelContext.save()
        dismiss()
    }

    private func recoverFromTrash() {
        receipt.trashedAt = nil
        try? modelContext.save()
    }

    private func performPermanentDeleteUnverified() {
        try? ReceiptPermanentDeletion.deletePermanently(
            receipt,
            modelContext: modelContext,
            verifiedReason: nil,
            verifiedAuthorizedBy: nil
        )
        dismiss()
    }

    private func performVerifiedPermanentDelete() {
        do {
            try ReceiptPermanentDeletion.deletePermanently(
                receipt,
                modelContext: modelContext,
                verifiedReason: tombReason,
                verifiedAuthorizedBy: tombActor
            )
            showVerifiedEraseSheet = false
            tombReason = ""
            tombActor = ""
            dismiss()
        } catch {
            // Missing audit fields are prevented by button disable; keep sheet open on unexpected failure.
        }
    }

    private func performExplodeAllPages() {
        explodeErrorMessage = nil
        do {
            _ = try ReceiptPageDecouplerService.explodeAllPages(from: receipt, modelContext: modelContext)
            ReceiptEditHaptics.verifiedSave()
        } catch {
            explodeErrorMessage = error.localizedDescription
        }
    }

    private var summaryStrip: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text((receipt.transactionDate ?? receipt.createdAt).formatted(date: .abbreviated, time: .shortened))
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(Color.ratioVitaAdaptiveText)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundStyle(brandAccent)
                }
                .labelStyle(.titleAndIcon)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(receipt.total, format: .currency(code: receipt.currencyCode))
                    .font(DesignSystem.Typography.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(brandAccent)
                    .monospacedDigit()
                Text(receipt.currencyCode)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .stroke(brandAccent.opacity(0.25), lineWidth: 1)
        )
        .shadow(DesignSystem.Shadow.small)
    }

    private var linkedProductionProject: ProductionProject? {
        let sessions = receipt.workSessions.sorted { $0.sortIndex < $1.sortIndex }
        return receipt.productionProject ?? sessions.first?.productionProject
    }

    @ViewBuilder
    private var productionProjectCard: some View {
        if let project = linkedProductionProject {
            NavigationLink {
                ProductionProjectRenameView(project: project)
            } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "theatermasks")
                        .foregroundStyle(brandAccent)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show / project")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                        Text(project.title)
                            .font(DesignSystem.Typography.bodyEmphasized)
                            .foregroundStyle(Color.ratioVitaAdaptiveText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .fill(Color.ratioVitaAdaptiveSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var showsBusinessUseSlider: Bool {
        DocumentTypeOption.fromStored(receipt.documentType).showsBusinessUsePercentControls
    }

    @ViewBuilder
    private var businessUseCard: some View {
        if showsBusinessUseSlider {
            VStack(alignment: .leading, spacing: Layout.innerSpacing) {
                Text("Business use %")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(brandAccent)
                ReceiptBusinessUsePercentControls(receipt: receipt, disabled: false)
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
            )
        }
    }

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            Text("Document")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(brandAccent)

            if !sortedImages.isEmpty {
                imageAdjustToolbar
            }

            Text(
                "**Region crop** isolates part of a page (e.g. EP statement) and re-runs OCR on that crop."
            )
            .font(DesignSystem.Typography.caption2)
            .foregroundStyle(Color.ratioVitaTextSecondary)

            if sortedImages.count >= 2 {
                ReceiptMultiPageCanvasStrip(
                    receipt: receipt,
                    selectedPageIndices: $selectedPageIndices,
                    documentToolbarImageID: $documentToolbarImageID,
                    onExpandPage: { image in
                        expandedImageToken = ReceiptImageExpandedToken(id: image.id)
                    },
                    onDecoupleError: { decoupleErrorMessage = $0 },
                    onDecoupleSuccess: { decoupleSuccessMessage = $0 }
                )
            } else if let only = sortedImages.first {
                ReceiptDetailImageRow(
                    image: only,
                    showsInlineImageTools: true,
                    pageLabelAlignment: .topTrailing,
                    onExpand: { expandedImageToken = ReceiptImageExpandedToken(id: only.id) }
                )
            }
        }
        .onAppear {
            if documentToolbarImageID == nil {
                documentToolbarImageID = sortedImages.first?.id
            }
        }
    }

    @ViewBuilder
    private var imageAdjustToolbar: some View {
        if let img = documentToolbarImage {
            VStack(alignment: .leading, spacing: 8) {
                Text("Image adjust")
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                if sortedImages.count > 1 {
                    Picker("Target page", selection: $documentToolbarImageID) {
                        ForEach(sortedImages, id: \.id) { i in
                            Text("Page \(i.pageIndex + 1)").tag(Optional(i.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button {
                        img.applyRotationQuarterTurnsClockwise(-1)
                    } label: {
                        Label("Rotate left", systemImage: "rotate.left")
                            .labelStyle(.iconOnly)
                    }
                    .help("Quarter turn counterclockwise")

                    Button {
                        img.applyRotationQuarterTurnsClockwise(1)
                    } label: {
                        Label("Rotate right", systemImage: "rotate.right")
                            .labelStyle(.iconOnly)
                    }
                    .help("Quarter turn clockwise")

                    Button {
                        img.applyRotationQuarterTurnsClockwise(2)
                    } label: {
                        Label("180°", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .rotationEffect(.degrees(180))
                    }
                    .help("Half turn")

                    Button {
                        img.applyFlipHorizontal()
                    } label: {
                        Label("Mirror", systemImage: "arrow.left.and.right")
                            .labelStyle(.iconOnly)
                    }
                    .help("Flip horizontally")

                    Button {
                        img.applyFlipVertical()
                    } label: {
                        Label("Flip vertical", systemImage: "arrow.up.and.down")
                            .labelStyle(.iconOnly)
                    }
                    .help("Flip vertically")

                    #if os(iOS)
                    Button {
                        perspectiveCropTarget = PerspectiveCropTarget(id: img.id)
                    } label: {
                        Label("Square off", systemImage: "skew")
                            .labelStyle(.iconOnly)
                    }
                    .help("Perspective crop (remove desk skew)")
                    #endif

                    Button {
                        regionCropTarget = ReceiptPageRegionCropToken(id: img.id)
                    } label: {
                        Label("Region crop", systemImage: "crop")
                            .labelStyle(.iconOnly)
                    }
                    .help("Square-select a region (EP statement) and re-OCR that crop")

                    Button {
                        documentToolbarImageID = img.id
                        showReplacePageImporter = true
                    } label: {
                        Label("Replace page", systemImage: "arrow.triangle.2.circlepath")
                            .labelStyle(.iconOnly)
                    }
                    .help("Pick a new image file for this page (re-scan)")
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 4)
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            Text("Notes")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text(notes)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
        )
    }

    private func ocrSection(_ ocrText: String) -> some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            DisclosureGroup {
                Text(ocrText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color.ratioVitaAdaptiveText.opacity(0.92))
                    .textSelection(.enabled)
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                            .fill(Color.ratioVitaAdaptiveBorder.opacity(0.35))
                    )
            } label: {
                Text("Full OCR text (all pages)")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
        )
    }

    // Return Image explicitly so Image modifiers like .resizable() are available
    private func placeholderImage() -> Image {
        #if canImport(UIKit)
        let size = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            let text = "Image Unavailable"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.systemGray,
            ]
            let rect = CGRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
            text.draw(in: rect, withAttributes: attrs)
        }
        return Image(rvImage: image)
        #elseif canImport(AppKit)
        let size = NSSize(width: 300, height: 400)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        NSColor.systemGray.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        let text = "Image Unavailable" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.systemGray,
        ]
        let rect = NSRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
        text.draw(in: rect, withAttributes: attrs)
        
        return Image(nsImage: image)
        #endif
    }
}

private struct ReceiptDetailImageRow: View {
    enum PageLabelAlignment {
        case below
        case topTrailing
    }

    @Bindable var image: ReceiptImage
    var showsInlineImageTools: Bool = true
    var pageLabelAlignment: PageLabelAlignment = .below
    var onExpand: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Group {
                if let platformImage = image.platformImage {
                    Image(rvImage: platformImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
                        .shadow(DesignSystem.Shadow.small)
                        .onTapGesture(perform: onExpand)
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .fill(Color.ratioVitaAdaptiveSurface)
                        .frame(width: 220, height: 280)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                        }
                }
            }

            if pageLabelAlignment == .topTrailing {
                HStack {
                    Spacer(minLength: 0)
                    Text("Page \(image.pageIndex + 1)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                }
            }

            if showsInlineImageTools {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button {
                        image.applyRotationQuarterTurnsClockwise(-1)
                    } label: {
                        Label("Rotate left", systemImage: "rotate.left")
                            .labelStyle(.iconOnly)
                    }
                    .help("Quarter turn counterclockwise")

                    Button {
                        image.applyRotationQuarterTurnsClockwise(1)
                    } label: {
                        Label("Rotate right", systemImage: "rotate.right")
                            .labelStyle(.iconOnly)
                    }
                    .help("Quarter turn clockwise")

                    Button {
                        image.applyRotationQuarterTurnsClockwise(2)
                    } label: {
                        Label {
                            Text("Turn 180°")
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(180))
                        }
                        .labelStyle(.iconOnly)
                    }
                    .help("Half turn")

                    Button {
                        image.applyFlipHorizontal()
                    } label: {
                        Label("Mirror", systemImage: "arrow.left.and.right")
                            .labelStyle(.iconOnly)
                    }
                    .help("Flip horizontally")

                    Button {
                        image.applyFlipVertical()
                    } label: {
                        Label("Flip vertical", systemImage: "arrow.up.and.down")
                            .labelStyle(.iconOnly)
                    }
                    .help("Flip vertically")
                }
                .buttonStyle(.bordered)
            }

            if pageLabelAlignment == .below {
                Text("Page \(image.pageIndex + 1)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
        }
    }
}

private struct ReceiptImageFullScreenSheet: View {
    @Environment(\.brandAccent) private var brandAccent
    @Bindable var image: ReceiptImage
    @State private var isSharpening = false
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let plat = image.platformImage {
                    Image(rvImage: plat)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
            .navigationTitle("Page \(image.pageIndex + 1)")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.black.opacity(0.55), for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { onClose() }
                            .fontWeight(.semibold)
                    }
                    #if os(macOS)
                    ToolbarItemGroup(placement: .primaryAction) {
                        fullScreenImageToolbarContent
                    }
                    #endif
                }
            // iPhone sheet / full-screen: `.primaryAction` groups collapse to a single trailing control.
            // Keep every transform visible in a bottom bar (scrolls on narrow widths).
            #if os(iOS) || os(visionOS)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    expandedImageBottomToolBar
                }
            #endif
        }
    }

    @ViewBuilder
    private var fullScreenImageToolbarContent: some View {
        Button {
            image.applyRotationQuarterTurnsClockwise(-1)
        } label: {
            Image(systemName: "rotate.left")
        }
        .help("Quarter turn counterclockwise")
        Button {
            image.applyRotationQuarterTurnsClockwise(1)
        } label: {
            Image(systemName: "rotate.right")
        }
        .help("Quarter turn clockwise")
        Button {
            image.applyRotationQuarterTurnsClockwise(2)
        } label: {
            Image(systemName: "arrow.clockwise")
                .rotationEffect(.degrees(180))
        }
        .help("Half turn")
        Button {
            image.applyFlipHorizontal()
        } label: {
            Image(systemName: "arrow.left.and.right")
        }
        .help("Mirror horizontally")
        Button {
            image.applyFlipVertical()
        } label: {
            Image(systemName: "arrow.up.and.down")
        }
        .help("Flip vertically")
        Button {
            Task { @MainActor in
                isSharpening = true
                defer { isSharpening = false }
                try? await image.applyReceiptSharpening()
            }
        } label: {
            if isSharpening {
                ProgressView()
            } else {
                Label("Sharpen", systemImage: "wand.and.stars")
            }
        }
        .disabled(isSharpening)
    }

    private var expandedImageBottomToolBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.15))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    toolIconButton(systemImage: "rotate.left", accessibilityLabel: "Rotate left") {
                        image.applyRotationQuarterTurnsClockwise(-1)
                    }
                    toolIconButton(systemImage: "rotate.right", accessibilityLabel: "Rotate right") {
                        image.applyRotationQuarterTurnsClockwise(1)
                    }
                    toolIconButton(
                        systemImage: "arrow.clockwise",
                        accessibilityLabel: "Turn 180 degrees",
                        imageRotationDegrees: 180
                    ) {
                        image.applyRotationQuarterTurnsClockwise(2)
                    }
                    toolIconButton(systemImage: "arrow.left.and.right", accessibilityLabel: "Mirror horizontally") {
                        image.applyFlipHorizontal()
                    }
                    toolIconButton(systemImage: "arrow.up.and.down", accessibilityLabel: "Flip vertically") {
                        image.applyFlipVertical()
                    }
                    sharpenBottomButton
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            .frame(minHeight: 52)
            .background(Color.black.opacity(0.92))
        }
    }

    private func toolIconButton(
        systemImage: String,
        accessibilityLabel: String,
        imageRotationDegrees: Double = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .rotationEffect(.degrees(imageRotationDegrees))
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(brandAccent)
        .accessibilityLabel(accessibilityLabel)
    }

    private var sharpenBottomButton: some View {
        Button {
            Task { @MainActor in
                isSharpening = true
                defer { isSharpening = false }
                try? await image.applyReceiptSharpening()
            }
        } label: {
            Group {
                if isSharpening {
                    ProgressView()
                        .tint(brandAccent)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(brandAccent)
        .disabled(isSharpening)
        .accessibilityLabel("Sharpen image")
    }
}

/// Where `EditReceiptView` appears in the forensic command center.
enum EditReceiptChrome: Equatable {
    /// Legacy modal (e.g. external callers).
    case modalSheet
    /// Right column beside document + OCR (`NavigationSplitView` detail).
    case sideCarColumn
    /// Stacked under the document on narrow / iPad portrait.
    case inlineScrollStack
}

struct EditReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    let receipt: Receipt
    var chrome: EditReceiptChrome = .modalSheet
    /// Pop the receipt detail (library list) when editing in the iPad side-car column.
    var onBackFromSideCar: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showDistributionPrompt = false
    @State private var merchant: String
    @State private var total: String
    @State private var notes: String
    @State private var currency: ReceiptCurrency
    @State private var vendorAddress: String
    @State private var documentNumber: String
    @State private var chequeNumber: String
    @State private var internalInvoiceNumber: String
    @State private var clientAccountingToken: String
    @State private var payorName: String
    @State private var payeeName: String
    @State private var paymentMethod: String
    @State private var subtotal: String
    @State private var tax: String
    @State private var documentKind: String
    @State private var documentType: DocumentTypeOption
    @State private var annotations: String
    @State private var productionType: String
    @State private var department: String
    @State private var taxCategory: String
    @State private var hasTransactionDate: Bool
    @State private var transactionDate: Date
    @State private var vaultPathPrefixField: String = ""
    @State private var showMerchantRuleSheet = false
    @State private var merchantRuleLineHint: String = ""
    @State private var lastCRMLookupMerchant = ""
    @State private var chequeReparseMessage: String?
    @State private var chequeReparseIsError = false

    private var showsChequeStubReparse: Bool {
        combinedOCRText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 60
            && (
                documentType == .incomeOrCheck
                    || ChequeStubParser.parse(combinedOCR: combinedOCRText) != nil
            )
    }

    init(receipt: Receipt, chrome: EditReceiptChrome = .modalSheet, onBackFromSideCar: (() -> Void)? = nil) {
        self.receipt = receipt
        self.chrome = chrome
        self.onBackFromSideCar = onBackFromSideCar
        _merchant = State(initialValue: receipt.merchant)
        _total = State(initialValue: receipt.total.formatted(.currency(code: receipt.currencyCode)))
        _notes = State(initialValue: receipt.notes ?? "")
        _currency = State(initialValue: ReceiptCurrency.resolved(from: receipt.currencyCode))
        _vendorAddress = State(initialValue: receipt.vendorAddress ?? "")
        _documentNumber = State(initialValue: receipt.documentNumber ?? "")
        _chequeNumber = State(initialValue: receipt.chequeNumber ?? "")
        _internalInvoiceNumber = State(initialValue: receipt.internalInvoiceNumber ?? "")
        _clientAccountingToken = State(initialValue: receipt.clientAccountingToken ?? "")
        _payorName = State(initialValue: receipt.payorName ?? "")
        _payeeName = State(initialValue: receipt.payeeName ?? "")
        _paymentMethod = State(initialValue: receipt.paymentMethodSummary ?? "")
        _subtotal = State(initialValue: receipt.subtotalAmount.map { Self.decimalString($0) } ?? "")
        _tax = State(initialValue: receipt.taxAmount.map { Self.decimalString($0) } ?? "")
        _documentKind = State(initialValue: receipt.documentKind ?? "")
        _documentType = State(initialValue: DocumentTypeOption.fromStored(receipt.documentType))
        _annotations = State(initialValue: receipt.annotations ?? "")
        _productionType = State(initialValue: receipt.productionType ?? "")
        _department = State(initialValue: receipt.department ?? "")
        _taxCategory = State(initialValue: receipt.taxCategory ?? "")
        _hasTransactionDate = State(initialValue: receipt.transactionDate != nil)
        _transactionDate = State(initialValue: receipt.transactionDate ?? Date())
        _vaultPathPrefixField = State(initialValue: receipt.vaultPathPrefix ?? "")
    }

    var body: some View {
        Group {
            switch chrome {
                case .modalSheet:
                    NavigationStack {
                        formWithBusinessUse
                            .navigationTitle("Edit Receipt")
                        #if os(iOS) || os(visionOS)
                            .navigationBarTitleDisplayMode(.inline)
                        #endif
                            .toolbar { modalToolbar }
                    }
                case .sideCarColumn:
                    formWithBusinessUse
                        .navigationTitle("Receipt fields")
                    #if os(iOS) || os(visionOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                        .toolbar { sideCarToolbar }
                case .inlineScrollStack:
                    formWithBusinessUse
            }
        }
        .ratioVitaTheme()
        .onAppear { syncFromReceipt() }
        .task(id: receipt.persistentModelID) { syncFromReceipt() }
        .sheet(isPresented: $showDistributionPrompt) {
            ReceiptDistributionPromptSheet(
                receipt: receipt,
                onDismiss: { showDistributionPrompt = false }
            )
            #if os(iOS) || os(visionOS)
            .presentationDetents([.medium, .large])
            #endif
        }
        .sheet(isPresented: $showMerchantRuleSheet) {
            MerchantFilingRuleQuickSheet(
                merchantContains: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                targetPrefix: vaultPathPrefixField.trimmingCharacters(in: .whitespacesAndNewlines),
                lineHint: $merchantRuleLineHint
            )
        }
        #if os(iOS) || os(visionOS)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        #endif
    }

    private var formWithBusinessUse: some View {
        editForm
    }

    private var showsFullOCRInEditColumn: Bool {
        chrome == .sideCarColumn || chrome == .inlineScrollStack
    }

    private var combinedOCRText: String {
        receipt.images
            .sorted { $0.pageIndex < $1.pageIndex }
            .compactMap(\.ocrText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private var editForm: some View {
        Form {
            Section("Receipt Details") {
                TextField("Merchant", text: $merchant)
                    .textSelection(.enabled)
                    .onChange(of: merchant) { _, newValue in
                        applyCRMSuggestionIfNeeded(forMerchant: newValue)
                    }
                Picker("Currency", selection: $currency) {
                    ForEach(ReceiptCurrency.allCases) { code in
                        Text(code.code).tag(code)
                    }
                }
                TextField("Total", text: $total)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if showsFullOCRInEditColumn {
                Section {
                    DisclosureGroup("Full OCR text (all pages)") {
                        if combinedOCRText.isEmpty {
                            Text("No OCR text on file yet. Re-scan or import with OCR enabled.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ScrollView {
                                Text(combinedOCRText)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(Color.ratioVitaAdaptiveText.opacity(0.92))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 260)
                        }
                    }
                } header: {
                    Text("Sniper (source)")
                } footer: {
                    Text("Keep this open while you edit line items and totals so nothing is blocked.")
                        .font(DesignSystem.Typography.caption2)
                }
            }

            if documentType.showsBusinessUsePercentControls {
                Section("Business use %") {
                    ReceiptBusinessUsePercentControls(receipt: receipt, disabled: false)
                }
            }

            if documentType == .incomeOrCheck {
                Section {
                    TextField("Cheque number", text: $chequeNumber)
                        .onChange(of: chequeNumber) { _, _ in persistChequeStubFieldsOnly() }
                    TextField("Your invoice #", text: $internalInvoiceNumber)
                        .onChange(of: internalInvoiceNumber) { _, _ in persistChequeStubFieldsOnly() }
                    TextField("Client accounting token", text: $clientAccountingToken)
                        .onChange(of: clientAccountingToken) { _, _ in persistChequeStubFieldsOnly() }
                    TextField("Payor", text: $payorName)
                        .onChange(of: payorName) { _, _ in persistChequeStubFieldsOnly() }
                    TextField("Payee", text: $payeeName)
                        .onChange(of: payeeName) { _, _ in persistChequeStubFieldsOnly() }
                    if showsChequeStubReparse {
                        Button {
                            rerunChequeStubParse()
                        } label: {
                            Label("Re-run cheque stub parse", systemImage: "arrow.clockwise")
                        }
                    }
                } header: {
                    Text("Invoice / Cheque Breakdown (Extracted)")
                } footer: {
                    if let chequeReparseMessage {
                        Text(chequeReparseMessage)
                            .foregroundStyle(chequeReparseIsError ? .orange : .green)
                    }
                }
            }

            Section("Structured fields") {
                TextField("Vendor address", text: $vendorAddress, axis: .vertical)
                    .lineLimit(2...5)
                    .textSelection(.enabled)
                TextField("Receipt / invoice #", text: $documentNumber)
                TextField("Payment method", text: $paymentMethod)
                TextField("Document kind (e.g. lottery)", text: $documentKind)
                Picker("Document type", selection: $documentType) {
                    ForEach(DocumentTypeOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                TextField("Handwritten notes (e.g. edep …)", text: $annotations, axis: .vertical)
                    .lineLimit(2...6)
                TextField("Subtotal", text: $subtotal)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                TextField("Tax", text: $tax)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                Toggle("Transaction date on receipt", isOn: $hasTransactionDate)
                if hasTransactionDate {
                    DatePicker("Date", selection: $transactionDate, displayedComponents: [.date])
                }
            }

            Section("Production & tax") {
                TextField("Production type", text: $productionType)
                TextField("Department / crew", text: $department)
                TextField("Tax category", text: $taxCategory)
            }

            Section("Arctic Vault") {
                TextField("Path prefix (optional)", text: $vaultPathPrefixField, axis: .vertical)
                    .lineLimit(1...3)
                filingPreviewLine
                Button("Save as merchant filing rule…") {
                    merchantRuleLineHint = ""
                    showMerchantRuleSheet = true
                }
                .disabled(
                    vaultPathPrefixField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            if chrome == .inlineScrollStack {
                Section {
                    Button("Save changes") {
                        persistEditsAndFollowUp()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var filingPreviewLine: some View {
        let trimmedPrefix = vaultPathPrefixField.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixForPreview: String? = trimmedPrefix.isEmpty ? nil : trimmedPrefix
        return Text(
            "Filing to: \(ReceiptVaultPathing.previewDisplayPath(merchant: merchant, transactionDate: transactionDate, createdAt: receipt.createdAt, hasTransactionDate: hasTransactionDate, vaultPathPrefix: prefixForPreview))"
        )
        .font(DesignSystem.Typography.caption)
        .foregroundStyle(Color.ratioVitaTextSecondary)
    }

    private func applyCRMSuggestionIfNeeded(forMerchant newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.lowercased() != lastCRMLookupMerchant.lowercased() else { return }
        lastCRMLookupMerchant = trimmed
        guard let suggestion = CounterpartyCRMLookup.suggest(forMerchant: trimmed, context: modelContext) else {
            return
        }

        if vendorAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let addr = suggestion.vendorAddress
        {
            vendorAddress = addr
        }
        if receipt.counterpartyContact == nil, let contact = suggestion.contact {
            receipt.counterpartyContact = contact
        }
        let hint = "CRM (\(suggestion.sourceLabel))"
        if annotations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, suggestion.businessEntity != nil {
            annotations = hint
        }
    }

    private func rerunChequeStubParse() {
        do {
            let result = try ReceiptChequeStubRefresh.reapplyFromSavedOCR(receipt: receipt, context: modelContext)
            chequeReparseIsError = !result.applied
            chequeReparseMessage = result.message
            if result.applied {
                syncFromReceipt()
            }
        } catch {
            chequeReparseIsError = true
            chequeReparseMessage = error.localizedDescription
        }
    }

    /// Writes cheque breakdown fields to SwiftData immediately (macOS side-car recycles views often).
    private func persistChequeStubFieldsOnly() {
        receipt.chequeNumber = chequeNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.internalInvoiceNumber = internalInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.clientAccountingToken = clientAccountingToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.payorName = payorName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.payeeName = payeeName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        try? modelContext.save()
    }

    private func syncFromReceipt() {
        merchant = receipt.merchant
        lastCRMLookupMerchant = receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        total = receipt.total.formatted(.currency(code: receipt.currencyCode))
        notes = receipt.notes ?? ""
        currency = ReceiptCurrency.resolved(from: receipt.currencyCode)
        vendorAddress = receipt.vendorAddress ?? ""
        documentNumber = receipt.documentNumber ?? ""
        chequeNumber = receipt.chequeNumber ?? ""
        internalInvoiceNumber = receipt.internalInvoiceNumber ?? ""
        clientAccountingToken = receipt.clientAccountingToken ?? ""
        payorName = receipt.payorName ?? ""
        payeeName = receipt.payeeName ?? ""
        paymentMethod = receipt.paymentMethodSummary ?? ""
        subtotal = receipt.subtotalAmount.map { Self.decimalString($0) } ?? ""
        tax = receipt.taxAmount.map { Self.decimalString($0) } ?? ""
        documentKind = receipt.documentKind ?? ""
        documentType = DocumentTypeOption.fromStored(receipt.documentType)
        annotations = receipt.annotations ?? ""
        productionType = receipt.productionType ?? ""
        department = receipt.department ?? ""
        taxCategory = receipt.taxCategory ?? ""
        hasTransactionDate = receipt.transactionDate != nil
        transactionDate = receipt.transactionDate ?? Date()
        vaultPathPrefixField = receipt.vaultPathPrefix ?? ""
    }

    @ToolbarContentBuilder
    private var sideCarToolbar: some ToolbarContent {
        #if os(iOS) || os(visionOS)
        if let onBackFromSideCar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBackFromSideCar) {
                    Label("Back", systemImage: "chevron.backward")
                }
                .accessibilityHint("Return to the previous list")
            }
        }
        #endif
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                persistEditsAndFollowUp()
            }
        }
    }

    @ToolbarContentBuilder
    private var modalToolbar: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                persistEditsAndFollowUp()
                dismiss()
            }
        }
        #else
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                persistEditsAndFollowUp()
                dismiss()
            }
        }
        #endif
    }

    private func persistEditsAndFollowUp() {
        saveChanges()
        ReceiptEditHaptics.verifiedSave()
        if shouldOfferDistributionAfterSave, chrome != .modalSheet {
            showDistributionPrompt = true
        }
    }

    private var shouldOfferDistributionAfterSave: Bool {
        guard documentType.showsBusinessUsePercentControls else { return false }
        let p = receipt.businessUsePercent ?? 0
        return p > 0.5 && p < 99.5
    }

    private func saveChanges() {
        receipt.merchant = merchant
        receipt.currencyCode = currency.code

        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = receipt.currencyCode

        var parsedTotal: Decimal?
        if let number = nf.number(from: total) {
            parsedTotal = number.decimalValue
        } else if let plain = parseDecimal(from: total) {
            parsedTotal = plain
        }

        receipt.notes = notes.isEmpty ? nil : notes
        receipt.vendorAddress = vendorAddress.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.documentNumber = documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.chequeNumber = chequeNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.internalInvoiceNumber = internalInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.clientAccountingToken = clientAccountingToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.payorName = payorName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.payeeName = payeeName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.paymentMethodSummary = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.documentKind = documentKind.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.documentType = documentType.rawValue
        let dt = documentType
        if let parsedTotal {
            receipt.total = AccountingAmountPolarity.canonicalTotal(documentType: dt, amount: parsedTotal)
        }
        receipt.annotations = annotations.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.productionType = productionType.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.department = department.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.taxCategory = taxCategory.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        receipt.subtotalAmount = AccountingAmountPolarity.canonicalOptionalAmount(
            documentType: dt,
            amount: parseDecimal(from: subtotal)
        )
        receipt.taxAmount = AccountingAmountPolarity.canonicalOptionalAmount(
            documentType: dt,
            amount: parseDecimal(from: tax)
        )
        receipt.transactionDate = hasTransactionDate ? transactionDate : nil
        receipt.extractionSource = "manual"

        let vp = vaultPathPrefixField.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.vaultPathPrefix = vp.isEmpty ? nil : vp.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        ReceiptCabinetRouting.applyImplicitCabinetForDocumentType(receipt: receipt)

        try? modelContext.save()
    }

    private func parseDecimal(from raw: String) -> Decimal? {
        let filtered = raw.filter { "0123456789.,-".contains($0) }
        guard !filtered.isEmpty else { return nil }
        let normalized = filtered.replacingOccurrences(of: ",", with: "")
        return Decimal(string: normalized)
    }

    private static func decimalString(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}

private struct MerchantFilingRuleQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let merchantContains: String
    let targetPrefix: String
    @Binding var lineHint: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Rule") {
                    Text("When the merchant line contains “\(merchantContains)” (case-insensitive).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Optional line-item keyword", text: $lineHint)
                    Text("Target prefix: \(targetPrefix)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Merchant rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        do {
                            let li = lineHint.trimmingCharacters(in: .whitespacesAndNewlines)
                            try FilingCoordinator.insertMerchantRule(
                                merchantContains: merchantContains,
                                lineItemContains: li.isEmpty ? nil : li,
                                targetVaultPathPrefix: targetPrefix,
                                context: modelContext
                            )
                            Task { @MainActor in
                                await DesignSystem.TouchFeedback.impactMediumBurst(count: 3)
                            }
                            dismiss()
                        } catch {
                            UserMessageCenter.shared.present(
                                title: "Couldn’t save rule",
                                message: error.ratioVitaUserDescription
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Business-use remainder (Costco-style)

private struct ReceiptDistributionPromptSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var receipt: Receipt
    var onDismiss: () -> Void

    @Query(sort: \ProductionProject.title) private var productionProjects: [ProductionProject]
    @State private var remainderIsPersonal = true
    @State private var selectedProjectID: UUID?

    private var activeProductionProjects: [ProductionProject] {
        productionProjects.filter { $0.registryStatus == .active }
    }

    private var activeProjectsByParent: [(entity: String, projects: [ProductionProject])] {
        let buckets = Dictionary(grouping: activeProductionProjects, by: { $0.parentBusinessGroupingTitle })
        return buckets.keys.sorted().map { key in
            let rows = (buckets[key] ?? []).sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return (entity: key, projects: rows)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    let biz = Int((receipt.businessUsePercent ?? 0).rounded())
                    let personal = max(0, 100 - biz)
                    Text(
                        "Business use is \(biz)%. Tag how you want the remaining \(personal)% represented in your audit trail (e.g. personal groceries vs. another show)."
                    )
                    .font(.body)
                }
                Section("Remainder") {
                    Picker("Assign remainder", selection: $remainderIsPersonal) {
                        Text("Personal / non-business").tag(true)
                        Text("Another production").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if !remainderIsPersonal {
                        if activeProductionProjects.isEmpty {
                            Text("Add an active production in Timeline (Manage productions) or Contacts first.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Production project", selection: Binding(
                                get: {
                                    selectedProjectID ?? receipt.productionProject?.id
                                        ?? activeProductionProjects.first?.id
                                },
                                set: { selectedProjectID = $0 }
                            )) {
                                ForEach(activeProjectsByParent, id: \.entity) { group in
                                    Section(group.entity) {
                                        ForEach(group.projects) { project in
                                            Text(project.title).tag(Optional(project.id))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Split remainder")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip", role: .cancel) {
                            onDismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Record") {
                            applyAndDismiss()
                        }
                        .disabled(!remainderIsPersonal && activeProductionProjects.isEmpty)
                    }
                }
        }
    }

    private func applyAndDismiss() {
        let remainderPercent = max(0, 100 - (receipt.businessUsePercent ?? 0))
        let line = if remainderIsPersonal {
            "[Remainder allocation] \(Int(remainderPercent.rounded()))% after business-use split recorded as personal / non-business."
        } else if let id = selectedProjectID ?? receipt.productionProject?.id ?? activeProductionProjects.first?.id,
                  let project = activeProductionProjects.first(where: { $0.id == id })
        {
            "[Remainder allocation] \(Int(remainderPercent.rounded()))% recorded against production: \(project.title)."
        } else {
            "[Remainder allocation] \(Int(remainderPercent.rounded()))% — production not selected."
        }
        mergeRemainderAllocationLine(into: receipt, line: line)
        do {
            try modelContext.save()
            #if os(iOS) || os(visionOS)
            DesignSystem.TouchFeedback.impactMedium()
            #endif
        } catch {
            #if DEBUG
            print("RatioVita: remainder split save failed: \(error.localizedDescription)")
            #endif
        }
        onDismiss()
    }

    private func mergeRemainderAllocationLine(into receipt: Receipt, line: String) {
        let marker = "[Remainder allocation]"
        let existing = receipt.annotations ?? ""
        let parts = existing.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let filtered = parts.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix(marker) }
        let nonEmptyTail = filtered.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let combined = ([line] + nonEmptyTail)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.annotations = combined.nilIfEmpty
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
