import SwiftUI

/// Master Vault radio-button persona morph (Sprint DDDD).
struct SetOSPersonaSwitcherSection: View {
    @ObservedObject private var vault = MasterVaultProfileManager.shared
    @ObservedObject private var session = ConsultantSessionManager.shared

    var body: some View {
        Section {
            Picker("Macro tenant", selection: Binding(
                get: { vault.activeMacroDomain },
                set: { vault.selectMacroDomain($0) }
            )) {
                ForEach(MacroTenantDomain.allCases) { domain in
                    Text(domain.displayName).tag(domain)
                }
            }

            ForEach(vault.personas) { persona in
                Button {
                    vault.selectPersona(persona)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(persona.positionTitle)
                                .font(.subheadline.weight(.semibold))
                            Text("\(persona.assignedGuild.displayName) · \(persona.rankTier.displayName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vault.activePersonaID == persona.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            LabeledContent("Active hat", value: session.activeOperationalHat.displayName)
        } header: {
            Text("Master Vault · persona")
        } footer: {
            Text(
                "One app shell — tap a persona to morph widgets, data scope, and department consoles. Vault controls which modules appear on your home screen."
            )
        }
    }
}
