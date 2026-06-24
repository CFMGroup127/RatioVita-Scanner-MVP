import Foundation

/// Denormalized production-day snapshot — mirrors VitaLogic `ProductionDayStateDocument`.
struct ProductionDayStateSnapshot: Codable, Sendable {
    var productionId: String
    var lastUpdated: Date
    var sourceFiles: [String]
    var latestIngestionSummary: String?
    var activeCallSheetId: String?
    var transitExceptionSummaries: [ProductionDayTransitSnapshot]

    init(
        productionId: String,
        lastUpdated: Date = .now,
        sourceFiles: [String] = [],
        latestIngestionSummary: String? = nil,
        activeCallSheetId: String? = nil,
        transitExceptionSummaries: [ProductionDayTransitSnapshot] = []
    ) {
        self.productionId = productionId
        self.lastUpdated = lastUpdated
        self.sourceFiles = sourceFiles
        self.latestIngestionSummary = latestIngestionSummary
        self.activeCallSheetId = activeCallSheetId
        self.transitExceptionSummaries = transitExceptionSummaries
    }
}

struct ProductionDayTransitSnapshot: Codable, Sendable, Hashable {
    let id: String
    let callSheetId: String
    let descriptionNotes: String
    let affectedArterial: String
    let severity: String
    let loggedAt: Date

    func asTransitRecord() -> TransitExceptionRecord {
        TransitExceptionRecord(
            id: id,
            callSheetId: callSheetId,
            descriptionNotes: descriptionNotes,
            affectedArterial: affectedArterial,
            severity: severity,
            loggedAt: loggedAt
        )
    }
}

enum ProductionDayStateParser {
    static func parse(productionId: String, data: [String: Any]) -> ProductionDayStateSnapshot? {
        let pid = data["productionId"] as? String ?? productionId
        let lastUpdated = parseDate(data["lastUpdated"]) ?? .now
        let sourceFiles = data["sourceFiles"] as? [String] ?? []
        let latestIngestionSummary = data["latestIngestionSummary"] as? String
        let activeCallSheetId = data["activeCallSheetId"] as? String

        let transitSummaries: [ProductionDayTransitSnapshot] = (data["transitExceptionSummaries"] as? [[String: Any]] ?? [])
            .compactMap { row in
                guard let id = row["id"] as? String else { return nil }
                return ProductionDayTransitSnapshot(
                    id: id,
                    callSheetId: row["callSheetId"] as? String ?? "",
                    descriptionNotes: row["descriptionNotes"] as? String ?? "",
                    affectedArterial: row["affectedArterial"] as? String ?? "",
                    severity: row["severity"] as? String ?? "Critical_Closure",
                    loggedAt: parseDate(row["loggedAt"]) ?? .now
                )
            }

        return ProductionDayStateSnapshot(
            productionId: pid,
            lastUpdated: lastUpdated,
            sourceFiles: sourceFiles,
            latestIngestionSummary: latestIngestionSummary,
            activeCallSheetId: activeCallSheetId,
            transitExceptionSummaries: transitSummaries
        )
    }

    private static func parseDate(_ value: Any?) -> Date? {
        #if canImport(FirebaseFirestore)
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        #endif
        if let seconds = value as? TimeInterval {
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        if let seconds = value as? Double {
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        return nil
    }
}

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
