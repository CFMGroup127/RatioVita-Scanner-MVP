import SwiftData
import SwiftUI

/// Full-screen crew day editor shared by **modal** (`WorkDateDetailView`) and the **macOS** Labor Sentinel detail pane.
struct TimecardWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator
    @Bindable var day: CrewTimecardDay
    var siblingProjectDays: [CrewTimecardDay]
    var showsProductionSwitcher: Bool = false
    var productionOptions: [ProductionProject] = []
    /// When true, shows a trailing **Done** control that saves, runs Chef-floor audit hooks, then calls
    /// `onToolbarDone`.
    var showsToolbarDone: Bool
    var onToolbarDone: () -> Void

    @Query(sort: \LaborAgreement.title) private var laborAgreements: [LaborAgreement]
    @AppStorage("laborSentinelAgreementCode") private var laborSentinelAgreementCode: String = ""

    private static let departmentPresets = [
        "Costumes", "Transport", "Set Dec", "Grip & Electric", "Hair & Makeup", "Production Office",
    ]
    private static let unitPresets = ["Main Unit", "2nd Unit", "Splinter Unit", "Office"]

    private var agreement: LaborAgreement? {
        let trimmed = laborSentinelAgreementCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let match = laborAgreements.first(where: { $0.code == trimmed }) {
            return match
        }
        let def = LaborSentinelBootstrap.defaultAgreementCode
        return laborAgreements.first { $0.code == def } ?? laborAgreements.first
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                TimecardWeeklyMatrixView(
                    focusDay: day,
                    siblingProjectDays: siblingProjectDays
                )
                timecardForm
                PayrollComplianceEditorSection()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            applyCallSheetLaborPrefillIfNeeded()
            applyHarvestedRateTierIfNeeded()
        }
        .onChange(of: day.department) { _, _ in
            applyHarvestedRateTierIfNeeded()
        }
        .onChange(of: day.occupationTitle) { _, _ in
            applyHarvestedRateTierIfNeeded()
        }
        .toolbar {
            if showsToolbarDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        persistToolbarDone()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timecardForm: some View {
        #if os(macOS)
        macTimecardForm
        #else
        iosTimecardForm
        #endif
    }

    #if os(macOS)
    private var macTimecardForm: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            if showsProductionSwitcher, !productionOptions.isEmpty {
                LeftAlignedFormSection("Production") {
                    Picker("Production", selection: productionBinding) {
                        ForEach(productionOptions) { p in
                            Text(p.title).tag(p.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 360, alignment: .leading)
                }
            }
            LeftAlignedFormSection("Work date") {
                DatePicker("Date", selection: $day.workDate, displayedComponents: .date)
                    .labelsHidden()
                    .frame(maxWidth: 200, alignment: .leading)
            }
            LeftAlignedFormSection("Travel") {
                optionalTime("Leave zone (travel start)", selection: $day.travelLeaveZoneStart)
                optionalTime("Arrive set", selection: $day.travelToSetArrive)
                optionalTime("Leave set (return)", selection: $day.travelReturnLeaveSet)
                optionalTime("Home (travel end)", selection: $day.travelReturnHome)
            }
            LeftAlignedFormSection(
                "Set & crew call",
                footer: "Times export in 24-hour military format (HH:mm). Meal penalties use the earlier of six hours from your start or general crew call."
            ) {
                HStack { Text("Set & crew call")
                    RatioVitaHint(term: .crewCall)
                }
                optionalTime("Your call", selection: $day.callOnSet)
                optionalTime("General crew call", selection: $day.generalCrewCall)
                optionalTime("Wrap", selection: $day.wrapOffSet)
            }
            LeftAlignedFormSection("Meals") {
                optionalTime("Meal 1 start", selection: $day.meal1Start)
                optionalTime("Meal 1 end", selection: $day.meal1End)
                optionalTime("Meal 2 start", selection: $day.meal2Start)
                optionalTime("Meal 2 end", selection: $day.meal2End)
            }
            LeftAlignedFormSection("Classification") {
                Picker("Unit", selection: unitBinding) {
                    Text("Unset").tag("")
                    ForEach(Self.unitPresets, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 280, alignment: .leading)
                Picker("Department", selection: departmentBinding) {
                    Text("Unset").tag("")
                    ForEach(Self.departmentPresets, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 280, alignment: .leading)
                TextField(
                    "Occupation (EP line)",
                    text: Binding(
                        get: { day.occupationTitle ?? "" },
                        set: { day.occupationTitle = $0.isEmpty ? nil : $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360, alignment: .leading)
                DecimalOptionalField(title: "Hourly override (CAD/hr)", value: $day.overrideBaseHourlyRateCAD)
            }
            LeftAlignedFormSection("Human element") {
                Toggle("Paper timecard (manual forensic audit)", isOn: $day.paperForensicAuditMode)
            }
            LeftAlignedFormSection("MTO / travel log") {
                Toggle("Travel log verified", isOn: $day.travelLogMTOVerified)
                TextField(
                    "Pay-period note",
                    text: Binding(
                        get: { day.travelLogPayPeriodNote ?? "" },
                        set: { day.travelLogPayPeriodNote = $0.isEmpty ? nil : $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            LeftAlignedFormSection(
                "Kit / box rental",
                footer: "Routed to EP **Other rates** on export. Full-time kit uses weekly contract rates."
            ) {
                Toggle("Upgrade to full-time kit", isOn: $day.kitRentalFullTimeMode)
                    .onChange(of: day.kitRentalFullTimeMode) { _, on in
                        guard let project = day.productionProject else { return }
                        if on {
                            KitRentalContractHelper.applyFullTimeKitContract(to: day, project: project)
                        } else {
                            KitRentalContractHelper.applyCasualKitDefaults(to: day, project: project)
                        }
                    }
                Stepper("Phone days: \(day.ancillaryPhoneDays)", value: $day.ancillaryPhoneDays, in: 0...7)
                DecimalOptionalField(
                    title: day.kitRentalFullTimeMode ? "Phone allowance (CAD/week)" : "Phone rate (CAD/day)",
                    value: $day.ancillaryPhoneRateCAD
                )
                Stepper("Laptop days: \(day.ancillaryLaptopDays)", value: $day.ancillaryLaptopDays, in: 0...7)
                DecimalOptionalField(
                    title: day.kitRentalFullTimeMode ? "Laptop allowance (CAD/week)" : "Laptop rate (CAD/day)",
                    value: $day.ancillaryLaptopRateCAD
                )
                Stepper("Tablet days: \(day.ancillaryTabletDays)", value: $day.ancillaryTabletDays, in: 0...7)
                DecimalOptionalField(
                    title: day.kitRentalFullTimeMode ? "Tablet allowance (CAD/week)" : "Tablet rate (CAD/day)",
                    value: $day.ancillaryTabletRateCAD
                )
                if day.productionProject?.payrollVehicleKitOn == true {
                    Stepper(
                        "Vehicle days: \(day.ancillaryVehicleDays ?? 0)",
                        value: ancillaryVehicleDaysBinding(for: day),
                        in: 0...7
                    )
                    DecimalOptionalField(
                        title: day.kitRentalFullTimeMode ? "Vehicle allowance (CAD/week)" : "Vehicle rate (CAD/day)",
                        value: $day.ancillaryVehicleRateCAD
                    )
                }
            }
            LeftAlignedFormSection("Notes") {
                TextField("Notes", text: Binding(
                    get: { day.notes ?? "" },
                    set: { day.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            macSentinelPreview
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var macSentinelPreview: some View {
        if let agr = agreement {
            LeftAlignedFormSection("Sentinel preview") {
                let est = SentinelPayrollEngine.estimate(
                    for: day,
                    inProjectDays: siblingProjectDays,
                    agreement: agr
                )
                LabeledContent("Straight h", value: String(format: "%.2f", est.straightHours))
                LabeledContent("OT 8–12 h", value: String(format: "%.2f", est.overtime8To12Hours))
                LabeledContent("OT 12+ h", value: String(format: "%.2f", est.overtimeOver12Hours))
                LabeledContent("Travel h", value: String(format: "%.2f", est.travelHours))
                LabeledContent("Meal ½h units", value: "\(est.mealPenaltyHalfHours)")
                LabeledContent("Labor subtotal (CAD)", value: "\(est.laborSubtotalCAD)")
                LabeledContent("Model total (CAD)", value: "\(est.modelTotalCAD)")
            }
        }
    }
    #endif

    private var iosTimecardForm: some View {
        Form {
            if showsProductionSwitcher, !productionOptions.isEmpty {
                Section {
                    Picker("Production", selection: productionBinding) {
                        ForEach(productionOptions) { p in
                            Text(p.title)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .tag(p.id)
                        }
                    }
                } header: {
                    Text("Production")
                }
            }
            Section("Work date") {
                DatePicker("Date", selection: $day.workDate, displayedComponents: .date)
            }
            Section {
                optionalTime("Leave zone", selection: $day.travelLeaveZoneStart)
                optionalTime("Arrive set", selection: $day.travelToSetArrive)
                optionalTime("Leave set (return)", selection: $day.travelReturnLeaveSet)
                optionalTime("Home", selection: $day.travelReturnHome)
            } header: {
                Text("Travel")
            }
            Section {
                optionalTime("Your call", selection: $day.callOnSet)
                optionalTime("General crew call", selection: $day.generalCrewCall)
                optionalTime("Wrap", selection: $day.wrapOffSet)
            } header: {
                HStack {
                    Text("Set & crew call")
                    RatioVitaHint(term: .crewCall)
                }
            } footer: {
                Text(
                    "Meal penalties use the earlier of six hours from your start or from general crew call."
                )
                .font(.footnote)
            }
            Section("Meals") {
                optionalTime("Meal 1 start", selection: $day.meal1Start)
                optionalTime("Meal 1 end", selection: $day.meal1End)
                optionalTime("Meal 2 start", selection: $day.meal2Start)
                optionalTime("Meal 2 end", selection: $day.meal2End)
            }
            Section {
                Picker("Unit", selection: unitBinding) {
                    Text("Unset").tag("")
                    ForEach(Self.unitPresets, id: \.self) { Text($0).tag($0) }
                }
                Picker("Department", selection: departmentBinding) {
                    Text("Unset").tag("")
                    ForEach(Self.departmentPresets, id: \.self) { Text($0).tag($0) }
                }
                TextField(
                    "Occupation (EP line)",
                    text: Binding(
                        get: { day.occupationTitle ?? "" },
                        set: { day.occupationTitle = $0.isEmpty ? nil : $0 }
                    )
                )
                DecimalOptionalField(title: "Hourly override (CAD/hr)", value: $day.overrideBaseHourlyRateCAD)
            } header: {
                Text("Classification")
            }
            Section {
                Toggle("Paper timecard (manual forensic audit)", isOn: $day.paperForensicAuditMode)
                Text(
                    "Turn on when you submitted a handwritten sheet with no PDF trail. Sentinel still models hours from your entries so Forensic Pulse can watch pay deposits."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } header: {
                Text("Human element")
            }
            Section("MTO / travel log") {
                Toggle("Travel log verified", isOn: $day.travelLogMTOVerified)
                TextField(
                    "Pay-period note",
                    text: Binding(
                        get: { day.travelLogPayPeriodNote ?? "" },
                        set: { day.travelLogPayPeriodNote = $0.isEmpty ? nil : $0 }
                    )
                )
            }
            Section {
                Toggle("Upgrade to full-time kit", isOn: $day.kitRentalFullTimeMode)
                    .onChange(of: day.kitRentalFullTimeMode) { _, on in
                        guard let project = day.productionProject else { return }
                        if on {
                            KitRentalContractHelper.applyFullTimeKitContract(to: day, project: project)
                        } else {
                            KitRentalContractHelper.applyCasualKitDefaults(to: day, project: project)
                        }
                    }
                Stepper("Phone days: \(day.ancillaryPhoneDays)", value: $day.ancillaryPhoneDays, in: 0...7)
                DecimalOptionalField(
                    title: day.kitRentalFullTimeMode ? "Phone allowance (CAD/week)" : "Phone rate (CAD/day)",
                    value: $day.ancillaryPhoneRateCAD
                )
                Stepper("Laptop days: \(day.ancillaryLaptopDays)", value: $day.ancillaryLaptopDays, in: 0...7)
                DecimalOptionalField(
                    title: day.kitRentalFullTimeMode ? "Laptop allowance (CAD/week)" : "Laptop rate (CAD/day)",
                    value: $day.ancillaryLaptopRateCAD
                )
                Stepper("Tablet days: \(day.ancillaryTabletDays)", value: $day.ancillaryTabletDays, in: 0...7)
                DecimalOptionalField(
                    title: day.kitRentalFullTimeMode ? "Tablet allowance (CAD/week)" : "Tablet rate (CAD/day)",
                    value: $day.ancillaryTabletRateCAD
                )
                if day.productionProject?.payrollVehicleKitOn == true {
                    Stepper(
                        "Vehicle days: \(day.ancillaryVehicleDays ?? 0)",
                        value: ancillaryVehicleDaysBinding(for: day),
                        in: 0...7
                    )
                    DecimalOptionalField(
                        title: day.kitRentalFullTimeMode ? "Vehicle allowance (CAD/week)" : "Vehicle rate (CAD/day)",
                        value: $day.ancillaryVehicleRateCAD
                    )
                }
            } header: {
                Text("Kit / box rental")
            } footer: {
                Text(
                    "Full-time kit uses weekly contract rates from the deal memo; casual dailies use per-day rates."
                )
                .font(.footnote)
            }
            Section("Notes") {
                TextField("Notes", text: Binding(
                    get: { day.notes ?? "" },
                    set: { day.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .lineLimit(3...8)
            }
            sentinelPreviewSection
        }
    }

    private func persistToolbarDone() {
        day.updatedAt = .now
        if let agr = agreement, agr.effectiveCalculatorKind == .iatse411Chef {
            let est = SentinelPayrollEngine.estimate(
                for: day,
                inProjectDays: siblingProjectDays,
                agreement: agr
            )
            let floor = est.negotiatedDailyFloorCAD.map { "\($0)" } ?? "—"
            let raw = est.laborBeforeDailyFloorCAD.map { "\($0)" } ?? "—"
            if est.appliedDailyFloor {
                FilingCoordinator.appendAudit(
                    context: modelContext,
                    kindRaw: FilingCoordinator.auditKindSentinelChefFloorApplied,
                    title: "Sentinel calculation: Chef floor applied",
                    detail: "crewDay:\(day.id.uuidString);floorCAD:\(floor);rawLaborCAD:\(raw)"
                )
            } else {
                FilingCoordinator.appendAudit(
                    context: modelContext,
                    kindRaw: FilingCoordinator.auditKindSentinelChefTrueEarned,
                    title: "Sentinel calculation: OT/MP higher than floor",
                    detail:
                    "crewDay:\(day.id.uuidString);floorCAD:\(floor);rawLaborCAD:\(raw);modelTotalCAD:\(est.modelTotalCAD)"
                )
            }
        }
        try? modelContext.save()
        onToolbarDone()
    }

    private var departmentBinding: Binding<String> {
        Binding(
            get: { day.department ?? "" },
            set: { day.department = $0.isEmpty ? nil : $0 }
        )
    }

    private var productionBinding: Binding<UUID> {
        Binding(
            get: { day.productionProject?.id ?? productionOptions.first?.id ?? UUID() },
            set: { newID in
                guard let project = productionOptions.first(where: { $0.id == newID }) else { return }
                day.productionProject = project
                if day.kitRentalFullTimeMode {
                    KitRentalContractHelper.applyFullTimeKitContract(to: day, project: project)
                } else {
                    KitRentalContractHelper.applyCasualKitDefaults(to: day, project: project)
                }
                applyHarvestedRateTierIfNeeded()
                day.updatedAt = .now
            }
        )
    }

    private var unitBinding: Binding<String> {
        Binding(
            get: { day.unitType ?? "" },
            set: { day.unitType = $0.isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder
    private var sentinelPreviewSection: some View {
        if let agr = agreement {
            Section {
                let est = SentinelPayrollEngine.estimate(
                    for: day,
                    inProjectDays: siblingProjectDays,
                    agreement: agr
                )
                LabeledContent("Straight h", value: String(format: "%.2f", est.straightHours))
                LabeledContent("OT 8–12 h", value: String(format: "%.2f", est.overtime8To12Hours))
                LabeledContent("OT 12+ h", value: String(format: "%.2f", est.overtimeOver12Hours))
                LabeledContent("Travel h", value: String(format: "%.2f", est.travelHours))
                LabeledContent {
                    HStack(spacing: 4) {
                        Text("\(est.mealPenaltyHalfHours)")
                        RatioVitaHint(term: .mealPenalty)
                    }
                } label: {
                    Text("Meal ½h units")
                }
                LabeledContent("Labor subtotal (CAD)", value: "\(est.laborSubtotalCAD)")
                LabeledContent("Model total (CAD)", value: "\(est.modelTotalCAD)")
            } header: {
                Text("Sentinel preview")
            }
        }
    }

    @ViewBuilder
    private func optionalTime(_ title: String, selection: Binding<Date?>) -> some View {
        #if os(macOS)
        macOptionalTimeRow(title, selection: selection)
        #else
        Toggle(
            title,
            isOn: optionalTimeBinding(selection)
        )
        if selection.wrappedValue != nil {
            DatePicker(
                "",
                selection: Binding(
                    get: { selection.wrappedValue ?? day.workDate },
                    set: { selection.wrappedValue = $0 }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
        #endif
    }

    #if os(macOS)
    private func macOptionalTimeRow(_ title: String, selection: Binding<Date?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: optionalTimeBinding(selection)) {
                Text(title)
                    .adaptiveDetailText()
            }
            if selection.wrappedValue != nil {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selection.wrappedValue ?? day.workDate },
                        set: { selection.wrappedValue = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .environment(\.locale, Locale(identifier: "en_GB_POSIX"))
                .frame(maxWidth: 160, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    #endif

    private func optionalTimeBinding(_ selection: Binding<Date?>) -> Binding<Bool> {
        Binding(
            get: { selection.wrappedValue != nil },
            set: { on in
                if on, selection.wrappedValue == nil {
                    selection.wrappedValue = defaultClock(on: day.workDate)
                } else if !on {
                    selection.wrappedValue = nil
                }
            }
        )
    }

    private func defaultClock(on workDate: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: workDate)
        comps.hour = 7
        comps.minute = 0
        return cal.date(from: comps) ?? workDate
    }

    private func applyCallSheetLaborPrefillIfNeeded() {
        guard let pre = libraryNavigationCoordinator.consumeCallSheetLaborPrefillIfMatchingWorkDay(day.workDate) else { return }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: day.workDate)
        comps.hour = pre.crewCallHour
        comps.minute = pre.crewCallMinute
        comps.second = 0
        if let d = cal.date(from: comps) {
            day.generalCrewCall = d
        }
        if let loc = pre.setLocationLine?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
            let tag = "Set (call sheet): \(loc)"
            appendNoteLine(tag, relatedSubstring: loc)
        }
        if let prod = pre.productionTitleLine?.trimmingCharacters(in: .whitespacesAndNewlines), !prod.isEmpty {
            let tag = "Production (call sheet): \(prod)"
            appendNoteLine(tag, relatedSubstring: prod)
        }
        day.updatedAt = .now
    }

    private func applyHarvestedRateTierIfNeeded() {
        guard let project = day.productionProject else { return }
        let segment = project.activeRateSegment(
            for: day.workDate,
            occupation: day.occupationTitle,
            department: day.department
        )
        guard let segment else { return }

        if day.occupationTitle == nil || day.occupationTitle?.isEmpty == true {
            day.occupationTitle = segment.occupationTitle
        }
        if day.department == nil || day.department?.isEmpty == true, let d = segment.department {
            day.department = d
        }

        if project.usesCustomNonUnionSentinel, segment.rateKind == .flatDaily {
            day.overrideBaseHourlyRateCAD = nil
        } else {
            day.overrideBaseHourlyRateCAD = segment.combinedHourlyRateCAD
        }
        day.updatedAt = .now
    }

    private func appendNoteLine(_ line: String, relatedSubstring: String) {
        if let n = day.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            if !n.localizedCaseInsensitiveContains(relatedSubstring) {
                day.notes = "\(n)\n\(line)"
            }
        } else {
            day.notes = line
        }
    }

    private func ancillaryVehicleDaysBinding(for day: CrewTimecardDay) -> Binding<Int> {
        Binding(
            get: { day.ancillaryVehicleDays ?? 0 },
            set: { day.ancillaryVehicleDays = $0 }
        )
    }
}
