import Combine
import Foundation

/// Debug/testing anchor so you never lose track of what you were validating.
@MainActor
final class TestingMissionManager: ObservableObject {
    static let shared = TestingMissionManager()

    @Published var activeMission: String = ""
    @Published var isHUDVisible: Bool = true

    private init() {
        activeMission = UserDefaults.standard.string(forKey: Keys.mission) ?? ""
        isHUDVisible = UserDefaults.standard.object(forKey: Keys.hudVisible) as? Bool ?? true
    }

    func setMission(_ text: String) {
        activeMission = text.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(activeMission, forKey: Keys.mission)
    }

    func setHUDVisible(_ visible: Bool) {
        isHUDVisible = visible
        UserDefaults.standard.set(visible, forKey: Keys.hudVisible)
    }

    var missionContextLine: String? {
        let t = activeMission.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private enum Keys {
        static let mission = "com.ratiovita.testing.activeMission"
        static let hudVisible = "com.ratiovita.testing.missionHUDVisible"
    }
}
