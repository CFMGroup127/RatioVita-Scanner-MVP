import CryptoKit
import Foundation

/// Deterministic sovereign identifiers — device-independent SPID and production PUID strings.
enum SovereignIdentifierService {
    static func userSPID(from publicKey: Curve25519.Signing.PublicKey) -> String {
        let digest = SHA256.hash(data: publicKey.rawRepresentation)
        let bytes = Array(digest.prefix(8))
        let a = bytes.prefix(4).map { String(format: "%02X", $0) }.joined()
        let b = bytes.dropFirst(4).prefix(4).map { String(format: "%02X", $0) }.joined()
        return "SPID-\(a)-\(b)"
    }

    /// Example: `PROD-FP-2026-0304` for a Flashpoint wet-weather call on 2026-03-04.
    static func productionPUID(showTitle: String, workDate: Date, calendar: Calendar = .current) -> String {
        let slug = showTitle
            .uppercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .first
            .map(String.init) ?? "SHOW"
        let compact = String(slug.filter(\.isLetter).prefix(6))
        let day = calendar.dateComponents([.year, .month, .day], from: workDate)
        let y = day.year ?? 0
        let m = day.month ?? 0
        let d = day.day ?? 0
        return String(format: "PROD-%@-%04d-%02d%02d", compact.isEmpty ? "SHOW" : compact, y, m, d)
    }

    static func shortTransactionSerial(from spid: String) -> String {
        let hash = SHA256.hash(data: Data(spid.utf8))
        return hash.prefix(5).map { String(format: "%02X", $0) }.joined()
    }
}
