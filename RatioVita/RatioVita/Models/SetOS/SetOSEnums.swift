import Foundation

/// Geographic production node (Sprint SSS — multi-unit matrix).
enum ProductionUnitNode: String, Codable, CaseIterable, Identifiable, Sendable {
    case mainUnitAlgonquin = "MAIN_ALGONQUIN"
    case secondUnitMuskoka = "SECOND_MUSKOKA"
    case splinterThirdNode = "SPLINTER_THREE"
    case productionOffice = "OFFICE_BASE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .mainUnitAlgonquin: "Main · Algonquin"
            case .secondUnitMuskoka: "2nd · Muskoka"
            case .splinterThirdNode: "Splinter · Unit 3"
            case .productionOffice: "Production office"
        }
    }

    var defaultCrisisTier: CrisisScaleTier {
        switch self {
            case .secondUnitMuskoka: .activeEvacuation
            case .mainUnitAlgonquin: .operationalWarning
            default: .nominal
        }
    }
}

/// Field "hat" — drives perspective masking (Sprint SSS).
enum OperationalHatRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case driver
    case swamper
    case captain
    case coCaptain
    case coordinator
    case castProducerDriver
    case unitMover
    case pictureCar
    case costumeTruckSupervisor
    case costumeDesignerRemote
    case setSupervisor
    case locationsManager
    case productionManager
    case showRunner

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .driver: "Driver"
            case .swamper: "Swamper"
            case .captain: "Captain"
            case .coCaptain: "Co-Captain"
            case .coordinator: "Coordinator"
            case .castProducerDriver: "Cast / Producer driver"
            case .unitMover: "Unit mover"
            case .pictureCar: "Picture cars"
            case .costumeTruckSupervisor: "Costume truck supervisor"
            case .costumeDesignerRemote: "Designer / ACD (remote)"
            case .setSupervisor: "Set supervisor"
            case .locationsManager: "Locations manager"
            case .productionManager: "PM"
            case .showRunner: "Showrunner"
        }
    }

    var isTransportAdmin: Bool {
        switch self {
            case .captain, .coCaptain, .coordinator, .productionManager, .showRunner:
                true
            default:
                false
        }
    }

    var isCreativeMonitor: Bool {
        self == .costumeDesignerRemote || self == .setSupervisor
    }
}

enum CrisisScaleTier: Int, Codable, CaseIterable, Sendable {
    case nominal = 0
    case operationalWarning = 1
    case activeEvacuation = 2

    var label: String {
        switch self {
            case .nominal: "Nominal"
            case .operationalWarning: "Operational warning"
            case .activeEvacuation: "Active evacuation"
        }
    }
}

/// Indoor / on-set zone identifiers (Sprint UUU).
enum SpatialZoneID: String, Codable, CaseIterable, Sendable {
    case greenRoom = "GREEN_ROOM"
    case videoVillage = "VIDEO_VILLAGE"
    case baseCampTrailers = "BASE_CAMP_TRAILERS"
    case techLandSet = "TECH_LAND_SET"
    case unknown = "UNKNOWN"

    var displayLabel: String {
        switch self {
            case .greenRoom: "Green room"
            case .videoVillage: "Video Village"
            case .baseCampTrailers: "Base camp trailers"
            case .techLandSet: "Tech land · set"
            case .unknown: "Unknown"
        }
    }
}

struct VoiceIntentPayload: Codable, Sendable {
    let targetUserToken: String
    let statedLocationZoneID: String
    let actualLocationZoneID: String
    let requiresTrajectoryCorrection: Bool
    let spokenCorrection: String
}
