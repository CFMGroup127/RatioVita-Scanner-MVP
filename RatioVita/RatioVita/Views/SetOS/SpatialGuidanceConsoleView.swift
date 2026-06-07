import SwiftData
import SwiftUI

/// Chantal → Wayne spatial correction loop (Sprint UUU).
struct SpatialGuidanceConsoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpatialBeaconAsset.spatialGridX) private var beacons: [SpatialBeaconAsset]
    @Query(sort: \SpatialCrewPosition.lastSeenTimestamp, order: .reverse) private var crew: [SpatialCrewPosition]

    @State private var voiceTranscript = "Vita, guide me to Wayne's position in the green room."
    @State private var pathStep = 0
    @State private var correctionText: String?
    @State private var handshakeText: String?

    private var wayne: SpatialCrewPosition? {
        crew.first { $0.displayName.lowercased().contains("wayne") }
    }

    var body: some View {
        List {
            Section("Voice intent") {
                TextField("Transcript", text: $voiceTranscript, axis: .vertical)
                    .lineLimit(2...5)
                Button("Resolve spatial intent") { resolve() }
                Button("Seed Wayne @ Video Village") { seedWayne() }
                Button("Seed beacon path") { seedBeacons() }
            }
            if let correctionText {
                Section("Vita correction") {
                    Text(correctionText)
                    Button("Speak correction") {
                        AudioGuidanceFeedbackEngine.speak(correctionText)
                    }
                }
            }
            if let handshakeText {
                Section("Arrival handshake") {
                    Text(handshakeText).font(.caption)
                }
            }
            Section("Hands-free path cues") {
                let anchors = SpatialMeshBeaconController.anchors(from: beacons)
                let target = wayne?.verifiedZone ?? .videoVillage
                ForEach(
                    Array(PassiveMeshPathfinder.fullHandsFreeScript(anchors: anchors, targetZone: target).enumerated()),
                    id: \.offset
                ) { index, line in
                    HStack {
                        Text(line).font(.caption)
                        Spacer()
                        if index == pathStep {
                            Image(systemName: "ear.fill").foregroundStyle(.purple)
                        }
                    }
                }
                HStack {
                    Button("Previous cue") { pathStep = max(0, pathStep - 1) }
                    Button("Next cue") { advanceCue(anchors: anchors, target: target) }
                }
            }
        }
        .navigationTitle("Spatial guidance")
    }

    private func seedWayne() {
        if wayne != nil { return }
        modelContext.insert(
            SpatialCrewPosition(
                userToken: "WAYNE-SET",
                displayName: "Wayne",
                unit: .secondUnitMuskoka,
                department: "COSTUME",
                zone: .videoVillage
            )
        )
        _ = try? modelContext.save()
    }

    private func seedBeacons() {
        try? SpatialMeshBeaconController.seedDemoPath(
            context: modelContext,
            toward: .videoVillage
        )
    }

    private func resolve() {
        seedWayne()
        seedBeacons()
        guard let wayne else {
            correctionText = "Wayne profile not seeded."
            return
        }
        let stated = SpatialIntentResolver.parseStatedZone(from: voiceTranscript)
        let payload = SpatialIntentResolver.resolveGuidance(target: wayne, statedZone: stated)
        correctionText = payload.spokenCorrection
        handshakeText = AudioGuidanceFeedbackEngine.arrivalHandshakeMessage(supervisorName: "Chantal")
        pathStep = 0

        _ = try? HierarchyCommsEngine.ingest(
            context: modelContext,
            title: "En route",
            body: handshakeText ?? "",
            senderRole: "CHANTAL-TRUCK",
            priority: .standard
        )
        _ = try? modelContext.save()
    }

    private func advanceCue(
        anchors: [SpatialMeshBeaconController.RoutingAnchor],
        target: SpatialZoneID
    ) {
        let script = PassiveMeshPathfinder.fullHandsFreeScript(anchors: anchors, targetZone: target)
        guard pathStep < script.count - 1 else { return }
        pathStep += 1
        if let cue = PassiveMeshPathfinder.progressiveCueQueue(
            anchors: anchors,
            targetZone: target,
            stepIndex: pathStep
        ) {
            AudioGuidanceFeedbackEngine.speak(cue)
        }
    }
}
