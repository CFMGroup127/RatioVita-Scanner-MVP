import Foundation
import SwiftData

// MARK: - Set Medic (Medic Core)

enum MedicIncidentSeverity: String, Codable, CaseIterable {
    case minor
    case moderate
    case urgent
    case emergencyTransport
}

enum MedicCoveragePhase: String, Codable, CaseIterable {
    case rigging
    case shooting
    case derigging
    case standby
}

/// Timestamped on-set treatment / incident log — generates production-compliant PDF dispatch.
@Model
final class MedicTreatmentIncident {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var incidentAt: Date
    var locationLabel: String
    /// Role label only — no PHI stored in free-text subject fields.
    var subjectRoleLabel: String
    var injurySummary: String
    var treatmentSummary: String
    var medicName: String
    var severityRaw: String
    var pdfReportGeneratedAt: Date?
    var createdAt: Date

    init(
        productionProjectID: UUID? = nil,
        incidentAt: Date = .now,
        locationLabel: String = "",
        subjectRoleLabel: String = "",
        injurySummary: String = "",
        treatmentSummary: String = "",
        medicName: String = "",
        severity: MedicIncidentSeverity = .minor,
        pdfReportGeneratedAt: Date? = nil
    ) {
        id = UUID()
        self.productionProjectID = productionProjectID
        self.incidentAt = incidentAt
        self.locationLabel = locationLabel
        self.subjectRoleLabel = subjectRoleLabel
        self.injurySummary = injurySummary
        self.treatmentSummary = treatmentSummary
        self.medicName = medicName
        severityRaw = severity.rawValue
        self.pdfReportGeneratedAt = pdfReportGeneratedAt
        createdAt = .now
    }

    var severity: MedicIncidentSeverity {
        get { MedicIncidentSeverity(rawValue: severityRaw) ?? .minor }
        set { severityRaw = newValue.rawValue }
    }
}

/// Mobile trauma kit / restricted supply with expiration tracking.
@Model
final class MedicKitSupplyItem {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var itemName: String
    var skuLabel: String
    var quantityOnHand: Int
    var expirationDate: Date?
    var reorderThreshold: Int
    var lastAuditedAt: Date?
    var createdAt: Date

    init(
        productionProjectID: UUID? = nil,
        itemName: String,
        skuLabel: String = "",
        quantityOnHand: Int = 0,
        expirationDate: Date? = nil,
        reorderThreshold: Int = 1,
        lastAuditedAt: Date? = nil
    ) {
        id = UUID()
        self.productionProjectID = productionProjectID
        self.itemName = itemName
        self.skuLabel = skuLabel
        self.quantityOnHand = quantityOnHand
        self.expirationDate = expirationDate
        self.reorderThreshold = reorderThreshold
        self.lastAuditedAt = lastAuditedAt
        createdAt = .now
    }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }

    var needsReorder: Bool { quantityOnHand <= reorderThreshold }
}

/// Continuous medic coverage across rigging, shooting, and de-rigging.
@Model
final class MedicCoverageInterval {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var medicName: String
    var coveragePhaseRaw: String
    var locationLabel: String
    var startedAt: Date
    var endedAt: Date?
    var createdAt: Date

    init(
        productionProjectID: UUID? = nil,
        medicName: String,
        coveragePhase: MedicCoveragePhase = .shooting,
        locationLabel: String = "",
        startedAt: Date = .now,
        endedAt: Date? = nil
    ) {
        id = UUID()
        self.productionProjectID = productionProjectID
        self.medicName = medicName
        coveragePhaseRaw = coveragePhase.rawValue
        self.locationLabel = locationLabel
        self.startedAt = startedAt
        self.endedAt = endedAt
        createdAt = .now
    }

    var coveragePhase: MedicCoveragePhase {
        get { MedicCoveragePhase(rawValue: coveragePhaseRaw) ?? .shooting }
        set { coveragePhaseRaw = newValue.rawValue }
    }

    var isActive: Bool { endedAt == nil }
}

