import Foundation

/// Three-tier UI archetype (Sprint AAAA — contextual role matrix).
enum StructuralRankTier: Int, Codable, Comparable, Sendable {
    case fieldCrew = 1
    case departmentHead = 2
    case administrative = 3

    static func < (lhs: StructuralRankTier, rhs: StructuralRankTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
            case .fieldCrew: "Field · Level 1"
            case .departmentHead: "Strategic · Level 2"
            case .administrative: "Administrative · Level 3"
        }
    }
}

struct DepartmentContextHat: Identifiable, Codable, Sendable {
    var id: UUID
    var department: String
    var tier: StructuralRankTier
    var assignedRoleTitle: String

    init(
        id: UUID = UUID(),
        department: String,
        tier: StructuralRankTier,
        assignedRoleTitle: String
    ) {
        self.id = id
        self.department = department
        self.tier = tier
        self.assignedRoleTitle = assignedRoleTitle
    }
}

enum ActiveUnionGuild: String, Codable, CaseIterable, Identifiable, Sendable {
    case dgc = "DIRECTORS_GUILD_CANADA"
    case iatse411 = "LOGISTICS_OFFICE_411"
    case iatse873 = "TECHNICAL_CREW_873"
    case iatse667 = "CAMERA_CINEMATOGRAPHY_667"
    case nabet700 = "BROADCAST_TECHNICAL_700"
    case actra = "ACTRA_TALENT"
    case mobileCraft = "MOBILE_CRAFT_CATERING"
    case facility176 = "176_YONGE_FACILITY"
    case vitalogic = "VITALOGIC_CORE_ADMIN"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .dgc: "DGC"
            case .iatse411: "IATSE 411"
            case .iatse873: "IATSE 873"
            case .iatse667: "IATSE 667"
            case .nabet700: "NABET 700"
            case .actra: "ACTRA / Talent"
            case .mobileCraft: "Mobile Craft & Catering"
            case .facility176: "176 Yonge Facility"
            case .vitalogic: "VitaLogic Admin"
        }
    }
}

enum MacroTenantDomain: String, Codable, CaseIterable, Identifiable, Sendable {
    case technicalCrews = "TECHNICAL_CREW_GUILDS"
    case performerGuilds = "ACTRA_TALENT_AGENTS"
    case commercialCulinary = "MOBILE_CRAFT_CATERING"
    case realEstateFacility = "176_YONGE_FACILITY"
    case systemArchitecture = "VITALOGIC_CORE_ADMIN"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .technicalCrews: "Technical crew guilds"
            case .performerGuilds: "Performers & agents"
            case .commercialCulinary: "Commercial culinary fleet"
            case .realEstateFacility: "Facility & real estate"
            case .systemArchitecture: "Platform administration"
        }
    }
}

struct UserPersonaProfile: Identifiable, Codable, Sendable {
    var id: UUID
    var assignedGuild: ActiveUnionGuild
    var positionTitle: String
    var rankTier: StructuralRankTier
    var departmentCategory: String
    var operationalHatRaw: String

    var operationalHat: OperationalHatRole {
        OperationalHatRole(rawValue: operationalHatRaw) ?? .driver
    }

    init(
        id: UUID = UUID(),
        assignedGuild: ActiveUnionGuild,
        positionTitle: String,
        rankTier: StructuralRankTier,
        departmentCategory: String,
        operationalHat: OperationalHatRole
    ) {
        self.id = id
        self.assignedGuild = assignedGuild
        self.positionTitle = positionTitle
        self.rankTier = rankTier
        self.departmentCategory = departmentCategory
        operationalHatRaw = operationalHat.rawValue
    }
}

struct ExtendedTenantProfile: Identifiable, Codable, Sendable {
    var id: UUID
    var activeDomain: MacroTenantDomain
    var organizationName: String
    var administrativeClearanceLevel: Int
}

enum CameraCategoryProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case directorOfPhotography = "DP_CINEMATOGRAPHER"
    case cameraOperator = "CAM_OPERATOR"
    case firstAssistantCamera = "1AC_FOCUS_PULLER"
    case secondAssistantCamera = "2AC_CLAPPER_LOADER"
    case digitalImagingTechnician = "DIT_ENGINEER"
    case unitPublicist = "UNIT_PUBLICIST"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .directorOfPhotography: "Director of Photography"
            case .cameraOperator: "Camera operator"
            case .firstAssistantCamera: "1st AC · Focus"
            case .secondAssistantCamera: "2nd AC · Loader"
            case .digitalImagingTechnician: "DIT"
            case .unitPublicist: "Unit publicist"
        }
    }
}

struct MediaStorageVolume: Identifiable, Codable, Sendable {
    var id: UUID
    var magazineSerial: String
    var rawByteCapacity: Int64
    var verificationChecksum: String
    var isVerifiedAndLocked: Bool
}

enum CaucusClassification: String, Codable, CaseIterable, Identifiable, Sendable {
    case productionCoordinator = "OFFICE_PC"
    case officePA = "OFFICE_PA"
    case craftserviceProvider = "SET_CRAFT_SERVICE"
    case honeywagonOperator = "FLEET_HONEYWAGON"

    var id: String { rawValue }
}

struct LegalClearanceAsset: Identifiable, Codable, Sendable {
    var id: UUID
    var brandName: String
    var assetContextDescription: String
    var isLegalClearanceApproved: Bool
    var boundDepartmentHat: String
}

struct HoneywagonTrailerStatus: Identifiable, Codable, Sendable {
    var id: UUID
    var trailerUnitID: String
    var greywaterTankLevel: Double
    var activePowerSource: String
    var climateTemperatureCelsius: Double
}
