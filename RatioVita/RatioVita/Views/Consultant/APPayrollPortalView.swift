import SwiftData
import SwiftUI

/// AP / Payroll mode — consultant vault + production queue + DTR watchdog + lock scheduler.
struct APPayrollPortalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConsultationTimecard.createdAt, order: .reverse) private var consultCards: [ConsultationTimecard]
    @Query(sort: \CrewTimecardDay.workDate, order: .reverse) private var productionDays: [CrewTimecardDay]
    @Query(sort: \DailyTimeReportEntry.workDate, order: .reverse) private var dtrEntries: [DailyTimeReportEntry]
    @Query(
        sort: \WorkerPayrollWeekStatus.updatedAt,
        order: .reverse
    ) private var payrollStatuses: [WorkerPayrollWeekStatus]

    @State private var schedulerMessage: String?

    var body: some View {
        List {
            Section("Payroll lock scheduler (Sprint RRR)") {
                if payrollStatuses.isEmpty {
                    Text("No weekly lock rows yet. Seed DTR, then run scheduler tick.")
                        .foregroundStyle(.secondary)
                }
                ForEach(payrollStatuses) { status in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.workerAnonymousToken)
                            .font(.caption.monospaced())
                        Text(
                            "Week ending \(status.weekEndingDate.formatted(date: .abbreviated, time: .omitted)) · \(status.productionTitle)"
                        )
                        .font(.caption)
                        HStack {
                            Text(status.lockState.label)
                            Spacer()
                            Text(status.hasSubmittedWeeklyTimecard ? "Submitted" : "Pending")
                                .foregroundStyle(status.hasSubmittedWeeklyTimecard ? .green : .orange)
                        }
                        .font(.caption2)
                        if !status.lastNudgeMessage.isEmpty {
                            Text(status.lastNudgeMessage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Run scheduler tick now") { runSchedulerTick(simulatedNow: nil) }
                Button("Simulate Sunday 2 PM (escalation)") {
                    runSchedulerTick(simulatedNow: simulatedSundayAfternoon())
                }
                NavigationLink("AD floor wrap console") {
                    ADFloorWrapConsoleView()
                }
                if let schedulerMessage {
                    Text(schedulerMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Consultant honorarium queue (\(consultCards.count))") {
                if consultCards.isEmpty {
                    Text("No consultant timecards yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(consultCards) { card in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.anonymousToken)
                            .font(.headline.monospaced())
                        Text(
                            "\(card.hoursLogged, format: .number) h · \(card.workDate.formatted(date: .abbreviated, time: .omitted))"
                        )
                        Text(card.localizedNotes)
                            .font(.caption)
                    }
                }
            }
            Section("Production timecards pending AP") {
                ForEach(APPayrollPortalEngine.productionTimecardQueue(days: productionDays)) { day in
                    Text("\(day.workDate.formatted(date: .abbreviated, time: .omitted)) · \(day.department ?? "Dept")")
                }
            }
            Section("DTR discrepancy watchdog") {
                let alerts = APPayrollPortalEngine.missingTimecardAlerts(
                    dtrEntries: dtrEntries,
                    timecardDays: productionDays
                )
                if alerts.isEmpty {
                    Text("No missing weekly cards vs DTR.")
                        .foregroundStyle(.secondary)
                }
                ForEach(alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.workerToken)
                            .font(.caption.monospaced())
                        Text(alert.department)
                        Text(alert.urgency)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle("AP · Payroll portal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Seed DTR sample") { seedDTR() }
            }
        }
    }

    private func runSchedulerTick(simulatedNow: Date?) {
        do {
            let days = try modelContext.fetch(FetchDescriptor<CrewTimecardDay>())
            let consult = try modelContext.fetch(FetchDescriptor<ConsultationTimecard>())
            let nudges = try PayrollLockScheduler.runTick(
                context: modelContext,
                now: simulatedNow ?? .now,
                timecardDays: days,
                consultCards: consult
            )
            schedulerMessage = nudges.isEmpty
                ? "Tick complete — no new nudges."
                : "Tick complete — \(nudges.count) nudge(s) posted to Comms."
        } catch {
            schedulerMessage = error.localizedDescription
        }
    }

    /// Sunday 14:00 Toronto — triggers warningMedium when weekly card is missing.
    private func simulatedSundayAfternoon() -> Date? {
        let cal = PayrollWeekCalendar.toronto
        let weekEnd = PayrollWeekCalendar.weekEndingSaturday(for: .now, calendar: cal)
        guard let sunday = cal.date(byAdding: .day, value: 1, to: weekEnd) else { return nil }
        var comps = cal.dateComponents([.year, .month, .day], from: sunday)
        comps.hour = 14
        comps.minute = 0
        return cal.date(from: comps)
    }

    private func seedDTR() {
        let entry = DailyTimeReportEntry(
            productionTitle: "Sanctuary",
            workDate: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
            workerToken: "H4SH-SETDEC-JENNA",
            department: "Set Dec"
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }
}
