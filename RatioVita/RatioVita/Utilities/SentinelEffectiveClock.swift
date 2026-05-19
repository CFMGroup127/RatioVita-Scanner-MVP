import Foundation

/// **Portal-to-portal** (catering shop-to-shop) vs standard set clock — used for OT, meals, and Fraturday sorting.
enum SentinelEffectiveClock {
    static func portalToPortalEnabled(project: ProductionProject?) -> Bool {
        project?.laborCateringPortalMode == true
    }

    /// “Call” for Sentinel math: shop departure when catering portal mode is on.
    static func effectiveCall(day: CrewTimecardDay, project: ProductionProject?) -> Date? {
        if portalToPortalEnabled(project: project) {
            return day.travelLeaveZoneStart ?? day.callOnSet
        }
        return day.callOnSet
    }

    /// “Wrap” for Sentinel math: return to shop when catering portal mode is on.
    static func effectiveWrapRaw(day: CrewTimecardDay, project: ProductionProject?) -> Date? {
        if portalToPortalEnabled(project: project) {
            return day.travelReturnHome ?? day.wrapOffSet
        }
        return day.wrapOffSet
    }
}
