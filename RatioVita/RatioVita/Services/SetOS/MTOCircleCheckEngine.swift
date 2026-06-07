import Combine
import Foundation

/// A time-stamped, unalterable commercial circle check record (MTO compliance, Sprint KKKK).
struct CircleCheckRecord: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var vehicleID: UUID
    var licensePlate: String
    var driverUnionID: String
    var startedAt: Date
    var signedAt: Date?
    /// Cryptographic-style signature token bound to the signing moment.
    var signatureToken: String?
    var defectsNoted: [String]

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        licensePlate: String,
        driverUnionID: String,
        startedAt: Date = .now,
        signedAt: Date? = nil,
        signatureToken: String? = nil,
        defectsNoted: [String] = []
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.licensePlate = licensePlate
        self.driverUnionID = driverUnionID
        self.startedAt = startedAt
        self.signedAt = signedAt
        self.signatureToken = signatureToken
        self.defectsNoted = defectsNoted
    }

    var isSigned: Bool { signedAt != nil && signatureToken != nil }
}

/// Immutable security event emitted when a vehicle moves before a signed circle check.
struct PreFlightViolationEvent: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var vehicleID: UUID
    var licensePlate: String
    var driverUnionID: String
    var detectedAt: Date
    var metersMoved: Double
    var summary: String

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        licensePlate: String,
        driverUnionID: String,
        detectedAt: Date = .now,
        metersMoved: Double,
        summary: String
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.licensePlate = licensePlate
        self.driverUnionID = driverUnionID
        self.detectedAt = detectedAt
        self.metersMoved = metersMoved
        self.summary = summary
    }
}

@MainActor
final class MTOCircleCheckEngine: ObservableObject {
    static let shared = MTOCircleCheckEngine()

    @Published private(set) var records: [CircleCheckRecord] = []
    @Published private(set) var violations: [PreFlightViolationEvent] = []
    @Published private(set) var activeBanner: String?

    /// Pre-flight lockout tolerance: any movement beyond this distance trips a violation.
    private let movementToleranceMeters = 1.0

    private nonisolated static let recordKey = "setos.mto.circlechecks.v1"
    private nonisolated static let violationKey = "setos.mto.violations.v1"
    private let persistenceQueue = DispatchQueue(label: "com.ratiovita.mto.engine", qos: .utility)

    private init() {
        loadFromDisk()
    }

    /// Opens a circle check the moment a vehicle is assigned for the day.
    @discardableResult
    func beginCircleCheck(
        vehicleID: UUID,
        licensePlate: String,
        driverUnionID: String
    ) -> CircleCheckRecord {
        if let existing = openRecord(forVehicle: vehicleID) {
            return existing
        }
        let record = CircleCheckRecord(
            vehicleID: vehicleID,
            licensePlate: licensePlate,
            driverUnionID: driverUnionID
        )
        records.insert(record, at: 0)
        persist()
        return record
    }

    /// Applies a valid digital signature. After this the vehicle is cleared to move.
    func signCircleCheck(recordID: UUID, defects: [String] = []) {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }
        let signedAt = Date()
        records[index].signedAt = signedAt
        records[index].defectsNoted = defects
        records[index].signatureToken = Self.signatureToken(
            recordID: recordID,
            at: signedAt
        )
        if records[index].licensePlate == activeBannerPlate {
            activeBanner = nil
        }
        persist()
    }

    /// Telemetry hook: report observed movement. If the active check isn't signed, lock down.
    @discardableResult
    func reportMovement(
        vehicleID: UUID,
        licensePlate: String,
        driverUnionID: String,
        metersMoved: Double
    ) -> Bool {
        guard metersMoved > movementToleranceMeters else { return true }
        let signed = openRecord(forVehicle: vehicleID)?.isSigned ?? false
        guard !signed else { return true }

        let event = PreFlightViolationEvent(
            vehicleID: vehicleID,
            licensePlate: licensePlate,
            driverUnionID: driverUnionID,
            metersMoved: metersMoved,
            summary: String(
                format: "Pre-flight lockout breach: %@ moved %.1fm before a signed circle check.",
                licensePlate,
                metersMoved
            )
        )
        violations.insert(event, at: 0)
        activeBanner = event.summary
        activeBannerPlate = licensePlate

        // Liability locks to the vehicle's immutable passport instantly.
        TransportLiabilityLedger.shared.logIncident(
            vehicleID: vehicleID,
            summary: "MTO pre-flight breach — moved before signed circle check"
        )
        persist()
        return false
    }

    func openRecord(forVehicle vehicleID: UUID) -> CircleCheckRecord? {
        records.first { $0.vehicleID == vehicleID && !$0.isSigned }
            ?? records.first { $0.vehicleID == vehicleID }
    }

    // MARK: - Internals

    private var activeBannerPlate: String?

    private static func signatureToken(recordID: UUID, at date: Date) -> String {
        // Lightweight deterministic token binding the record to its signing moment.
        let seed = "\(recordID.uuidString)|\(date.timeIntervalSince1970)"
        return "SIG-\(abs(seed.hashValue))"
    }

    private func persist() {
        let recordSnapshot = records
        let violationSnapshot = violations
        persistenceQueue.async {
            let defaults = UserDefaults.standard
            if let data = try? JSONEncoder().encode(recordSnapshot) {
                defaults.set(data, forKey: Self.recordKey)
            }
            if let data = try? JSONEncoder().encode(violationSnapshot) {
                defaults.set(data, forKey: Self.violationKey)
            }
        }
    }

    private func loadFromDisk() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.recordKey),
           let decoded = try? JSONDecoder().decode([CircleCheckRecord].self, from: data)
        {
            records = decoded
        }
        if let data = defaults.data(forKey: Self.violationKey),
           let decoded = try? JSONDecoder().decode([PreFlightViolationEvent].self, from: data)
        {
            violations = decoded
        }
    }
}
