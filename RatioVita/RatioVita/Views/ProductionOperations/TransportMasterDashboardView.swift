import SwiftData
import SwiftUI

/// Captain / coordinator fleet monitor with diversion prompts.
struct TransportMasterDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransportVehicleRun.updatedAt, order: .reverse) private var runs: [TransportVehicleRun]

    @State private var diversionMessage: String?

    var body: some View {
        List {
            if let diversionMessage {
                Section("Captain alert") {
                    Text(diversionMessage)
                        .font(.subheadline)
                    Button("Accept diversion (simulated)") {
                        self.diversionMessage = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Section("Active fleet (\(runs.count))") {
                if runs.isEmpty {
                    Text("No vehicle runs — seed from Shuttle tracker or Operations hub.")
                        .foregroundStyle(.secondary)
                }
                ForEach(runs) { run in
                    fleetRow(run)
                }
            }
        }
        .navigationTitle("Fleet monitor")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Check 401 delays") { evaluateDelays() }
            }
        }
    }

    private func fleetRow(_ run: TransportVehicleRun) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(run.driverName)
                    .font(.headline)
                Spacer()
                Text("\(Int(TransportGeofenceMesh.taskCompletionPercent(for: run) * 100))%")
                    .font(.caption.monospacedDigit())
            }
            Text(run.statusLabel)
                .font(.caption)
            Text("\(run.vehicleDescription) · \(run.licensePlate)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ProgressView(value: TransportGeofenceMesh.taskCompletionPercent(for: run))
        }
        .padding(.vertical, 4)
    }

    private func evaluateDelays() {
        if runs.isEmpty {
            seed401Scenario()
        }
        guard runs.count >= 1 else { return }
        let delayed = runs.first { $0.trafficDelayMinutes >= 15 } ?? runs[0]
        let candidate = runs.count > 1 ? runs[1] : runs[0]
        diversionMessage = TransportGeofenceMesh.diversionRecommendation(
            delayedRun: delayed,
            candidateRun: candidate,
            interceptStopName: "Holt Renfrew — Bloor"
        )
    }

    private func seed401Scenario() {
        let stalled = TransportVehicleRun(
            driverName: "Driver X",
            vehicleDescription: "Cargo van",
            licensePlate: "ON-401X",
            statusLabel: "Stalled — 401 at Warden",
            etaMinutes: 45,
            trafficDelayMinutes: 22
        )
        let samantha = TransportVehicleRun(
            driverName: "Samantha",
            vehicleDescription: "Executive SUV",
            licensePlate: "ON-SAM1",
            statusLabel: "Davenport → Four Seasons pickup",
            etaMinutes: 8
        )
        modelContext.insert(stalled)
        modelContext.insert(samantha)
        try? modelContext.save()
    }
}
