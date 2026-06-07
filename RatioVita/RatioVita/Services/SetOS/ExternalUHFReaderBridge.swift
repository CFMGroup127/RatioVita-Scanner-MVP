import Foundation
import SwiftData

/// Bluetooth / USB UHF sled + fixed gate batch streams (Sprint WWW).
@MainActor
enum ExternalUHFReaderBridge {
    static func simulateBumperGateBurst(
        chairCount: Int = 146,
        tableCount: Int = 20,
        truckLabel: String = "CUBE-02"
    ) -> [HardwareSignalPacket] {
        var packets: [HardwareSignalPacket] = []
        for index in 1...chairCount {
            packets.append(
                HardwareSignalPacket(
                    epcHexPayload: "RFID-CHAIR-\(String(format: "%03d", index))",
                    hardwareProfile: .fixedGateGateway,
                    signalStrengthRSSI: -38
                )
            )
        }
        for index in 1...tableCount {
            packets.append(
                HardwareSignalPacket(
                    epcHexPayload: "RFID-TABLE-\(index)",
                    hardwareProfile: .fixedGateGateway,
                    signalStrengthRSSI: -42
                )
            )
        }
        for heaterIndex in 1...4 {
            packets.append(
                HardwareSignalPacket(
                    epcHexPayload: "RFID-HEAT-\(heaterIndex)",
                    hardwareProfile: .fixedGateGateway,
                    signalStrengthRSSI: -44
                )
            )
        }
        _ = truckLabel
        return packets
    }

    static func processBurst(
        context: ModelContext,
        packets: [HardwareSignalPacket],
        truckLabel: String,
        assets: [LocationsEquipmentAsset]
    ) throws -> LocationsEquipmentMeshController.BumperSweepResult? {
        let accepted = HardwareIngestionManager.shared.ingestBatch(packets)
        let optical = accepted.map {
            UniversalScanPayload(rawPayloadString: $0.epcHexPayload, sourceMode: .externalUHFBluetooth)
        }
        return try HardwareIngestionManager.shared.routeToLocationsMesh(
            context: context,
            truckLabel: truckLabel,
            payloads: optical,
            assets: assets
        )
    }
}
