import SwiftData
import SwiftUI

/// Per-production payroll fields and default paperwork template.
struct ProductionPayrollSettingsSection: View {
    private static let departmentPresets = [
        "Costumes", "Transport", "Set Dec", "Grip & Electric", "Hair & Makeup", "Production Office",
    ]

    @Bindable var project: ProductionProject
    @Environment(\.modelContext) private var modelContext

    @State private var productionCompanyField = ""
    @State private var loanoutField = ""
    @State private var unionField = ""
    @State private var unionIDField = ""
    @State private var crewInitialsField = ""
    @State private var vehicleRateField = ""

    var body: some View {
        #if os(macOS)
        macContent
        #else
        iosFormContent
        #endif
    }

    #if os(macOS)
    private var macContent: some View {
        LeftAlignedFormSection(
            "Payroll & paperwork",
            footer: "Default document is used in Labor Sentinel export. ACTRA voucher PDFs are planned — use notes until templates ship."
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                payrollDocumentPicker
                departmentPicker
                productionFormFields
                residencyAndGuildPickers
                crewInitialsFields
                vehicleKitFields
            }
        }
        .onAppear(perform: loadFields)
        .onChange(of: project.businessEntity?.id) { _, _ in
            project.syncPayrollLoanoutFromCorporateEntityIfEmpty()
            loadFields()
        }
    }
    #endif

    private var iosFormContent: some View {
        Section {
            payrollDocumentPicker
            departmentPicker
            productionFormFields
            residencyAndGuildPickers
            crewInitialsFields
            vehicleKitFields
        } header: {
            Text("Payroll & paperwork")
        } footer: {
            Text(
                "Production company is the studio/network on the EP sheet. Loan-out is your corporation registered for payroll. Name on the PDF uses your payroll display name from Settings."
            )
            .font(.footnote)
        }
        .onAppear(perform: loadFields)
        .onChange(of: project.businessEntity?.id) { _, _ in
            project.syncPayrollLoanoutFromCorporateEntityIfEmpty()
            loadFields()
        }
    }

    @ViewBuilder
    private var payrollDocumentPicker: some View {
        #if os(macOS)
        ProductionFormLabeledRow(label: "Payroll document") {
            payrollDocumentPickerControl
        }
        #else
        payrollDocumentPickerControl
        #endif
    }

    private var payrollDocumentPickerControl: some View {
        Picker("Payroll document", selection: payrollDocumentBinding) {
            Section("Crew") {
                ForEach(ProductionPayrollDocumentKind.crewCases) { kind in
                    Text(kind.menuTitle).tag(kind)
                }
            }
            Section("Talent") {
                ForEach(ProductionPayrollDocumentKind.talentCases) { kind in
                    Text(kind.menuTitle).tag(kind)
                }
            }
            Section("ACTRA voucher") {
                ForEach(ProductionPayrollDocumentKind.actraCases) { kind in
                    Text(kind.menuTitle).tag(kind)
                }
            }
        }
        #if os(macOS)
        .labelsHidden()
        .frame(maxWidth: 420, alignment: .leading)
        #endif
    }

    @ViewBuilder
    private var departmentPicker: some View {
        #if os(macOS)
        ProductionFormLabeledRow(label: "Department") {
            departmentPickerControl
        }
        #else
        departmentPickerControl
        #endif
    }

    private var departmentPickerControl: some View {
        Picker("Department", selection: departmentBinding) {
            Text("Use timecard / deal memo").tag("")
            ForEach(Self.departmentPresets, id: \.self) { Text($0).tag($0) }
        }
        #if os(macOS)
        .labelsHidden()
        .frame(maxWidth: 280, alignment: .leading)
        #endif
    }

    @ViewBuilder
    private var productionFormFields: some View {
        #if os(macOS)
        ProductionFormLabeledRow(label: "Production company") {
            TextField("Studio / network", text: $productionCompanyField)
                .textFieldStyle(.roundedBorder)
                .onChange(of: productionCompanyField) { _, v in
                    project.payrollProductionCompany = v.isEmpty ? nil : v
                    save()
                }
        }
        ProductionFormLabeledRow(label: "Loan-out") {
            TextField("Corporate entity for payroll", text: $loanoutField)
                .textFieldStyle(.roundedBorder)
                .onChange(of: loanoutField) { _, v in
                    project.payrollLoanoutCompany = v.isEmpty ? nil : v
                    save()
                }
        }
        ProductionFormLabeledRow(label: "Union") {
            TextField("e.g. IA 873", text: $unionField)
                .textFieldStyle(.roundedBorder)
                .onChange(of: unionField) { _, v in
                    project.payrollUnionName = v.isEmpty ? nil : v
                    save()
                }
        }
        ProductionFormLabeledRow(label: "Union ID") {
            TextField("Optional", text: $unionIDField)
                .textFieldStyle(.roundedBorder)
                .onChange(of: unionIDField) { _, v in
                    project.payrollUnionID = v.isEmpty ? nil : v
                    save()
                }
        }
        #else
        TextField("Production company", text: $productionCompanyField)
            .onChange(of: productionCompanyField) { _, v in
                project.payrollProductionCompany = v.isEmpty ? nil : v
                save()
            }
        TextField("Loan-out (corporate entity)", text: $loanoutField)
            .onChange(of: loanoutField) { _, v in
                project.payrollLoanoutCompany = v.isEmpty ? nil : v
                save()
            }
        TextField("Union", text: $unionField)
            .onChange(of: unionField) { _, v in
                project.payrollUnionName = v.isEmpty ? nil : v
                save()
            }
        TextField("Union ID #", text: $unionIDField)
            .onChange(of: unionIDField) { _, v in
                project.payrollUnionID = v.isEmpty ? nil : v
                save()
            }
        #endif
    }

    @ViewBuilder
    private var residencyAndGuildPickers: some View {
        #if os(macOS)
        ProductionFormLabeledRow(label: "Residency") {
            residencyPickerControl
        }
        ProductionFormLabeledRow(label: "Guild status") {
            guildPickerControl
        }
        #else
        Picker("Residency", selection: residencyBinding) { residencyPickerControl }
        Picker("Guild status", selection: guildBinding) { guildPickerControl }
        #endif
    }

    private var residencyPickerControl: some View {
        Picker("Residency", selection: residencyBinding) {
            Text("Use global default").tag("")
            ForEach(PayrollComplianceProfile.ResidencyTier.allCases) { tier in
                Text(tier.label).tag(tier.rawValue)
            }
        }
        #if os(macOS)
        .labelsHidden()
        .frame(maxWidth: 220, alignment: .leading)
        #endif
    }

    private var guildPickerControl: some View {
        Picker("Guild status", selection: guildBinding) {
            Text("Use global default").tag("")
            ForEach(PayrollComplianceProfile.GuildTier.allCases) { tier in
                Text(tier.label).tag(tier.rawValue)
            }
        }
        #if os(macOS)
        .labelsHidden()
        .frame(maxWidth: 220, alignment: .leading)
        #endif
    }

    @ViewBuilder
    private var crewInitialsFields: some View {
        #if os(macOS)
        ProductionFormLabeledRow(label: "Crew initials") {
            TextField("e.g. CM", text: $crewInitialsField)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80, alignment: .leading)
                .onChange(of: crewInitialsField) { _, v in
                    project.payrollCrewInitialsOverride = v.isEmpty ? nil : v.uppercased()
                    save()
                }
        }
        Toggle("Auto-stamp crew initials on export", isOn: autoStampCrewInitialsBinding)
            .padding(.leading, 148 + DesignSystem.Spacing.md)
        #else
        Toggle("Auto-stamp crew initials on export", isOn: autoStampCrewInitialsBinding)
        TextField("Crew initials override (optional)", text: $crewInitialsField)
            .onChange(of: crewInitialsField) { _, v in
                project.payrollCrewInitialsOverride = v.isEmpty ? nil : v.uppercased()
                save()
            }
        #if os(iOS)
            .textInputAutocapitalization(.characters)
        #endif
        #endif
    }

    private var selectedDocumentKind: ProductionPayrollDocumentKind {
        ProductionPayrollDocumentKind.fromStored(project.payrollDefaultDocumentKindRaw)
    }

    private var payrollDocumentBinding: Binding<ProductionPayrollDocumentKind> {
        Binding(
            get: { selectedDocumentKind },
            set: {
                project.payrollDefaultDocumentKindRaw = $0.rawValue
                save()
            }
        )
    }

    private var departmentBinding: Binding<String> {
        Binding(
            get: { project.payrollDepartment ?? "" },
            set: {
                project.payrollDepartment = $0.isEmpty ? nil : $0
                save()
            }
        )
    }

    private var residencyBinding: Binding<String> {
        Binding(
            get: { project.payrollResidencyStatusRaw ?? "" },
            set: {
                project.payrollResidencyStatusRaw = $0.isEmpty ? nil : $0
                save()
            }
        )
    }

    private var guildBinding: Binding<String> {
        Binding(
            get: { project.payrollGuildStatusRaw ?? "" },
            set: {
                project.payrollGuildStatusRaw = $0.isEmpty ? nil : $0
                save()
            }
        )
    }

    private var autoStampCrewInitialsBinding: Binding<Bool> {
        Binding(
            get: { project.payrollAutoStampCrewInitials ?? false },
            set: {
                project.payrollAutoStampCrewInitials = $0
                save()
            }
        )
    }

    @ViewBuilder
    private var vehicleKitFields: some View {
        #if os(macOS)
        ProductionFormLabeledRow(label: "Vehicle / car") {
            vehicleKitControls
        }
        #else
        vehicleKitControls
        #endif
    }

    private var vehicleKitControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Bill vehicle on EP Other rates", isOn: vehicleKitBinding)
            if project.payrollVehicleKitOn {
                TextField("Vehicle rate (CAD/day)", text: $vehicleRateField)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                    .onChange(of: vehicleRateField) { _, v in
                        let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let d = Decimal(string: trimmed.replacingOccurrences(of: ",", with: ".")) {
                            project.defaultKitVehicleRateCAD = d
                        } else if trimmed.isEmpty {
                            project.defaultKitVehicleRateCAD = nil
                        }
                        save()
                    }
            }
            Text("When enabled, billed vehicle days on each crew row appear with cell, laptop, and iPad on export.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var vehicleKitBinding: Binding<Bool> {
        Binding(
            get: { project.payrollVehicleKitOn },
            set: {
                project.payrollVehicleKitOn = $0
                save()
            }
        )
    }

    private func loadFields() {
        project.syncPayrollLoanoutFromCorporateEntityIfEmpty()
        productionCompanyField = project.payrollProductionCompany ?? project.billingClientCompanyName ?? ""
        loanoutField = project.payrollLoanoutCompany ?? ""
        if let rate = project.defaultKitVehicleRateCAD {
            vehicleRateField = "\(rate)"
        } else {
            vehicleRateField = ""
        }
        unionField = project.payrollUnionName ?? ""
        unionIDField = project.payrollUnionID ?? ""
        crewInitialsField = project.payrollCrewInitialsOverride ?? ""
    }

    private func save() {
        project.updatedAt = .now
        try? modelContext.save()
    }
}
