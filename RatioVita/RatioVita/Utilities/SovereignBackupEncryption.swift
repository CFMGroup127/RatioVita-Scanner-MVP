import CryptoKit
import Foundation
import Security

/// Wraps a cleartext blob (typically a ZIP) in a **RatioVita Sovereign** envelope: random salt + AES-GCM sealed box.
/// File layout: `RVSOVEREIGN01` (12 UTF-8 bytes) + UInt32BE salt length + salt + `AES.GCM.open(combined:)`.
enum SovereignBackupEncryption {
    static let magic = Data("RVSOVEREIGN01".utf8)

    static func seal(plaintext: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw SovereignBackupEncryptionError.emptyPassword
        }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { buf in
            SecRandomCopyBytes(kSecRandomDefault, 16, buf.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw SovereignBackupEncryptionError.randomFailed
        }
        let keyMaterial = Data(password.utf8) + salt + Data("RatioVita.SovereignBackup.v1".utf8)
        let key = SymmetricKey(data: SHA256.hash(data: keyMaterial))
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw SovereignBackupEncryptionError.sealFailed
        }
        var out = Data()
        out.append(magic)
        out.appendUInt32BE(UInt32(salt.count))
        out.append(salt)
        out.append(combined)
        return out
    }

    /// Reverses `seal`: unwrap `RVSOVEREIGN01` + salt + AES-GCM `combined` box into the original cleartext ZIP bytes.
    static func unseal(sealed: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw SovereignBackupEncryptionError.emptyPassword
        }
        guard sealed.count >= magic.count + 4 + 16 + 12 else {
            throw SovereignBackupEncryptionError.invalidEnvelope
        }
        guard sealed.prefix(magic.count) == magic else {
            throw SovereignBackupEncryptionError.badMagic
        }
        var idx = magic.count
        let saltLen = Int(sealed.subdata(in: idx..<idx + 4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        idx += 4
        guard saltLen > 0, saltLen < 1_000_000, sealed.count >= idx + saltLen else {
            throw SovereignBackupEncryptionError.invalidEnvelope
        }
        let salt = sealed.subdata(in: idx..<idx + saltLen)
        idx += saltLen
        let combined = sealed.subdata(in: idx..<sealed.count)
        let keyMaterial = Data(password.utf8) + salt + Data("RatioVita.SovereignBackup.v1".utf8)
        let key = SymmetricKey(data: SHA256.hash(data: keyMaterial))
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw SovereignBackupEncryptionError.decryptFailed
        }
    }

    enum SovereignBackupEncryptionError: Error, LocalizedError {
        case emptyPassword
        case randomFailed
        case sealFailed
        case invalidEnvelope
        case badMagic
        case decryptFailed

        var errorDescription: String? {
            switch self {
                case .emptyPassword: "Choose a non-empty passphrase."
                case .randomFailed: "Could not generate random salt."
                case .sealFailed: "Could not seal archive."
                case .invalidEnvelope: "This file is not a valid Sovereign archive."
                case .badMagic: "Unrecognized Sovereign archive header."
                case .decryptFailed: "Wrong passphrase or corrupted archive."
            }
        }
    }
}

extension Data {
    fileprivate mutating func appendUInt32BE(_ v: UInt32) {
        var be = v.bigEndian
        Swift.withUnsafeBytes(of: &be) { append(contentsOf: $0) }
    }
}
