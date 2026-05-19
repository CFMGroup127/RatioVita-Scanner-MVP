import SwiftData
import SwiftUI

/// Edit one deal-memo rate tier (department, occupation, rates, effective date).
struct ShowLaborPositionRateEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var rate: ShowLaborPositionRate

    @State private var baseRateText = ""
    @State private var premiumRateText = ""
    @State private var selectedDepartment = ""
    @State private var selectedOccupation = ""
    @State private var customOccupation = ""
    @State private var useCustomOccupation = false
    @State private var useCustomDepartment = false

    private var occupationOptions: [String] {
        let dept = useCustomDepartment
            ? selectedDepartment
            : (selectedDepartment.isEmpty ? (rate.department ?? "") : selectedDepartment)
        return ProductionDepartmentOccupationCatalog.occupations(for: dept)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if useCustomDepartment {
                        TextField("Department", text: $selectedDepartment)
                    } else {
                        Picker("Department", selection: $selectedDepartment) {
                            Text("Select department").tag("")
                            ForEach(ProductionDepartmentOccupationCatalog.departmentPresets, id: \.self) { dept in
                                Text(dept).tag(dept)
                            }
                            Text(ProductionDepartmentOccupationCatalog.otherDepartment).tag(
                                ProductionDepartmentOccupationCatalog.otherDepartment
                            )
                        }
                    }
                    Toggle("Custom department name", isOn: $useCustomDepartment)
                } header: {
                    Text("Department")
                } footer: {
                    Text("Choose Costumes to see the 873 feature-film wardrobe role list.")
                        .font(.caption)
                }

                Section {
                    if useCustomOccupation {
                        TextField("Occupation / classification", text: $customOccupation)
                    } else {
                        Picker("Occupation / classification", selection: $selectedOccupation) {
                            Text("Select occupation").tag("")
                            ForEach(occupationOptions, id: \.self) { title in
                                Text(title).tag(title)
                            }
                        }
                        .disabled(selectedDepartment.isEmpty && !useCustomDepartment)
                    }
                    Toggle("Custom occupation", isOn: $useCustomOccupation)
                } header: {
                    Text("Occupation / classification")
                }

                Section("Rates (CAD)") {
                    TextField("Base hourly", text: $baseRateText)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    TextField("Premium add-on hourly", text: $premiumRateText)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    Text(
                        "Combined: \(rate.combinedHourlyRateCAD.formatted(.number.precision(.fractionLength(2)))) CAD/hr"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section {
                    DatePicker("Effective from", selection: $rate.effectiveFromDate, displayedComponents: .date)
                } header: {
                    Text("Effective from")
                }

                Section {
                    Text(
                        "Itemized kit & rental allowances (cell, tablet, laptop, vehicle, costume truck kit) will link here and to Cabinets → Kits. Deal-memo import will pre-fill rates when available."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Rental items & kit allowances")
                }

                Section {
                    Button("Delete this tier", role: .destructive) {
                        modelContext.delete(rate)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Position & rate")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { commitAndDismiss() }
                    }
                }
                .onAppear { syncFields() }
                .onChange(of: selectedDepartment) { _, newDept in
                    if newDept == ProductionDepartmentOccupationCatalog.otherDepartment {
                        useCustomDepartment = true
                    }
                    if !useCustomOccupation, !occupationOptions.contains(selectedOccupation) {
                        selectedOccupation = ""
                    }
                }
                .onChange(of: useCustomDepartment) { _, on in
                    if !on, selectedDepartment == ProductionDepartmentOccupationCatalog.otherDepartment {
                        selectedDepartment = ""
                    }
                }
                .onChange(of: selectedOccupation) { _, occ in
                    if occ == CostumesDepartmentOccupationCatalog.otherTitle {
                        useCustomOccupation = true
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    private func syncFields() {
        baseRateText = "\(rate.baseHourlyRateCAD)"
        premiumRateText = "\(rate.premiumHourlyRateCAD)"

        let dept = rate.department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if ProductionDepartmentOccupationCatalog.departmentPresets.contains(dept) {
            selectedDepartment = dept
            useCustomDepartment = false
        } else if dept.isEmpty {
            selectedDepartment = ""
            useCustomDepartment = false
        } else {
            selectedDepartment = dept
            useCustomDepartment = true
        }

        let occ = rate.occupationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = ProductionDepartmentOccupationCatalog.occupations(
            for: useCustomDepartment ? selectedDepartment : (selectedDepartment.isEmpty ? dept : selectedDepartment)
        )
        if options.contains(occ) {
            selectedOccupation = occ
            useCustomOccupation = false
            customOccupation = ""
        } else if occ.isEmpty {
            selectedOccupation = ""
            useCustomOccupation = false
        } else {
            customOccupation = occ
            useCustomOccupation = true
        }
    }

    private func commitAndDismiss() {
        let dept = selectedDepartment.trimmingCharacters(in: .whitespacesAndNewlines)
        rate.department = dept.isEmpty ? nil : dept

        if useCustomOccupation {
            let occ = customOccupation.trimmingCharacters(in: .whitespacesAndNewlines)
            rate.occupationTitle = occ.isEmpty ? rate.occupationTitle : occ
        } else if !selectedOccupation.isEmpty,
                  selectedOccupation != CostumesDepartmentOccupationCatalog.otherTitle
        {
            rate.occupationTitle = selectedOccupation
        }

        commitBase()
        commitPremium()
        touch()
        try? modelContext.save()
        dismiss()
    }

    private func commitBase() {
        let trimmed = baseRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = Decimal(string: trimmed.replacingOccurrences(of: ",", with: ".")) {
            rate.baseHourlyRateCAD = d
        }
    }

    private func commitPremium() {
        let trimmed = premiumRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = Decimal(string: trimmed.replacingOccurrences(of: ",", with: ".")) {
            rate.premiumHourlyRateCAD = d
        }
    }

    private func touch() {
        rate.updatedAt = .now
        try? modelContext.save()
    }
}
