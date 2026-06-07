import Combine
import Foundation

/// Immutable per-vehicle ledger. Incident + fault history is append-only by design so
/// no dishonest driver or defensive rep can rewrite the timeline after the fact (Sprint KKKK).
struct VehicleSafetyPassport: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var vin: String
    var licensePlate: String
    var makeModel: String
    var color: String
    var cvorStatusValid: Bool
    var insurancePinkSlipCaptured: Bool
    /// Open faults awaiting sign-off (loose lug nuts, cutting-out tail lights, etc.).
    var activeMechanicalFaults: [String]
    /// Locked background log array — append only, never edited or removed.
    var unalterableIncidentHistory: [String]

    init(
        id: UUID = UUID(),
        vin: String,
        licensePlate: String,
        makeModel: String = "",
        color: String = "",
        cvorStatusValid: Bool = false,
        insurancePinkSlipCaptured: Bool = false,
        activeMechanicalFaults: [String] = [],
        unalterableIncidentHistory: [String] = []
    ) {
        self.id = id
        self.vin = vin
        self.licensePlate = licensePlate
        self.makeModel = makeModel
        self.color = color
        self.cvorStatusValid = cvorStatusValid
        self.insurancePinkSlipCaptured = insurancePinkSlipCaptured
        self.activeMechanicalFaults = activeMechanicalFaults
        self.unalterableIncidentHistory = unalterableIncidentHistory
    }

    var hasOpenLiability: Bool {
        !activeMechanicalFaults.isEmpty
    }
}

enum TransportUnionLocal: String, Codable, Sendable, CaseIterable {
    case iatse = "IATSE"
    case aqtis = "AQTIS"
    case nabet = "NABET"
    case teamsters = "Teamsters"
}

/// Cross-show driver record keyed by legitimate union ID. Open incidents carry across
/// productions, so a coordinator sees the hazard before authorizing a deal memo.
struct DriverSafetyRecord: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var fullName: String
    var unionLocalRaw: String
    var unionIDNumber: String
    /// Uncleared damage incidents inherited from prior shows.
    var openIncidentFlags: [String]
    var clearedForAssignment: Bool

    init(
        id: UUID = UUID(),
        fullName: String,
        unionLocal: TransportUnionLocal,
        unionIDNumber: String,
        openIncidentFlags: [String] = [],
        clearedForAssignment: Bool = true
    ) {
        self.id = id
        self.fullName = fullName
        unionLocalRaw = unionLocal.rawValue
        self.unionIDNumber = unionIDNumber
        self.openIncidentFlags = openIncidentFlags
        self.clearedForAssignment = clearedForAssignment
    }

    var unionLocal: TransportUnionLocal {
        TransportUnionLocal(rawValue: unionLocalRaw) ?? .iatse
    }

    var hasUnclearedHazard: Bool {
        !openIncidentFlags.isEmpty || !clearedForAssignment
    }
}

/// Result returned to the Transport Coordinator console before clearing a driver assignment.
struct DriverClearanceVerdict: Sendable {
    let cleared: Bool
    let hazardBanner: String?
    let matchedRecord: DriverSafetyRecord?
}

@MainActor
final class TransportLiabilityLedger: ObservableObject {
    static let shared = TransportLiabilityLedger()

    @Published private(set) var passports: [VehicleSafetyPassport] = []
    @Published private(set) var drivers: [DriverSafetyRecord] = []

    private nonisolated static let passportKey = "setos.transport.passports.v1"
    private nonisolated static let driverKey = "setos.transport.drivers.v1"
    private let persistenceQueue = DispatchQueue(label: "com.ratiovita.transport.ledger", qos: .utility)

    private init() {
        loadFromDisk()
        if passports.isEmpty, drivers.isEmpty {
            seedDemoData()
        }
    }

    // MARK: - Vehicle passports

    func registerVehicle(_ passport: VehicleSafetyPassport) {
        if let index = passports.firstIndex(where: { $0.id == passport.id }) {
            // Preserve the immutable incident history regardless of inbound payload.
            let lockedHistory = passports[index].unalterableIncidentHistory
            var merged = passport
            merged.unalterableIncidentHistory = Array(
                Set(lockedHistory + passport.unalterableIncidentHistory)
            ).sorted()
            passports[index] = merged
        } else {
            passports.insert(passport, at: 0)
        }
        persist()
    }

