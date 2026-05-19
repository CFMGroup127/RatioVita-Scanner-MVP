import SwiftData
import SwiftUI

/// Edit one deal-memo rate tier (occupation, department, effective date, rates).
struct ShowLaborPositionRateEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var rate: ShowLaborPositionRate

    @State private var baseRateText = ""
    @State private var premiumRateText = ""
    @State private var departmentText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    DatePicker("Effective from", selection: $rate.effectiveFromDate, displayedComponents: .date)
                    TextField("Occupation / classification", text: $rate.occupationTitle)
                    TextField("Department", text: $departmentText)
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
                        Button("Save") {
                            commitAndDismiss()
                        }
                    }
                }
                .onAppear {
                    syncFields()
                }
                .onChange(of: rate.effectiveFromDate) { _, _ in touch() }
                .onChange(of: rate.occupationTitle) { _, _ in touch() }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 420)
        #endif
    }

    private func syncFields() {
        baseRateText = "\(rate.baseHourlyRateCAD)"
        premiumRateText = "\(rate.premiumHourlyRateCAD)"
        departmentText = rate.department ?? ""
    }

    private func commitAndDismiss() {
        let dept = departmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        rate.department = dept.isEmpty ? nil : dept
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
