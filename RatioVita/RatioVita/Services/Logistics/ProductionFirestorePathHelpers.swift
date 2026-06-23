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

    static func medicIncidentsCollection(productionId: String) -> String {
        "\(productionsCollection)/\(productionId)/medic_incidents"
    }

    static func medicKitSuppliesCollection(productionId: String) -> String {
        "\(productionsCollection)/\(productionId)/medic_kit_supplies"
    }

    static func medicCoverageLogsCollection(productionId: String) -> String {
        "\(productionsCollection)/\(productionId)/medic_coverage_logs"
    }

    static func lspLocationTasksCollection(productionId: String) -> String {
        "\(productionsCollection)/\(productionId)/lsp_location_tasks"
    }

    static func securityAccessLogsCollection(productionId: String) -> String {
        "\(productionsCollection)/\(productionId)/security_access_logs"
    }
}
