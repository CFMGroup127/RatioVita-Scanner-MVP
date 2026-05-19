import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// New production form shared by **Corporate registry** and **Labor Sentinel** (+ button).
struct ProductionProjectAddSheet: View {
    enum LaborPreset: String, CaseIterable, Identifiable {
        case film873Standard = "Film / TV (873 scale)"
        case chefCatering411 = "Chef / Catering (411 floor)"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @AppStorage("laborSentinelAgreementCode") private var laborSentinelAgreementCode: String = ""

    @Query(sort: \BusinessEntity.legalName) private var businessEntities: [BusinessEntity]

    var onDismiss: () -> Void
    var onCreated: ((ProductionProject) -> Void)?
    /// When true, plays a success haptic after a successful create (Labor hub).
    var triggerSuccessHaptic: Bool = false
    /// Default row in the labor preset picker.
    var defaultLaborPreset: LaborPreset = .film873Standard

    @State private var title = ""
    @State private var parentEntity = ""
    @State private var colorHex = ""
    @State private var laborPreset: LaborPreset = .film873Standard
    @State private var contractKind: ProductionContractKind = .corporateContract
    @State private var selectedEntityID: UUID?
    @State private var crewOccupationTitle: String?
    @State private var paymentTerms: PaymentTermsMode = .unspecified
    @State private var governance: ProductionAutomationGovernance = .unionIATSE873

    var body: some View {
        NavigationStack {
            Form {
                Section("Production") {
                    TextField("Show / project title", text: $title)
                    TextField("Parent business (optional)", text: $parentEntity)
                    IATSE873OccupationPicker(occupationTitle: $crewOccupationTitle)
                    TextField("Radar color RRGGBB (optional)", text: $colorHex)
                    #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    #endif
                }
                Section("Billing") {
                    Picker("Contract type", selection: $contractKind) {
                        ForEach(ProductionContractKind.allCases) { k in
                            Text(k.menuTitle).tag(k)
                        }
                    }
                    Picker("Corporate entity", selection: $selectedEntityID) {
                        Text("None").tag(UUID?.none)
                        ForEach(businessEntities) { e in
                            Text(e.legalName).tag(Optional(e.id))
                        }
                    }
                    Picker("Pay / AR cadence", selection: $paymentTerms) {
                        ForEach(PaymentTermsMode.allCases) { mode in
                            Text(mode.menuTitle).tag(mode)
                        }
                    }
                }
                Section("Labor Sentinel") {
                    Picker("Rate governance", selection: $governance) {
                        ForEach(ProductionAutomationGovernance.allCases) { g in
                            Text(g.menuTitle).tag(g)
                        }
                    }
                    Picker("Default labor profile", selection: $laborPreset) {
                        ForEach(LaborPreset.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    Text(
                        "411 enables the negotiated daily floor with ÷14 implied OT base and turns on shop-to-shop "
                            + "clocking for catering runs."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Section {
                    Button("Create") {
                        createProduction()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("New production")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onDismiss() }
                    }
                }
                .onAppear {
                    laborPreset = defaultLaborPreset
                }
        }
    }

    private func createProduction() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let parentTrim = parentEntity.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = parentTrim.isEmpty ? nil : parentTrim
        let hexRaw = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let hex = hexRaw.isEmpty ? nil : hexRaw
        let p = ProductionProject(
            title: t,
            parentBusinessTitle: parent,
            timelineColorHex: hex,
            crewOccupationTitle: crewOccupationTitle
        )
        p.productionContractKind = contractKind
        if let eid = selectedEntityID {
            p.businessEntity = businessEntities.first { $0.id == eid }
        }
        p.paymentTermsRaw = paymentTerms == .unspecified ? "" : paymentTerms.rawValue
        p.automationGovernance = governance
        switch laborPreset {
            case .film873Standard:
                p.laborCateringPortalMode = false
            case .chefCatering411:
                p.laborCateringPortalMode = true
                laborSentinelAgreementCode = LaborSentinelBootstrap.chef411AgreementCode
                if contractKind == .corporateContract {
                    contractKind = .personalContractor
                    p.productionContractKind = .personalContractor
                }
        }
        modelContext.insert(p)
        try? modelContext.save()
        onCreated?(p)
        if triggerSuccessHaptic {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
        onDismiss()
    }
}
