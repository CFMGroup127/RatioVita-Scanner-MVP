import Foundation
import SwiftData

// MARK: - Temporal role grant (24h handoff)

@Model
final class TemporalRoleGrant {
    @Attribute(.unique) var id: UUID
    var userToken: String
    var temporaryRoleRaw: String
    var unitNodeRaw: String
    var expirationTimestamp: Date
    var issuedByToken: String
    var createdAt: Date

    init(
        userToken: String,
        temporaryRole: OperationalHatRole,
        unit: ProductionUnitNode,
        expiration: Date,
        issuedBy: String
    ) {
        id = UUID()
        self.userToken = userToken
        temporaryRoleRaw = temporaryRole.rawValue
        unitNodeRaw = unit.rawValue
        expirationTimestamp = expiration
        issuedByToken = issuedBy
        createdAt = .now
    }

    var temporaryRole: OperationalHatRole {
        get { OperationalHatRole(rawValue: temporaryRoleRaw) ?? .driver }
        set { temporaryRoleRaw = newValue.rawValue }
    }

    var unitNode: ProductionUnitNode {
        get { ProductionUnitNode(rawValue: unitNodeRaw) ?? .mainUnitAlgonquin }
        set { unitNodeRaw = newValue.rawValue }
    }

    var isActive: Bool { expirationTimestamp > .now }
}

// MARK: - First looks creative feed (does not mutate E104 continuity codes)

@Model
final class CreativeFirstLookSnapshot {
    @Attribute(.unique) var id: UUID
    var castDisplayID: String
    var sessionTag: String
    var truckSupervisorToken: String
    var productionTitle: String
    var notes: String
    var continuityCodeUntouched: String
    var capturedAt: Date

    init(
        castDisplayID: String,
        sessionTag: String,
        truckSupervisorToken: String,
        productionTitle: String,
        continuityAnchor: String = "E104-CH-1"
    ) {
        id = UUID()
        self.castDisplayID = castDisplayID
        self.sessionTag = sessionTag
        self.truckSupervisorToken = truckSupervisorToken
        self.productionTitle = productionTitle
        notes = "First look of day — continuity record unchanged."
        continuityCodeUntouched = continuityAnchor
        capturedAt = .now
    }
}

// MARK: - Multi-unit crisis node

@Model
final class ProductionUnitCrisisNode {
    @Attribute(.unique) var id: UUID
    var unitNodeRaw: String
    var crisisTierRaw: Int
    var statusLabel: String
    var fleetTrailerCount: Int
    var surplusDriverTokensJSON: String
    var inboundDriverTokensJSON: String
    var legacyLayoutTemplateID: String
    var updatedAt: Date

    init(
        unit: ProductionUnitNode,
        crisisTier: CrisisScaleTier = .nominal,
        statusLabel: String,
        fleetTrailerCount: Int = 0,
        legacyLayoutTemplateID: String = ""
    ) {
        id = UUID()
        unitNodeRaw = unit.rawValue
        crisisTierRaw = crisisTier.rawValue
        self.statusLabel = statusLabel
        self.fleetTrailerCount = fleetTrailerCount
        surplusDriverTokensJSON = "[]"
        inboundDriverTokensJSON = "[]"
        self.legacyLayoutTemplateID = legacyLayoutTemplateID
        updatedAt = .now
    }

    var unitNode: ProductionUnitNode {
        get { ProductionUnitNode(rawValue: unitNodeRaw) ?? .mainUnitAlgonquin }
        set { unitNodeRaw = newValue.rawValue }
    }

    var crisisTier: CrisisScaleTier {
        get { CrisisScaleTier(rawValue: crisisTierRaw) ?? .nominal }
        set { crisisTierRaw = newValue.rawValue }
    }

    var surplusDriverTokens: [String] {
        get { Self.decodeTokens(surplusDriverTokensJSON) }
        set { surplusDriverTokensJSON = Self.encodeTokens(newValue) }
    }

    var inboundDriverTokens: [String] {
        get { Self.decodeTokens(inboundDriverTokensJSON) }
        set { inboundDriverTokensJSON = Self.encodeTokens(newValue) }
    }

    private static func encodeTokens(_ tokens: [String]) -> String {
        (try? String(data: JSONEncoder().encode(tokens), encoding: .utf8)) ?? "[]"
    }

    private static func decodeTokens(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return decoded
    }
}

// MARK: - Passive RF beacon (indoor mesh)

@Model
final class SpatialBeaconAsset {
    @Attribute(.unique) var id: UUID
    var rfidToken: String
    var departmentOwner: String
    var floorLevel: Int
    var spatialGridX: Double
    var spatialGridY: Double
    var zoneLabel: String

    init(
        rfidToken: String,
        departmentOwner: String,
        floorLevel: Int = 0,
        spatialGridX: Double,
        spatialGridY: Double,
        zoneLabel: String
    ) {
        id = UUID()
        self.rfidToken = rfidToken
        self.departmentOwner = departmentOwner
        self.floorLevel = floorLevel
        self.spatialGridX = spatialGridX
        self.spatialGridY = spatialGridY
        self.zoneLabel = zoneLabel
    }
}

// MARK: - Live crew position token

@Model
final class SpatialCrewPosition {
    @Attribute(.unique) var id: UUID
    var userToken: String
    var displayName: String
    var unitNodeRaw: String
    var assignedDepartment: String
    var verifiedZoneID: String
    var lastSeenTimestamp: Date

    init(
        userToken: String,
        displayName: String,
        unit: ProductionUnitNode,
        department: String,
        zone: SpatialZoneID
    ) {
        id = UUID()
        self.userToken = userToken
        self.displayName = displayName
        unitNodeRaw = unit.rawValue
        assignedDepartment = department
        verifiedZoneID = zone.rawValue
        lastSeenTimestamp = .now
    }

    var unitNode: ProductionUnitNode {
        get { ProductionUnitNode(rawValue: unitNodeRaw) ?? .mainUnitAlgonquin }
        set { unitNodeRaw = newValue.rawValue }
    }

    var verifiedZone: SpatialZoneID {
        get { SpatialZoneID(rawValue: verifiedZoneID) ?? .unknown }
        set {
            verifiedZoneID = newValue.rawValue
            lastSeenTimestamp = .now
        }
    }
}
