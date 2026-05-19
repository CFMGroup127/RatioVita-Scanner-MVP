import SwiftData
import SwiftUI
#if canImport(PDFKit)
import PDFKit
#endif

/// **Labor Sentinel** hub: crew timecard days, agreement template, EP-style PDF export.
struct LaborSentinelHubView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LaborAgreement.title) private var laborAgreements: [LaborAgreement]
    @Query(sort: \ProductionProject.title) private var productionProjects: [ProductionProject]
    @Query(sort: \CrewTimecardDay.workDate, order: .reverse) private var crewDays: [CrewTimecardDay]
    @Query(sort: \WorkRecord.workDate, order: .reverse) private var workRecordsLibrary: [WorkRecord]

    @State private var selectedProjectID: UUID?
    @State private var editingDay: CrewTimecardDay?
    @State private var exportItem: PayrollExportSheetItem?
    @State private var exportError: String?
    @State private var exportFormat: TimecardPDFFormatKind = .epCanadaCrewWeekly
    @State private var showAddProductionSheet = false
    @State private var weeklyAuditRows: [WeeklyPayCycleAuditService.Discrepancy] = []
    @AppStorage("payCycleLastAutoSweepWeekToken") private var payCycleLastAutoSweepWeekToken: String = ""
    @AppStorage("laborSentinelAgreementCode") private var laborSentinelAgreementCode: String = ""
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID: String = ""

    @Query(sort: \BusinessEntity.legalName) private var businessEntities: [BusinessEntity]

    private var selectedProject: ProductionProject? {
        guard let id = selectedProjectID else { return nil }
        return productionProjects.first { $0.id == id }
    }

    private var agreement: LaborAgreement? {
        let trimmed = laborSentinelAgreementCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let match = laborAgreements.first(where: { $0.code == trimmed }) {
            return match
        }
        let def = LaborSentinelBootstrap.defaultAgreementCode
        return laborAgreements.first { $0.code == def } ?? laborAgreements.first
    }

    private var daysForProject: [CrewTimecardDay] {
        guard let p = selectedProject else { return [] }
        return crewDays.filter { $0.productionProject?.id == p.id }
    }

    private var workRecordsForProject: [WorkRecord] {
        guard let p = selectedProject else { return [] }
        return workRecordsLibrary.filter { $0.productionProject?.id == p.id }
    }

    private var sentinelChainByDayID: [UUID: SentinelPayEstimate] {
        guard let agr = agreement, selectedProject != nil, !daysForProject.isEmpty else { return [:] }
        return SentinelPayrollEngine.estimatesWithTurnaround(projectDays: daysForProject, agreement: agr)
    }

    @ViewBuilder
    private var laborHubSections: some View {
        Section {
            Picker("Production", selection: $selectedProjectID) {
                Text("Choose a show…").tag(UUID?.none)
                ForEach(productionProjects) { p in
                    Text(p.title).tag(Optional(p.id))
                }
            }
            .onChange(of: selectedProjectID) { _, newID in
                if let id = newID {
                    forensicActiveProductionID = id.uuidString
                }
                syncExportFormatFromSelectedProject()
                if let day = editingDay {
                    if let nid = newID {
                        if day.productionProject?.id != nid { editingDay = nil }
                    } else {
                        editingDay = nil
                    }
                }
            }
        } header: {
            Text("Link days to a production")
        }

        if let p = selectedProject {
            Section {
                Picker("Billing mode", selection: contractKindBinding(for: p)) {
                    ForEach(ProductionContractKind.allCases) { k in
                        Text(k.menuTitle).tag(k)
                    }
                }
                Picker("Corporate entity", selection: businessEntityBinding(for: p)) {
                    Text("None").tag(UUID?.none)
                    ForEach(businessEntities) { e in
                        Text(e.legalName).tag(Optional(e.id))
                    }
                }
                Picker("Pay / AR cadence", selection: paymentTermsBinding(for: p)) {
                    ForEach(PaymentTermsMode.allCases) { mode in
                        Text(mode.menuTitle).tag(mode)
                    }
                }
                Picker("Rate governance", selection: governanceBinding(for: p)) {
                    ForEach(ProductionAutomationGovernance.allCases) { g in
                        Text(g.menuTitle).tag(g)
                    }
                }
            } header: {
                Text("Who & how you bill")
            } footer: {
                Text(
                    "Personal contractor gigs export a professional invoice with your entity letterhead instead of an EP timecard twin."
                )
                .font(.footnote)
            }

            Section {
                Toggle(
                    "Catering / door-to-door (shop-to-shop)",
                    isOn: cateringPortalBinding(for: p)
                )
                Text(
                    "When on, Sentinel treats leave zone as call and return home as wrap for OT and meal "
                        + "penalties, and does not add separate zone-travel pay on top of that span."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } header: {
                Text("Portal-to-portal")
            }

            Section {
                ForEach(sortedLaborRates(p), id: \.id) { rate in
                    ShowLaborPositionRateEditorRow(rate: rate)
                }
                Button("Add position / rate change") {
                    addLaborRateSegment(project: p)
                }
                .disabled(agreement == nil)
            } header: {
                Text("Rate sheet (multi-position)")
            } footer: {
                Text(
                    "Each segment applies from its effective date onward until the next row. "
                        + "Per-day classification and hourly override live on each crew day."
                )
                .font(.footnote)
            }
        }

        if let agr = agreement {
            Section {
                Picker("Sentinel template", selection: $laborSentinelAgreementCode) {
                    Text("Default (873)").tag("")
                    ForEach(laborAgreements, id: \.code) { a in
                        Text(a.title).tag(a.code)
                    }
                }
            } header: {
                Text("Engine")
            } footer: {
                Text("411 Chef uses your negotiated daily minimum ÷ guarantee hours as the OT / meal-penalty base.")
                    .font(.footnote)
            }

            if selectedProject != nil {
                Section {
                    Button("Run discrepancy sweep") {
                        weeklyAuditRows = WeeklyPayCycleAuditService.sweep(
                            projectDays: daysForProject,
                            agreement: agr,
                            anchorDate: Date(),
                            calendar: .current
                        )
                    }
                    if weeklyAuditRows.isEmpty {
                        Text(
                            "No rows yet — run after you log crew days, or open Labor Sentinel on Saturday for an automatic weekly pass."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(weeklyAuditRows) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.workDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(row.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(row.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("Weekly pay cycle audit")
                } footer: {
                    Text(
                        "Compares logged days and Sentinel rules for the **current ISO week** (meal penalties, turnaround gold, and crew call + 6h vs. Meal 1)."
                    )
                    .font(.footnote)
                }
            }

            Section {
                LabeledContent("Template", value: agr.title)
                LabeledContent("Base (CAD/hr)", value: "\(agr.baseHourlyRateCAD)")
                LabeledContent("Zone travel (CAD/hr)", value: "\(agr.zoneTravelHourlyCAD)")
                if let notes = agr.scaleNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Sentinel agreement")
            }
        } else {
            Section {
                Text("No labor agreement found. Re-open this screen after library migration.")
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            if selectedProject == nil {
                Text("Pick a production to add or list crew days.")
                    .foregroundStyle(.secondary)
            } else {
                let chain = sentinelChainByDayID
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(daysForProject) { day in
                        Button {
                            editingDay = day
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.workDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                                if let agr = agreement {
                                    let est = chain[day.id] ?? SentinelPayrollEngine.estimate(
                                        day: day,
                                        agreement: agr
                                    )
                                    Text(
                                        verbatim: "Model gross ≈ \(est.modelTotalCAD.formatted(.number.precision(.fractionLength(2)))) CAD"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    if let proj = selectedProject,
                                       let portalLine = portalClockReadout(day: day, project: proj)
                                    {
                                        Text(portalLine)
                                            .font(.caption2)
                                            .foregroundStyle(Color.ratioVitaAdaptiveText.opacity(0.85))
                                    }
                                    if est.turnaroundInfringementApplied {
                                        Text(
                                            "Turnaround gold ×\(String(format: "%.2f", est.turnaroundGoldMultiplier))"
                                        )
                                        .font(.caption2)
                                        .foregroundStyle(Color.orange)
                                    }
                                    if FraturdayCalendar.wrapsPastMidnight(day: day, calendar: .current) {
                                        Text("Fraturday wrap (past midnight)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if est.appliedDailyFloor {
                                        Text("Daily floor applied (411)")
                                            .font(.caption2)
                                            .foregroundStyle(Color.ratioVitaSuccess)
                                    }
                                }
                            }
                        }
                    }
                }
                Button("Add day") { addBlankDay() }
            }
        } header: {
            Text("Crew timecard days")
        }

        if let p = selectedProject, !p.isIndependentContractor {
            Section {
                KitCheckoutLaborSection(project: p, days: daysForProject)
            } header: {
                Text("Kit checkout → EP Other rates")
            } footer: {
                Text(
                    "Checked-out gear marks each crew day for phone/laptop lines. "
                        + "Export aggregates EP-style lines like CELL x5 and COMPUTER x5."
                )
                .font(.footnote)
            }
        }

        Section {
            if selectedProject?.isIndependentContractor == true {
                Button {
                    exportInvoiceTapped()
                } label: {
                    Label("Export as invoice (contractor)", systemImage: "doc.richtext")
                }
                .disabled(selectedProject == nil || agreement == nil || daysForProject.isEmpty)
            } else {
                Picker("PDF layout", selection: $exportFormat) {
                    ForEach(TimecardPDFFormatKind.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                Button {
                    exportPDFTapped()
                } label: {
                    Label("Export digital twin PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(selectedProject == nil || agreement == nil || daysForProject.isEmpty)
            }
            if let exportError {
                Text(exportError)
                    .font(.footnote)
                    .foregroundStyle(Color.ratioVitaError)
            }
        } footer: {
            if selectedProject?.isIndependentContractor == true {
                Text(
                    "Uses Sentinel math (base + premiums, 411 floor when applicable) on your corporate letterhead. Not tax or legal advice."
                )
            } else {
                Text(
                    "Uses this show’s default payroll document from Productions. One combined pay-week sheet lists each role and unit in the occupation block. After editing an export PDF, use Import grid on the export sheet — it is not automatic."
                )
            }
        }
    }

    @ViewBuilder
    private var macLaborTimecardDetail: some View {
        if let day = editingDay {
            TimecardWorkspaceView(
                day: day,
                siblingProjectDays: crewDays.filter { $0.productionProject?.id == day.productionProject?.id },
                showsToolbarDone: true,
                onToolbarDone: { editingDay = nil }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(day.workDate.formatted(date: .abbreviated, time: .omitted))
        } else {
            ContentUnavailableView(
                "Timecard workspace",
                systemImage: "calendar.day.timeline.left",
                description: Text("Select a crew day in the list.")
            )
        }
    }

    @ViewBuilder
    private var laborHubRoot: some View {
        #if os(macOS)
        NavigationSplitView {
            List { laborHubSections }
                .navigationTitle("Labor Sentinel")
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
        } detail: {
            macLaborTimecardDetail
                .navigationSplitViewColumnWidth(min: 450, ideal: 650, max: 900)
        }
        .resetsNavigationSplitColumnsOnLaunch()
        #else
        List { laborHubSections }
            .navigationTitle("Labor Sentinel")
        #endif
    }

    var body: some View {
        laborHubRoot
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddProductionSheet = true
                    } label: {
                        Label("New production", systemImage: "plus")
                    }
                    .accessibilityHint("Create a show without leaving Labor Sentinel.")
                }
            }
            .sheet(isPresented: $showAddProductionSheet) {
                ProductionProjectAddSheet(
                    onDismiss: { showAddProductionSheet = false },
                    onCreated: { p in selectedProjectID = p.id },
                    triggerSuccessHaptic: true
                )
            }
            .task {
                do {
                    try LaborSentinelBootstrap.ensureDefault873(modelContext: modelContext)
                    try LaborSentinelBootstrap.ensureDefault411Chef(modelContext: modelContext)
                } catch {
                    #if DEBUG
                    print("LaborSentinelBootstrap: \(error)")
                    #endif
                }
            }
            .onAppear {
                syncExportFormatFromSelectedProject()
                maybeAutoSaturdayPayCycleSweep()
            }
        #if os(iOS)
            .fullScreenCover(item: $editingDay) { day in
                NavigationStack {
                    WorkDateDetailView(
                        day: day,
                        siblingProjectDays: crewDays.filter { $0.productionProject?.id == day.productionProject?.id }
                    )
                }
            }
        #elseif !os(macOS)
            .sheet(item: $editingDay) { day in
                NavigationStack {
                    WorkDateDetailView(
                        day: day,
                        siblingProjectDays: crewDays.filter { $0.productionProject?.id == day.productionProject?.id }
                    )
                }
            }
        #endif
            .sheet(item: $exportItem) { item in
                NavigationStack {
                    TimecardExportResultSheet(
                        item: item,
                        crewDays: daysForProject,
                        modelContext: modelContext
                    ) {
                        exportItem = nil
                    }
                }
                #if os(macOS)
                .frame(minWidth: 820, idealWidth: 900, minHeight: 640, idealHeight: 720)
                #endif
            }
    }

    private func portalClockReadout(day: CrewTimecardDay, project: ProductionProject) -> String? {
        guard project.laborCateringPortalMode else { return nil }
        let cal = Calendar.current
        let tf = DateFormatter()
        tf.timeStyle = .short
        tf.dateStyle = .none
        let call = SentinelEffectiveClock.effectiveCall(day: day, project: project)
        let wrapRaw = SentinelEffectiveClock.effectiveWrapRaw(day: day, project: project)
        let wrap = FraturdayCalendar.normalizedWrapAfterCall(
            call: call,
            wrap: wrapRaw,
            workDateStart: cal.startOfDay(for: day.workDate),
            calendar: cal
        )
        let a = call.map { tf.string(from: $0) } ?? "—"
        let b = wrap.map { tf.string(from: $0) } ?? "—"
        return "Effective call → wrap \(a) → \(b)"
    }

    private func contractKindBinding(for project: ProductionProject) -> Binding<ProductionContractKind> {
        Binding(
            get: { project.productionContractKind },
            set: { newVal in
                project.productionContractKind = newVal
                project.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private func businessEntityBinding(for project: ProductionProject) -> Binding<UUID?> {
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

    private func paymentTermsBinding(for project: ProductionProject) -> Binding<PaymentTermsMode> {
        Binding(
            get: {
                let t = project.paymentTermsRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { return .unspecified }
                return PaymentTermsMode(rawValue: project.paymentTermsRaw) ?? .unspecified
            },
            set: { newVal in
                project.paymentTermsRaw = newVal == .unspecified ? "" : newVal.rawValue
                project.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private func governanceBinding(for project: ProductionProject) -> Binding<ProductionAutomationGovernance> {
        Binding(
            get: { project.automationGovernance },
            set: { newVal in
                project.automationGovernance = newVal
                try? modelContext.save()
            }
        )
    }

    private func syncExportFormatFromSelectedProject() {
        guard let p = selectedProject,
              let fmt = p.payrollDefaultDocumentKind.timecardFormat else { return }
        exportFormat = fmt
    }

    private func exportInvoiceTapped() {
        exportError = nil
        guard let p = selectedProject, let agr = agreement, !daysForProject.isEmpty else { return }
        do {
            let chain = sentinelChainByDayID
            let url = try ContractorInvoicePDFGenerator.writeInvoicePDF(
                production: p,
                entity: p.businessEntity,
                occupation: p.crewOccupationTitle,
                days: daysForProject,
                agreement: agr,
                estimateByDayID: chain
            )
            exportItem = PayrollExportSheetItem(
                url: url,
                productionTitle: p.title,
                exportFormat: .epCanadaCrewWeekly,
                isContractorInvoice: true
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func exportWeekEndingLabel(days: [CrewTimecardDay]) -> String {
        guard let last = FraturdayCalendar.sortedForPayrollChain(days, calendar: .current).last else {
            return ""
        }
        let cal = Calendar.current
        let anchor = FraturdayCalendar.payrollAnchorStartOfDay(for: last, calendar: cal)
        let weekday = cal.component(.weekday, from: anchor)
        let daysToSaturday = (7 - weekday) % 7
        let end = cal.date(byAdding: .day, value: daysToSaturday, to: anchor) ?? anchor
        return end.formatted(date: .abbreviated, time: .omitted)
    }

    private func exportPDFTapped() {
        exportError = nil
        guard let p = selectedProject, let agr = agreement, !daysForProject.isEmpty else { return }
        do {
            try KitCheckoutService.applyActiveCheckoutsToCrewDays(
                project: p,
                days: daysForProject,
                context: modelContext
            )
            let chain = sentinelChainByDayID
            // One combined pay-week sheet; roles + units are summarized in OCCUPATION / LOANOUT.
            let url = try TimecardDigitalTwinPDFGenerators.writeTwinPDF(
                kind: exportFormat,
                productionTitle: p.title,
                occupation: p.crewOccupationTitle,
                days: daysForProject,
                workRecords: workRecordsForProject,
                agreement: agr,
                estimateByDayID: chain,
                production: p
            )
            let urls = [url]
            guard let first = urls.first else { return }
            let occLine = daysForProject.compactMap(\.occupationTitle).first { !$0.isEmpty }
                ?? p.crewOccupationTitle
                ?? ""
            exportItem = PayrollExportSheetItem(
                url: first,
                extraURLs: Array(urls.dropFirst()),
                productionTitle: p.title,
                exportFormat: exportFormat,
                occupationLine: occLine,
                weekEndingLabel: exportWeekEndingLabel(days: daysForProject),
                isContractorInvoice: false
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func cateringPortalBinding(for project: ProductionProject) -> Binding<Bool> {
        Binding(
            get: { project.laborCateringPortalMode },
            set: { newVal in
                project.laborCateringPortalMode = newVal
                project.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private func sortedLaborRates(_ project: ProductionProject) -> [ShowLaborPositionRate] {
        project.laborPositionRates.sorted { $0.effectiveFromDate < $1.effectiveFromDate }
    }

    private func addLaborRateSegment(project: ProductionProject) {
        guard let agr = agreement else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let base = project.effectiveLaborBaseRate(for: today, calendar: cal) ?? agr.baseHourlyRateCAD
        let title =
            project.effectiveOccupationFromRateSheet(for: today, calendar: cal)
                ?? project.crewOccupationTitle
                ?? "Classification"
        let rate = ShowLaborPositionRate(
            effectiveFromDate: today,
            occupationTitle: title,
            baseHourlyRateCAD: base,
            productionProject: project
        )
        modelContext.insert(rate)
        try? modelContext.save()
    }

    private func addBlankDay() {
        guard let p = selectedProject else { return }
        let day = CrewTimecardDay(workDate: Calendar.current.startOfDay(for: Date()), productionProject: p)
        if day.ancillaryPhoneRateCAD == nil { day.ancillaryPhoneRateCAD = p.defaultKitPhoneRateCAD }
        if day.ancillaryLaptopRateCAD == nil { day.ancillaryLaptopRateCAD = p.defaultKitLaptopRateCAD }
        if day.ancillaryTabletRateCAD == nil { day.ancillaryTabletRateCAD = p.defaultKitTabletRateCAD }
        if p.payrollVehicleKitOn, day.ancillaryVehicleRateCAD == nil {
            day.ancillaryVehicleRateCAD = p.defaultKitVehicleRateCAD
        }
        modelContext.insert(day)
        editingDay = day
        try? modelContext.save()
    }

    private func maybeAutoSaturdayPayCycleSweep() {
        let cal = Calendar.current
        guard cal.component(.weekday, from: Date()) == 7 else { return }
        guard let agr = agreement, selectedProject != nil, !daysForProject.isEmpty else { return }

        let y = cal.component(.yearForWeekOfYear, from: Date())
        let w = cal.component(.weekOfYear, from: Date())
        let token = "\(y)-\(w)"
        guard token != payCycleLastAutoSweepWeekToken else { return }
        weeklyAuditRows = WeeklyPayCycleAuditService.sweep(
            projectDays: daysForProject,
            agreement: agr,
            anchorDate: Date(),
            calendar: cal
        )
        payCycleLastAutoSweepWeekToken = token
    }
}

private struct PayrollExportSheetItem: Identifiable {
    let id = UUID()
    let url: URL
    var extraURLs: [URL] = []
    let productionTitle: String
    let exportFormat: TimecardPDFFormatKind
    var occupationLine: String = ""
    var weekEndingLabel: String = ""
    var isContractorInvoice: Bool = false
}

// MARK: - Export preview

private struct TimecardExportResultSheet: View {
    let item: PayrollExportSheetItem
    let crewDays: [CrewTimecardDay]
    let modelContext: ModelContext
    var onDone: () -> Void

    @State private var importMessage: String?
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(item.productionTitle)
                .font(.headline)
                .adaptiveDetailText()

            if !item.isContractorInvoice {
                Text(item.exportFormat.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .adaptiveDetailText()
                Text(
                    "Official blank form PDF from payroll vendor — your hours are stamped on the bundled template."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .adaptiveDetailText()
            }

            #if canImport(PDFKit)
            PayrollPDFFitPageView(url: item.url)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
            #else
            Text("PDF saved — use Share to open in Preview.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .adaptiveDetailText()
            #endif

            ShareLink(item: item.url) {
                Label("Share PDF", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)

            if !item.isContractorInvoice, item.exportFormat == .epCanadaCrewWeekly {
                if let importMessage {
                    Text(importMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .adaptiveDetailText()
                }
                if let importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .adaptiveDetailText()
                }

                Text(
                    "Save & close reads DATE / CALL / MEAL / WRAP / TRAVEL from the PDF file on disk. "
                        + "Edit in Preview (or another app), save the file, then tap Save & close here. "
                        + "In-app grid preview is display-only — hours should be entered in Labor Sentinel or external Preview."
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .adaptiveDetailText()
            }

            if !item.extraURLs.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Also exported \(item.extraURLs.count) department sheet(s):")
                            .font(.subheadline.weight(.semibold))
                            .adaptiveDetailText()
                        ForEach(Array(item.extraURLs.enumerated()), id: \.offset) { _, url in
                            ShareLink(item: url) {
                                Label(url.lastPathComponent, systemImage: "doc.fill")
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .navigationTitle("Timecard export")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Save & close") {
                        if !item.isContractorInvoice, item.exportFormat == .epCanadaCrewWeekly {
                            importFromEditedPDF()
                        }
                        onDone()
                    }
                }
            }
    }

    private func importFromEditedPDF() {
        importMessage = nil
        importError = nil
        #if canImport(PDFKit)
        guard let document = PDFDocument(url: item.url),
              let parsed = EPCanadaPDFFormImporter.parse(document: document) else
        {
            importError = EPCanadaPDFFormImporter.ImportError.notEPForm.localizedDescription
            return
        }
        do {
            let count = try EPCanadaPDFFormImporter.apply(parsed: parsed, to: crewDays)
            try modelContext.save()
            importMessage = "Updated \(count) day(s) from the PDF. Check notes for [EP PDF import] tags."
        } catch {
            importError = error.localizedDescription
        }
        #else
        importError = "PDF import requires PDFKit."
        #endif
    }
}

private struct ShowLaborPositionRateEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var rate: ShowLaborPositionRate
    @State private var baseRateText: String = ""
    @State private var premiumRateText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("Effective from", selection: $rate.effectiveFromDate, displayedComponents: .date)
            TextField("Occupation", text: $rate.occupationTitle)
            TextField("Base CAD/hr", text: $baseRateText)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
                .onAppear { syncBaseText() }
                .onSubmit { commitBase() }
                .onChange(of: baseRateText) { _, _ in commitBase() }
            TextField("Premium add-on CAD/hr", text: $premiumRateText)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
                .onAppear { syncPremiumText() }
                .onSubmit { commitPremium() }
                .onChange(of: premiumRateText) { _, _ in commitPremium() }
            Text(
                verbatim: "Combined: \(rate.combinedHourlyRateCAD.formatted(.number.precision(.fractionLength(2)))) CAD/hr (OT uses total)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button(role: .destructive) {
                modelContext.delete(rate)
                try? modelContext.save()
            } label: {
                Text("Remove segment")
            }
        }
        .padding(.vertical, 4)
        .onChange(of: rate.effectiveFromDate) { _, _ in
            rate.updatedAt = .now
            try? modelContext.save()
        }
        .onChange(of: rate.occupationTitle) { _, _ in
            rate.updatedAt = .now
            try? modelContext.save()
        }
    }

    private func syncBaseText() {
        baseRateText = "\(rate.baseHourlyRateCAD)"
    }

    private func commitBase() {
        let trimmed = baseRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = Decimal(string: trimmed.replacingOccurrences(of: ",", with: ".")) {
            rate.baseHourlyRateCAD = d
            rate.updatedAt = .now
            try? modelContext.save()
        }
    }

    private func syncPremiumText() {
        premiumRateText = "\(rate.premiumHourlyRateCAD)"
    }

    private func commitPremium() {
        let trimmed = premiumRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = Decimal(string: trimmed.replacingOccurrences(of: ",", with: ".")) {
            rate.premiumHourlyRateCAD = d
            rate.updatedAt = .now
            try? modelContext.save()
        }
    }
}
