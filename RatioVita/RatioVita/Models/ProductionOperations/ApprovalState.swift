import Foundation

/// Linear authorization machine for timesheets, POs, and on-set run tickets.
enum ApprovalState: Int, Codable, CaseIterable, Sendable {
    case drafted = 0
    case departmentHeadVerified = 1
    case productionManagerAuthorized = 2
    case accountingCleared = 3
    case rejected = 4

    var menuTitle: String {
        switch self {
            case .drafted: "Draft"
            case .departmentHeadVerified: "Dept head signed"
            case .productionManagerAuthorized: "PM authorized"
            case .accountingCleared: "Accounting cleared"
            case .rejected: "Rejected"
        }
    }
}

enum OrderUrgency: String, Codable, CaseIterable, Sendable {
    case standardReload = "Standard Reload"
    case castSpecialRequest = "Cast/Director Premium"
    case setEmergencyRun = "Set Emergency Run"
    case pmBulkRequest = "PM Bulk Request"
}

enum SupplyListKind: String, Codable, CaseIterable, Sendable {
    case loadList = "Load List"
    case buyAndLoad = "Buy and Load"
}

enum TransportVehicleScale: String, Codable, CaseIterable, Sendable {
    case passengerVan = "Passenger Van"
    case cubeTruck = "Cube Truck"
    case stakeTruck = "Stake Truck"
    case sedan = "Sedan"
}

enum ShuttleLoadProfile: String, Codable, CaseIterable, Sendable {
    case solo = "Just Me"
    case mePlusGear = "Me + Light Gear"
    case mePlusHeavyRacks = "Me + Heavy Racks"
}
