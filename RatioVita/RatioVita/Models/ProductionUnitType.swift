import Foundation

/// EP budget / callsheet unit anchor for split PDF twins.
enum ProductionUnitType: String, CaseIterable, Identifiable, Codable, Sendable {
    case mainUnit = "Main Unit"
    case secondUnit = "2nd Unit"
    case splinterUnit = "Splinter Unit"
    case office = "Office"

    var id: String { rawValue }

    var epAbbreviation: String {
        switch self {
            case .mainUnit: "MAIN"
            case .secondUnit: "2ND"
            case .splinterUnit: "SPL"
            case .office: "OFF"
        }
    }

    static func fromStored(_ raw: String?) -> ProductionUnitType? {
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        if let exact = ProductionUnitType(rawValue: t) { return exact }
        let lower = t.lowercased()
        if lower.contains("splinter") { return .splinterUnit }
        if lower.contains("2nd") || lower.contains("second") { return .secondUnit }
        if lower.contains("office") { return .office }
        if lower.contains("main") { return .mainUnit }
        return nil
    }
}
