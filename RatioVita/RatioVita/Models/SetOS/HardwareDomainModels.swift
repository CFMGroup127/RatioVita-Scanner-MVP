import Foundation
import SwiftData

enum HardwareScanSource: Int, Codable, CaseIterable, Sendable {
    case nativeCameraOptical = 0
    case externalUHFBluetooth = 1
    case fixedVehicleGateway = 2
}

enum ScanningHardwareProfile: String, Codable, CaseIterable, Sendable {
    case nativeCameraOptical = "CAMERA_VISION"
    case wearablePhaseArrayHub = "WEARABLE_VEST_UHF"
    case slimBatonDirectional = "SLIM_BATON_UHF"
    case fixedGateGateway = "VEHICLE_BUMPER_GATE"
}

enum ProximityClassification: String, Codable, Sendable {
    case immediateProximity
    case midRangeZone
    case distantBoundary
}

struct UniversalScanPayload: Identifiable, Sendable, Codable {
    var id: UUID
    var rawPayloadString: String
    var sourceMode: HardwareScanSource
    var timestamp: Date

    init(rawPayloadString: String, sourceMode: HardwareScanSource) {
        id = UUID()
        self.rawPayloadString = rawPayloadString
        self.sourceMode = sourceMode
        timestamp = .now
    }
}

struct HardwareSignalPacket: Identifiable, Sendable, Codable {
    var id: UUID
    var epcHexPayload: String
    var hardwareProfile: ScanningHardwareProfile
    var signalStrengthRSSI: Double
    var timestamp: Date

    init(
        epcHexPayload: String,
        hardwareProfile: ScanningHardwareProfile,
        signalStrengthRSSI: Double = -55
    ) {
        id = UUID()
        self.epcHexPayload = epcHexPayload
        self.hardwareProfile = hardwareProfile
        self.signalStrengthRSSI = signalStrengthRSSI
        timestamp = .now
    }
}

// MARK: - RTLS receiver mesh (Sprint YYY)

@Model
final class RTLSReceiverNode {
    @Attribute(.unique) var id: UUID
    var deviceNodeID: String
    var physicalLocationDesc: String
    var activeRadiusMeters: Double
    var isMasterSiteNode: Bool

    init(
        deviceNodeID: String,
        physicalLocationDesc: String,
        activeRadiusMeters: Double = 12,
        isMasterSiteNode: Bool = false
    ) {
        id = UUID()
        self.deviceNodeID = deviceNodeID
        self.physicalLocationDesc = physicalLocationDesc
        self.activeRadiusMeters = activeRadiusMeters
        self.isMasterSiteNode = isMasterSiteNode
    }
}

@Model
final class ActiveTransitToken {
    @Attribute(.unique) var id: UUID
    var assetOrCrewID: String
    var currentNodeID: String
    var previousNodeID: String
    var vendorRegistry: String
    var timestamp: Date

    init(
        assetOrCrewID: String,
        currentNodeID: String,
        previousNodeID: String = "",
        vendorRegistry: String = ""
    ) {
        id = UUID()
        self.assetOrCrewID = assetOrCrewID
        self.currentNodeID = currentNodeID
        self.previousNodeID = previousNodeID
        self.vendorRegistry = vendorRegistry
        timestamp = .now
    }
}