    /// Append-only. The faulted vehicle's liability locks instantly to the cloud ledger.
    func logMechanicalFault(vehicleID: UUID, fault: String) {
        guard let index = passports.firstIndex(where: { $0.id == vehicleID }) else { return }
        let stamp = Self.timestamp()
        passports[index].activeMechanicalFaults.append(fault)
        passports[index].unalterableIncidentHistory.append("[\(stamp)] FAULT: \(fault)")
        persist()
    }

    func logIncident(vehicleID: UUID, summary: String) {
        guard let index = passports.firstIndex(where: { $0.id == vehicleID }) else { return }
        let stamp = Self.timestamp()
        passports[index].unalterableIncidentHistory.append("[\(stamp)] INCIDENT: \(summary)")
        persist()
    }

    func passport(forPlate plate: String) -> VehicleSafetyPassport? {
        passports.first { $0.licensePlate.caseInsensitiveCompare(plate) == .orderedSame }
    }

    // MARK: - Driver crosswalk

    func upsertDriver(_ record: DriverSafetyRecord) {
        if let index = drivers.firstIndex(where: {
            $0.unionIDNumber == record.unionIDNumber && $0.unionLocalRaw == record.unionLocalRaw
        }) {
            drivers[index] = record
        } else {
            drivers.insert(record, at: 0)
        }
        persist()
    }

    func flagDriverIncident(unionLocal: TransportUnionLocal, unionID: String, flag: String) {
        guard let index = drivers.firstIndex(where: {
            $0.unionIDNumber == unionID && $0.unionLocalRaw == unionLocal.rawValue
        }) else { return }
        drivers[index].openIncidentFlags.append("[\(Self.timestamp())] \(flag)")
        drivers[index].clearedForAssignment = false
        persist()
    }

    /// High-priority crosswalk run before a deal memo is authorized for basecamp tracking.
    func clearanceCheck(unionLocal: TransportUnionLocal, unionID: String) -> DriverClearanceVerdict {
        guard let record = drivers.first(where: {
            $0.unionIDNumber == unionID && $0.unionLocalRaw == unionLocal.rawValue
        }) else {
            return DriverClearanceVerdict(
                cleared: false,
                hazardBanner: "No verified \(unionLocal.rawValue) #\(unionID) on file — onboard before clearing.",
                matchedRecord: nil
            )
        }
        if record.hasUnclearedHazard {
            let detail = record.openIncidentFlags.last ?? "Uncleared damage log from previous show"
            return DriverClearanceVerdict(
                cleared: false,
                hazardBanner: "⚠️ HAZARD — \(record.fullName) (\(unionLocal.rawValue) #\(unionID)): \(detail)",
                matchedRecord: record
            )
        }
        return DriverClearanceVerdict(cleared: true, hazardBanner: nil, matchedRecord: record)
    }

    // MARK: - Persistence (off the UI thread)

    static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }

    private func persist() {
        let passportSnapshot = passports
        let driverSnapshot = drivers
        persistenceQueue.async {
            let defaults = UserDefaults.standard
            if let data = try? JSONEncoder().encode(passportSnapshot) {
                defaults.set(data, forKey: Self.passportKey)
            }
            if let data = try? JSONEncoder().encode(driverSnapshot) {
                defaults.set(data, forKey: Self.driverKey)
            }
        }
    }

    private func loadFromDisk() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.passportKey),
           let decoded = try? JSONDecoder().decode([VehicleSafetyPassport].self, from: data)
        {
            passports = decoded
        }
        if let data = defaults.data(forKey: Self.driverKey),
           let decoded = try? JSONDecoder().decode([DriverSafetyRecord].self, from: data)
        {
            drivers = decoded
        }
    }

    private func seedDemoData() {
        passports = [
            VehicleSafetyPassport(
                vin: "1FTBW3XM8PKA00000",
                licensePlate: "BMTP-204",
                makeModel: "Ford Transit 350 (15-pax)",
                color: "White",
                cvorStatusValid: true,
                insurancePinkSlipCaptured: true
            ),
        ]
        drivers = [
            DriverSafetyRecord(
                fullName: "Sample Driver",
                unionLocal: .teamsters,
                unionIDNumber: "T-88123",
                clearedForAssignment: true
            ),
        ]
    }
}
