import SwiftData
import SwiftUI

struct VitaVoiceConsoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpatialCrewPosition.lastSeenTimestamp, order: .reverse) private var crew: [SpatialCrewPosition]
    @ObservedObject private var voice = VitaVoiceAudioManager.shared
    @ObservedObject private var vault = MasterVaultProfileManager.shared

    @State private var transcript =
        "Vita, tell Erin one of the cases fell off my dolly and is on the trail. Please grab it."
    @State private var senderToken = "ERM-CREW"
    @State private var routeResult: String?

    var body: some View {
        List {
            Section("Vita Voice mesh (Sprint FFFF)") {
                VoiceCommsOverlayView()
                Button("Role-insulated whisper test (PM)") {
                    vault.selectPersona(
                        vault.personas.first { $0.positionTitle.contains("Production manager") }
                            ?? vault.personas[0]
                    )
                    voice.broadcast(
                        message: "All department heads — stage B lock at 18:00.",
                        priority: .administrativeWhisper
                    )
                    routeResult = voice.sessionStatus
                }
                Button("Persona shift cutoff (Mobile Craft → 176 Yonge)") {
                    vault.selectMacroDomain(.commercialCulinary)
                    voice.broadcast(message: "Kitchen line check", priority: .tacticalDepartment)
                    vault.selectMacroDomain(.realEstateFacility)
                    routeResult = voice.sessionStatus
                }
                Button("Spatial honeywagon bridge") {
                    HoneywagonTelemetryDeck.shared.simulateCrisis()
                    routeResult = voice.sessionStatus
                }
            }
            Section("Wake-word simulator") {
                TextField("Phrase", text: $transcript, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Sender token", text: $senderToken)
                Button("Route Vita memo") { route() }
                Button("Seed crew directory") { seedCrew() }
            }
            if let routeResult {
                Section("Result") {
                    Text(routeResult).font(.caption)
                }
            }
            Section("Predictive dispatch (Erminia sim)") {
                Button("Simulate incline stress → auto utility 4x4") {
                    simulatePredictive()
                }
            }
            Section("Crew directory") {
                ForEach(crew) { member in
                    Text("\(member.displayName) · \(member.verifiedZone.displayLabel)")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Vita voice")
    }

    private func seedCrew() {
        if crew.contains(where: { $0.displayName == "Erin" }) { return }
        modelContext.insert(
            SpatialCrewPosition(
                userToken: "ERIN-PA",
                displayName: "Erin",
                unit: .secondUnitMuskoka,
                department: "TRANSPORT",
                zone: .techLandSet
            )
        )
        try? modelContext.save()
    }

    private func simulatePredictive() {
        let telemetry = PredictiveDispatchEngine.StressTelemetry(
            workerToken: "ERM-CREW",
            velocityMetersPerMinute: 4,
            inclineGrade: 0.12,
            loadAnomalyScore: 0.85
        )
        do {
            if let assignment = try PredictiveDispatchEngine.assignInterceptVehicle(
                context: modelContext,
                telemetry: telemetry,
                unit: .secondUnitMuskoka
            ) {
                routeResult = "Auto-dispatched \(assignment.vehicleLabel) · \(assignment.routeHint)"
            } else {
                routeResult = "Stress thresholds not met."
            }
        } catch {
            routeResult = error.localizedDescription
        }
    }

    private func route() {
        seedCrew()
        do {
            if let routed = try VitaVoiceInferenceService.routeMemo(
                context: modelContext,
                transcript: transcript,
                senderToken: senderToken,
                crewDirectory: crew
            ) {
                routeResult = "Routed to \(routed.targetDisplayName): \(routed.transcript)"
            } else {
                routeResult = "Could not parse wake phrase. Start with “Vita, tell …”"
            }
        } catch {
            routeResult = error.localizedDescription
        }
    }
}
