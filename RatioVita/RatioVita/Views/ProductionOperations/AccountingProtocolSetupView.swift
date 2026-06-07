import SwiftData
import SwiftUI

/// Accounting department rules for PO and timesheet routing.
struct AccountingProtocolSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID = ""

    @State private var rules: ProductionApprovalRule?
    @State private var saveMessage: String?

    private var activeProjectID: UUID? {
        UUID(uuidString: forensicActiveProductionID)
    }

    var body: some View {
        Form {
            if let rules {
                Section("Petty cash & runs") {
                    currencyField("Auto-approve under (CAD)", value: rules.pettyCashAutoApproveCAD) {
                        rules.pettyCashAutoApproveCAD = $0
                    }
                    Text("Ice, milk, and standard emergency runs under this amount skip PM after dept head signs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Purchase order thresholds") {
                    currencyField("Dept head max", value: rules.poDeptHeadMaxCAD) { rules.poDeptHeadMaxCAD = $0 }
                    currencyField("PM required above", value: rules.poRequiresPMAboveCAD) {
                        rules.poRequiresPMAboveCAD = $0
                    }
                    currencyField("Accounting above", value: rules.poRequiresAccountingAboveCAD) {
                        rules.poRequiresAccountingAboveCAD = $0
                    }
                    currencyField("Executive above", value: rules.poRequiresExecutiveAboveCAD) {
                        rules.poRequiresExecutiveAboveCAD = $0
                    }
                }
                Section("Timesheets") {
                    Toggle("Dept head / key", isOn: bind(\.timesheetRequiresDeptHead))
                    Toggle("Production manager", isOn: bind(\.timesheetRequiresPM))
                    Toggle("Accounting", isOn: bind(\.timesheetRequiresAccounting))
                }
                Section {
                    Button("Save production rules") { saveRules() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView("Loading rules", systemImage: "gearshape.2")
            }
            if let saveMessage {
                Section {
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Approval protocols")
        .task { await loadRules() }
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<ProductionApprovalRule, Bool>) -> Binding<Bool> {
        Binding(
            get: { rules?[keyPath: keyPath] ?? true },
            set: { rules?[keyPath: keyPath] = $0 }
        )
    }

    private func currencyField(
        _ title: String,
        value: Decimal,
        onChange: @escaping (Decimal) -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Amount", value: Binding(
                get: { NSDecimalNumber(decimal: value).doubleValue },
                set: { onChange(Decimal($0)) }
            ), format: .number)
                .multilineTextAlignment(.trailing)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
        }
    }

    private func loadRules() async {
        do {
            rules = try AccountingProtocolEngine.fetchOrCreateRules(
                context: modelContext,
                productionProjectID: activeProjectID
            )
        } catch {
            saveMessage = error.localizedDescription
        }
    }

    private func saveRules() {
        guard let rules else { return }
        rules.updatedAt = .now
        do {
            try modelContext.save()
            saveMessage = "Saved for active production."
        } catch {
            saveMessage = error.localizedDescription
        }
    }
}
