import Foundation
import SwiftData

/// Non-intrusive UI telemetry for consultant / tester builds.
@MainActor
enum UserFrictionAnalytics {
    private static var viewOpenedAt: [String: Date] = [:]

    static func trackViewOpened(_ identifier: String) {
        viewOpenedAt[identifier] = .now
    }

    @discardableResult
    static func trackViewClosed(
        context: ModelContext,
        identifier: String,
        unexpectedlyClosed: Bool,
        anonymousToken: String = ""
    ) throws -> FrictionEventLog? {
        let opened = viewOpenedAt.removeValue(forKey: identifier) ?? .now
        let duration = Date().timeIntervalSince(opened)
        let mission = TestingMissionManager.shared.missionContextLine ?? ""

        guard unexpectedlyClosed || duration > 45 else { return nil }

        let log = FrictionEventLog(
            viewIdentifier: identifier,
            duration: duration,
            unexpectedlyClosed: unexpectedlyClosed,
            missionContext: mission,
            anonymousToken: anonymousToken
        )
        context.insert(log)
        try context.save()
        return log
    }
}
