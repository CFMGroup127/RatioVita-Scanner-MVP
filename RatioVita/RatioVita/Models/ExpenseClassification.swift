import Foundation

/// High-volume production spend tiers (New Horizons / CapEx pipeline).
enum ExpenseClassification: String, CaseIterable, Codable, Sendable, Identifiable {
    case crewField = "Crew Field"
    case capitalExpenditure = "Capital Expenditure (CapEx)"
    case culinaryLogistics = "Culinary Logistics"
    case mediaInfrastructure = "Media Infrastructure"
    case commercialVendorPO = "Commercial Vendor / PO"

    var id: String { rawValue }

    static func fromStored(_ raw: String?) -> ExpenseClassification? {
        guard let raw, !raw.isEmpty else { return nil }
        return ExpenseClassification(rawValue: raw)
    }
}
