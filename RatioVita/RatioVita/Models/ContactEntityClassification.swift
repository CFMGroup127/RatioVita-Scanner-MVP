import Foundation

/// How a `ProductionContact` row participates in CRM vs payee/recipient routing.
enum ContactEntityClassification: String, Codable, CaseIterable {
    case externalVendor
    case internalOwner
    case ownedCorporateBody

    var displayTitle: String {
        switch self {
            case .externalVendor: "External vendor / client"
            case .internalOwner: "Internal owner (you)"
            case .ownedCorporateBody: "Owned corporation"
        }
    }

    var isInternalIdentity: Bool {
        switch self {
            case .externalVendor: false
            case .internalOwner, .ownedCorporateBody: true
        }
    }
}
