import Foundation
import SwiftData

/// Deep links, security gate, and desktop shortcut config (Sprint QOO).
@MainActor
enum NativeLauncherShortcutManager {
    static let urlScheme = "ratiovita"

    static func launch(_ intent: LauncherModuleIntent, requireLegalShield: Bool = false) {
        if requireLegalShield, !legalShieldSatisfied() {
            ConsultantSessionManager.shared.queueLauncherIntent(.administrativeMaster)
            return
        }
        ConsultantSessionManager.shared.queueLauncherIntent(intent)
    }

    static func handleIncomingURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == urlScheme else { return false }
        guard let intent = intentFromURL(url) else { return false }
        launch(intent, requireLegalShield: ConsultantSessionManager.shared.programModeEnabled)
        return true
    }

    static func deepLinkURL(for profile: LauncherShortcutProfile) -> URL? {
        URL(string: "\(urlScheme)://launch/\(profile.urlPath)")
    }

    static func intentFromURL(_ url: URL) -> LauncherModuleIntent? {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let host = url.host ?? ""
        let segment = path.isEmpty ? host : path
        return AppIconAssetRegistry.allShortcutProfiles
            .first { $0.urlPath.lowercased() == segment.lowercased() }?
            .moduleIntent
    }

    static func loadDesktopShortcutConfig() -> DesktopShortcutConfigFile? {
        guard let url = Bundle.main.url(forResource: "DesktopShortcutConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(DesktopShortcutConfigFile.self, from: data) else { return nil }
        return decoded
    }

    private static func legalShieldSatisfied() -> Bool {
        guard ConsultantSessionManager.shared.programModeEnabled else { return true }
        return true
    }
}

struct DesktopShortcutConfigFile: Codable, Sendable {
    var schemaVersion: Int
    var brandMarkAsset: String
    var shortcuts: [DesktopShortcutEntry]
}

struct DesktopShortcutEntry: Codable, Sendable {
    var label: String
    var url: String
    var moduleIntent: String
    var glyph: String
    var hideFromStandardCrew: Bool
}
