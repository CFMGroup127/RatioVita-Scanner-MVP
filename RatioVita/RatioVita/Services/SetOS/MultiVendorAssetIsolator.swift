import Foundation

/// Directional wand vendor filter — Western vs Eastern boot haystacks (Sprint YYY).
@MainActor
enum MultiVendorAssetIsolator {
    static func vendorSignature(in epcOrToken: String) -> String {
        let upper = epcOrToken.uppercased()
        if upper.contains("WESTERN") { return "VENDOR_WESTERN" }
        if upper.contains("EASTERN") { return "VENDOR_EASTERN" }
        if upper.contains("THUNDER") { return "VENDOR_THUNDER" }
        if upper.contains("MARLBORO") { return "VENDOR_MARLORO" }
        return "VENDOR_UNKNOWN"
    }

    static func matchesTarget(epc: String, vendorFilter: String) -> Bool {
        vendorSignature(in: epc) == vendorFilter
    }

    static func isolateTarget(
        packets: [HardwareSignalPacket],
        vendorFilter: String
    ) -> [HardwareSignalPacket] {
        packets.filter { matchesTarget(epc: $0.epcHexPayload, vendorFilter: vendorFilter) }
    }

    static func radarAudioCue(
        for packet: HardwareSignalPacket?,
        vendorFilter: String
    ) -> String {
        guard let packet, matchesTarget(epc: packet.epcHexPayload, vendorFilter: vendorFilter) else {
            return "Sweeping… no target vendor in beam."
        }
        let proximity = HardwareIngestionManager.shared.proximityClass(for: packet.signalStrengthRSSI)
        switch proximity {
            case .immediateProximity:
                return "FAST RADAR PING — target locked."
            case .midRangeZone:
                return "Ping accelerating — closing distance."
            case .distantBoundary:
                return "Faint ping — target in range boundary."
        }
    }
}
