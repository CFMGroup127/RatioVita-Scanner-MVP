import Foundation

/// Corporate registry lifecycle for a canonical production / show (`ProductionProject`).
enum ProductionRegistryStatus: String, Equatable, CaseIterable, Codable, Sendable {
    case active
    case retired

    var menuTitle: String {
        switch self {
            case .active: "Active"
            case .retired: "Retired"
        }
    }
}
