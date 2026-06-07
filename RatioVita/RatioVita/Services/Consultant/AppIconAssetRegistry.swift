import SwiftUI

/// Department tactical glyphs + RatioVita logo anchor (Sprint QOO).
enum DepartmentIconGlyph: String, Codable, CaseIterable {
    case transportDriver = "GLYPH_STEERING_ORANGE"
    case instantTimecard = "GLYPH_STOPWATCH_BLUE"
    case costumeContinuity = "GLYPH_HANGER_PURPLE"
    case accountingAP = "GLYPH_VAULT_EMERALD"
    case trailerAD = "GLYPH_RADAR_YELLOW"
    case swamper = "GLYPH_SPARKLES_SILVER"
    case firstLooks = "GLYPH_CAMERA_PURPLE"
}

struct LauncherShortcutProfile: Identifiable, Sendable {
    var id: UUID
    var moduleIntent: LauncherModuleIntent
    var systemLogoAsset: String
    var departmentGlyph: DepartmentIconGlyph
    var desktopLabel: String
    var urlPath: String

    init(
        id: UUID = UUID(),
        moduleIntent: LauncherModuleIntent,
        systemLogoAsset: String = "RatioVitaLogoMark",
        departmentGlyph: DepartmentIconGlyph,
        desktopLabel: String,
        urlPath: String
    ) {
        self.id = id
        self.moduleIntent = moduleIntent
        self.systemLogoAsset = systemLogoAsset
        self.departmentGlyph = departmentGlyph
        self.desktopLabel = desktopLabel
        self.urlPath = urlPath
    }
}

@MainActor
enum AppIconAssetRegistry {
    /// Drop `RatioVitaLogoMark.png` (1024×256 or square mark) into this imageset to replace the text fallback.
    static let masterLogoAssetName = "RatioVitaLogoMark"

    static let graphiteBackground = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let logoBarSilver = Color(red: 0.78, green: 0.80, blue: 0.84)

    static var allShortcutProfiles: [LauncherShortcutProfile] {
        [
            LauncherShortcutProfile(
                moduleIntent: .driverTransit,
                departmentGlyph: .transportDriver,
                desktopLabel: "RV · Driver",
                urlPath: "driver"
            ),
            LauncherShortcutProfile(
                moduleIntent: .instantTimecard,
                departmentGlyph: .instantTimecard,
                desktopLabel: "RV · Timecard",
                urlPath: "timecard"
            ),
            LauncherShortcutProfile(
                moduleIntent: .costumeContinuity,
                departmentGlyph: .costumeContinuity,
                desktopLabel: "RV · Costume",
                urlPath: "costume"
            ),
            LauncherShortcutProfile(
                moduleIntent: .firstLooks,
                departmentGlyph: .firstLooks,
                desktopLabel: "RV · First Looks",
                urlPath: "firstlooks"
            ),
            LauncherShortcutProfile(
                moduleIntent: .apPayroll,
                departmentGlyph: .accountingAP,
                desktopLabel: "RV · AP Payroll",
                urlPath: "ap"
            ),
            LauncherShortcutProfile(
                moduleIntent: .tadConsole,
                departmentGlyph: .trailerAD,
                desktopLabel: "RV · TAD",
                urlPath: "tad"
            ),
            LauncherShortcutProfile(
                moduleIntent: .swamperTerminal,
                departmentGlyph: .swamper,
                desktopLabel: "RV · Swamper",
                urlPath: "swamper"
            ),
        ]
    }

    static func profile(for intent: LauncherModuleIntent) -> LauncherShortcutProfile? {
        allShortcutProfiles.first { $0.moduleIntent == intent }
    }

    static func profile(forGlyph glyph: DepartmentIconGlyph) -> LauncherShortcutProfile? {
        allShortcutProfiles.first { $0.departmentGlyph == glyph }
    }

    static func glyphStyle(_ glyph: DepartmentIconGlyph) -> (symbol: String, color: Color) {
        switch glyph {
            case .transportDriver:
                ("steeringwheel", Color(red: 1.0, green: 0.45, blue: 0.12))
            case .instantTimecard:
                ("stopwatch", Color(red: 0.25, green: 0.55, blue: 1.0))
            case .costumeContinuity:
                ("hanger", Color(red: 0.55, green: 0.35, blue: 0.85))
            case .accountingAP:
                ("lock.shield", Color(red: 0.20, green: 0.72, blue: 0.52))
            case .trailerAD:
                ("antenna.radiowaves.left.and.right", Color(red: 1.0, green: 0.82, blue: 0.20))
            case .swamper:
                ("sparkles", Color(red: 0.72, green: 0.74, blue: 0.78))
            case .firstLooks:
                ("camera.viewfinder", Color(red: 0.72, green: 0.42, blue: 0.92))
        }
    }
}
