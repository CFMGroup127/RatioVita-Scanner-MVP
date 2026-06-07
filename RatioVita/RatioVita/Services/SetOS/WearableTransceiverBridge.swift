import Foundation

/// Wearable vest phase-array high-density simulation (Sprint XXX).
@MainActor
enum WearableTransceiverBridge {
    static func simulateVestWalkthrough(assetCount: Int = 100) -> [HardwareSignalPacket] {
        (1...assetCount).map { index in
            HardwareSignalPacket(
                epcHexPayload: "MICRO-RFID-COSTUME-\(String(format: "%04d", index))",
                hardwareProfile: .wearablePhaseArrayHub,
                signalStrengthRSSI: Double(-75 + (index % 30))
            )
        }
    }

    static func simulateRSSIApproach(targetEPC: String, steps: Int = 5) -> [HardwareSignalPacket] {
        let rssiSteps: [Double] = [-82, -72, -58, -45, -32]
        return rssiSteps.prefix(steps).map { rssi in
            HardwareSignalPacket(
                epcHexPayload: targetEPC,
                hardwareProfile: .slimBatonDirectional,
                signalStrengthRSSI: rssi
            )
        }
    }

    static func auditoryProximityCue(for classification: ProximityClassification) -> String {
        switch classification {
            case .immediateProximity: "Target acquired — immediate proximity."
            case .midRangeZone: "Signal strengthening — mid range."
            case .distantBoundary: "Target distant — continue sweep."
        }
    }
}
