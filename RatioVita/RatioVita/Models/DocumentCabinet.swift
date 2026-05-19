import Foundation

/// Future **Cabinet** hierarchy (Vehicles / Equipment / Tools). Sidebar entries are placeholders until filing rules
/// land.
enum DocumentCabinet: String, CaseIterable, Identifiable, Hashable {
    case vehicles
    case equipment
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
            case .vehicles: "Vehicles"
            case .equipment: "Equipment"
            case .tools: "Tools"
        }
    }

    var systemImage: String {
        switch self {
            case .vehicles: "car.fill"
            case .equipment: "wrench.and.screwdriver.fill"
            case .tools: "hammer.fill"
        }
    }

    var detailHeadline: String {
        "Cabinet: \(title)"
    }

    var detailCopy: String {
        switch self {
            case .vehicles:
                "Vehicle-related receipts and maintenance logs will file here. This cabinet is a placeholder for the upcoming folder hierarchy."
            case .equipment:
                "Grip, electric, and rental equipment paperwork will live here once cabinet routing is enabled."
            case .tools:
                "Tooling and small-asset purchases will map here for production and facility ops."
        }
    }
}
