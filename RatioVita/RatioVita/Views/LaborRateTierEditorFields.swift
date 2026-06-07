import SwiftData
import SwiftUI

/// Shared department → occupation → rate fields for rate tiers (sheet + Labor Sentinel inline rows).
struct LaborRateTierEditorFields: View {
    @Bindable var rate: ShowLaborPositionRate
    @Binding var baseRateText: String
    @Binding var premiumRateText: String

    @State private var selectedDepartment = ""
    @State private var selectedOccupation = ""
    @State private var customOccupation = ""
    @State private var useCustomOccupation = false
    @State private var useCustomDepartment = false

    private var occupationOptions: [String] {
        let dept = useCustomDepartment ? selectedDepartment : selectedDepartment
        return ProductionDepartmentOccupationCatalog.occupations(for: dept)
    }

    var body: some View {
        Group {
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

            TextField("Base hourly (CAD)", text: $baseRateText)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
            TextField("Premium add-on hourly (CAD)", text: $premiumRateText)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
            Text(
                "Combined: \(combinedPreview.formatted(.number.precision(.fractionLength(2)))) CAD/hr"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            DatePicker("Effective from", selection: $rate.effectiveFromDate, displayedComponents: .date)
        }
        .onAppear { syncFromRate() }
        .onChange(of: baseRateText) { _, _ in commitRatesFromText() }
        .onChange(of: premiumRateText) { _, _ in commitRatesFromText() }
        .onChange(of: rate.effectiveFromDate) { _, _ in
            rate.updatedAt = .now
        }
        .onChange(of: selectedDepartment) { _, newDept in
            if newDept == ProductionDepartmentOccupationCatalog.otherDepartment {
                useCustomDepartment = true
            }
            if !useCustomOccupation, !occupationOptions.contains(selectedOccupation) {
                selectedOccupation = ""
            }
            commitDepartment()
        }
        .onChange(of: selectedOccupation) { _, occ in
            if occ == CostumesDepartmentOccupationCatalog.otherTitle {
                useCustomOccupation = true
            } else {
                commitOccupation()
            }
        }
        .onChange(of: customOccupation) { _, _ in commitOccupation() }
        .onChange(of: useCustomOccupation) { _, _ in commitOccupation() }
        .onChange(of: useCustomDepartment) { _, on in
            if !on, selectedDepartment == ProductionDepartmentOccupationCatalog.otherDepartment {
                selectedDepartment = ""
            }
            commitDepartment()
        }
    }

    private var combinedPreview: Decimal {
        let base = Decimal(string: baseRateText.replacingOccurrences(of: ",", with: ".")) ?? rate.baseHourlyRateCAD
        let prem =
            Decimal(string: premiumRateText.replacingOccurrences(of: ",", with: ".")) ?? rate.premiumHourlyRateCAD
        return base + prem
    }

    func syncFromRate() {
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
        let options = ProductionDepartmentOccupationCatalog.occupations(for: selectedDepartment)
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

    func commitToRate() {
        commitDepartment()
        commitOccupation()
        if let d = Decimal(string: baseRateText.replacingOccurrences(of: ",", with: ".")) {
            rate.baseHourlyRateCAD = d
        }
        if let d = Decimal(string: premiumRateText.replacingOccurrences(of: ",", with: ".")) {
            rate.premiumHourlyRateCAD = d
        }
        rate.updatedAt = .now
    }

    private func commitDepartment() {
        let dept = selectedDepartment.trimmingCharacters(in: .whitespacesAndNewlines)
        rate.department = dept.isEmpty ? nil : dept
        rate.updatedAt = .now
    }

    private func commitOccupation() {
        if useCustomOccupation {
            let occ = customOccupation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !occ.isEmpty { rate.occupationTitle = occ }
        } else if !selectedOccupation.isEmpty,
                  selectedOccupation != CostumesDepartmentOccupationCatalog.otherTitle
        {
            rate.occupationTitle = selectedOccupation
        }
        rate.updatedAt = .now
    }

    private func commitRatesFromText() {
        if let d = Decimal(string: baseRateText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(
            of: ",",
            with: "."
        )) {
            rate.baseHourlyRateCAD = d
        }
        if let d = Decimal(string: premiumRateText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(
            of: ",",
            with: "."
        )) {
            rate.premiumHourlyRateCAD = d
        }
        rate.updatedAt = .now
    }
}
