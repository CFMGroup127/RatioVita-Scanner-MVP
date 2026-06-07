import SwiftData
import SwiftUI

/// Crew-facing shuttle tracker — vehicle fingerprint + ETA (Broadview rescue).
struct LiveShuttleMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransportVehicleRun.updatedAt, order: .reverse) private var runs: [TransportVehicleRun]

    @State private var selectedRunID: UUID?
    @State private var simulateBGHop = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if let run = selectedRun {
                    shuttleCard(run)
                    mapPlaceholder(run)
                    Button("Simulate BG Holding hop") {
                        simulateHop(on: run)
                    }
                    .buttonStyle(.bordered)
                } else {
                    ContentUnavailableView(
                        "No active shuttle",
                        systemImage: "bus.fill",
                        description: Text("Transport captain assigns a run, or tap Simulate below.")
                    )
                }
                Button("Simulate Broadview shuttle approach") {
                    seedDemoRun()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth, alignment: .leading)
        }
        .navigationTitle("Shuttle tracker")
        .onAppear {
            selectedRunID = runs.first?.id
        }
    }

    private var selectedRun: TransportVehicleRun? {
        guard let id = selectedRunID else { return runs.first }
        return runs.first { $0.id == id } ?? runs.first
    }

    private func shuttleCard(_ run: TransportVehicleRun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(run.statusLabel)
                .font(.headline)
            LabeledContent("Vehicle", value: run.vehicleDescription)
            LabeledContent("Plate", value: run.licensePlate.isEmpty ? "—" : run.licensePlate)
            LabeledContent("Driver", value: run.driverName)
            LabeledContent("ETA", value: "\(run.etaMinutes) min")
            LabeledContent("Passengers", value: "\(run.passengersCheckedIn)/\(run.passengersBooked) at corner")
            ProgressView(value: TransportGeofenceMesh.taskCompletionPercent(for: run))
        }
        .padding()
        .background(Color.ratioVitaAdaptiveSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }

    private func mapPlaceholder(_ run: TransportVehicleRun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live vector map")
                .font(.caption.weight(.semibold))
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.ratioVitaAdaptiveSurface)
                    .frame(height: 200)
                VStack(spacing: 8) {
                    Image(systemName: "location.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("You are here")
                        .font(.caption)
                    if let next = run.waypoints.first(where: { !$0.isCompleted }) {
                        Text("Shuttle → \(next.name)")
                            .font(.caption.bold())
                    }
                }
            }
            .frame(maxWidth: SafeLayoutBounds.maxTimecardPreviewWidth)
        }
    }

    private func seedDemoRun() {
        let run = TransportVehicleRun(
            driverName: "Jafar Bastan Hagh",
            vehicleDescription: "Ford Transit (Black)",
            licensePlate: "CA-IA873",
            statusLabel: "Travelling from Set toward Base Camp",
            progressPercent: 0.35,
            etaMinutes: 4,
            passengersBooked: 8,
            passengersCheckedIn: 5,
            waypoints: [
                LocationWaypointPayload(name: "Set", latitude: 43.655, longitude: -79.355, sequenceOrder: 0),
                LocationWaypointPayload(name: "BG Holding", latitude: 43.660, longitude: -79.350, sequenceOrder: 1),
                LocationWaypointPayload(name: "Base Camp", latitude: 43.665, longitude: -79.348, sequenceOrder: 2),
                LocationWaypointPayload(name: "Crew Parking", latitude: 43.670, longitude: -79.345, sequenceOrder: 3),
            ]
        )
        modelContext.insert(run)
        try? modelContext.save()
        selectedRunID = run.id
    }

    private func simulateHop(on run: TransportVehicleRun) {
        _ = TransportGeofenceMesh.applyPassengerHop(
            run: run,
            newStopName: "BG Holding",
            latitude: 43.660,
            longitude: -79.350
        )
        try? modelContext.save()
    }
}
