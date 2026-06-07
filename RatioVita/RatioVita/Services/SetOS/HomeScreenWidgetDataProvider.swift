import Foundation

/// App Group bridge for home-screen widget timelines (Sprint HHHH).
@MainActor
enum HomeScreenWidgetDataProvider {
    static let appGroupID = "group.com.ratiovita.shared"
    static let contextKey = "widget.context.state.json"

    static func publish(from coordinator: SetOSOnboardingCoordinator) {
        let position = coordinator.activePosition
        var state = WidgetContextState(
            selectedProductionName: coordinator.productionTitle.isEmpty
                ? (coordinator.sandboxMode ? "Sandbox practice show" : coordinator.showCode)
                : coordinator.productionTitle,
            activeDepartment: coordinator.selectedDepartmentName,
            userPositionTitle: coordinator.selectedPositionTitle,
            operationalHatRaw: position?.hatRole.rawValue ?? OperationalHatRole.driver.rawValue,
            industryScopeRaw: coordinator.activeIndustryScope?.rawValue
                ?? IndustryDepartmentScope.transport.rawValue,
            sandboxMode: coordinator.sandboxMode,
            enabledQuadrants: coordinator.enabledQuadrants.map(\.rawValue),
            pinnedLauncherIntents: coordinator.pinnedLauncherIntents.map(\.rawValue)
        )
        state.sideHustleInvoiceCount = coordinator.sideHustleEnabled ? 1 : 0
        write(state)
        TimecardWidgetTimelineProvider.shared.scheduleRefresh(reason: "onboarding.finalize")
    }

    static func load() -> WidgetContextState? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: contextKey) else { return nil }
        return try? JSONDecoder().decode(WidgetContextState.self, from: data)
    }

    static func write(_ state: WidgetContextState) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: contextKey)
    }

    static func recordMealOneStart() {
        mutate { $0.mealOneStart = .now }
    }

    static func recordMealOneEnd() {
        mutate { $0.mealOneEnd = .now }
    }

    static func recordWrap() {
        mutate { $0.currentWrapTime = .now }
    }

    private static func mutate(_ block: (inout WidgetContextState) -> Void) {
        guard var state = load() else { return }
        block(&state)
        write(state)
        TimecardWidgetTimelineProvider.shared.scheduleRefresh(reason: "timecard.event")
    }
}
