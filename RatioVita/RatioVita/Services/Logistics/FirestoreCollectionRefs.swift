import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Nested Firestore collection references aligned with VitaLogic `ProductionFirestorePaths`.
enum FirestoreCollectionRefs {
    static func productions() -> CollectionReference? {
        guard let db = RatioVitaFirebaseBootstrap.firestore() else { return nil }
        return db.collection("productions")
    }

    static func callSheets(productionId: String) -> CollectionReference? {
        guard let root = productions() else { return nil }
        let id = sanitizedProductionId(productionId)
        return root.document(id).collection("call_sheets")
    }

    static func transitExceptions(productionId: String, callSheetId: String) -> CollectionReference? {
        guard let sheets = callSheets(productionId: productionId) else { return nil }
        let sheetId = sanitizedDocumentId(callSheetId)
        return sheets.document(sheetId).collection("transit_exceptions")
    }

    static func ingestionLogs(productionId: String) -> CollectionReference? {
        guard let root = productions() else { return nil }
        return root.document(sanitizedProductionId(productionId)).collection("ingestion_logs")
    }

    static func productionDayState(productionId: String) -> DocumentReference? {
        guard let root = productions() else { return nil }
        return root
            .document(sanitizedProductionId(productionId))
            .collection("production_day_state")
            .document("current")
    }

    static func lookBoardAssets(productionId: String) -> CollectionReference? {
        guard let root = productions() else { return nil }
        return root.document(sanitizedProductionId(productionId)).collection("look_board_assets")
    }

    static func medicIncidents(productionId: String) -> CollectionReference? {
        guard let root = productions() else { return nil }
        return root.document(sanitizedProductionId(productionId)).collection("medic_incidents")
    }

    static func medicKitSupplies(productionId: String) -> CollectionReference? {
        guard let root = productions() else { return nil }
        return root.document(sanitizedProductionId(productionId)).collection("medic_kit_supplies")
    }

    static func medicCoverageLogs(productionId: String) -> CollectionReference? {
        guard let root = productions() else { return nil }
        return root.document(sanitizedProductionId(productionId)).collection("medic_coverage_logs")
    }

    static func lspLocationTasks(productionId: String) -> CollectionReference? {
        guard let root = productions() else { return nil }
        return root.document(sanitizedProductionId(productionId)).collection("lsp_location_tasks")
    }

    static func securityAccessLogs(productionId: String) -> CollectionReference? {
        guard let root = productions() else { return nil }
        return root.document(sanitizedProductionId(productionId)).collection("security_access_logs")
    }

    private static func sanitizedProductionId(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? "default_production" : trimmed
    }

    private static func sanitizedDocumentId(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? UUID().uuidString : trimmed
    }
}
#endif
