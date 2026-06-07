import SwiftData
import SwiftUI

struct CrewFeedbackOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var manager = LiveFeedbackManager.shared

    @State private var notes = ""
    @State private var department = ""
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Context (auto-captured)") {
                    LabeledContent("Screen", value: manager.currentViewContext)
                    LabeledContent("Level", value: manager.sovereigntyLevel)
                    if let mission = TestingMissionManager.shared.missionContextLine {
                        LabeledContent("Test mission", value: mission)
                    }
                }
                Section("Your note") {
                    TextField("Department (e.g. Transport, Costumes)", text: $department)
                    TextField(
                        "One sentence — what should we fix or add?",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                }
                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Quick feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        manager.showOverlay = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if department.isEmpty {
                    department = manager.originatingDepartment
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private func send() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try manager.submit(
                context: modelContext,
                notes: trimmed,
                department: department.isEmpty ? "General" : department,
                level: manager.sovereigntyLevel,
                viewContext: manager.currentViewContext
            )
            statusMessage = "Sent — in-house team will see this in the feedback inbox."
            notes = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                manager.showOverlay = false
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
