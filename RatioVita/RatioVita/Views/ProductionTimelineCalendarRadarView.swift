import SwiftUI

/// One calendar day in the forensic radar: **work**, **income** (bank credits), **expense** (receipts, debits,
/// removals).
struct DayActivityBucket: Identifiable, Equatable {
    let calendarDay: Date
    var work: Int
    var income: Int
    var expense: Int

    var id: Date { calendarDay }
}

/// Month grid with weekday alignment (iCal-style shell for Sprint F “radar”).
struct ProductionTimelineCalendarRadarView: View {
    @Environment(\.brandAccent) private var brandAccent

    @Binding var monthAnchor: Date
    let bucketByStartOfDay: [Date: DayActivityBucket]
    @Binding var selectedDay: Date?
    /// When `false`, the chevron month title row is omitted (use an external year/month picker instead).
    var showsTopMonthNavigation: Bool = true
    /// When a production is selected and has `timelineColorHex`, work + receipt (expense) dots use this tint; bank
    /// credits stay **income** green.
    var receiptActivityTint: Color?

    private let calendar = Calendar.current

    private var workDotFill: Color { receiptActivityTint ?? brandAccent }
    private var incomeDotFill: Color { Color.ratioVitaSuccess }
    private var expenseDotFill: Color { receiptActivityTint ?? Color.orange.opacity(0.85) }

    /// Stable `ForEach` identity for the month grid (avoids duplicate symbol IDs; pads are unique per index).
    private struct RadarMonthGridSlot: Identifiable, Equatable {
        let id: String
        let day: Date?
    }

    private var radarMonthYMKey: String {
        let y = calendar.component(.year, from: monthAnchor)
        let m = calendar.component(.month, from: monthAnchor)
        return String(format: "%04d-%02d", y, m)
    }

    private var radarMonthGridSlots: [RadarMonthGridSlot] {
        gridCells.enumerated().map { idx, cell in
            if let d = cell {
                let t = Int(calendar.startOfDay(for: d).timeIntervalSince1970)
                return RadarMonthGridSlot(id: "radar-cell-\(radarMonthYMKey)-\(t)", day: cell)
            }
            return RadarMonthGridSlot(id: "radar-pad-\(radarMonthYMKey)-\(idx)", day: nil)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if showsTopMonthNavigation {
                    HStack {
                        Button {
                            shiftMonth(-1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        Text(monthTitle)
                            .font(DesignSystem.Typography.headline)
                        Spacer()
                        Button {
                            shiftMonth(1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                weekdayHeader
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(radarMonthGridSlots) { slot in
                        cellView(slot.day)
                    }
                }
                Text("Dots: work · income (credit) · expense. Tap a day to filter the stream below.")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TimelineMonthActivityDotStrip(
                monthAnchor: monthAnchor,
                bucketByStartOfDay: bucketByStartOfDay,
                selectedDay: $selectedDay,
                workDotFill: workDotFill,
                incomeDotFill: incomeDotFill,
                expenseDotFill: expenseDotFill
            )
            .frame(width: 52)
        }
        .padding(.vertical, 4)
    }

    private var monthTitle: String {
        monthAnchor.formatted(.dateTime.month(.wide).year())
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            withAnimation(.snappy(duration: 0.22)) {
                monthAnchor = d
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, sym in
                Text(sym)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Leading `nil` pads blank cells before the first of month.
    private var gridCells: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let start = monthInterval.start
        let dayRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        let firstWeekday = calendar.component(.weekday, from: start)
        let leading = (firstWeekday + 6) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in dayRange {
            if let day = calendar.date(byAdding: .day, value: d - 1, to: start) {
                cells.append(day)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    @ViewBuilder
    private func cellView(_ day: Date?) -> some View {
        if let day {
            let start = calendar.startOfDay(for: day)
            let bucket = bucketByStartOfDay[start]
            let isSel = selectedDay.map { calendar.isDate($0, inSameDayAs: start) } ?? false
            Button {
                selectedDay = start
            } label: {
                VStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: start))")
                        .font(DesignSystem.Typography.caption.weight(.semibold))
                    HStack(spacing: 3) {
                        if let b = bucket {
                            if b.work > 0 {
                                Circle().fill(workDotFill).frame(width: 5, height: 5)
                            }
                            if b.income > 0 {
                                Circle().fill(incomeDotFill).frame(width: 5, height: 5)
                            }
                            if b.expense > 0 {
                                Circle().fill(expenseDotFill).frame(width: 5, height: 5)
                            }
                        }
                    }
                    .frame(height: 8)
                    .id(
                        "radar-dots-\(Int(start.timeIntervalSince1970))-w\(bucket?.work ?? 0)i\(bucket?.income ?? 0)e\(bucket?.expense ?? 0)"
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isSel ? brandAccent : Color.ratioVitaAdaptiveBorder.opacity(0.35),
                            lineWidth: isSel ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 44)
        }
    }
}

// MARK: - Month activity strip (2nd column)

/// Vertical strip of **work / income / expense** dots aligned to each calendar day in the month (forensic “radar”
/// column).
struct TimelineMonthActivityDotStrip: View {
    @Environment(\.brandAccent) private var brandAccent

    let monthAnchor: Date
    let bucketByStartOfDay: [Date: DayActivityBucket]
    @Binding var selectedDay: Date?
    var workDotFill: Color
    var incomeDotFill: Color
    var expenseDotFill: Color

    private let calendar = Calendar.current

    /// One row per calendar day in the strip — IDs combine YM + ordinal + day stamp so nothing collides across months.
    private struct DotStripRow: Identifiable {
        let id: String
        let startOfDay: Date
    }

    private var stripMonthYMKey: String {
        let y = calendar.component(.year, from: monthAnchor)
        let m = calendar.component(.month, from: monthAnchor)
        return String(format: "%04d-%02d", y, m)
    }

    private var dotStripRows: [DotStripRow] {
        monthDays.enumerated().map { idx, day in
            let sod = calendar.startOfDay(for: day)
            let t = Int(sod.timeIntervalSince1970)
            return DotStripRow(id: "strip-\(stripMonthYMKey)-\(idx)-\(t)", startOfDay: sod)
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("•")
                .font(.system(size: 8))
                .foregroundStyle(.clear)
                .frame(height: 28)
            ForEach(dotStripRows) { row in
                let sod = row.startOfDay
                let bucket = bucketByStartOfDay[sod]
                let isSel = selectedDay.map { calendar.isDate($0, inSameDayAs: sod) } ?? false
                Button {
                    selectedDay = sod
                } label: {
                    VStack(spacing: 3) {
                        Text("\(calendar.component(.day, from: sod))")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            if let b = bucket {
                                dot(b.work > 0, fill: workDotFill)
                                dot(b.income > 0, fill: incomeDotFill)
                                dot(b.expense > 0, fill: expenseDotFill)
                            }
                        }
                        .frame(height: 7)
                        .id(
                            "strip-dots-\(Int(sod.timeIntervalSince1970))-w\(bucket?.work ?? 0)i\(bucket?.income ?? 0)e\(bucket?.expense ?? 0)"
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isSel ? brandAccent.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.35), lineWidth: 1)
        )
    }

    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let start = monthInterval.start
        let dayRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        return dayRange.compactMap { d in
            calendar.date(byAdding: .day, value: d - 1, to: start)
        }
    }

    @ViewBuilder
    private func dot(_ on: Bool, fill: Color) -> some View {
        Circle()
            .fill(on ? fill : Color.ratioVitaAdaptiveBorder.opacity(0.2))
            .frame(width: 4, height: 4)
    }
}
