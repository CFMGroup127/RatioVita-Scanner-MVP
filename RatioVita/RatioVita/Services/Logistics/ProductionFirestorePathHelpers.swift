import Foundation

/// Firestore path helpers aligned with VitaLogic `ProductionFirestorePaths`.
enum ProductionFirestorePathHelpers {
    static let productionsCollection = "productions"

    static func callSheetsCollection(productionId: String) -> String {
        "\(productionsCollection)/\(productionId)/call_sheets"
    }

    static func transitExceptionsCollection(productionId: String, callSheetId: String) -> String {
        "\(callSheetsCollection(productionId: productionId))/\(callSheetId)/transit_exceptions"
    }
}
