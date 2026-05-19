import SwiftUI
import UniformTypeIdentifiers

/// EP sheet compliance toggles, naming mask, and crew approval initials (detail column).
struct PayrollComplianceEditorSection: View {
    @State private var profile: PayrollComplianceProfile = PayrollComplianceProfileStore.profile
    @State private var userInitials: String = PayrollComplianceProfileStore.userInitials
    @State private var useImageInitials: Bool = CrewInitialsStampHelper.useImageInitials
    @State private var showInitialsImporter = false

    var body: some View {
        Group {
            complianceContent
        }
        .onAppear {
            profile = PayrollComplianceProfileStore.profile
            if userInitials.isEmpty {
                userInitials = PayrollComplianceProfileStore.suggestedInitials(
                    from: InternalIdentityRegistry.payrollDisplayName
                )
            }
        }
        .onChange(of: profile) { _, newValue in
            PayrollComplianceProfileStore.profile = newValue
        }
        .onChange(of: userInitials) { _, newValue in
            PayrollComplianceProfileStore.userInitials = newValue
        }
        .onChange(of: useImageInitials) { _, newValue in
            CrewInitialsStampHelper.useImageInitials = newValue
        }
        #if os(macOS)
        .fileImporter(
            isPresented: $showInitialsImporter,
            allowedContentTypes: [.png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first,
               let data = try? Data(contentsOf: url)
            {
                CrewInitialsStampHelper.savedImagePNGData = data
                useImageInitials = true
            }
        }
        #endif
    }

    @ViewBuilder
    private var complianceContent: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            residencyBlock
            guildBlock
            crewApprovalBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #else
        Section("EP compliance") {
            residencyToggles
            guildToggles
        }
        Section {
            crewApprovalFields
        } header: {
            Text("Crew approval (EP)")
        } footer: {
            Text(
                "Per-production union, residency, and loan-out overrides live under Productions → edit show → Payroll PDF."
            )
            .font(.footnote)
        }
        #endif
    }

    #if os(macOS)
    private var residencyBlock: some View {
        LeftAlignedFormSection("Residency (one only)") {
            residencyToggles
        }
    }

    private var guildBlock: some View {
        LeftAlignedFormSection("Guild status (one only)") {
            guildToggles
        }
    }

    private var crewApprovalBlock: some View {
        LeftAlignedFormSection(
            "Crew approval (EP CREW box)",
            footer: "Typed initials or a saved PNG signature. Enable auto-stamp to apply on every export."
        ) {
            crewApprovalFields
        }
    }
    #endif

    private var residencyToggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Resident", isOn: residencyBinding(.resident))
            Toggle("Non resident", isOn: residencyBinding(.nonResident))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var guildToggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Member", isOn: guildBinding(.member))
            Toggle("Permit", isOn: guildBinding(.permit))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var crewApprovalFields: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle("Auto-stamp crew initials on every export", isOn: $profile.autoStampCrewInitials)
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                Text("Typed initials")
                    .frame(width: 140, alignment: .leading)
                TextField("e.g. CM", text: $userInitials)
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80, alignment: .leading)
                #endif
            }
            approvalRow("Crew box value", keyPath: \.approvalInitialsCrew)
            Button("Copy typed initials → Crew box") {
                profile.approvalInitialsCrew = userInitials
            }
            .buttonStyle(.bordered)
            Toggle("Use saved script / image in Crew box", isOn: $useImageInitials)
            #if os(macOS)
            Button("Import initials image (PNG)…") {
                showInitialsImporter = true
            }
            .buttonStyle(.bordered)
            #endif
            if CrewInitialsStampHelper.savedImagePNGData != nil {
                Text("Saved initials image on file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func approvalRow(
        _ label: String,
        keyPath: WritableKeyPath<PayrollComplianceProfile, String>
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
            Text(label)
                .frame(width: 140, alignment: .leading)
            TextField("Initials", text: binding(for: keyPath))
            #if os(macOS)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80, alignment: .leading)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func residencyBinding(_ tier: PayrollComplianceProfile.ResidencyTier) -> Binding<Bool> {
        Binding(
            get: { profile.residencyStatus == tier },
            set: { on in
                profile.residencyStatus = on ? tier : (profile.residencyStatus == tier ? nil : profile.residencyStatus)
            }
        )
    }

    private func guildBinding(_ tier: PayrollComplianceProfile.GuildTier) -> Binding<Bool> {
        Binding(
            get: { profile.guildStatus == tier },
            set: { on in
                profile.guildStatus = on ? tier : (profile.guildStatus == tier ? nil : profile.guildStatus)
            }
        )
    }

    private func binding(for keyPath: WritableKeyPath<PayrollComplianceProfile, String>) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { profile[keyPath: keyPath] = $0.uppercased() }
        )
    }
}
