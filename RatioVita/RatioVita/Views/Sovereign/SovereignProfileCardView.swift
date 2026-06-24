import SwiftData
import SwiftUI

/// Sovereign onboarding card — dynamic QR, short serial, and privacy tier controls.
struct SovereignProfileCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SovereignProfile.updatedAt, order: .reverse) private var profiles: [SovereignProfile]
    @Query(sort: \ProductionProject.title) private var productions: [ProductionProject]

    @State private var shareTier: SovereignPrivacyTier = .logisticalOnly
    @State private var selectedProductionID: UUID?
    @State private var qrPayload: String = ""
    @State private var shortSerial: String = ""
    @State private var tokenError: String?
    @State private var guildNumber = ""
    @State private var department = ""
    @State private var unionStatus = ""
    @State private var loanOutEntity = ""

    private var profile: SovereignProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if let profile {
                    identityHeader(profile)
                    professionalFields(profile)
                    privacySection
                    productionBindingSection
                    tokenSection
                } else {
                    ContentUnavailableView(
                        "No sovereign profile",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Complete Sovereign setup in Settings to generate your SPID and onboarding QR.")
                    )
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .navigationTitle("Sovereign profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            syncFieldsFromProfile()
            refreshToken()
        }
        .onChange(of: shareTier) { _, _ in refreshToken() }
        .onChange(of: selectedProductionID) { _, _ in refreshToken() }
    }

    @ViewBuilder
    private func identityHeader(_ profile: SovereignProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sovereign Profile ID", systemImage: "person.text.rectangle")
                .font(.headline)
            Text(profile.userSPID)
                .font(.system(.title3, design: .monospaced))
                .textSelection(.enabled)
            Text("Device-independent — syncs via iCloud Keychain when enabled on your Apple ID.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Routing: \(profile.obfuscatedRoutingEmail)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ratioVitaAdaptiveSurface))
    }

    @ViewBuilder
    private func professionalFields(_ profile: SovereignProfile) -> some View {
        GroupBox("Professional details") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("IATSE / guild number", text: $guildNumber)
                TextField("Department", text: $department)
                TextField("Union status", text: $unionStatus)
                TextField("Loan-out / corp entity", text: $loanOutEntity)
                Button("Save profile") {
                    saveProfessionalFields(profile)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var privacySection: some View {
        GroupBox("Privacy shield tier") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Share tier", selection: $shareTier) {
                    ForEach(SovereignPrivacyTier.allCases) { tier in
                        Text(tier.title).tag(tier)
                    }
                }
                Text(shareTier.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var productionBindingSection: some View {
        GroupBox("Production handshake (optional)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Bind this token to tomorrow's call — e.g. Flashpoint wet-weather PUID.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Production", selection: $selectedProductionID) {
                    Text("None").tag(UUID?.none)
                    ForEach(productions) { project in
                        Text(project.title).tag(Optional(project.id))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tokenSection: some View {
        GroupBox("Onboarding token") {
            VStack(spacing: 16) {
                if let error = tokenError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                SovereignQRCodeRenderer.qrView(for: qrPayload)
                    .frame(maxWidth: 220, maxHeight: 220)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Short serial: \(shortSerial)")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Text("Show this QR to production accounting or scan from VitaLogic — no manual name/email typing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Refresh token") { refreshToken() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func syncFieldsFromProfile() {
        guard let profile else { return }
        shareTier = profile.defaultShareTier
        guildNumber = profile.guildNumber
        department = profile.department
        unionStatus = profile.unionStatus
        loanOutEntity = profile.loanOutEntity
    }

    private func saveProfessionalFields(_ profile: SovereignProfile) {
        profile.guildNumber = guildNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.department = department.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.unionStatus = unionStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.loanOutEntity = loanOutEntity.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.defaultShareTier = shareTier
        profile.updatedAt = .now
        try? modelContext.save()
        refreshToken()
    }

    private func refreshToken() {
        guard let profile else { return }
        tokenError = nil
        do {
            let signingKey = try SovereignProfileSeedStore.loadOrCreateSigningKey()
            let puid: String? = {
                guard let id = selectedProductionID,
                      let project = productions.first(where: { $0.id == id }) else { return nil }
                if let existing = project.sovereignPUID, !existing.isEmpty { return existing }
                let generated = SovereignIdentifierService.productionPUID(
                    showTitle: project.title,
                    workDate: Date()
                )
                project.sovereignPUID = generated
                try? modelContext.save()
                return generated
            }()
            let payload = try OnboardingTokenGenerator.generate(
                profile: profile,
                privateKey: signingKey,
                productionPUID: puid,
                shareTier: shareTier
            )
            qrPayload = try OnboardingTokenGenerator.encodeForQR(payload)
            shortSerial = OnboardingTokenGenerator.shortSerial(for: payload)
        } catch {
            tokenError = error.localizedDescription
            qrPayload = ""
            shortSerial = ""
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SovereignProfileCardView()
    }
    .modelContainer(SampleData.previewContainer)
}
#endif
