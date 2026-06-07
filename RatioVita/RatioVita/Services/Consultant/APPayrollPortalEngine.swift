import Foundation
import SwiftData

struct DTRMissingTimecardAlert: Identifiable, Sendable {
    var id: String { workerToken + workDate.description }
    var workerToken: String
    var workDate: Date
    var department: String
    var urgency: String
}

@MainActor
enum APPayrollPortalEngine {
    static func consultationQueue(context: ModelContext) throws -> [ConsultationTimecard] {
        try ConsultantTimecardEngine.cardsForAccountingVault(context: context)
    }

    static func productionTimecardQueue(
        days: [CrewTimecardDay]
    ) -> [CrewTimecardDay] {
        days.filter { $0.approvalState != .accountingCleared }
            .sorted { $0.workDate > $1.workDate }
    }

    /// DTR present but no weekly timecard submitted — escalating urgency by calendar day.
    static func missingTimecardAlerts(
        dtrEntries: [DailyTimeReportEntry],
        timecardDays: [CrewTimecardDay],
        now: Date = .now
    ) -> [DTRMissingTimecardAlert] {
        let calendar = Calendar.current
        var alerts: [DTRMissingTimecardAlert] = []

        for dtr in dtrEntries where dtr.signedOff {
            let hasCard = timecardDays.contains { day in
                calendar.isDate(day.workDate, inSameDayAs: dtr.workDate)
            }
            guard !hasCard else { continue }

            let weekday = calendar.component(.weekday, from: now)
            let urgency = if weekday == 1 {
                "High — Monday payroll lock approaching (10:00 AM)"
            } else if weekday == 7 || weekday == 1 {
                "Medium — weekend reminder"
            } else {
                "Low — post-wrap reminder"
            }

            alerts.append(
                DTRMissingTimecardAlert(
                    workerToken: dtr.workerAnonymousToken,
                    workDate: dtr.workDate,
                    department: dtr.departmentLabel,
                    urgency: urgency
                )
            )
        }
        return alerts
    }
}
