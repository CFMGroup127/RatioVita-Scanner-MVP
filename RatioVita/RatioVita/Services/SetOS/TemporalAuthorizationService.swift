import Foundation
import SwiftData

/// 24-hour permission handoff for acting captain / co-captain roles (Sprint SSS).
@MainActor
enum TemporalAuthorizationService {
    static func issueGrant(
        context: ModelContext,
        userToken: String,
        temporaryRole: OperationalHatRole,
        unit: ProductionUnitNode,
        durationHours: Double = 24,
        issuedBy: String
    ) throws -> TemporalRoleGrant {
        pruneExpired(context: context)
        let expiration = Date().addingTimeInterval(durationHours * 3600)
        let grant = TemporalRoleGrant(
            userToken: userToken,
            temporaryRole: temporaryRole,
            unit: unit,
            expiration: expiration,
            issuedBy: issuedBy
        )
        context.insert(grant)
        try context.save()
        return grant
    }

    static func activeGrant(
        context: ModelContext,
        userToken: String
    ) throws -> TemporalRoleGrant? {
        pruneExpired(context: context)
        let all = try context.fetch(FetchDescriptor<TemporalRoleGrant>())
        return all
            .filter { $0.userToken == userToken && $0.isActive }
            .sorted { $0.expirationTimestamp > $1.expirationTimestamp }
            .first
    }

    static func pruneExpired(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<TemporalRoleGrant>()) else { return }
        let expired = all.filter { !$0.isActive }
        for grant in expired {
            context.delete(grant)
        }
        try? context.save()
    }

    static func formattedRemaining(_ grant: TemporalRoleGrant) -> String {
        let remaining = grant.expirationTimestamp.timeIntervalSinceNow
        guard remaining > 0 else { return "Expired" }
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m remaining"
    }
}
