import SwiftUI

/// Widget / dock tile picker scoped to active department only (Sprint JJJJ).
struct IsolatedWidgetPickerView: View {
    @ObservedObject var coordinator: SetOSOnboardingCoordinator

    private var allowedProfiles: [LauncherShortcutProfile] {
        guard let scope = coordinator.activeIndustryScope,
              let position = coordinator.activePosition else { return [] }
        return DepartmentScopeController.visibleShortcutProfiles(
            hat: position.hatRole,
            department: scope,
            consultantTier: tier(for: position.rankTier),
            temporalGrant: nil,
            macroDomain: .technicalCrews
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available for \(coordinator.selectedDepartmentName)")
                .font(.caption.weight(.semibold))
            Text(coordinator.selectedPositionTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(
                "Only tools for your department appear here. Camera, transport, costume, and unrelated guild modules are hidden."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            ForEach(allowedProfiles) { profile in
                Toggle(isOn: binding(for: profile.moduleIntent)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.desktopLabel)
                            .font(.subheadline.weight(.semibold))
                        Text(profile.moduleIntent.rawValue)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if allowedProfiles.isEmpty {
                Text("No launcher tiles for this assignment yet.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Section {
                ForEach(WidgetQuadrant.allCases) { quadrant in
                    Toggle(isOn: quadrantBinding(quadrant)) {
                        Text(quadrant.displayName)
                    }
                }
            } header: {
                Text("Home screen quadrants")
            }
        }
    }

    private func binding(for intent: LauncherModuleIntent) -> Binding<Bool> {
        Binding(
            get: { coordinator.pinnedLauncherIntents.contains(intent) },
            set: { enabled in
                if enabled {
                    coordinator.pinnedLauncherIntents.insert(intent)
                } else {
                    coordinator.pinnedLauncherIntents.remove(intent)
                }
            }
        )
    }

    private func quadrantBinding(_ quadrant: WidgetQuadrant) -> Binding<Bool> {
        Binding(
            get: { coordinator.enabledQuadrants.contains(quadrant) },
            set: { enabled in
                if enabled {
                    coordinator.enabledQuadrants.insert(quadrant)
                } else {
                    coordinator.enabledQuadrants.remove(quadrant)
                }
            }
        )
    }

    private func tier(for rank: StructuralRankTier) -> ConsultantTier {
        switch rank {
            case .fieldCrew: .subordinate
            case .departmentHead: .departmentHead
            case .administrative: .accountingVault
        }
    }
}
