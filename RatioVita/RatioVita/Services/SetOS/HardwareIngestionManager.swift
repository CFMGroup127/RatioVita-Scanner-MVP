import Foundation
import SwiftData

/// Unified optical + UHF ingestion hub (Sprint WWW / XXX).
@MainActor
final class HardwareIngestionManager {
    static let shared = HardwareIngestionManager()

    private var recentPayloads: [String: Date] = [:]
    private let deduplicationWindow: TimeInterval = 0.5

    private init() {}

    func ingestOptical(_ raw: String) -> UniversalScanPayload? {
        ingestUniversal(UniversalScanPayload(rawPayloadString: raw, sourceMode: .nativeCameraOptical))
    }

    func ingestUHF(
        epcHex: String,
        profile: ScanningHardwareProfile,
        rssi: Double = -55
    ) -> HardwareSignalPacket? {
        let packet = HardwareSignalPacket(
            epcHexPayload: epcHex,
            hardwareProfile: profile,
            signalStrengthRSSI: rssi
        )
        guard shouldAccept(epcHex) else { return nil }
        return packet
    }

    func ingestBatch(_ packets: [HardwareSignalPacket]) -> [HardwareSignalPacket] {
        packets.filter { packet in
            ingestUHF(
                epcHex: packet.epcHexPayload,
                profile: packet.hardwareProfile,
                rssi: packet.signalStrengthRSSI
            ) != nil
        }
    }

    @discardableResult
    func ingestUniversal(_ payload: UniversalScanPayload) -> UniversalScanPayload? {
        let key = payload.rawPayloadString.uppercased()
        guard shouldAccept(key) else { return nil }
        return payload
    }

    func proximityClass(for rssi: Double) -> ProximityClassification {
        if rssi >= -40 { return .immediateProximity }
        if rssi >= -65 { return .midRangeZone }
        return .distantBoundary
    }

    func routeToLocationsMesh(
        context: ModelContext,
        truckLabel: String,
        payloads: [UniversalScanPayload],
        assets: [LocationsEquipmentAsset]
    ) throws -> LocationsEquipmentMeshController.BumperSweepResult? {
        let tokens = Set(payloads.map(\.rawPayloadString))
        let manifest = try context.fetch(FetchDescriptor<LocationsTruckManifest>())
            .first { $0.truckLabel == truckLabel }
        guard let manifest else { return nil }

        try LocationsEquipmentMeshController.applySweepToAssets(
            context: context,
            assets: assets,
            truckLabel: truckLabel,
            detectedTokens: tokens
        )

        let refreshed = try context.fetch(FetchDescriptor<LocationsEquipmentAsset>())
        return LocationsEquipmentMeshController.performBumperSweep(
            manifest: manifest,
            assets: refreshed,
            truckLabel: truckLabel
        )
    }

    private func shouldAccept(_ key: String) -> Bool {
        let now = Date()
        if let last = recentPayloads[key], now.timeIntervalSince(last) < deduplicationWindow {
            return false
        }
        recentPayloads[key] = now
        pruneStale(before: now.addingTimeInterval(-deduplicationWindow * 4))
        return true
    }

    private func pruneStale(before cutoff: Date) {
        recentPayloads = recentPayloads.filter { $0.value >= cutoff }
    }
}
