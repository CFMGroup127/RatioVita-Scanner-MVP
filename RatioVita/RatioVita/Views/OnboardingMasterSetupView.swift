import SwiftData
import SwiftUI

/// First-run sovereign identity wizard — save partial progress anytime.
struct OnboardingMasterSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var existingProfiles: [MasterUserIdentity]

    @State private var step = 0
    @State private var primaryLegalName = ""
    @State private var addressCard = ""
    @State private var phoneLine = ""
    @State private var aliasLine = ""
    @State private var familyLine = ""
    @State private var saveError: String?

    var onFinished: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                    case 0:
                        Section("Legal identity") {
                            TextField("Primary legal name", text: $primaryLegalName)
                            TextField("Mailing address", text: $addressCard, axis: .vertical)
                                .lineLimit(2...4)
                            TextField("Phone", text: $phoneLine)
                                .textContentType(.telephoneNumber)
                        }
                    case 1:
                        Section("Name variations") {
                            Text(
                                "Add every spelling production payroll might use (comma-separated). RatioVita routes matching receipts and timesheets to you."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            TextField("Aliases", text: $aliasLine, axis: .vertical)
                                .lineLimit(2...6)
                        }
                    case 2:
                        Section("Family isolation shield") {
                            Text(
                                "Checks or payments in these names stay in a family vault — not your corporate gross earnings."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            TextField("Spouse / dependents (comma-separated)", text: $familyLine, axis: .vertical)
                                .lineLimit(2...4)
                        }
                    default:
                        Section("Corporations") {
                            Text(
                                "Link corporations anytime from Settings → My corporations. You can finish onboarding now and add entities later."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            NavigationLink("Open corporation registry") {
                                CorporateRegistryView(ownedOnly: true)
                            }
                        }
                }
            }
            .navigationTitle("Sovereign setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step < 3 {
                        Button("Next") { step += 1 }
                            .disabled(step == 0 && primaryLegalName.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Button("Finish") { finish() }
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Save & continue later") { saveDraft() }
                }
            }
            .alert("Could not save", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .onAppear(perform: loadExistingIfAny)
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }

    private func loadExistingIfAny() {
        guard let profile = existingProfiles.first else { return }
        primaryLegalName = profile.primaryLegalName
        addressCard = profile.addressCard
        phoneLine = profile.phoneNumbers.joined(separator: ", ")
        aliasLine = profile.recognizedNameAliases.joined(separator: ", ")
        familyLine = profile.isolatedFamilyNames.joined(separator: ", ")
    }

    private func splitCSV(_ raw: String) -> [String] {
        raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func persistProfile(markComplete: Bool) throws {
        let name = primaryLegalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SaveError.missingName }

        let profile: MasterUserIdentity
        if let existing = existingProfiles.first {
            profile = existing
            profile.primaryLegalName = name
            profile.addressCard = addressCard
            profile.phoneNumbers = splitCSV(phoneLine)
            profile.recognizedNameAliases = splitCSV(aliasLine)
            profile.isolatedFamilyNames = splitCSV(familyLine)
            profile.updatedAt = .now
        } else {
            profile = MasterUserIdentity(
                primaryLegalName: name,
                addressCard: addressCard,
                phoneNumbers: splitCSV(phoneLine),
                recognizedNameAliases: splitCSV(aliasLine),
                isolatedFamilyNames: splitCSV(familyLine)
            )
            modelContext.insert(profile)
        }

        if markComplete {
            SovereignFeatureFlags.onboardingCompleted = true
            UserDefaults.standard.set(name, forKey: "com.ratiovita.internalOwnerLegalName")
        }
        try ModelContextMainActorSave.saveThrows(modelContext)
    }

    private func saveDraft() {
        do {
            try persistProfile(markComplete: false)
            UserMessageCenter.shared.present(
                title: "Profile saved",
                message: "Return anytime via Settings → Sovereign identity to add aliases or family names."
            )
            dismiss()
            onFinished?()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func finish() {
        do {
            try persistProfile(markComplete: true)
            dismiss()
            onFinished?()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private enum SaveError: LocalizedError {
        case missingName
        var errorDescription: String? {
            switch self {
                case .missingName: "Primary legal name is required."
            }
        }
    }
}
