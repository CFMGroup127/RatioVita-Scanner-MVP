import SwiftData
import SwiftUI

struct FirstLooksCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var session = ConsultantSessionManager.shared

    @State private var castID = "CAST-09"
    @State private var sessionTag: FirstLooksAssetRouter.CaptureSessionTag = .firstLooksCH1
    @State private var hatNote = "Hat travelling with supervisor"
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("Chantal · First look checkpoint") {
                TextField("Cast display ID", text: $castID)
                Picker("Session tag", selection: $sessionTag) {
                    ForEach(FirstLooksAssetRouter.CaptureSessionTag.allCases, id: \.self) { tag in
                        Text(tag.displayName).tag(tag)
                    }
                }
                TextField("Set supervisor note (optional)", text: $hatNote)
                Button("Capture first look (mock photo)") { capture() }
            }
            Section("Routing") {
                Text("Feeds Designer / ACD monitors without mutating E104 continuity codes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                NavigationLink("Creative monitor feed") {
                    CreativeMonitorFeedView()
                }
            }
            if let statusMessage {
                Section { Text(statusMessage).font(.caption) }
            }
        }
        .navigationTitle("RV · First Looks")
        .onAppear { UserFrictionAnalytics.trackViewOpened("FirstLooksCapture") }
    }

    private func capture() {
        do {
            let profileToken = session.activeProfileID?.uuidString ?? "CHANTAL-TRUCK"
            _ = try FirstLooksAssetRouter.captureFirstLook(
                context: modelContext,
                castDisplayID: castID,
                sessionTag: sessionTag,
                truckSupervisorToken: profileToken,
                productionTitle: "Sanctuary",
                hatManifestNote: hatNote
            )
            statusMessage = "First look routed to creative feed + Comms."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
