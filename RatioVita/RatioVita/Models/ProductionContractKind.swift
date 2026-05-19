import Foundation

/// How a show is billed: union timecard vs **independent contractor** invoice.
enum ProductionContractKind: String, CaseIterable, Identifiable, Codable {
    case corporateContract = "corporate"
    case personalContractor = "personal_contractor"

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
            case .corporateContract: "Corporate contract (EP / payroll)"
            case .personalContractor: "Personal contractor (invoice)"
        }
    }

    var shortTitle: String {
        switch self {
            case .corporateContract: "Corporate"
            case .personalContractor: "Contractor"
        }
    }
}
