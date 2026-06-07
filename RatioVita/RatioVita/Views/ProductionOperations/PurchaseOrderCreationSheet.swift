import SwiftData
import SwiftUI

struct PurchaseOrderCreationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID = ""

    @State private var vendorName = ""
    @State private var lineItemsSummary = ""
    @State private var amountText = ""
    @State private var submittedByRole = "Coordinator"
    @State private var note = ""
    @State private var rules: ProductionApprovalRule?
    @State private var warningText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Vendor") {
                    TextField("Vendor name", text: $vendorName)
                    TextField("Line items summary", text: $lineItemsSummary, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Total (CAD)", text: $amountText)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    Picker("Submitted by", selection: $submittedByRole) {
                        Text("Coordinator").tag("Coordinator")
                        Text("Department head").tag("Department Head")
                        Text("Production manager").tag("Production Manager")
                        Text("Producer").tag("Producer")
                    }
                    TextField("Context note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                if let warningText {
                    Section("Approval path") {
                        Text(warningText)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("New purchase order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submit() }
                        .disabled(vendorName.isEmpty || parsedAmount == nil)
                }
            }
            .onChange(of: amountText) { _, _ in refreshWarning() }
            .onChange(of: submittedByRole) { _, _ in refreshWarning() }
            .task { await loadRules() }
        }
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    private func loadRules() async {
        let pid = UUID(uuidString: forensicActiveProductionID)
        rules = try? AccountingProtocolEngine.fetchOrCreateRules(
            context: modelContext,
            productionProjectID: pid
        )
        if let rules,
           let override = UserDefaults.standard.object(forKey: RuntimeConfigKeys.pettyCashOverrideKey) as? Double
        {
            rules.pettyCashAutoApproveCAD = Decimal(override)
        }
        refreshWarning()
    }

    private func refreshWarning() {
        guard let rules, let amount = parsedAmount else {
            warningText = nil
            return
        }
        let steps = AccountingProtocolEngine.requiredStepsForPurchaseOrder(
            amount: amount,
            submittedByRole: submittedByRole,
            rules: rules
        )
        var parts: [String] = []
        if steps.needsDeptHead { parts.append("Department head") }
        if steps.needsPM { parts.append("Production manager") }
        if steps.needsAccounting { parts.append("Accounting") }
        if steps.needsExecutive { parts.append("Executive producer") }
        if amount > rules.pettyCashAutoApproveCAD {
            parts.insert("Above petty cash threshold (\(rules.pettyCashAutoApproveCAD))", at: 0)
        }
        warningText = parts.isEmpty
            ? "No additional approvals required for this amount."
            : "Before field launch: " + parts.joined(separator: " → ")
    }

    private func submit() {
        guard let amount = parsedAmount else { return }
        let pid = UUID(uuidString: forensicActiveProductionID)
        let po = ProductionPurchaseOrder(
            productionProjectID: pid,
            vendorName: vendorName,
            lineItemsSummary: lineItemsSummary.isEmpty ? "—" : lineItemsSummary,
            totalAmountCAD: amount,
            submittedByRole: submittedByRole,
            contextualNote: note
        )
        modelContext.insert(po)
        try? modelContext.save()
        dismiss()
    }
}
