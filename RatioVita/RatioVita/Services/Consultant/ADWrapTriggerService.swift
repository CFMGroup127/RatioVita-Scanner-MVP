import Foundation
import SwiftData

struct ADWrapBroadcast: Sendable {
    var dtrEntry: DailyTimeReportEntry
    var trailerUnit: TrailerOperationalUnit
}

/// Live bridge: AD floor wrap → DTR row + TAD cast en route (Sprint RRR).
@MainActor
enum ADWrapTriggerService {
    @discardableResult
    static func wrapCastMember(
        context: ModelContext,
        castDisplayID: String,
        workerToken: String,
        department: String,
        productionTitle: String,
        trailerNumber: String,
        wrappedByRole: String = "2nd AD"
    ) throws -> ADWrapBroadcast {
        let now = Date()
        let cal = PayrollWeekCalendar.toronto
        let wrapHour = cal.component(.hour, from: now)
        let wrapMinute = cal.component(.minute, from: now)

        let unit = findOrCreateTrailer(
            context: context,
            trailerNumber: trailerNumber,
            castID: castDisplayID
        )

        let dtr = DailyTimeReportEntry(
            productionTitle: productionTitle,
            workDate: cal.startOfDay(for: now),
            workerToken: workerToken,
            department: department,
            castDisplayID: castDisplayID,
            signedOff: true,
            wrappedByRole: wrappedByRole
        )
        dtr.wrapTimestamp = now
        dtr.wrapTimeHour = wrapHour
        dtr.wrapTimeMinute = wrapMinute

        context.insert(dtr)
        try TrailerWrapSequenceController.markCastWrapped(context: context, unit: unit)

        try HierarchyCommsEngine.ingest(
            context: context,
            title: "Wrap: \(castDisplayID) en route to base",
            body: "\(wrappedByRole) wrapped \(castDisplayID) at \(now.formatted(date: .omitted, time: .shortened)). DTR signed; TAD trailer \(trailerNumber) updated.",
            senderRole: wrappedByRole,
            priority: .operationalUrgent,
            targetDepartment: "TAD"
        )

        try context.save()
        return ADWrapBroadcast(dtrEntry: dtr, trailerUnit: unit)
    }

    private static func findOrCreateTrailer(
        context: ModelContext,
        trailerNumber: String,
        castID: String
    ) -> TrailerOperationalUnit {
        let descriptor = FetchDescriptor<TrailerOperationalUnit>()
        if let existing = try? context.fetch(descriptor),
           let match = existing.first(where: { $0.trailerNumber == trailerNumber })
        {
            match.assignedCastID = castID
            match.updatedAt = .now
            return match
        }
        let unit = TrailerOperationalUnit(trailerNumber: trailerNumber, castID: castID)
        context.insert(unit)
        return unit
    }
}
