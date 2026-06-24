import Foundation

/// Hub-scoped sidebar destinations for Column 1 progressive visibility.
enum SovereignSidebarCatalog {

    enum Item: String, CaseIterable, Identifiable, Hashable {
        case operationsCommand
        case expertProgram
        case home
        case productions
        case receipts
        case timeline
        case laborSentinel
        case timeSheets
        case mediaCore
        case fieldOps
        case contacts
        case myCorporations
        case review
        case reconciliation
        case bankImport
        case trash
        case importScan
        case inboxTriage
        case inventory
        case insuranceVault

        var id: String { rawValue }

        var title: String {
            switch self {
            case .operationsCommand: "Dispatch & approvals"
            case .expertProgram: "Expert program"
            case .home: "Home"
            case .productions: "Productions"
            case .receipts: "Receipts feed"
            case .timeline: "Timeline"
            case .laborSentinel: "Labor Sentinel"
            case .timeSheets: "Time & billing"
            case .mediaCore: "Personal media"
            case .fieldOps: "Field ops"
            case .contacts: "Contacts"
            case .myCorporations: "Corporate registry"
            case .review: "Review"
            case .reconciliation: "Expense matrix"
            case .bankImport: "Vault banking"
            case .trash: "Trash"
            case .importScan: "Import"
            case .inboxTriage: "Inbox triage"
            case .inventory: "Inventory & kit"
            case .insuranceVault: "Policies & warranties"
            }
        }

        var systemImage: String {
            switch self {
            case .operationsCommand: "checkmark.seal.fill"
            case .expertProgram: "person.badge.shield.checkmark.fill"
            case .home: "square.grid.2x2.fill"
            case .productions: "film.stack"
            case .receipts: "doc.text.fill"
            case .timeline: "calendar.day.timeline.left"
            case .laborSentinel: "shield.lefthalf.filled"
            case .timeSheets: "calendar.day.timeline.left"
            case .mediaCore: "waveform.circle"
            case .fieldOps: "car.2.fill"
            case .contacts: "person.2"
            case .myCorporations: "building.2.crop.circle"
            case .review: "tray.full"
            case .reconciliation: "arrow.triangle.merge"
            case .bankImport: "building.columns.fill"
            case .trash: "trash"
            case .importScan: "square.and.arrow.down.on.square"
            case .inboxTriage: "tray.2.fill"
            case .inventory: "shippingbox.fill"
            case .insuranceVault: "shield.checkered"
            }
        }
    }

    static func baseItems(for hub: SovereignHubKind) -> [Item] {
        switch hub {
        case .personal:
            return [
                .home, .receipts, .inboxTriage, .review, .reconciliation,
                .bankImport, .mediaCore, .trash, .importScan,
            ]
        case .ventures:
            return [
                .home, .receipts, .inboxTriage, .reconciliation,
                .laborSentinel, .timeSheets, .bankImport,
            ]
        case .production:
            return [
                .home, .productions, .timeline, .laborSentinel, .fieldOps,
                .operationsCommand, .expertProgram, .inboxTriage,
            ]
        }
    }

    static func extensionItems(for hub: SovereignHubKind) -> [Item] {
        SovereignLedgerExtensionStore.enabled(for: hub).flatMap { ext in
            switch ext {
            case .advancedAssets:
                return [Item.insuranceVault, .inventory]
            case .toolInventoryTracking:
                return [.inventory, .fieldOps]
            case .productionKitPullForward:
                return [.inventory, .laborSentinel]
            }
        }
    }

    static func visibleItems(for hub: SovereignHubKind) -> [Item] {
        var ordered = baseItems(for: hub)
        for item in extensionItems(for: hub) where !ordered.contains(item) {
            ordered.append(item)
        }
        return ordered
    }

    static func showsContactsSection(for hub: SovereignHubKind) -> Bool {
        hub != .production
    }

    static func showsCabinetsSection(for hub: SovereignHubKind) -> Bool {
        hub == .personal || hub == .ventures
    }
}
