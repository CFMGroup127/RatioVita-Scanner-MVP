import SwiftData
import SwiftUI

/// Edit one deal-memo rate tier (occupation, department, effective date, rates).
struct ShowLaborPositionRateEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var rate: ShowLaborPositionRate

    @State private var baseRateText = ""
    @State private var premiumRateText = ""
    @State private var rentalDrafts: [RentalAllowanceDraft] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Department & position") {
                    LaborRateTierEditorFields(
                        rate: rate,
                        baseRateText: $baseRateText,
                        premiumRateText: $premiumRateText
                    )
                }

                Section {
                    if rentalDrafts.isEmpty {
                        Text("No rental lines yet — add cell, tablet, laptop, vehicle, or kit.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($rentalDrafts) { $draft in
                            VStack(alignment: .leading, spacing: 6) {
                                Picker("Type", selection: $draft.kind) {
                                    ForEach(RentalAllowanceKind.allCases) { k in
                                        Text(k.label).tag(k)
                                    }
                                }
                                TextField("Rate (CAD/day)", text: $draft.rateText)
                                #if os(iOS)
                                    .keyboardType(.decimalPad)
                                #endif
                            }
                        }
                        .onDelete { rentalDrafts.remove(atOffsets: $0) }
                    }
                    Button {
                        rentalDrafts.append(RentalAllowanceDraft())
                    } label: {
                        Label("Add rental item", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Rental items & kit allowances")
                } footer: {
                    Text(
                        "Stored on this tier until the brand → model → serial cascade ships. Deal-memo import will pre-fill later."
                    )
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
                .onAppear {
                    baseRateText = "\(rate.baseHourlyRateCAD)"
                    premiumRateText = "\(rate.premiumHourlyRateCAD)"
                    syncRentalDraftsFromNotes()
                }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    private func syncRentalDraftsFromNotes() {
        guard let notes = rate.allowanceNotes, !notes.isEmpty else { return }
        rentalDrafts = notes.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { return nil }
            let kind = RentalAllowanceKind(rawValue: String(parts[0])) ?? .cell
            return RentalAllowanceDraft(kind: kind, rateText: String(parts[1]))
        }
    }

    private func commitAndDismiss() {
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
        rate.allowanceNotes = rentalDrafts.isEmpty
            ? nil
            : rentalDrafts.map { "\($0.kind.rawValue)|\($0.rateText)" }.joined(separator: "\n")
        rate.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}

private enum RentalAllowanceKind: String, CaseIterable, Identifiable {
    case cell
    case tablet
    case laptop
    case vehicle
    case kit

    var id: String { rawValue }
    var label: String {
        switch self {
            case .cell: "Cell / mobile"
            case .tablet: "Tablet / iPad"
            case .laptop: "Laptop / computer"
            case .vehicle: "Car / vehicle"
            case .kit: "Kit rental"
        }
    }
}

private struct RentalAllowanceDraft: Identifiable {
    let id = UUID()
    var kind: RentalAllowanceKind = .cell
    var rateText: String = "5"
}
