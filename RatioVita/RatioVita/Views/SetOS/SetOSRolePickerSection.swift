import SwiftData
import SwiftUI

/// Locked assignment from onboarding — no global hat pollution (Sprint JJJJ).
struct SetOSRolePickerSection: View {
    @ObservedObject private var session = ConsultantSessionManager.shared
    @ObservedObject private var onboarding = SetOSOnboardingCoordinator.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TemporalRoleGrant.expirationTimestamp, order: .reverse) private var grants: [TemporalRoleGrant]

    var body: some View {
        Section("SetOS · Active assignment") {
            if onboarding.isComplete {
                LabeledContent("Department", value: onboarding.activeDepartmentName)
                LabeledContent("Position", value: onboarding.activePositionTitle)
                LabeledContent(
                    "Production",
                    value: onboarding.productionTitle.isEmpty
                        ? (onboarding.sandboxMode ? "Sandbox" : onboarding.showCode)
                        : onboarding.productionTitle
                )
                LabeledContent(
                    "Structural rank",
                    value: onboarding.activePosition?.rankTier.displayName
                        ?? DepartmentScopeController.structuralRank(
                            hat: session.activeOperationalHat,
                            department: onboarding.activeIndustryScope,
                            consultantTier: nil
                        ).displayName
                )

                if onboarding.developerRoleOverrideEnabled {
                    departmentFilteredHatPicker
                } else {
                    Text("Role locked from onboarding. Settings → Developer to enable override for testing.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Complete SetOS onboarding to lock department and position.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Production unit", selection: Binding(
                get: { session.activeUnitNode },
                set: { session.setActiveUnitNode($0) }
            )) {
                ForEach(ProductionUnitNode.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }

            if let active = grants.first(where: {
                $0.isActive && $0.userToken == (session.activeProfileID?.uuidString ?? "FIELD")
            }) {
                Label(
                    "Temporal grant: \(active.temporaryRole.displayName)",
                    systemImage: "clock.badge.checkmark"
                )
                Text(TemporalAuthorizationService.formattedRemaining(active))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var departmentFilteredHatPicker: some View {
        let hats = hatsForActiveDepartment
        Picker("Operational hat (dev override)", selection: Binding(
            get: { session.activeOperationalHat },
            set: { session.setOperationalHat($0) }
        )) {
            ForEach(hats, id: \.self) { hat in
                Text(hat.displayName).tag(hat)
            }
        }
    }

    private var hatsForActiveDepartment: [OperationalHatRole] {
        let positions = DepartmentHierarchyRegistry.positions(
            forDepartmentNamed: onboarding.selectedDepartmentName
        )
        let hats = positions.map(\.hatRole)
        return Array(Set(hats)).sorted { $0.displayName < $1.displayName }
    }
}
