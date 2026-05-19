import Foundation

/// Kit line on EP “Other rates” (phone, computer, vehicle, etc.).
enum ProductionKitDeviceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case phone
    case laptop
    case tablet
    case computer
    case vehicle

    var id: String { rawValue }

    /// EP-style shorthand on scanned forms (e.g. `CELL x5`, `COMPUTER x5`).
    var epOtherRatesLabel: String {
        switch self {
            case .phone: "CELL"
            case .laptop, .computer: "COMPUTER"
            case .tablet: "OSM"
            case .vehicle: "CAR"
        }
    }

    static func infer(from assetName: String) -> ProductionKitDeviceKind {
        let lower = assetName.lowercased()
        if lower.contains("phone") || lower.contains("cell") || lower.contains("iphone") { return .phone }
        if lower.contains("ipad") || lower.contains("tablet") { return .tablet }
        if lower.contains("laptop") || lower.contains("macbook") { return .laptop }
        if lower.contains("truck") || lower.contains("van") || lower.contains("car") { return .vehicle }
        return .computer
    }
}
