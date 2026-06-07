import Foundation

enum ZohoModuleTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case crmCreator = "ZOHO_CRM_CREATOR_ASSETS"
    case booksExpense = "ZOHO_BOOKS_EXPENSE_FINANCIAL"
    case peopleShifts = "ZOHO_PEOPLE_SHIFTS_LABOUR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .crmCreator: "CRM & Creator"
            case .booksExpense: "Books & Expense"
            case .peopleShifts: "People & Shifts"
        }
    }
}

struct ZohoDataPacket: Identifiable, Codable, Sendable {
    var id: UUID
    var targetModule: ZohoModuleTarget
    var recordPayloadHex: String
    var boundTenantDomain: MacroTenantDomain
    var syncTimestamp: Date
}

struct ZohoSyncStatus: Sendable {
    var module: ZohoModuleTarget
    var lastSync: Date
    var pendingCount: Int
    var lastMessage: String
}

struct AutoTimecardDraft: Identifiable, Sendable {
    let id: UUID
    let crewToken: String
    let departmentLabel: String
    let hoursComputed: Double
    let gateCheckIns: Int
    let voiceLogEntries: Int
    let readyForSignOff: Bool
}
