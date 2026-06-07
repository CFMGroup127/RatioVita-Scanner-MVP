import Foundation
import SwiftData

// MARK: - Call sheet day package

@Model
final class ProductionCallSheetDay {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var sheetDate: Date
    var productionTitle: String
    var mainLocationName: String
    var mainLatitude: Double?
    var mainLongitude: Double?
    var crewCallHour: Int?
    var crewCallMinute: Int?
    var pickupHubsJSON: String
    var safetyNotesJSON: String
    var isRainDay: Bool
    var isInsuranceDay: Bool
    var distributedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        productionProjectID: UUID? = nil,
        sheetDate: Date,
        productionTitle: String = "",
        mainLocationName: String = "",
        mainLatitude: Double? = nil,
        mainLongitude: Double? = nil,
        crewCallHour: Int? = nil,
        crewCallMinute: Int? = nil,
        pickupHubs: [String] = [],
        safetyNotes: [String] = [],
        isRainDay: Bool = false,
        isInsuranceDay: Bool = false,
        distributedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.productionProjectID = productionProjectID
        self.sheetDate = sheetDate
        self.productionTitle = productionTitle
        self.mainLocationName = mainLocationName
        self.mainLatitude = mainLatitude
        self.mainLongitude = mainLongitude
        self.crewCallHour = crewCallHour
        self.crewCallMinute = crewCallMinute
        pickupHubsJSON = (try? String(data: JSONEncoder().encode(pickupHubs), encoding: .utf8)) ?? "[]"
        safetyNotesJSON = (try? String(data: JSONEncoder().encode(safetyNotes), encoding: .utf8)) ?? "[]"
        self.isRainDay = isRainDay
        self.isInsuranceDay = isInsuranceDay
        self.distributedAt = distributedAt
        self.createdAt = createdAt
    }

    var pickupHubs: [String] {
        get { decodeStringArray(pickupHubsJSON) }
        set { pickupHubsJSON = encodeStringArray(newValue) }
    }

    var safetyNotes: [String] {
        get { decodeStringArray(safetyNotesJSON) }
        set { safetyNotesJSON = encodeStringArray(newValue) }
    }
}

// MARK: - Live shuttle / vehicle run

struct LocationWaypointPayload: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var sequenceOrder: Int
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        sequenceOrder: Int,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.sequenceOrder = sequenceOrder
        self.isCompleted = isCompleted
    }
}

@Model
final class TransportVehicleRun {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var driverName: String
    var driverRoleRaw: String
    var vehicleDescription: String
    var licensePlate: String
    var statusLabel: String
    var progressPercent: Double
    var etaMinutes: Int
    var passengersBooked: Int
    var passengersCheckedIn: Int
    var waypointsJSON: String
    var trafficDelayMinutes: Int
    var isEmergency: Bool
    var updatedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        productionProjectID: UUID? = nil,
        driverName: String,
        driverRole: TransportCrewRole = .driver,
        vehicleDescription: String = "Passenger van",
        licensePlate: String = "",
        statusLabel: String = "En route",
        progressPercent: Double = 0,
        etaMinutes: Int = 0,
        passengersBooked: Int = 0,
        passengersCheckedIn: Int = 0,
        waypoints: [LocationWaypointPayload] = [],
        trafficDelayMinutes: Int = 0,
        isEmergency: Bool = false
    ) {
        self.id = id
        self.productionProjectID = productionProjectID
        self.driverName = driverName
        driverRoleRaw = driverRole.rawValue
        self.vehicleDescription = vehicleDescription
        self.licensePlate = licensePlate
        self.statusLabel = statusLabel
        self.progressPercent = progressPercent
        self.etaMinutes = etaMinutes
        self.passengersBooked = passengersBooked
        self.passengersCheckedIn = passengersCheckedIn
        waypointsJSON = (try? String(data: JSONEncoder().encode(waypoints), encoding: .utf8)) ?? "[]"
        self.trafficDelayMinutes = trafficDelayMinutes
        self.isEmergency = isEmergency
        updatedAt = .now
        createdAt = .now
    }

    var driverRole: TransportCrewRole {
        get { TransportCrewRole(rawValue: driverRoleRaw) ?? .driver }
        set { driverRoleRaw = newValue.rawValue }
    }

    var waypoints: [LocationWaypointPayload] {
        get {
            guard let data = waypointsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([LocationWaypointPayload].self, from: data) else { return [] }
            return decoded
        }
        set {
            waypointsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
            updatedAt = .now
        }
    }
}

enum TransportCrewRole: String, Codable, CaseIterable {
    case coordinator
    case captain
    case driver
    case wagonDriver
    case swamper
}

// MARK: - Cross-venture chain of custody

enum AssetChainOfCustodyState: Int, Codable, CaseIterable {
    case preparedAtKitchen = 0
    case transferredToTransit = 1
    case arrivedAtLocationHub = 2
    case handedToSetPA = 3
    case deliveredToChair = 4
}

@Model
final class CrossVentureOrderTicket {
    @Attribute(.unique) var id: UUID
    var itemDescription: String
    var sourceEntityID: String
    var targetProductionID: String?
    var currentHolderLabel: String
    var statusRaw: Int
    var recipientName: String
    var updatedAt: Date
    var createdAt: Date

    init(
        itemDescription: String,
        sourceEntityID: String = "176_YONGE",
        targetProductionID: String? = nil,
        currentHolderLabel: String = "Kitchen",
        status: AssetChainOfCustodyState = .preparedAtKitchen,
        recipientName: String = ""
    ) {
        id = UUID()
        self.itemDescription = itemDescription
        self.sourceEntityID = sourceEntityID
        self.targetProductionID = targetProductionID
        self.currentHolderLabel = currentHolderLabel
        statusRaw = status.rawValue
        self.recipientName = recipientName
        updatedAt = .now
        createdAt = .now
    }

    var status: AssetChainOfCustodyState {
        get { AssetChainOfCustodyState(rawValue: statusRaw) ?? .preparedAtKitchen }
        set { statusRaw = newValue.rawValue }
    }
}

// MARK: - Comms queue

enum CommPriorityLevel: Int, Codable, CaseIterable {
    case standard = 0
    case operationalUrgent = 1
    case infrastructureCritical = 2
    case callSheetDistribution = 3
}

@Model
final class CrewCommsNotice {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var senderRole: String
    var priorityRaw: Int
    var targetDepartment: String?
    var wasDelivered: Bool
    var wasQueuedDuringDND: Bool
    var createdAt: Date

    init(
        title: String,
        body: String,
        senderRole: String = "Production",
        priority: CommPriorityLevel = .standard,
        targetDepartment: String? = nil,
        wasDelivered: Bool = false,
        wasQueuedDuringDND: Bool = false
    ) {
        id = UUID()
        self.title = title
        self.body = body
        self.senderRole = senderRole
        priorityRaw = priority.rawValue
        self.targetDepartment = targetDepartment
        self.wasDelivered = wasDelivered
        self.wasQueuedDuringDND = wasQueuedDuringDND
        createdAt = .now
    }

    var priority: CommPriorityLevel {
        get { CommPriorityLevel(rawValue: priorityRaw) ?? .standard }
        set { priorityRaw = newValue.rawValue }
    }
}

private func decodeStringArray(_ json: String) -> [String] {
    guard let data = json.data(using: .utf8),
          let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return decoded
}

private func encodeStringArray(_ values: [String]) -> String {
    (try? String(data: JSONEncoder().encode(values), encoding: .utf8)) ?? "[]"
}
