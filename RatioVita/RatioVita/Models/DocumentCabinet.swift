import Foundation

/// Future **Cabinet** hierarchy (Vehicles / Equipment / Tools). Sidebar entries are placeholders until filing rules
/// land.
enum DocumentCabinet: String, CaseIterable, Identifiable, Hashable {
    case vehicles
    case equipment
    case tools
    case supplies
    case kits

    var id: String { rawValue }

    var title: String {
        switch self {
            case .vehicles: "Vehicles"
            case .equipment: "Equipment"
            case .tools: "Tools"
            case .supplies: "Supplies"
            case .kits: "Kits"
        }
    }

    var systemImage: String {
        switch self {
            case .vehicles: "car.fill"
            case .equipment: "wrench.and.screwdriver.fill"
            case .tools: "hammer.fill"
            case .supplies: "shippingbox.fill"
            case .kits: "case.fill"
        }
    }

    var detailHeadline: String {
        "Cabinet: \(title)"
    }

    var detailCopy: String {
        switch self {
            case .vehicles:
                "Vehicle-related receipts, insurance, and plate records for payroll kit / car allowances."
            case .equipment:
                "Grip, electric, and rental equipment paperwork will live here once cabinet routing is enabled."
            case .tools:
                "Tooling and small-asset purchases will map here for production and facility ops."
            case .supplies:
                "Consumables (printer ink, breakdown supplies, notions) tracked for loss and replacement."
            case .kits:
                "Named costume-truck / office kits built from Equipment, Tools, and Supplies for deal-memo rentals."
        }
    }
}
