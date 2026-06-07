import Foundation
import SwiftData

// MARK: - Locations zones (physical plot anchors)

enum LocationsZoneID: String, Codable, CaseIterable, Identifiable, Sendable {
    case mainBGHolding = "MAIN_BG_HOLDING"
    case satelliteBGHolding = "SATELLITE_BG_HOLDING"
    case crewLunchArea = "CREW_LUNCH_AREA"
    case tentRowOnSet = "TENT_ROW_ON_SET"
    case cubeTruckGate = "CUBE_TRUCK_GATE"
    case baseCampServices = "BASE_CAMP_SERVICES"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .mainBGHolding: "Main BG holding"
            case .satelliteBGHolding: "Satellite BG holding"
            case .crewLunchArea: "Crew lunch area"
            case .tentRowOnSet: "Tent row · on set"
            case .cubeTruckGate: "Cube truck gate"
            case .baseCampServices: "Base camp services"
        }
    }
}

enum LocationsAssetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case chairRental = "CHAIR_RENTAL"
    case table6ft = "TABLE_6FT"
    case tent10x10 = "TENT_10X10"
    case spaceHeater = "SPACE_HEATER"
    case buttBin = "BUTT_BIN"
    case signageArrow = "SIGNAGE_ARROW"
    case sandbag = "SANDBAG"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .chairRental: "Rental chairs"
            case .table6ft: "6′ folding tables"
            case .tent10x10: "10×10 pop-up tents"
            case .spaceHeater: "Master space heaters"
            case .buttBin: "Butt bins"
            case .signageArrow: "Directional signage"
            case .sandbag: "Sandbags"
        }
    }
}

// MARK: - Tagged rental / owned gear

@Model
final class LocationsEquipmentAsset {
    @Attribute(.unique) var id: UUID
    var rfidToken: String
    var assetTypeRaw: String
    var vendorSource: String
    var lastKnownZoneID: String
    var assignedTruckLabel: String
    var isLoadedInTruck: Bool
    var lastSeenAt: Date

    init(
        rfidToken: String,
        assetType: LocationsAssetType,
        vendorSource: String = "Marlboro Rentals",
        zone: LocationsZoneID,
        truckLabel: String = ""
    ) {
        id = UUID()
        self.rfidToken = rfidToken
        assetTypeRaw = assetType.rawValue
        self.vendorSource = vendorSource
        lastKnownZoneID = zone.rawValue
        assignedTruckLabel = truckLabel
        isLoadedInTruck = false
        lastSeenAt = .now
    }

    var assetType: LocationsAssetType {
        get { LocationsAssetType(rawValue: assetTypeRaw) ?? .chairRental }
        set { assetTypeRaw = newValue.rawValue }
    }

    var lastKnownZone: LocationsZoneID {
        get { LocationsZoneID(rawValue: lastKnownZoneID) ?? .mainBGHolding }
        set {
            lastKnownZoneID = newValue.rawValue
            lastSeenAt = .now
        }
    }
}

// MARK: - Cube truck dispatch manifest (morning baseline)

@Model
final class LocationsTruckManifest {
    @Attribute(.unique) var id: UUID
    var truckLabel: String
    var productionTitle: String
    var linesJSON: String
    var createdAt: Date

    init(truckLabel: String, productionTitle: String, lines: [LocationsManifestLine] = []) {
        id = UUID()
        self.truckLabel = truckLabel
        self.productionTitle = productionTitle
        linesJSON = LocationsTruckManifest.encodeLines(lines)
        createdAt = .now
    }

    var lines: [LocationsManifestLine] {
        get { LocationsTruckManifest.decodeLines(linesJSON) }
        set { linesJSON = LocationsTruckManifest.encodeLines(newValue) }
    }

    static func encodeLines(_ lines: [LocationsManifestLine]) -> String {
        (try? String(data: JSONEncoder().encode(lines), encoding: .utf8)) ?? "[]"
    }

    static func decodeLines(_ json: String) -> [LocationsManifestLine] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([LocationsManifestLine].self, from: data) else { return [] }
        return decoded
    }
}

struct LocationsManifestLine: Codable, Sendable, Identifiable {
    var id: String { assetTypeRaw + vendorSource }
    var assetTypeRaw: String
    var expectedCount: Int
    var vendorSource: String

    var assetType: LocationsAssetType {
        LocationsAssetType(rawValue: assetTypeRaw) ?? .chairRental
    }

    init(assetType: LocationsAssetType, expectedCount: Int, vendorSource: String = "Marlboro Rentals") {
        assetTypeRaw = assetType.rawValue
        self.expectedCount = expectedCount
        self.vendorSource = vendorSource
    }
}

// MARK: - Green-zone + hotel crosswalk (LM / LAM)

@Model
final class LocationsGreenZone {
    @Attribute(.unique) var id: UUID
    var zoneName: String
    var overheadNotes: String
    var securedHotelRooms: Int
    var requiredBedCapacity: Int
    var isFavourable: Bool
    var isSelectedForFocus: Bool
    var updatedAt: Date

    init(
        zoneName: String,
        securedHotelRooms: Int,
        requiredBedCapacity: Int,
        isFavourable: Bool = false,
        overheadNotes: String = ""
    ) {
        id = UUID()
        self.zoneName = zoneName
        self.securedHotelRooms = securedHotelRooms
        self.requiredBedCapacity = requiredBedCapacity
        self.isFavourable = isFavourable
        self.overheadNotes = overheadNotes
        isSelectedForFocus = false
        updatedAt = .now
    }
}

// MARK: - PM / Showrunner macro snapshot (zero-chatter canvas)

@Model
final class ExecutiveLogisticsSnapshot {
    @Attribute(.unique) var id: UUID
    var crisisTierRaw: Int
    var activeCallSheetHeadcount: Int
    var securedHotelRoomsCount: Int
    var requiredBedCapacity: Int
    var hmwTrailersLocked: Bool
    var castShuttlesAligned: Bool
    var gennyStandby: Bool
    var transportFleetReadyCount: Int
    var transportFleetTotal: Int
    var inboundDriverCount: Int
    var locationsGreenZonesSecured: Int
    var locationsGreenZonesTotal: Int
    var updatedAt: Date

    init(
        crisisTier: CrisisScaleTier = .operationalWarning,
        headcount: Int = 312,
        securedRooms: Int = 0,
        requiredBeds: Int = 312
    ) {
        id = UUID()
        crisisTierRaw = crisisTier.rawValue
        activeCallSheetHeadcount = headcount
        securedHotelRoomsCount = securedRooms
        requiredBedCapacity = requiredBeds
        hmwTrailersLocked = false
        castShuttlesAligned = false
        gennyStandby = false
        transportFleetReadyCount = 0
        transportFleetTotal = 30
        inboundDriverCount = 0
        locationsGreenZonesSecured = 0
        locationsGreenZonesTotal = 5
        updatedAt = .now
    }

    var crisisTier: CrisisScaleTier {
        get { CrisisScaleTier(rawValue: crisisTierRaw) ?? .nominal }
        set { crisisTierRaw = newValue.rawValue }
    }
}
