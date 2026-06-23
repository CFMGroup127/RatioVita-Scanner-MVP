import Foundation

/// Lightweight crew-facing mirror of VitaLogic `TransitException` documents in Firestore.
struct TransitExceptionRecord: Identifiable, Sendable {
    let id: String
    let callSheetId: String
    let descriptionNotes: String
    let affectedArterial: String
    let severity: String
    let loggedAt: Date

    var isHighwayCritical: Bool {
        let combined = (descriptionNotes + " " + affectedArterial).uppercased()
        return combined.contains("GARDINER") || combined.contains("QEW")
    }

    var crewBannerText: String {
        "⚠️ CRITICAL TRANSIT ALERT: \(descriptionNotes) — Your alarm buffers have been calculated and shifted by 45 minutes."
    }
}
