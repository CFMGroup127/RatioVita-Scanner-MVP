import Foundation
import SwiftData

@MainActor
enum ConsultantTimecardEngine {
    @discardableResult
    static func submit(
        context: ModelContext,
        profile: ExpertConsultantProfile,
        hours: Double,
        notes: String
    ) throws -> ConsultationTimecard {
        let card = ConsultationTimecard(
            consultantID: profile.id,
            department: profile.department,
            anonymousToken: profile.anonymousToken,
            hoursLogged: hours,
            notes: notes,
            biometricVerified: true
        )
        context.insert(card)
        try PayrollLockScheduler.markWeeklyTimecardSubmitted(
            context: context,
            workerToken: profile.anonymousToken
        )
        try context.save()
        return card
    }

    static func cardsForAccountingVault(
        context: ModelContext
    ) throws -> [ConsultationTimecard] {
        let descriptor = FetchDescriptor<ConsultationTimecard>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
