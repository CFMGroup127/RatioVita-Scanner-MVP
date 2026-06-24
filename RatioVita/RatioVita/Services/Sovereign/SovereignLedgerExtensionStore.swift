import Foundation

/// Progressive opt-in ledger modules surfaced in Column 1 per sovereign hub.
enum SovereignLedgerExtension: String, CaseIterable, Identifiable, Codable {
    case advancedAssets
    case toolInventoryTracking
    case productionKitPullForward

    var id: String { rawValue }

    var title: String {
        switch self {
        case .advancedAssets: "Advanced Assets Module"
        case .toolInventoryTracking: "Tool & Inventory Tracking"
        case .productionKitPullForward: "Kit Pull-Forward Bridge"
        }
    }

    var subtitle: String {
        switch self {
        case .advancedAssets:
            "High-value property, appraisals, gallery loans, transit ledgers."
        case .toolInventoryTracking:
            "Utility trailers, fabrication gear, and venture-scoped inventory."
        case .productionKitPullForward:
            "Link personal / venture kit onto the active production token."
        }
    }

    var systemImage: String {
        switch self {
        case .advancedAssets: "sparkles.rectangle.stack"
        case .toolInventoryTracking: "wrench.and.screwdriver"
        case .productionKitPullForward: "arrow.triangle.branch"
        }
    }

    var hub: SovereignHubKind {
        switch self {
        case .advancedAssets: .personal
        case .toolInventoryTracking: .ventures
        case .productionKitPullForward: .production
        }
    }

    static func options(for hub: SovereignHubKind) -> [SovereignLedgerExtension] {
        allCases.filter { $0.hub == hub }
    }
}

enum SovereignLedgerExtensionStore {
    private static let key = "com.ratiovita.sovereign.ledgerExtensions"

    static func isEnabled(_ ext: SovereignLedgerExtension) -> Bool {
        enabledIDs().contains(ext.rawValue)
    }

    static func setEnabled(_ ext: SovereignLedgerExtension, enabled: Bool) {
        var ids = enabledIDs()
        if enabled {
            ids.insert(ext.rawValue)
        } else {
            ids.remove(ext.rawValue)
        }
        UserDefaults.standard.set(Array(ids), forKey: key)
    }

    static func enabled(for hub: SovereignHubKind) -> [SovereignLedgerExtension] {
        let active = enabledIDs()
        return SovereignLedgerExtension.options(for: hub).filter { active.contains($0.rawValue) }
    }

    private static func enabledIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
}
