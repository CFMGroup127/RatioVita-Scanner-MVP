import Foundation

/// Launchpad tile → app module (handled by `ContentView` / `LibraryNavigationCoordinator`).
enum HomeModuleDestination: String, CaseIterable, Identifiable {
    case productions
    case laborSentinel
    case arcticVault
    case inventory
    case finances
    case corporateRegistry
    case insurance
    case contacts
    case sovereignAudit
    case continuityStyleVault
    case inboxTriage

    var id: String { rawValue }

    var title: String {
        switch self {
            case .productions: "Productions"
            case .laborSentinel: "Labor Sentinel"
            case .arcticVault: "Arctic Vault"
            case .inventory: "Inventory"
            case .finances: "Finances"
            case .corporateRegistry: "Corporate Registry"
            case .insurance: "Insurance"
            case .contacts: "Contacts"
            case .sovereignAudit: "Sovereign Audit"
            case .continuityStyleVault: "Style Vault"
            case .inboxTriage: "Inbox Triage"
        }
    }

    var systemImage: String {
        switch self {
            case .productions: "film.stack"
            case .laborSentinel: "shield.lefthalf.filled"
            case .arcticVault: "doc.text.fill"
            case .inventory: "shippingbox.fill"
            case .finances: "arrow.triangle.merge"
            case .corporateRegistry: "building.2.fill"
            case .insurance: "shield.checkered"
            case .contacts: "person.2.fill"
            case .sovereignAudit: "list.bullet.clipboard.fill"
            case .continuityStyleVault: "photo.on.rectangle.angled"
            case .inboxTriage: "tray.2.fill"
        }
    }

    var subtitle: String {
        switch self {
            case .productions: "Shows & registry"
            case .laborSentinel: "Timecards & Chef floor"
            case .arcticVault: "Receipt library"
            case .inventory: "Gear & rentals"
            case .finances: "Reconcile & bank"
            case .corporateRegistry: "Entities & GST"
            case .insurance: "Warranties & policies"
            case .contacts: "CRM & clients"
            case .sovereignAudit: "Forensic trail"
            case .continuityStyleVault: "Look boards & fittings"
            case .inboxTriage: "Cross-entity routing"
        }
    }
}
