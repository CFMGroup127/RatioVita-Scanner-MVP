import Foundation
import SwiftData

struct PayrollNudgePayload: Identifiable, Sendable {
    var id: String { workerToken + productionTitle + String(state.rawValue) }
    var workerToken: String
    var productionTitle: String
    var state: LockScheduleState
    var message: String
}

/// Tuesday 10:00 AM Toronto lock + weekend escalation (Sprint RRR).
@MainActor
enum PayrollLockScheduler {
    static func runTick(
        context: ModelContext,
        now: Date = .now,
        timecardDays: [CrewTimecardDay] = [],
        consultCards: [ConsultationTimecard] = []
    ) throws -> [PayrollNudgePayload] {
        let cal = PayrollWeekCalendar.toronto
        let weekEnd = PayrollWeekCalendar.weekEndingSaturday(for: now, calendar: cal)
        let dtrDescriptor = FetchDescriptor<DailyTimeReportEntry>()
        let allDTR = try context.fetch(dtrDescriptor)
        let weekDTR = allDTR.filter { PayrollWeekCalendar.isDate($0.workDate, inWeekEnding: weekEnd, calendar: cal) }

        let tokensInWeek = Set(weekDTR.map(\.workerAnonymousToken))
        var nudges: [PayrollNudgePayload] = []

        for token in tokensInWeek {
            let submitted = hasWeeklySubmission(
                token: token,
                weekEnding: weekEnd,
                timecardDays: timecardDays,
                consultCards: consultCards,
                calendar: cal
            )
            let status = try fetchOrCreateStatus(
                context: context,
                token: token,
                weekEnding: weekEnd,
                productionTitle: weekDTR.first(where: { $0.workerAnonymousToken == token })?.productionTitle ?? "Production"
            )
            status.hasSubmittedWeeklyTimecard = submitted

            let newState = resolveLockState(now: now, weekEnding: weekEnd, submitted: submitted, calendar: cal)
            let escalated = newState.rawValue > status.lockState.rawValue
            status.lockState = newState

            if newState == .locked, status.lockedAt == nil {
                status.lockedAt = now
            }

            if !submitted, escalated || shouldRepeatNudge(status: status, now: now, calendar: cal) {
                let message = nudgeMessage(for: newState, weekEnding: weekEnd, calendar: cal)
                status.lastNudgeMessage = message
                status.lastNudgeAt = now
                nudges.append(
                    PayrollNudgePayload(
                        workerToken: token,
                        productionTitle: status.productionTitle,
                        state: newState,
                        message: message
                    )
                )
                try postNudge(context: context, token: token, message: message, state: newState)
            }
        }

        try context.save()
        return nudges
    }

    static func markWeeklyTimecardSubmitted(
        context: ModelContext,
        workerToken: String,
        referenceDate: Date = .now
    ) throws {
        let cal = PayrollWeekCalendar.toronto
        let weekEnd = PayrollWeekCalendar.weekEndingSaturday(for: referenceDate, calendar: cal)
        let status = try fetchOrCreateStatus(
            context: context,
            token: workerToken,
            weekEnding: weekEnd,
            productionTitle: ""
        )
        status.hasSubmittedWeeklyTimecard = true
        status.lockState = .open
        status.updatedAt = .now
        try context.save()
    }

    private static func resolveLockState(
        now: Date,
        weekEnding: Date,
        submitted: Bool,
        calendar: Calendar
    ) -> LockScheduleState {
        if submitted { return .open }
        let lockInstant = PayrollWeekCalendar.payrollLockInstant(afterWeekEnding: weekEnding, calendar: calendar)
        if now >= lockInstant { return .locked }

        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        if weekday == 2, hour >= 8 { return .warningHigh }
        if weekday == 1, hour >= 12 { return .warningMedium }
        if weekday == 6 || weekday == 7 || (weekday == 1 && hour < 8) {
            if weekday == 6, hour >= 18 { return .warningLow }
            if weekday == 7 { return .warningMedium }
        }
        if weekday == 6, hour >= 21 { return .warningLow }
        return .open
    }

    private static func nudgeMessage(for state: LockScheduleState, weekEnding: Date, calendar: Calendar) -> String {
        let lockLabel = PayrollWeekCalendar.payrollLockInstant(afterWeekEnding: weekEnding, calendar: calendar)
            .formatted(date: .abbreviated, time: .shortened)
        switch state {
            case .warningLow:
                return "Wrap complete — please sign your weekly timecard when ready. Payroll lock \(lockLabel)."
            case .warningMedium:
                return "Payroll processing begins soon. Your weekly timecard is still pending."
            case .warningHigh:
                return "Final notice: RatioVita payroll lock is Tuesday at 10:00 AM. Submit your weekly timecard now or payment may roll to next cycle."
            case .locked:
                return "Payroll cycle locked at \(lockLabel). Missing weekly timecard will roll to the following pay run."
            case .open:
                return ""
        }
    }

    private static func hasWeeklySubmission(
        token: String,
        weekEnding: Date,
        timecardDays: [CrewTimecardDay],
        consultCards: [ConsultationTimecard],
        calendar: Calendar
    ) -> Bool {
        if consultCards.contains(where: { card in
            card.anonymousToken == token
                && PayrollWeekCalendar.isDate(card.workDate, inWeekEnding: weekEnding, calendar: calendar)
        }) {
            return true
        }
        let payrollName = UserDefaults.standard.string(forKey: "com.ratiovita.payrollDisplayName") ?? ""
        if !payrollName.isEmpty, token.contains(payrollName) || token == "PROD-\(payrollName)" {
            if timecardDays.contains(where: { PayrollWeekCalendar.isDate(
                $0.workDate,
                inWeekEnding: weekEnding,
                calendar: calendar
            ) }) {
                return true
            }
        }
        return false
    }

    private static func fetchOrCreateStatus(
        context: ModelContext,
        token: String,
        weekEnding: Date,
        productionTitle: String
    ) throws -> WorkerPayrollWeekStatus {
        let descriptor = FetchDescriptor<WorkerPayrollWeekStatus>()
        let all = try context.fetch(descriptor)
        let cal = PayrollWeekCalendar.toronto
        if let match = all.first(where: {
            $0.workerAnonymousToken == token
                && cal.isDate($0.weekEndingDate, inSameDayAs: weekEnding)
        }) {
            return match
        }
        let status = WorkerPayrollWeekStatus(
            weekEndingDate: weekEnding,
            workerToken: token,
            productionTitle: productionTitle
        )
        context.insert(status)
        return status
    }

    private static func shouldRepeatNudge(
        status: WorkerPayrollWeekStatus,
        now: Date,
        calendar _: Calendar
    ) -> Bool {
        guard let last = status.lastNudgeAt else { return true }
        return now.timeIntervalSince(last) > 6 * 3600
    }

    private static func postNudge(
        context: ModelContext,
        token: String,
        message: String,
        state: LockScheduleState
    ) throws {
        guard !message.isEmpty else { return }
        let priority: CommPriorityLevel = state == .locked || state == .warningHigh
            ? .operationalUrgent
            : .standard
        try HierarchyCommsEngine.ingest(
            context: context,
            title: "Payroll: \(state.label)",
            body: "\(token): \(message)",
            senderRole: "Payroll Scheduler",
            priority: priority
        )
    }
}
