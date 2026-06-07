import SwiftUI

/// Visual payroll assurance — crew sees the sheet move up the chain.
struct TimecardApprovalMilestoneTrack: View {
    let day: CrewTimecardDay
    var viewerRole: String = HierarchyCommsEngine.userOperationalRole

    private var steps: [(String, Bool)] {
        [
            ("Submitted", day.crewSignedAt != nil),
            ("Key", day.deptHeadSignedAt != nil),
            ("PM", day.pmSignedAt != nil),
            ("Acct", day.accountingSignedAt != nil),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payroll assurance track")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    milestoneChip(step.0, step.1)
                    if idx < steps.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                }
            }
            if shouldShowCrewSignPrompt {
                Text("Your crew sign-off box is ready — tap to stamp with biometrics.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var shouldShowCrewSignPrompt: Bool {
        day.crewSignedAt == nil
            && (viewerRole.lowercased().contains("crew") || viewerRole.lowercased().contains("employee"))
    }

    private func milestoneChip(_ title: String, _ done: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
        }
        .frame(width: FixedColumnWidths.approvalBoxWidth * 0.7)
    }
}
