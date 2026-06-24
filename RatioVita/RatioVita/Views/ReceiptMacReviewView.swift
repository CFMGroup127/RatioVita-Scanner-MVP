#if os(macOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// macOS-first **Review & correction** layout: scanned pages on the left, structured fields on the right.
struct ReceiptMacReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent

    @Bindable var receipt: Receipt

    @State private var selectedImageID: UUID?
    @State private var totalField: String = ""
    @State private var subtotalField: String = ""
    @State private var taxField: String = ""
    @State private var currency: ReceiptCurrency = .CAD
    @State private var showReferencePicker = false
    @State private var referenceRetargetLink: ReceiptReferenceLink?
    @State private var duplicateWarning: String?
    @State private var selectedPageIndices: Set<Int> = []
    @State private var decoupleSuccessMessage: String?
    @State private var decoupleErrorMessage: String?
    @State private var confirmExplodeAllPages = false
    @State private var explodeErrorMessage: String?
    @State private var regionCropTarget: ReceiptPageRegionCropToken?
    @State private var showReplacePageImporter = false
    @State private var rescanErrorMessage: String?
    @State private var dealMemoOnboarding: DealMemoOnboardingService.Result?
    @State private var dealMemoTimecardDay: CrewTimecardDay?
    @State private var chequeReparseMessage: String?
    @State private var chequeReparseIsError = false
    @State private var draftReceiptShowTitle = ""

    private var documentTypeOption: DocumentTypeOption {
        DocumentTypeOption.fromStored(receipt.documentType)
    }

    private var sortedImages: [ReceiptImage] {
        receipt.images.sorted { $0.pageIndex < $1.pageIndex }
    }

    private var sortedLineItems: [ReceiptLineItem] {
        receipt.lineItems.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var sortedWorkSessions: [WorkSession] {
        receipt.workSessions.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var sortedReferenceLinks: [ReceiptReferenceLink] {
        receipt.referenceLinks.sorted(by: { $0.createdAt < $1.createdAt })
    }

    private var combinedOCRText: String {
        sortedImages.compactMap(\.ocrText).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private var isLocked: Bool {
        receipt.isVerified
    }

    private var workspaceLayout: DynamicWorkspaceLayout {
        DynamicWorkspaceLayout.forDocumentType(documentTypeOption)
    }

    private var showsChequeStubReparse: Bool {
        combinedOCRText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 60
            && (
                documentTypeOption == .incomeOrCheck
                    || ChequeStubParser.parse(combinedOCR: combinedOCRText) != nil
            )
    }

    var body: some View {
        NavigationSplitView {
            documentPreviewColumn
                .navigationSplitViewColumnWidth(min: 280, ideal: 420, max: 720)
        } detail: {
            if let day = dealMemoTimecardDay {
                dealMemoTimecardWorkspace(day)
            } else {
                reviewFormColumn
            }
        }
        .navigationTitle(receipt.merchant)
        .safeAreaInset(edge: .top, spacing: 0) {
            if receipt.workspaceBatchPinned {
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.orange)
                    Text("Multi-page batch pinned in Review until you file or clear the pin.")
                        .font(.caption)
                    Spacer()
                    Button("Clear pin") {
                        ReceiptWorkspaceBatchGuard.releaseBatchPin(receipt)
                        try? modelContext.save()
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.12))
            }
        }
        .onAppear {
            if selectedImageID == nil {
                selectedImageID = sortedImages.first?.id
            }
            syncFieldsFromReceipt()
            refreshDealMemoOnboardingIfNeeded()
        }
        .task(id: receipt.persistentModelID) {
            syncFieldsFromReceipt()
            let dups = ReceiptDuplicateSentinel.findLikelyDuplicates(
                of: receipt,
                context: modelContext,
                includePendingReview: true
            )
            duplicateWarning =
                dups.isEmpty
                    ? nil
                    : "Duplicate sentinel: \(dups.count) other item(s) share this invoice #, document date, and total (different scans are OK if the # differs)."
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if sortedImages.count > 1 {
                    Button {
                        confirmExplodeAllPages = true
                    } label: {
                        Image(systemName: "rectangle.split.3x1.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.orange)
                    }
                    .help("Explode every page into its own receipt")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    applyMoneyFieldsToReceipt()
                    try? modelContext.save()
                }
                .disabled(isLocked)
            }
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
        .sheet(item: $regionCropTarget) { target in
            if let img = receipt.images.first(where: { $0.id == target.id }) {
                ReceiptRegionCropSheet(image: img)
            }
        }
        .fileImporter(
            isPresented: $showReplacePageImporter,
            allowedContentTypes: [.jpeg, .png, .heic, .tiff],
            allowsMultipleSelection: false
        ) { result in
            switch result {
                case let .success(urls):
                    guard let url = urls.first,
                          let tid = selectedImageID,
                          let img = receipt.images.first(where: { $0.id == tid }) else { return }
                    Task { @MainActor in
                        do {
                            try await ReceiptImageRescanSupport.replacePageRasterFromFile(
                                receiptImage: img,
                                fileURL: url,
                                modelContext: modelContext
                            )
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
        .sheet(isPresented: $showReferencePicker, onDismiss: { referenceRetargetLink = nil }) {
            ReceiptReferencePickerSheet(fromReceipt: receipt, linkToFill: referenceRetargetLink)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .id(receipt.persistentModelID)
    }

    // MARK: - Columns

    private var documentPreviewColumn: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Document")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(brandAccent)
            Text(
                "Select a page. Use **Adjust** for rotate / mirror / region crop / replace scan. Split & explode live in the toolbar."
            )
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(.secondary)

            if let sel = selectedImageID, let img = sortedImages.first(where: { $0.id == sel }) {
                macPageAdjustStrip(image: img)
            }

            if sortedImages.isEmpty {
                ContentUnavailableView("No pages", systemImage: "doc.text")
            } else if sortedImages.count >= 2 {
                ReceiptMultiPageCanvasStrip(
                    receipt: receipt,
                    selectedPageIndices: $selectedPageIndices,
                    documentToolbarImageID: $selectedImageID,
                    onExpandPage: { img in
                        selectedImageID = img.id
                    },
                    onDecoupleError: { decoupleErrorMessage = $0 },
                    onDecoupleSuccess: { decoupleSuccessMessage = $0 }
                )
            } else if let only = sortedImages.first {
                pagePreviewButton(only)
            }

            if !combinedOCRText.isEmpty {
                DisclosureGroup {
                    ScrollView {
                        Text(combinedOCRText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.ratioVitaAdaptiveText.opacity(0.92))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignSystem.Spacing.sm)
                    }
                    .frame(maxHeight: 280)
                } label: {
                    Text("Full OCR text (all pages)")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(brandAccent)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ratioVitaAdaptiveBackground)
    }

    private func pagePreviewButton(_ img: ReceiptImage) -> some View {
        let selected = selectedImageID == img.id
        return Button {
            selectedImageID = img.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Page \(img.pageIndex + 1)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                if let rv = img.platformImage {
                    ZoomableDocumentImageView(image: rv, maxHeight: 480)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                                .stroke(
                                    selected ? brandAccent : Color.ratioVitaAdaptiveBorder.opacity(0.45),
                                    lineWidth: selected ? 2 : 1
                                )
                        )
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                        .fill(Color.ratioVitaAdaptiveSurface)
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveSurface.opacity(selected ? 1.0 : 0.6))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func macPageAdjustStrip(image: ReceiptImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adjust")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.ratioVitaTextSecondary)
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    image.applyRotationQuarterTurnsClockwise(-1)
                } label: {
                    Label("Rotate left", systemImage: "rotate.left").labelStyle(.iconOnly)
                }
                Button {
                    image.applyRotationQuarterTurnsClockwise(1)
                } label: {
                    Label("Rotate right", systemImage: "rotate.right").labelStyle(.iconOnly)
                }
                Button {
                    image.applyRotationQuarterTurnsClockwise(2)
                } label: {
                    Label("180°", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .rotationEffect(.degrees(180))
                }
                Button {
                    image.applyFlipHorizontal()
                } label: {
                    Label("Mirror", systemImage: "arrow.left.and.right").labelStyle(.iconOnly)
                }
                Button {
                    image.applyFlipVertical()
                } label: {
                    Label("Flip vertical", systemImage: "arrow.up.and.down").labelStyle(.iconOnly)
                }
                Button {
                    regionCropTarget = ReceiptPageRegionCropToken(id: image.id)
                } label: {
                    Label("Region crop", systemImage: "crop").labelStyle(.iconOnly)
                }
                Button {
                    showReplacePageImporter = true
                } label: {
                    Label("Replace page", systemImage: "arrow.triangle.2.circlepath").labelStyle(.iconOnly)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func performExplodeAllPages() {
        explodeErrorMessage = nil
        do {
            _ = try ReceiptPageDecouplerService.explodeAllPages(from: receipt, modelContext: modelContext)
        } catch {
            explodeErrorMessage = error.localizedDescription
        }
    }

    private var reviewFormColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if let duplicateWarning {
                    Text(duplicateWarning)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                }
                statusHeader

                if let onboarding = dealMemoOnboarding {
                    dealMemoOnboardingBanner(onboarding)
                }

                Text("Filing to: \(ReceiptVaultPathing.displayPath(for: receipt))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.xs)

                Form {
                    Section("Classification") {
                        Picker("Document type", selection: $receipt.documentType) {
                            ForEach(DocumentTypeOption.allCases) { option in
                                Text(option.rawValue).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isLocked)
                        .onChange(of: receipt.documentType) { _, _ in
                            guard !isLocked else { return }
                            applyMoneyFieldsToReceipt()
                            refreshDealMemoOnboardingIfNeeded()
                        }
                        Text("Receipt, invoice, paycheck, statement, and other types for filing and document graph.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if workspaceLayout == .contractBlueprint {
                        DealMemoContractBlueprintView(
                            receipt: receipt,
                            isLocked: isLocked,
                            onOpenTimecard: { openDealMemoTimecardWorkspace() }
                        )
                    }

                    if workspaceLayout == .chequePayout || showsChequeStubReparse {
                        Section {
                            TextField("Cheque number", text: bindingOptional($receipt.chequeNumber))
                                .disabled(isLocked)
                            TextField(
                                "Your invoice # (FACTURE / INVOICE)",
                                text: bindingOptional($receipt.internalInvoiceNumber)
                            )
                            .disabled(isLocked)
                            TextField(
                                "Client accounting token (SAP / ref.)",
                                text: bindingOptional($receipt.clientAccountingToken)
                            )
                            .disabled(isLocked)
                            TextField("Payor (drawer)", text: bindingOptional($receipt.payorName))
                                .disabled(isLocked)
                            TextField("Payee", text: bindingOptional($receipt.payeeName))
                                .disabled(isLocked)

                            if showsChequeStubReparse {
                                Button {
                                    rerunChequeStubParse()
                                } label: {
                                    Label("Re-run cheque stub parse", systemImage: "arrow.clockwise")
                                }
                                .disabled(isLocked)
                            }
                        } header: {
                            Text("Invoice / Cheque Breakdown (Extracted)")
                        } footer: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    "Banking token, your invoice #, and network SAP/ref are tracked separately for reconciliation."
                                )
                                if let chequeReparseMessage {
                                    Text(chequeReparseMessage)
                                        .foregroundStyle(chequeReparseIsError ? Color.orange : Color.green)
                                }
                            }
                        }
                    } else if workspaceLayout != .chequePayout, showsChequeStubReparse {
                        Section {
                            Button {
                                rerunChequeStubParse()
                            } label: {
                                Label("Re-run cheque stub parse", systemImage: "arrow.clockwise")
                            }
                            .disabled(isLocked)
                        } header: {
                            Text("Cheque stub detected")
                        } footer: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    "Saved OCR looks like a corporate payout stub. Re-parse to split cheque #, invoice #, and SAP token, then set Document type to Income / Check."
                                )
                                if let chequeReparseMessage {
                                    Text(chequeReparseMessage)
                                        .foregroundStyle(chequeReparseIsError ? Color.orange : Color.green)
                                }
                            }
                        }
                    }

                    if workspaceLayout == .retailTransaction || workspaceLayout == .laborTimeline {
                        Section("Merchant info") {
                            TextField("Merchant", text: $receipt.merchant)
                                .disabled(isLocked)
                            TextField("Vendor address", text: bindingOptional($receipt.vendorAddress), axis: .vertical)
                                .lineLimit(2...6)
                                .disabled(isLocked)
                            TextField("Receipt / invoice #", text: bindingOptional($receipt.documentNumber))
                                .disabled(isLocked)
                            if workspaceLayout == .retailTransaction {
                                TextField("Notes", text: bindingOptional($receipt.notes), axis: .vertical)
                                    .lineLimit(2...6)
                                    .disabled(isLocked)
                                TextField(
                                    "Handwritten annotations (e.g. edep …)",
                                    text: bindingOptional($receipt.annotations),
                                    axis: .vertical
                                )
                                .lineLimit(2...8)
                                .disabled(isLocked)
                                Toggle("Deposit date present (edep)", isOn: Binding(
                                    get: { receipt.depositDate != nil },
                                    set: { on in
                                        if on {
                                            if receipt.depositDate == nil { receipt.depositDate = Date() }
                                        } else {
                                            receipt.depositDate = nil
                                        }
                                    }
                                ))
                                .disabled(isLocked)
                                if receipt.depositDate != nil {
                                    DatePicker(
                                        "Deposit date",
                                        selection: Binding(
                                            get: { receipt.depositDate ?? Date() },
                                            set: { receipt.depositDate = $0 }
                                        ),
                                        displayedComponents: [.date]
                                    )
                                    .disabled(isLocked)
                                }
                            }
                        }
                    }

                    if workspaceLayout == .retailTransaction {
                        Section("Invoice / production (extracted)") {
                            TextField("Purchase order #", text: bindingOptional($receipt.invoicePurchaseOrderNumber))
                                .disabled(isLocked)
                            TextField(
                                "Production manager",
                                text: bindingOptional($receipt.invoiceProductionManagerName)
                            )
                            .disabled(isLocked)
                            TextField(
                                "Client project / show title",
                                text: bindingOptional($receipt.invoiceClientProjectTitle)
                            )
                            .disabled(isLocked)
                            TextField(
                                "Production company / network",
                                text: bindingOptional($receipt.invoiceClientCompany)
                            )
                            .disabled(isLocked)
                        }
                    }

                    if documentTypeOption.showsRetailFinancialFields {
                        Section("Financials") {
                            Picker("Currency", selection: $currency) {
                                ForEach(ReceiptCurrency.allCases) { c in
                                    Text(c.code).tag(c)
                                }
                            }
                            .disabled(isLocked)
                            .onChange(of: currency) { _, newValue in
                                receipt.currencyCode = newValue.code
                            }

                            TextField("Total", text: $totalField)
                                .disabled(isLocked)
                            TextField("Subtotal", text: $subtotalField)
                                .disabled(isLocked)
                            TextField("Tax", text: $taxField)
                                .disabled(isLocked)

                            Toggle("Transaction date on receipt", isOn: transactionDateEnabledBinding)
                                .disabled(isLocked)
                            if receipt.transactionDate != nil {
                                DatePicker(
                                    "Date",
                                    selection: Binding(
                                        get: { receipt.transactionDate ?? Date() },
                                        set: { receipt.transactionDate = $0 }
                                    ),
                                    displayedComponents: [.date]
                                )
                                .disabled(isLocked)
                            }

                            TextField("Payment method", text: bindingOptional($receipt.paymentMethodSummary))
                                .disabled(isLocked)

                            TextField(
                                "Reference invoice number (AR/AP)",
                                text: bindingOptional($receipt.referenceInvoiceNumber)
                            )
                            .disabled(isLocked)
                        }
                    } else if workspaceLayout == .contractBlueprint {
                        Section("Financials") {
                            Text(
                                "Deal memos archive contract rates — not purchase totals. Financial fields are cleared."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    } else if documentTypeOption == .timeSheet {
                        Section("Labor tracking") {
                            Text(
                                "Time sheets use the **Time Sheets** workspace for call, wrap, meals, and kit lines — not purchase totals."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Section("Production & tax (VitaLogic)") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(
                                "Show / project (canonical title)",
                                text: $draftReceiptShowTitle
                            )
                            .disabled(isLocked)
                            .onSubmit {
                                commitReceiptShowTitle(draftReceiptShowTitle)
                            }
                            HStack {
                                Text("Press Return or Save to link this show — typing alone does not create a production.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Save show") {
                                    commitReceiptShowTitle(draftReceiptShowTitle)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isLocked)
                            }
                        }
                        .onAppear { syncDraftReceiptShowTitle() }
                        .onChange(of: receipt.id) { _, _ in syncDraftReceiptShowTitle() }
                        TextField(
                            "Production type (e.g. commercial, payroll)",
                            text: bindingOptional($receipt.productionType)
                        )
                        .disabled(isLocked)
                        TextField("Department / crew role", text: bindingOptional($receipt.department))
                            .disabled(isLocked)
                        TextField(
                            "Tax category (agent-suggested or manual)",
                            text: bindingOptional($receipt.taxCategory)
                        )
                        .disabled(isLocked)
                    }

                    if documentTypeOption.showsBusinessUsePercentControls {
                        Section("Business use %") {
                            ReceiptBusinessUsePercentControls(receipt: receipt, disabled: isLocked)
                        }
                        if !sortedLineItems.isEmpty {
                            Section("Line-item allocation") {
                                ReceiptItemAllocationView(receipt: receipt, isLocked: isLocked)
                            }
                        }
                    }

                    Section("Line items") {
                        if sortedLineItems.isEmpty {
                            Text("No line items yet.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(sortedLineItems, id: \.id) { li in
                            @Bindable var line = li
                            ReceiptMacLineItemRow(line: line, isLocked: isLocked)
                        }
                        Button("Add line item") {
                            addLineItem()
                        }
                        .disabled(isLocked)
                    }

                    Section("Work sessions") {
                        Text("Per-day entries for time reports (calendar / CV export later).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(sortedWorkSessions, id: \.id) { ws in
                            @Bindable var session = ws
                            ReceiptMacWorkSessionRow(session: session, receipt: receipt, isLocked: isLocked)
                        }
                        Button("Add work day") {
                            addWorkSession()
                        }
                        .disabled(isLocked)
                    }

                    Section("References") {
                        Text(
                            "Link related documents (invoice ↔ paycheck ↔ warranty). Search the library and pick a record."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if sortedReferenceLinks.isEmpty {
                            Text("No related documents yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(sortedReferenceLinks, id: \.id) { link in
                                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(link.toReceipt?.merchant ?? "Not linked")
                                            .font(.body)
                                        if let target = link.toReceipt {
                                            Text((target.transactionDate ?? target.createdAt).formatted(
                                                date: .abbreviated,
                                                time: .omitted
                                            ))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            if !target.documentType.isEmpty {
                                                Text(target.documentType)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary.opacity(0.9))
                                            }
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    if link.toReceipt == nil {
                                        Button("Choose document…") {
                                            referenceRetargetLink = link
                                            showReferencePicker = true
                                        }
                                        .disabled(isLocked)
                                    }
                                    Button(role: .destructive) {
                                        removeReferenceLink(link)
                                    } label: {
                                        Image(systemName: "trash")
                                            .accessibilityLabel("Remove link")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(isLocked)
                                }
                            }
                        }

                        Button("Link related document…") {
                            referenceRetargetLink = nil
                            showReferencePicker = true
                        }
                        .disabled(isLocked)
                    }
                }
                .formStyle(.grouped)

                verifyBar
            }
            .padding(DesignSystem.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ratioVitaAdaptiveBackground)
    }

    private var statusHeader: some View {
        let status = receipt.documentGraphStatus
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Status")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(status.rawValue)
                    .font(DesignSystem.Typography.bodyEmphasized)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(statusCapsuleFill(status))
                    )
            }
            Text(status.detailBlurb)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusCapsuleFill(_ status: ReceiptDocumentGraphStatus) -> Color {
        switch status {
            case .pending:
                Color.orange.opacity(0.22)
            case .verified:
                Color.green.opacity(0.22)
            case .linked:
                brandAccent.opacity(0.2)
        }
    }

    private var verifyBar: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    applyMoneyFieldsToReceipt()
                    receipt.isVerified = true
                    receipt.extractionSource = "manual"
                    try? modelContext.save()
                } label: {
                    Label("Verify", systemImage: "checkmark.seal")
                }
                .buttonStyle(.borderedProminent)
                .tint(brandAccent)
                .disabled(receipt.isVerified)

                if receipt.isVerified {
                    Button("Unlock for editing") {
                        receipt.isVerified = false
                        try? modelContext.save()
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text(
                "Verify confirms totals, dates, and line items for this record. Unlock if you need to correct something."
            )
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - Mutations

    private func addLineItem() {
        let next = (receipt.lineItems.map(\.sortIndex).max() ?? -1) + 1
        let line = ReceiptLineItem(
            sortIndex: next,
            lineDescription: "New item",
            receipt: receipt
        )
        modelContext.insert(line)
        receipt.lineItems.append(line)
        try? modelContext.save()
    }

    private func addWorkSession() {
        let next = (receipt.workSessions.map(\.sortIndex).max() ?? -1) + 1
        let session = WorkSession(
            sortIndex: next,
            workDate: Date(),
            productionTitle: receipt.productionProject?.title,
            productionProject: receipt.productionProject,
            receipt: receipt
        )
        modelContext.insert(session)
        receipt.workSessions.append(session)
        try? modelContext.save()
    }

    private func removeReferenceLink(_ link: ReceiptReferenceLink) {
        guard !isLocked else { return }
        receipt.referenceLinks.removeAll { $0.id == link.id }
        modelContext.delete(link)
        try? modelContext.save()
    }

    private func syncFieldsFromReceipt() {
        totalField = Self.decimalString(receipt.total)
        subtotalField = receipt.subtotalAmount.map { Self.decimalString($0) } ?? ""
        taxField = receipt.taxAmount.map { Self.decimalString($0) } ?? ""
        currency = ReceiptCurrency.resolved(from: receipt.currencyCode)
    }

    private func applyMoneyFieldsToReceipt() {
        let dt = DocumentTypeOption.fromStored(receipt.documentType)
        if let t = parseDecimal(from: totalField) {
            receipt.total = AccountingAmountPolarity.canonicalTotal(documentType: dt, amount: t)
        }
        receipt.subtotalAmount = AccountingAmountPolarity.canonicalOptionalAmount(
            documentType: dt,
            amount: parseDecimal(from: subtotalField)
        )
        receipt.taxAmount = AccountingAmountPolarity.canonicalOptionalAmount(
            documentType: dt,
            amount: parseDecimal(from: taxField)
        )
        receipt.currencyCode = currency.code
        ReceiptCabinetRouting.applyImplicitCabinetForDocumentType(receipt: receipt)
        if dt == .dealMemo {
            ReceiptFinancialSanity.applyDealMemoFinancialPolicy(
                to: receipt,
                combinedOCR: combinedOCRText,
                context: modelContext
            )
            syncFieldsFromReceipt()
        }
    }

    private func rerunChequeStubParse() {
        guard !isLocked else { return }
        do {
            let result = try ReceiptChequeStubRefresh.reapplyFromSavedOCR(receipt: receipt, context: modelContext)
            chequeReparseIsError = !result.applied
            chequeReparseMessage = result.message
            if result.applied {
                syncFieldsFromReceipt()
                applyMoneyFieldsToReceipt()
            }
        } catch {
            chequeReparseIsError = true
            chequeReparseMessage = error.localizedDescription
        }
    }

    private func refreshDealMemoOnboardingIfNeeded() {
        guard documentTypeOption == .dealMemo else {
            dealMemoOnboarding = nil
            return
        }
        guard !receipt.dealMemoTimecardPromptDismissed else {
            dealMemoOnboarding = nil
            return
        }
        if let project = receipt.productionProject {
            dealMemoOnboarding = DealMemoOnboardingService.bannerPresentation(receipt: receipt, project: project)
            return
        }
        if let result = DealMemoOnboardingService.processIfDealMemo(receipt: receipt, context: modelContext) {
            dealMemoOnboarding = result
            if result.appendedRateTier || result.createdNewProject {
                DesignSystem.TouchFeedback.impactMedium()
            }
        } else {
            dealMemoOnboarding = nil
        }
    }

    @ViewBuilder
    private func dealMemoTimecardWorkspace(_ day: CrewTimecardDay) -> some View {
        NavigationStack {
            TimecardWorkspaceView(
                day: day,
                siblingProjectDays: day.productionProject?.crewTimecardDays ?? [],
                showsProductionSwitcher: true,
                productionOptions: fetchActiveProductions(),
                showsToolbarDone: true,
                onToolbarDone: {
                    dealMemoTimecardDay = nil
                    refreshDealMemoOnboardingIfNeeded()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(day.workDate.formatted(date: .abbreviated, time: .omitted))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back to deal memo") {
                        dealMemoTimecardDay = nil
                        refreshDealMemoOnboardingIfNeeded()
                    }
                }
            }
        }
    }

    private func fetchActiveProductions() -> [ProductionProject] {
        let all = (try? modelContext.fetch(FetchDescriptor<ProductionProject>(sortBy: [
            SortDescriptor(\.title),
        ]))) ?? []
        return all.filter { $0.registryStatus != .retired }
    }

    private func openDealMemoTimecardWorkspace() {
        if let project = receipt.productionProject {
            createDealMemoTimecard(for: project)
        }
    }

    @ViewBuilder
    private func dealMemoOnboardingBanner(_ onboarding: DealMemoOnboardingService.Result) -> some View {
        let name = onboarding.project.title
        let headline = onboarding.createdNewProject
            ? "New project onboarded"
            : (onboarding.appendedRateTier ? "New position tier stacked" : "Deal memo linked")
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label(headline, systemImage: "shield.checkered")
                .font(DesignSystem.Typography.bodyEmphasized)
                .foregroundStyle(brandAccent)
            if let summary = onboarding.harvestedSummary {
                Text(summary)
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(brandAccent.opacity(0.9))
            }
            Text(
                "We've extracted your rates from the \(name) deal memo and automatically created the production profile. Would you like to initialize your first weekly timecard and begin tracking your hours now, or handle this later?"
            )
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Create Timecard Now") {
                    createDealMemoTimecard(for: onboarding.project)
                }
                .buttonStyle(.borderedProminent)
                .tint(brandAccent)
                Button("Decouple & File Later") {
                    receipt.dealMemoTimecardPromptDismissed = true
                    dealMemoOnboarding = nil
                    try? modelContext.save()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
        )
    }

    private func createDealMemoTimecard(for project: ProductionProject) {
        let cal = Calendar.current
        let day = CrewTimecardDay(
            workDate: cal.startOfDay(for: Date()),
            productionProject: project
        )
        if day.ancillaryPhoneRateCAD == nil { day.ancillaryPhoneRateCAD = project.defaultKitPhoneRateCAD }
        if day.ancillaryLaptopRateCAD == nil { day.ancillaryLaptopRateCAD = project.defaultKitLaptopRateCAD }
        if day.ancillaryTabletRateCAD == nil { day.ancillaryTabletRateCAD = project.defaultKitTabletRateCAD }
        modelContext.insert(day)
        try? modelContext.save()
        dealMemoTimecardDay = day
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

    private var transactionDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { receipt.transactionDate != nil },
            set: { on in
                if on {
                    if receipt.transactionDate == nil {
                        receipt.transactionDate = Date()
                    }
                } else {
                    receipt.transactionDate = nil
                }
            }
        )
    }

    private func syncDraftReceiptShowTitle() {
        let sorted = receipt.workSessions.sorted { $0.sortIndex < $1.sortIndex }
        draftReceiptShowTitle = receipt.productionProject?.title
            ?? sorted.first?.productionProject?.title
            ?? sorted.first?.productionTitle
            ?? ""
    }

    private func commitReceiptShowTitle(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            receipt.productionProject = nil
            try? modelContext.save()
            return
        }
        let p = ProductionProjectResolver.findOrInsert(title: trimmed, modelContext: modelContext)
        receipt.productionProject = p
        for ws in receipt.workSessions where ws.productionProject == nil {
            ws.productionProject = p
            ws.productionTitle = p.title
        }
        try? modelContext.save()
    }

    /// Two-way binding for optional persisted `String?` fields using empty string in the UI.
    private func bindingOptional(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                value.wrappedValue = trimmed.isEmpty ? nil : trimmed
            }
        )
    }
}

// MARK: - Subviews

private struct ReceiptMacLineItemRow: View {
    @Bindable var line: ReceiptLineItem
    let isLocked: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: $line.lineDescription)
                        .disabled(isLocked)
                }
                GridRow {
                    Text("Qty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        "",
                        text: Binding(
                            get: { line.quantity.map(String.init) ?? "" },
                            set: { line.quantity = Int($0.trimmingCharacters(in: .whitespaces)) }
                        )
                    )
                    .disabled(isLocked)
                }
                GridRow {
                    Text("Unit price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: decimalBinding(\.unitPrice))
                        .disabled(isLocked)
                }
                GridRow {
                    Text("Line total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: decimalBinding(\.totalPrice))
                        .disabled(isLocked)
                }
                GridRow {
                    Text("Serial #")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: optionalStringBinding(\.serialNumber))
                        .disabled(isLocked)
                }
                GridRow {
                    Text("Barcode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: optionalStringBinding(\.barcodeValue))
                        .disabled(isLocked)
                }
                GridRow {
                    Text("RFID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: optionalStringBinding(\.rfidTag))
                        .disabled(isLocked)
                }
                GridRow {
                    Text("GL code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: optionalStringBinding(\.glCode))
                        .disabled(isLocked)
                }
                GridRow {
                    Text("Warranty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(
                        "Track warranty end date",
                        isOn: Binding(
                            get: { line.warrantyEndDate != nil },
                            set: { on in
                                if on {
                                    if line.warrantyEndDate == nil {
                                        line.warrantyEndDate = Date()
                                    }
                                } else {
                                    line.warrantyEndDate = nil
                                }
                            }
                        )
                    )
                    .disabled(isLocked)
                }
                Group {
                    if line.warrantyEndDate != nil {
                        GridRow {
                            Text("Warranty end")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { line.warrantyEndDate ?? Date() },
                                    set: { line.warrantyEndDate = $0 }
                                ),
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .disabled(isLocked)
                        }
                    }
                }
                GridRow {
                    Spacer()
                    Button(role: .destructive) {
                        modelContext.delete(line)
                        try? modelContext.save()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .disabled(isLocked)
                }
            }
        }
    }

    private func decimalBinding(_ keyPath: ReferenceWritableKeyPath<ReceiptLineItem, Decimal?>) -> Binding<String> {
        Binding(
            get: {
                guard let v = line[keyPath: keyPath] else { return "" }
                return v.formatted(.number.precision(.fractionLength(2)))
            },
            set: { raw in
                let filtered = raw.filter { "0123456789.,-".contains($0) }
                guard !filtered.isEmpty else {
                    line[keyPath: keyPath] = nil
                    return
                }
                line[keyPath: keyPath] = Decimal(string: filtered.replacingOccurrences(of: ",", with: ""))
            }
        )
    }

    private func optionalStringBinding(_ keyPath: ReferenceWritableKeyPath<ReceiptLineItem, String?>)
        -> Binding<String>
    {
        Binding(
            get: { line[keyPath: keyPath] ?? "" },
            set: { newValue in
                let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                line[keyPath: keyPath] = t.isEmpty ? nil : t
            }
        )
    }
}

private struct ReceiptMacWorkSessionRow: View {
    @Bindable var session: WorkSession
    var receipt: Receipt
    let isLocked: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var draftProductionTitle = ""

    var body: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Work date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $session.workDate, displayedComponents: [.date])
                        .labelsHidden()
                        .disabled(isLocked)
                }
                GridRow {
                    Text("Production / show")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("", text: $draftProductionTitle)
                            .disabled(isLocked)
                            .onSubmit {
                                commitProductionTitle(draftProductionTitle)
                            }
                        Button("Save show") {
                            commitProductionTitle(draftProductionTitle)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isLocked)
                    }
                    .onAppear { syncDraftProductionTitle() }
                    .onChange(of: session.id) { _, _ in syncDraftProductionTitle() }
                }
                GridRow {
                    Text("Department / category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: optionalStringBinding(\.departmentOrCategory))
                        .disabled(isLocked)
                }
                GridRow {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: optionalStringBinding(\.notes), axis: .vertical)
                        .lineLimit(2...4)
                        .disabled(isLocked)
                }
                GridRow {
                    Spacer()
                    Button(role: .destructive) {
                        modelContext.delete(session)
                        try? modelContext.save()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .disabled(isLocked)
                }
            }
        }
    }

    private func syncDraftProductionTitle() {
        draftProductionTitle = session.productionProject?.title ?? session.productionTitle ?? ""
    }

    private func commitProductionTitle(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            session.productionProject = nil
            session.productionTitle = nil
            try? modelContext.save()
            return
        }
        let p = ProductionProjectResolver.findOrInsert(title: trimmed, modelContext: modelContext)
        session.productionProject = p
        session.productionTitle = p.title
        if receipt.productionProject == nil {
            receipt.productionProject = p
        }
        try? modelContext.save()
    }

    private func optionalStringBinding(_ keyPath: ReferenceWritableKeyPath<WorkSession, String?>) -> Binding<String> {
        Binding(
            get: { session[keyPath: keyPath] ?? "" },
            set: { newValue in
                let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                session[keyPath: keyPath] = t.isEmpty ? nil : t
            }
        )
    }
}

#else
import SwiftData
import SwiftUI

/// Placeholder on non-macOS targets (detail uses `ReceiptDetailView`).
struct ReceiptMacReviewView: View {
    let receipt: Receipt

    var body: some View {
        EmptyView()
    }
}
#endif
