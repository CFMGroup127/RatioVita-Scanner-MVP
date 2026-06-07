import SwiftData
import SwiftUI

struct InstantTimecardOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = ConsultantSessionManager.shared

    @State private var timeIn = Date()
    @State private var timeOut = Date()
    @State private var done = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("In", selection: $timeIn)
                DatePicker("Out", selection: $timeOut)
                if done {
                    Text("Logged — you can close this overlay.")
                        .foregroundStyle(.green)
                }
            }
            .navigationTitle("Time log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submit() }
                }
            }
        }
        .onAppear { UserFrictionAnalytics.trackViewOpened("InstantTimecardOverlay") }
    }

    private func submit() {
        let hours = max(0, timeOut.timeIntervalSince(timeIn) / 3600)
        if let id = session.activeProfileID {
            let descriptor = FetchDescriptor<ExpertConsultantProfile>()
            if let profiles = try? modelContext.fetch(descriptor),
               let profile = profiles.first(where: { $0.id == id })
            {
                _ = try? ConsultantTimecardEngine.submit(
                    context: modelContext,
                    profile: profile,
                    hours: hours,
                    notes: "Instant overlay \(timeIn.formatted(date: .omitted, time: .shortened))–\(timeOut.formatted(date: .omitted, time: .shortened))"
                )
            }
        }
        done = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
    }
}
