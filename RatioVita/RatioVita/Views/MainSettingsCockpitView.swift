import SwiftUI

/// Apple-style module toggles — controls optional sidebar surfaces and R&D features.
struct MainSettingsCockpitView: View {
    @AppStorage(SovereignFeatureFlags.manuscriptVaultKey) private var manuscriptVault = true
    @AppStorage(SovereignFeatureFlags.capExProcurementKey) private var capExProcurement = true
    @AppStorage(SovereignFeatureFlags.craftLogisticsMeshKey) private var craftLogisticsMesh = false
    @AppStorage(SovereignFeatureFlags.craftMicroTransactionsKey) private var craftMicroTransactions = false
    @AppStorage(SovereignFeatureFlags.transportRunnerRoutingKey) private var transportRunnerRouting = false
    @AppStorage(SovereignFeatureFlags.venueGroupCheckoutKey) private var venueGroupCheckout = false
    @AppStorage(SovereignFeatureFlags.bioInsulationTrackerKey) private var bioInsulationTracker = false
    @AppStorage(SovereignFeatureFlags.shakeToFeedbackKey) private var shakeToFeedback = true

    var body: some View {
        List {
            Section {
                moduleRow(
                    title: "Manuscript & project vault",
                    subtitle: "Historical knowledge graph, New Horizons blueprints, book assembly.",
                    icon: "book.closed.fill",
                    isOn: $manuscriptVault
                )
                moduleRow(
                    title: "CapEx procurement",
                    subtitle: "Zone-tagged capital receipts and multi-line vendor POs.",
                    icon: "building.2",
                    isOn: $capExProcurement
                )
                moduleRow(
                    title: "Craft logistics mesh",
                    subtitle: "Visual menus, 12h pre-orders, shuttle Uber-style delivery.",
                    icon: "truck.box.fill",
                    isOn: $craftLogisticsMesh
                )
                moduleRow(
                    title: "Craft truck micro-pay",
                    subtitle: "Wallet tap for off-list items; production vs crew ledger.",
                    icon: "wave.3.right.circle.fill",
                    isOn: $craftMicroTransactions
                )
                moduleRow(
                    title: "Venue group checkout",
                    subtitle: "Batch guest cards, exit scanners, automated tip cascade.",
                    icon: "qrcode.viewfinder",
                    isOn: $venueGroupCheckout
                )
                moduleRow(
                    title: "Transport & run routing",
                    subtitle: "Digital runner tickets, CaSHet green light, multi-leg dispatch.",
                    icon: "car.2.fill",
                    isOn: $transportRunnerRouting
                )
                moduleRow(
                    title: "Shake to feedback",
                    subtitle: "Field testers shake device (or ⌘⇧F on Mac) to send wishes to in-house dashboard.",
                    icon: "hand.raised.fill",
                    isOn: $shakeToFeedback
                )
                moduleRow(
                    title: "Bio-insulation tracker",
                    subtitle: "RatioVita crew wellness, geofence clock, BLE zones.",
                    icon: "heart.text.square.fill",
                    isOn: $bioInsulationTracker
                )
            } header: {
                Text("Feature modules")
            } footer: {
                Text(
                    "Disabled modules hide advanced navigation until you are ready. Core receipts and payroll stay available."
                )
            }
            FocusAndMissionSettingsSection()
        }
        .navigationTitle("Control cockpit")
    }

    private func moduleRow(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
