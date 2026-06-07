import Combine
import Foundation

/// Active consultant program session (separate from sovereign owner profile).
@MainActor
final class ConsultantSessionManager: ObservableObject {
    static let shared = ConsultantSessionManager()

    @Published var programModeEnabled: Bool = false
    @Published var activeProfileID: UUID?
    @Published var pendingLauncherIntent: LauncherModuleIntent?
    @Published var activeOperationalHat: OperationalHatRole = .driver
    @Published var activeUnitNode: ProductionUnitNode = .mainUnitAlgonquin

    private init() {
        programModeEnabled = UserDefaults.standard.bool(forKey: Keys.programEnabled)
        if let raw = UserDefaults.standard.string(forKey: Keys.profileID),
           let id = UUID(uuidString: raw)
        {
            activeProfileID = id
        }
        if let intentRaw = UserDefaults.standard.string(forKey: Keys.launcherIntent),
           let intent = LauncherModuleIntent(rawValue: intentRaw)
        {
            pendingLauncherIntent = intent
        }
        if let hatRaw = UserDefaults.standard.string(forKey: Keys.hat),
           let hat = OperationalHatRole(rawValue: hatRaw)
        {
            activeOperationalHat = hat
        }
        if let unitRaw = UserDefaults.standard.string(forKey: Keys.unit),
           let unit = ProductionUnitNode(rawValue: unitRaw)
        {
            activeUnitNode = unit
        }
    }

    /// Defers `@Published` writes to the next run-loop turn (avoids SwiftUI “publishing during view updates”).
    private func deferPublishedMutation(_ mutation: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            mutation()
        }
    }

    func setOperationalHat(_ hat: OperationalHatRole) {
        guard activeOperationalHat != hat else { return }
        deferPublishedMutation {
            self.activeOperationalHat = hat
            UserDefaults.standard.set(hat.rawValue, forKey: Keys.hat)
        }
    }

    func setActiveUnitNode(_ unit: ProductionUnitNode) {
        guard activeUnitNode != unit else { return }
        deferPublishedMutation {
            self.activeUnitNode = unit
            UserDefaults.standard.set(unit.rawValue, forKey: Keys.unit)
        }
    }

    func setProgramEnabled(_ enabled: Bool) {
        guard programModeEnabled != enabled else { return }
        deferPublishedMutation {
            self.programModeEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: Keys.programEnabled)
        }
    }

    func setActiveProfileID(_ id: UUID?) {
        guard activeProfileID != id else { return }
        deferPublishedMutation {
            self.activeProfileID = id
            if let id {
                UserDefaults.standard.set(id.uuidString, forKey: Keys.profileID)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.profileID)
            }
        }
    }

    func queueLauncherIntent(_ intent: LauncherModuleIntent?) {
        guard pendingLauncherIntent != intent else { return }
        deferPublishedMutation {
            self.pendingLauncherIntent = intent
            if let intent {
                UserDefaults.standard.set(intent.rawValue, forKey: Keys.launcherIntent)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.launcherIntent)
            }
        }
    }

    func consumeLauncherIntent() -> LauncherModuleIntent? {
        let intent = pendingLauncherIntent
        queueLauncherIntent(nil)
        return intent
    }

    private enum Keys {
        static let programEnabled = "com.ratiovita.consultant.programEnabled"
        static let profileID = "com.ratiovita.consultant.activeProfileID"
        static let launcherIntent = "com.ratiovita.consultant.launcherIntent"
        static let hat = "com.ratiovita.consultant.operationalHat"
        static let unit = "com.ratiovita.consultant.unitNode"
    }
}
