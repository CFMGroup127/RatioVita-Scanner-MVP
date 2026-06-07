import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Schedules widget timeline reloads when production state changes (Sprint HHHH).
@MainActor
final class TimecardWidgetTimelineProvider {
    static let shared = TimecardWidgetTimelineProvider()

    private let workerQueue = DispatchQueue(label: "com.ratiovita.widget.timeline", qos: .utility)

    private init() {}

    func scheduleRefresh(reason: String) {
        workerQueue.async {
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            Task { @MainActor in
                _ = reason
            }
        }
    }

    func buildTimelineSummary() -> String {
        guard let state = HomeScreenWidgetDataProvider.load() else {
            return "No widget context — complete onboarding."
        }
        var lines: [String] = [
            state.userPositionTitle,
            state.activeDepartment,
        ]
        if let meal = state.mealOneStart {
            lines.append("Meal 1 · \(meal.formatted(date: .omitted, time: .shortened))")
        }
        if state.sandboxMode {
            lines.append("Sandbox mode")
        }
        return lines.joined(separator: " · ")
    }
}
