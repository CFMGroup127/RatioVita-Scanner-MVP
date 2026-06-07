import SwiftData
import SwiftUI

/// Live digital timecard reproduction for the approvals split-screen (left pane).
struct TimecardDigitalApprovalPreview: View {
    let day: CrewTimecardDay
    let siblingDays: [CrewTimecardDay]
    var estimateByDayID: [UUID: SentinelPayEstimate] = [:]

    private let calendar = Calendar.current

    private var employeeName: String {
        let payroll = UserDefaults.standard.string(forKey: "com.ratiovita.payrollDisplayName") ?? ""
        if !payroll.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return payroll }
        return day.occupationTitle ?? "Crew member"
    }

    private var weekEndingText: String {
        let anchor = FraturdayCalendar.payrollAnchorStartOfDay(for: day, calendar: calendar)
        let weekday = calendar.component(.weekday, from: anchor)
        let daysToSaturday = (7 - weekday) % 7
        let end = calendar.date(byAdding: .day, value: daysToSaturday, to: anchor) ?? anchor
        return end.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                headerBand
                TimecardApprovalMilestoneTrack(day: day)
                TimecardWeeklyMatrixView(
                    focusDay: day,
                    siblingProjectDays: siblingDays,
                    estimateByDayID: estimateByDayID
                )
                approvalInitialsRow
            }
            .padding(DesignSystem.Spacing.md)
        }
        .frame(maxWidth: SafeLayoutBounds.maxTimecardPreviewWidth, alignment: .leading)
        .background(Color.ratioVitaAdaptiveSurface.opacity(0.4))
    }

    private var headerBand: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                metaCell(title: "Dept", value: day.department ?? "—", width: FixedColumnWidths.deptWidth)
                metaCell(title: "Unit", value: day.unitType ?? "Main", width: FixedColumnWidths.unitWidth)
                metaCell(title: "Name", value: employeeName, width: 160)
                metaCell(title: "Week ending", value: weekEndingText, width: 120)
            }
            if let occupation = day.occupationTitle, !occupation.isEmpty {
                Text("Occupation: \(occupation)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var approvalInitialsRow: some View {
        let states = TimecardApprovalService.boxStates(for: day)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Approval boxes on sheet")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(TimecardApprovalService.SignatureBox.allCases, id: \.self) { box in
                    sheetApprovalCell(
                        title: box.menuTitle,
                        state: states[box] ?? TimecardApprovalService.BoxState()
                    )
                }
            }
        }
    }

    private func metaCell(title: String, value: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
    }

    private func sheetApprovalCell(title: String, state: TimecardApprovalService.BoxState) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(state.initials ?? "—")
                .font(.title3.weight(.bold))
                .frame(width: FixedColumnWidths.approvalBoxWidth, height: FixedColumnWidths.approvalBoxHeight)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(state.isComplete ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1)
                )
        }
    }
}
