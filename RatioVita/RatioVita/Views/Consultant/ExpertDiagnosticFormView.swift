import SwiftData
import SwiftUI

struct ExpertDiagnosticFormView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: ExpertConsultantProfile

    @State private var matchesReality = true
    @State private var needsTweak = false
    @State private var frictionNotes = ""
    @State private var graceWindowNotes = ""
    @State private var routeNotes = ""
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("Active mission") {
                Text(TestingMissionManager.shared.missionContextLine ?? "No mission pinned")
                    .font(.caption)
            }
            Section("Operational validation") {
                Toggle("Matches on-set union reality", isOn: $matchesReality)
                Toggle("Requires protocol tweak", isOn: $needsTweak)
            }
            departmentQuestions
            Section("Friction log") {
                TextField("Layout, latency, biometric issues…", text: $frictionNotes, axis: .vertical)
                    .lineLimit(3...6)
            }
            if let statusMessage {
                Section {
                    Text(statusMessage).font(.caption)
                }
            }
            Section {
                Button("Submit secure diagnostics") { submit() }
                    .buttonStyle(.borderedProminent)
            } footer: {
                Text("Bound under token \(profile.anonymousToken). Submitted via encrypted local vault queue.")
            }
        }
        .navigationTitle("Expert diagnostic")
        .onAppear { UserFrictionAnalytics.trackViewOpened("ExpertDiagnosticForm") }
    }

    @ViewBuilder
    private var departmentQuestions: some View {
        switch profile.department {
            case .transport:
                Section("Transport matrix") {
                    TextField("Rain day grace hours for your agreement", text: $graceWindowNotes)
                    TextField("401 / Gardiner buffer methodology", text: $routeNotes, axis: .vertical)
                }
            case .cameraDIT:
                Section("DIT chain of custody") {
                    TextField("Checksum → report workflow notes", text: $routeNotes, axis: .vertical)
                }
            case .accounting:
                Section("Accounting routing") {
                    TextField("PO signature chain variations", text: $routeNotes, axis: .vertical)
                    TextField("Petty cash bypass exceptions", text: $graceWindowNotes)
                }
            default:
                Section("Department notes") {
                    TextField("Workflow specifics", text: $routeNotes, axis: .vertical)
                }
        }
    }

    private func submit() {
        let responses: [String: String] = [
            "grace": graceWindowNotes,
            "workflow": routeNotes,
        ]
        let submission = ExpertDiagnosticSubmission(
            department: profile.department,
            anonymousToken: profile.anonymousToken,
            questionnaireKey: profile.department.rawValue,
            responses: responses,
            matchesUnionReality: matchesReality,
            requiresProtocolTweak: needsTweak,
            frictionNotes: frictionNotes,
            missionContext: TestingMissionManager.shared.missionContextLine ?? "",
            consultantID: profile.id
        )
        modelContext.insert(submission)

        let feedbackNotes = """
        [Expert diagnostic · \(profile.department.displayName)]
        Matches reality: \(matchesReality)
        Needs tweak: \(needsTweak)
        \(frictionNotes)
        """
        do {
            _ = try LiveFeedbackManager.shared.submit(
                context: modelContext,
                notes: feedbackNotes,
                department: profile.department.displayName,
                level: "Consultant",
                viewContext: "Expert diagnostic"
            )
            try modelContext.save()
            statusMessage = "Diagnostics submitted — thank you."
            frictionNotes = ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
