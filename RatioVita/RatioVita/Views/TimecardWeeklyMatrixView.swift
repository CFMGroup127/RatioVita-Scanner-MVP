import SwiftData
import SwiftUI

/// EP / Cast & Crew–style **7-day matrix** preview (In, meals, wrap) above the per-day editor.
struct TimecardWeeklyMatrixView: View {
    let focusDay: CrewTimecardDay
    let siblingProjectDays: [CrewTimecardDay]
    var estimateByDayID: [UUID: SentinelPayEstimate] = [:]

    private let calendar = Calendar.current
    private static let columnHeaders = [
        "Day", "Date", "Trav", "Call", "M1 out", "M1 in", "M2 out", "M2 in", "Wrap", "Trav end", "Work h",
    ]

    private var weekDays: [CrewTimecardDay] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: focusDay.workDate) else {
            return [focusDay]
        }
        return siblingProjectDays
            .filter { interval.contains($0.workDate) }
            .sorted { $0.workDate < $1.workDate }
    }

    private var weekEndingText: String {
        guard let last = weekDays.last else { return "—" }
        let anchor = FraturdayCalendar.payrollAnchorStartOfDay(for: last, calendar: calendar)
        let weekday = calendar.component(.weekday, from: anchor)
        let daysToSaturday = (7 - weekday) % 7
        let end = calendar.date(byAdding: .day, value: daysToSaturday, to: anchor) ?? anchor
        return end.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly time log")
                    .font(DesignSystem.Typography.headline)
                Spacer(minLength: 8)
                Text("Week ending \(weekEndingText)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .adaptiveDetailText()
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                    GridRow {
                        ForEach(Self.columnHeaders, id: \.self) { header in
                            Text(header)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: headerMinWidth(header), alignment: .leading)
                        }
                    }
                    ForEach(weekDays, id: \.id) { day in
                        dayMatrixRow(day)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Color.ratioVitaAdaptiveSurface.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))

            Text(
                "Matches EP / Cast & Crew column order. Export uses the same slots in the digital twin PDF."
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .adaptiveDetailText()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerMinWidth(_ header: String) -> CGFloat {
        switch header {
            case "Day", "Date": 52
            case "Work h": 44
            default: 56
        }
    }

    @ViewBuilder
    private func dayMatrixRow(_ day: CrewTimecardDay) -> some View {
        let tf = timeFormatter
        let proj = day.productionProject
        let effCall = SentinelEffectiveClock.effectiveCall(day: day, project: proj)
        let effWrap = FraturdayCalendar.normalizedWrapAfterCall(
            call: effCall,
            wrap: SentinelEffectiveClock.effectiveWrapRaw(day: day, project: proj),
            workDateStart: calendar.startOfDay(for: day.workDate),
            calendar: calendar
        )
        let est = estimateByDayID[day.id]
        let workH = est.map {
            $0.straightHours + $0.overtime8To12Hours + $0.overtimeOver12Hours + $0.travelHours
        }

        GridRow {
            Text(day.workDate.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption.monospacedDigit())
            Text(day.workDate.formatted(date: .numeric, time: .omitted))
                .font(.caption.monospacedDigit())
            cell(day.travelLeaveZoneStart, tf: tf)
            cell(effCall, tf: tf)
            cell(day.meal1Start, tf: tf)
            cell(day.meal1End, tf: tf)
            cell(day.meal2Start, tf: tf)
            cell(day.meal2End, tf: tf)
            cell(effWrap, tf: tf)
            cell(day.travelReturnHome, tf: tf)
            Text(workH.map { String(format: "%.2f", $0) } ?? "—")
                .font(.caption.monospacedDigit())
        }
        .background(
            day.id == focusDay.id
                ? Color.ratioVitaAdaptiveSurface.opacity(0.65)
                : Color.clear
        )
    }

    private func cell(_ date: Date?, tf: DateFormatter) -> some View {
        Text(date.map { tf.string(from: $0) } ?? "—")
            .font(.caption.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(minWidth: 52, alignment: .leading)
    }

    private var timeFormatter: DateFormatter {
        let tf = DateFormatter()
        tf.timeStyle = .short
        tf.dateStyle = .none
        return tf
    }
}
