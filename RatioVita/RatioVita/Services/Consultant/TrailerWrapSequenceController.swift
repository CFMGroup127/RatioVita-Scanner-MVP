import Foundation
import SwiftData

@MainActor
enum TrailerWrapSequenceController {
    static func markCastWrapped(
        context: ModelContext,
        unit: TrailerOperationalUnit
    ) throws {
        unit.status = .castEnRouteToBase
        try context.save()
        TADLogisticsController.notifyCastEnRoute(unit: unit)
    }
}

@MainActor
enum CostumeTrailerBridge {
    static func markRoomDressed(unit: TrailerOperationalUnit) {
        unit.status = .roomDressedAndVerified
    }

    static func markWardrobeSecured(unit: TrailerOperationalUnit) {
        unit.status = .wardrobeSecuredPendingClearance
    }
}

@MainActor
enum TADLogisticsController {
    static func notifyCastEnRoute(unit: TrailerOperationalUnit) {
        unit.updatedAt = .now
    }

    static func markCastClear(unit: TrailerOperationalUnit) {
        unit.status = .cleanAndLockActive
        SwamperReleaseEngine.releaseForSanitization(unit: unit)
    }
}

@MainActor
enum SwamperReleaseEngine {
    static func releaseForSanitization(unit: TrailerOperationalUnit) {
        unit.status = .cleanAndLockActive
        unit.updatedAt = .now
    }

    static func markTrailerLocked(unit: TrailerOperationalUnit) {
        unit.status = .standby
        unit.assignedCastID = ""
    }
}