// MARK: - Location Support Personnel (LSP Track)

enum LSPTaskKind: String, Codable, CaseIterable {
    case coning
    case gearWatch
    case paSupport
    case truckLane
    case layoutAssist
}

enum LSPTaskStatus: String, Codable, CaseIterable {
    case open
    case assigned
    case inProgress
    case complete
}

struct LSPLayoutPinPayload: Codable, Identifiable, Sendable {
    var id: UUID
    var label: String
    var latitude: Double
    var longitude: Double
    var notes: String

    init(
        id: UUID = UUID(),
        label: String,
        latitude: Double,
        longitude: Double,
        notes: String = ""
    ) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
    }
}

/// Dynamic location tasking — coning, gear watch, permit-linked layout pins.
@Model
final class LSPLocationTask {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var taskKindRaw: String
    var title: String
    var assignedLSPName: String
    var permitReference: String
    var layoutPinsJSON: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        productionProjectID: UUID? = nil,
        taskKind: LSPTaskKind = .coning,
        title: String,
        assignedLSPName: String = "",
        permitReference: String = "",
        layoutPins: [LSPLayoutPinPayload] = [],
        status: LSPTaskStatus = .open
    ) {
        id = UUID()
        self.productionProjectID = productionProjectID
        taskKindRaw = taskKind.rawValue
        self.title = title
        self.assignedLSPName = assignedLSPName
        self.permitReference = permitReference
        layoutPinsJSON = Self.encodePins(layoutPins)
        statusRaw = status.rawValue
        createdAt = .now
        updatedAt = .now
    }

    var taskKind: LSPTaskKind {
        get { LSPTaskKind(rawValue: taskKindRaw) ?? .coning }
        set { taskKindRaw = newValue.rawValue; updatedAt = .now }
    }

    var status: LSPTaskStatus {
        get { LSPTaskStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue; updatedAt = .now }
    }

    var layoutPins: [LSPLayoutPinPayload] {
        get { Self.decodePins(layoutPinsJSON) }
        set { layoutPinsJSON = Self.encodePins(newValue); updatedAt = .now }
    }

    private static func encodePins(_ pins: [LSPLayoutPinPayload]) -> String {
        (try? String(data: JSONEncoder().encode(pins), encoding: .utf8)) ?? "[]"
    }

    private static func decodePins(_ json: String) -> [LSPLayoutPinPayload] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([LSPLayoutPinPayload].self, from: data) else { return [] }
        return decoded
    }
}

// MARK: - Dedicated Security Track

enum SecurityLogKind: String, Codable, CaseIterable {
    case guardShift
    case vehicleLockup
    case perimeterCheck
    case facilityAccess
    case assetCustodyHandoff
}

/// Pure asset protection — guard logs, lock-ups, perimeter verification.
@Model
final class SecurityAccessLog {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var logKindRaw: String
    var locationLabel: String
    var officerName: String
    var shiftStartedAt: Date
    var shiftEndedAt: Date?
    var verifiedAt: Date?
    var notes: String
    var createdAt: Date

    init(
        productionProjectID: UUID? = nil,
        logKind: SecurityLogKind = .guardShift,
        locationLabel: String = "",
        officerName: String = "",
        shiftStartedAt: Date = .now,
        shiftEndedAt: Date? = nil,
        verifiedAt: Date? = nil,
        notes: String = ""
    ) {
        id = UUID()
        self.productionProjectID = productionProjectID
        logKindRaw = logKind.rawValue
        self.locationLabel = locationLabel
        self.officerName = officerName
        self.shiftStartedAt = shiftStartedAt
        self.shiftEndedAt = shiftEndedAt
        self.verifiedAt = verifiedAt
        self.notes = notes
        createdAt = .now
    }

    var logKind: SecurityLogKind {
        get { SecurityLogKind(rawValue: logKindRaw) ?? .guardShift }
        set { logKindRaw = newValue.rawValue }
    }

    var isShiftOpen: Bool { shiftEndedAt == nil }
}
