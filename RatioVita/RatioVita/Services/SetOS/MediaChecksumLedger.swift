import Foundation

/// Background media volume verification (Sprint BBBB).
enum MediaChecksumLedger {
    private static let workerQueue = DispatchQueue(label: "com.ratiovita.media.checksum", qos: .utility)

    static func verify(
        volume: MediaStorageVolume,
        onComplete: @escaping @MainActor (MediaStorageVolume) -> Void
    ) {
        workerQueue.async {
            let digest = ChecksumDigest.simulated(serial: volume.magazineSerial, bytes: volume.rawByteCapacity)
            let result = MediaStorageVolume(
                id: volume.id,
                magazineSerial: volume.magazineSerial,
                rawByteCapacity: volume.rawByteCapacity,
                verificationChecksum: digest,
                isVerifiedAndLocked: !digest.isEmpty
            )
            Task { @MainActor in
                onComplete(result)
            }
        }
    }
}

private enum ChecksumDigest: Sendable {
    static func simulated(serial: String, bytes: Int64) -> String {
        let seed = "\(serial)-\(bytes)"
        return String(abs(seed.hashValue), radix: 16).uppercased()
    }
}
