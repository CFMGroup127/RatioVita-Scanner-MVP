import Foundation
import SwiftData

/// Visual craft menu row with allergy / heat metadata (VitaLogic consumer surface).
@Model
final class CraftMenuItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var ingredientBreakdown: String
    var allergenFlagsRaw: String
    /// 1–5 Scoville tier for crew transparency.
    var heatLevel: Int
    var photoAssetIdentifier: String?
    var isAvailableToday: Bool
    var sortIndex: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        ingredientBreakdown: String = "",
        allergenFlags: [String] = [],
        heatLevel: Int = 1,
        photoAssetIdentifier: String? = nil,
        isAvailableToday: Bool = true,
        sortIndex: Int = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.ingredientBreakdown = ingredientBreakdown
        allergenFlagsRaw = allergenFlags.joined(separator: ",")
        self.heatLevel = min(5, max(1, heatLevel))
        self.photoAssetIdentifier = photoAssetIdentifier
        self.isAvailableToday = isAvailableToday
        self.sortIndex = sortIndex
        self.updatedAt = updatedAt
    }

    var allergenFlags: [String] {
        get {
            allergenFlagsRaw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set { allergenFlagsRaw = newValue.joined(separator: ",") }
    }
}

enum ShuttleDeliveryStatus: String, Codable, CaseIterable {
    case draft
    case preordered
    case readyAtTruck
    case assigned
    case inTransit
    case delivered
    case cancelled
}

/// Perimeter / shuttle delivery ticket (internal Uber Eats mesh).
@Model
final class ShuttleDeliveryOrder {
    @Attribute(.unique) var id: UUID
    var crewMemberLabel: String
    var dropLocationLabel: String
    var menuItemIDsRaw: String
    var statusRaw: String
    var preorderLockedAt: Date?
    var assignedShuttleDeviceID: String?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        crewMemberLabel: String,
        dropLocationLabel: String,
        menuItemIDs: [UUID] = [],
        status: ShuttleDeliveryStatus = .draft,
        preorderLockedAt: Date? = nil,
        assignedShuttleDeviceID: String? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.crewMemberLabel = crewMemberLabel
        self.dropLocationLabel = dropLocationLabel
        menuItemIDsRaw = menuItemIDs.map(\.uuidString).joined(separator: ",")
        statusRaw = status.rawValue
        self.preorderLockedAt = preorderLockedAt
        self.assignedShuttleDeviceID = assignedShuttleDeviceID
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: ShuttleDeliveryStatus {
        get { ShuttleDeliveryStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }
}

/// Matches open shuttle orders to nearest active transit device (geofence hook — R&D).
enum ShuttleProximityMatcher {
    static func nearestShuttleID(
        truckCoordinate: (lat: Double, lon: Double),
        activeShuttleCoordinates: [(deviceID: String, lat: Double, lon: Double)]
    ) -> String? {
        guard !activeShuttleCoordinates.isEmpty else { return nil }
        return activeShuttleCoordinates.min(by: { a, b in
            distance(truckCoordinate, (a.lat, a.lon)) < distance(truckCoordinate, (b.lat, b.lon))
        })?.deviceID
    }

    private static func distance(_ a: (lat: Double, lon: Double), _ b: (lat: Double, lon: Double)) -> Double {
        let dLat = a.lat - b.lat
        let dLon = a.lon - b.lon
        return (dLat * dLat) + (dLon * dLon)
    }
}
