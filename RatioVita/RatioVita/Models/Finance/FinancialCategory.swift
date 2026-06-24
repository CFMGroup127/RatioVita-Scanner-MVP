import Foundation

/// NLP / Finance Agent category suggestion for an atomic line item.
enum FinancialCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case botanicalLipids = "Botanical Lipids / Ingredients"
    case toolsHardware = "Tools & Hardware"
    case bulkGroceries = "Bulk Catering Sourcing"
    case propertyMaintenance = "Property Maintenance / Fixtures"
    case unknown = "Unclassified Item"

    var id: String { rawValue }

    var displayLabel: String { rawValue }
}
