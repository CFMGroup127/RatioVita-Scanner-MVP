import SwiftData
import SwiftUI

struct ConsultantTimecardSubmitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let profile: ExpertConsultantProfile

    @State private var hours: Double = 4
    @State private var notes = ""
    @State private var submitted = false

    var body: some View {
        Form {
            Section("Consulting honorarium log") {
                Text("Token: \(profile.anonymousToken)")
                    .font(.caption.monospaced())
                Stepper(
                    "Hours: \(hours, format: .number.precision(.fractionLength(1)))",
                    value: $hours,
                    in: 0.5...16,
                    step: 0.5
                )
                TextField("What did you test today?", text: $notes, axis: .vertical)
            }
            if let locked = ImmutableProfileLock.read(profile: profile) {
                Section("Estimated gross (sandbox)") {
                    let gross = AnonymizedPayrollEngine.estimatedGross(
                        hours: hours,
                        hourlyRate: locked.hourlyRate,
                        kitAllowance: locked.kitAllowance
                    )
                    Text(gross, format: .currency(code: "CAD"))
                    Text(AnonymizedPayrollEngine.estimatedGrossDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Sign & submit (biometric sim)") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(submitted)
            } footer: {
                Text("After submission your card routes to the accounting vault only — it disappears from your view.")
            }
        }
        .navigationTitle("Consult timecard")
    }

    private func submit() {
        do {
            _ = try ConsultantTimecardEngine.submit(
                context: modelContext,
                profile: profile,
                hours: hours,
                notes: notes
            )
            submitted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        } catch {
            notes = error.localizedDescription
        }
    }
}
