import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Nested Firestore collection references aligned with VitaLogic `ProductionFirestorePaths`.
enum FirestoreCollectionRefs {
    static func productions(_ db: Firestore = Firestore.firestore()) -> CollectionReference {
        db.collection("productions")
    }

    static func callSheets(productionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        productions(db).document(productionId).collection("call_sheets")
    }

    static func transitExceptions(
        productionId: String,
        callSheetId: String,
        db: Firestore = Firestore.firestore()
    ) -> CollectionReference {
        callSheets(productionId: productionId, db: db).document(callSheetId).collection("transit_exceptions")
    }

    static func ingestionLogs(productionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        productions(db).document(productionId).collection("ingestion_logs")
    }

    static func lookBoardAssets(productionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        productions(db).document(productionId).collection("look_board_assets")
    }

    static func medicIncidents(productionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        productions(db).document(productionId).collection("medic_incidents")
    }

    static func medicKitSupplies(productionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        productions(db).document(productionId).collection("medic_kit_supplies")
    }

    static func medicCoverageLogs(productionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        productions(db).document(productionId).collection("medic_coverage_logs")
    }

    static func lspLocationTasks(productionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        productions(db).document(productionId).collection("lsp_location_tasks")
    }

    static func securityAccessLogs(productionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        productions(db).document(productionId).collection("security_access_logs")
    }
}
#endif
