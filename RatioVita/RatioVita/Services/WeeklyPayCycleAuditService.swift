import Foundation

/// **Pay cycle sentinel:** compares logged crew days + Sentinel model for the ISO week around an anchor date.
enum WeeklyPayCycleAuditService {
    struct Discrepancy: Identifiable, Equatable, Sendable {
        let id: String
        let workDate: Date
        let title: String
        let detail: String

        init(dayID: UUID, workDate: Date, kind: String, title: String, detail: String) {
            id = "\(dayID.uuidString)|\(kind)"
            self.workDate = workDate
            self.title = title
            self.detail = detail
        }
    }

    /// Runs a discrepancy sweep for `projectDays` in the **week of year** containing `anchorDate`.
    static func sweep(
        projectDays: [CrewTimecardDay],
        agreement: LaborAgreement,
        anchorDate: Date = .now,
        calendar: Calendar = .current
    ) -> [Discrepancy] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: anchorDate) else { return [] }
        let chain = SentinelPayrollEngine.estimatesWithTurnaround(
            projectDays: projectDays,
            agreement: agreement,
            calendar: calendar
        )

        var out: [Discrepancy] = []

        for day in projectDays {
            let sod = calendar.startOfDay(for: day.workDate)
            guard sod >= week.start, sod < week.end else { continue }

            let est = chain[day.id] ?? SentinelPayrollEngine.estimate(
                day: day,
                agreement: agreement,
                calendar: calendar
            )
            let project = day.productionProject

            if est.mealPenaltyHalfHours > 0 {
                out.append(
                    Discrepancy(
                        dayID: day.id,
                        workDate: day.workDate,
                        kind: "mp_model",
                        title: "Meal penalty in Sentinel model",
                        detail:
                        "\(est.mealPenaltyHalfHours)× ½h meal units on \(sod.formatted(date: .abbreviated, time: .omitted)) — compare with call sheet / production meal times."
                    )
                )
            }

            if est.turnaroundGoldMultiplier > 1.01 {
                out.append(
                    Discrepancy(
                        dayID: day.id,
                        workDate: day.workDate,
                        kind: "turnaround",
                        title: "Turnaround premium (gold)",
                        detail:
                        "Gold multiplier ×\(String(format: "%.2f", est.turnaroundGoldMultiplier)) — verify minimum rest before the next shoot day."
                    )
                )
            }

            if let gcc = day.generalCrewCall,
               let deadline = calendar.date(byAdding: .hour, value: 6, to: gcc)
            {
                let grace: TimeInterval = 15 * 60
                if let m1 = day.meal1Start, m1 > deadline.addingTimeInterval(grace) {
                    out.append(
                        Discrepancy(
                            dayID: day.id,
                            workDate: day.workDate,
                            kind: "meal1_late",
                            title: "Meal 1 after six hours from general crew call",
                            detail:
                            "Crew call + 6h was \(deadline.formatted(date: .omitted, time: .shortened)); Meal 1 logged at \(m1.formatted(date: .omitted, time: .shortened))."
                        )
                    )
                }

                if day.meal1Start == nil,
                   let wrap = SentinelEffectiveClock.effectiveWrapRaw(day: day, project: project),
                   wrap > deadline.addingTimeInterval(grace)
                {
                    out.append(
                        Discrepancy(
                            dayID: day.id,
                            workDate: day.workDate,
                            kind: "meal1_missing",
                            title: "No Meal 1 before wrap (vs. crew call + 6h)",
                            detail:
                            "General crew call is set but Meal 1 is empty while wrap is after \(deadline.formatted(date: .omitted, time: .shortened))."
                        )
                    )
                }
            }
        }

        return out
    }
}
