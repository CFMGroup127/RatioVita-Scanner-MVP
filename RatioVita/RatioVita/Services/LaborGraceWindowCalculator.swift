import Foundation

/// Union grace windows for rain-day / insurance-day cancellations.
@MainActor
enum LaborGraceWindowCalculator {
    struct RainDayResult: Sendable {
        var withinGraceWindow: Bool
        var hoursBeforeCall: Double
        var graceHoursRequired: Double
        var owesDailyMinimum: Bool
        var summary: String
    }

    static func evaluateCancellation(
        callDate: Date,
        cancelledAt: Date,
        agreementCode: String = "IATSE"
    ) -> RainDayResult {
        let grace = graceHours(for: agreementCode)
        let callComponents = Calendar.current.dateComponents([.year, .month, .day], from: callDate)
        var callTime = Calendar.current.date(from: callComponents) ?? callDate
        callTime = Calendar.current.date(byAdding: .hour, value: 7, to: callTime) ?? callTime
        let hours = callTime.timeIntervalSince(cancelledAt) / 3600
        let within = hours >= grace
        let owes = !within
        let summary = within
            ? "Cancelled within \(Int(grace))h grace — no daily minimum owed."
            : "Outside grace (\(String(format: "%.1f", hours))h before call) — daily minimum voucher flagged."
        return RainDayResult(
            withinGraceWindow: within,
            hoursBeforeCall: max(0, hours),
            graceHoursRequired: grace,
            owesDailyMinimum: owes,
            summary: summary
        )
    }

    private static func graceHours(for code: String) -> Double {
        switch code.uppercased() {
            case "DGC", "DIRECTORS": 48
            case "ACTRA": 24
            default: 12
        }
    }
}
