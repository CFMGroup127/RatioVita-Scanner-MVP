import Foundation
import SwiftData

// MARK: - Department scope

enum IndustryDepartmentScope: String, Codable, CaseIterable, Identifiable {
    case transport = "TRANSPORT_IA873"
    case cameraDIT = "CAMERA_DIT_IA667"
    case accounting = "PRODUCTION_ACCOUNTING"
    case artSetDec = "ART_DEPARTMENT_DGC"
    case culinaryCraft = "NEW_HORIZONS_CULINARY"
    case costume = "COSTUME_IA873"
    case tadAD = "TAD_AD_DESK"
    case locations = "LOCATIONS_DESK"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .transport: "Transport (IA 873)"
            case .cameraDIT: "Camera / DIT"
            case .accounting: "Production accounting"
            case .artSetDec: "Art / Set dec"
            case .culinaryCraft: "New Horizons culinary"
            case .costume: "Costume"
            case .tadAD: "TAD / AD desk"
            case .locations: "Locations"
        }
    }
}

enum ConsultantTier: String, Codable {
    case subordinate = "Subordinate"
    case departmentHead = "DepartmentHead"
    case accountingVault = "AccountingVault"
}

enum OnboardingDocumentStatus: Int, Codable, CaseIterable {
    case initiated = 0
    case dealMemoCompleted = 1
    case docsAttached = 2
    case verifiedAndFlattened = 3
}

enum TrailerLogisticsState: Int, Codable, CaseIterable {
    case standby = 0
    case castEnRouteToBase = 1
    case roomDressedAndVerified = 2
    case castOccupied = 3
    case wardrobeSecuredPendingClearance = 4
    case cleanAndLockActive = 5
}

enum LockScheduleState: Int, Codable, CaseIterable {
    case open = 0
    case warningLow = 1
    case warningMedium = 2
    case warningHigh = 3
    case locked = 4

    var label: String {
        switch self {
            case .open: "Open"
            case .warningLow: "Friday wrap reminder"
            case .warningMedium: "Sunday reminder"
            case .warningHigh: "Monday final notice"
            case .locked: "Locked — Tuesday 10:00 AM"
        }
    }
}

enum LauncherModuleIntent: String, Codable, CaseIterable {
    case driverTransit = "LAUNCH_DRIVER_CONSOLE"
    case instantTimecard = "LAUNCH_TIMECARD_OVERLAY"
    case costumeContinuity = "LAUNCH_COSTUME_MATRIX"
    case firstLooks = "LAUNCH_FIRST_LOOKS"
    case tadConsole = "LAUNCH_TAD_CONSOLE"
    case swamperTerminal = "LAUNCH_SWAMPER_TERMINAL"
    case apPayroll = "LAUNCH_AP_PAYROLL"
    case administrativeMaster = "LAUNCH_FULL_COCKPIT"
}

// MARK: - Expert consultant profile

@Model
final class ExpertConsultantProfile {
    @Attribute(.unique) var id: UUID
    var legalTokenHash: String
    var anonymousToken: String
    var departmentScopeRaw: String
    var tierRaw: String
    var yearsOfExperience: Int
    var activeProductionTitle: String
    var unionLocalCode: String
    var isAuthorizedForTesting: Bool
    var parentConsultantID: UUID?
    var inviteAllocationRemaining: Int
    var lockedProfileJSON: String
    var onboardingStatusRaw: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        department: IndustryDepartmentScope,
        tier: ConsultantTier = .subordinate,
        yearsOfExperience: Int = 0,
        activeProductionTitle: String = "",
        unionLocalCode: String = "IATSE-873",
        parentConsultantID: UUID? = nil,
        inviteAllocationRemaining _: Int = 0
    ) {
        id = UUID()
        legalTokenHash = ""
        anonymousToken = ConsultantTokenFactory.generateToken(for: department)
        departmentScopeRaw = department.rawValue
        tierRaw = tier.rawValue
        self.yearsOfExperience = yearsOfExperience
        self.activeProductionTitle = activeProductionTitle
        self.unionLocalCode = unionLocalCode
        isAuthorizedForTesting = false
        self.parentConsultantID = parentConsultantID
        inviteAllocationRemaining = tier == .departmentHead ? 3 : 0
        lockedProfileJSON = "{}"
        onboardingStatusRaw = OnboardingDocumentStatus.initiated.rawValue
        createdAt = .now
        updatedAt = .now
    }

    var department: IndustryDepartmentScope {
        get { IndustryDepartmentScope(rawValue: departmentScopeRaw) ?? .transport }
        set { departmentScopeRaw = newValue.rawValue }
    }

    var tier: ConsultantTier {
        get { ConsultantTier(rawValue: tierRaw) ?? .subordinate }
        set { tierRaw = newValue.rawValue }
    }

    var onboardingStatus: OnboardingDocumentStatus {
        get { OnboardingDocumentStatus(rawValue: onboardingStatusRaw) ?? .initiated }
        set { onboardingStatusRaw = newValue.rawValue }
    }
}

// MARK: - Consultation timecard (honorarium logging)

@Model
final class ConsultationTimecard {
    @Attribute(.unique) var id: UUID
    var consultantID: UUID
    var departmentScopeRaw: String
    var anonymousToken: String
    var workDate: Date
    var hoursLogged: Double
    var localizedNotes: String
    var biometricSignatureVerified: Bool
    var isVisibleToConsultant: Bool
    var createdAt: Date

    init(
        consultantID: UUID,
        department: IndustryDepartmentScope,
        anonymousToken: String,
        workDate: Date = .now,
        hoursLogged: Double,
        notes: String,
        biometricVerified: Bool = true
    ) {
        id = UUID()
        self.consultantID = consultantID
        departmentScopeRaw = department.rawValue
        self.anonymousToken = anonymousToken
        self.workDate = workDate
        self.hoursLogged = hoursLogged
        localizedNotes = notes
        biometricSignatureVerified = biometricVerified
        isVisibleToConsultant = false
        createdAt = .now
    }
}

// MARK: - Invitation tree

@Model
final class InvitationNode {
    @Attribute(.unique) var id: UUID
    var parentConsultantID: UUID
    var childEmail: String
    var singleUseToken: String
    var childDepartmentScopeRaw: String
    var isActivated: Bool
    var createdAt: Date

    init(
        parentConsultantID: UUID,
        childEmail: String,
        department: IndustryDepartmentScope
    ) {
        id = UUID()
        self.parentConsultantID = parentConsultantID
        self.childEmail = childEmail
        singleUseToken = ConsultantTokenFactory.generateInviteToken()
        childDepartmentScopeRaw = department.rawValue
        isActivated = false
        createdAt = .now
    }
}

// MARK: - Expert diagnostic questionnaire submission

@Model
final class ExpertDiagnosticSubmission {
    @Attribute(.unique) var id: UUID
    var consultantID: UUID?
    var departmentScopeRaw: String
    var anonymousToken: String
    var questionnaireKey: String
    var responsesJSON: String
    var matchesUnionReality: Bool
    var requiresProtocolTweak: Bool
    var frictionNotes: String
    var activeMissionContext: String
    var createdAt: Date

    init(
        department: IndustryDepartmentScope,
        anonymousToken: String,
        questionnaireKey: String,
        responses: [String: String],
        matchesUnionReality: Bool,
        requiresProtocolTweak: Bool,
        frictionNotes: String,
        missionContext: String,
        consultantID: UUID? = nil
    ) {
        id = UUID()
        self.consultantID = consultantID
        departmentScopeRaw = department.rawValue
        self.anonymousToken = anonymousToken
        self.questionnaireKey = questionnaireKey
        responsesJSON = (try? String(data: JSONEncoder().encode(responses), encoding: .utf8)) ?? "{}"
        self.matchesUnionReality = matchesUnionReality
        self.requiresProtocolTweak = requiresProtocolTweak
        self.frictionNotes = frictionNotes
        activeMissionContext = missionContext
        createdAt = .now
    }
}

// MARK: - Isolated department forum

@Model
final class DepartmentForumPost {
    @Attribute(.unique) var id: UUID
    var departmentScopeRaw: String
    var anonymousToken: String
    var body: String
    var sentimentRaw: String
    var createdAt: Date

    init(
        department: IndustryDepartmentScope,
        anonymousToken: String,
        body: String,
        sentiment: String = "neutral"
    ) {
        id = UUID()
        departmentScopeRaw = department.rawValue
        self.anonymousToken = anonymousToken
        self.body = body
        sentimentRaw = sentiment
        createdAt = .now
    }
}

// MARK: - Daily time report line

@Model
final class DailyTimeReportEntry {
    @Attribute(.unique) var id: UUID
    var productionTitle: String
    var workDate: Date
    var workerAnonymousToken: String
    var castDisplayID: String
    var departmentLabel: String
    var callTimeHour: Int?
    var wrapTimeHour: Int?
    var wrapTimeMinute: Int?
    var wrapTimestamp: Date?
    var wrappedByRole: String
    var signedOff: Bool
    var createdAt: Date

    init(
        productionTitle: String,
        workDate: Date,
        workerToken: String,
        department: String,
        castDisplayID: String = "",
        signedOff: Bool = true,
        wrappedByRole: String = "2nd AD"
    ) {
        id = UUID()
        self.productionTitle = productionTitle
        self.workDate = workDate
        workerAnonymousToken = workerToken
        self.castDisplayID = castDisplayID.isEmpty ? workerToken : castDisplayID
        departmentLabel = department
        self.signedOff = signedOff
        self.wrappedByRole = wrappedByRole
        createdAt = .now
    }
}

// MARK: - Weekly payroll lock tracking

@Model
final class WorkerPayrollWeekStatus {
    @Attribute(.unique) var id: UUID
    var weekEndingDate: Date
    var workerAnonymousToken: String
    var productionTitle: String
    var lockStateRaw: Int
    var hasSubmittedWeeklyTimecard: Bool
    var lastNudgeMessage: String
    var lastNudgeAt: Date?
    var lockedAt: Date?
    var updatedAt: Date

    init(
        weekEndingDate: Date,
        workerToken: String,
        productionTitle: String,
        lockState: LockScheduleState = .open
    ) {
        id = UUID()
        self.weekEndingDate = weekEndingDate
        workerAnonymousToken = workerToken
        self.productionTitle = productionTitle
        lockStateRaw = lockState.rawValue
        hasSubmittedWeeklyTimecard = false
        lastNudgeMessage = ""
        updatedAt = .now
    }

    var lockState: LockScheduleState {
        get { LockScheduleState(rawValue: lockStateRaw) ?? .open }
        set {
            lockStateRaw = newValue.rawValue
            updatedAt = .now
        }
    }
}

// MARK: - Friction analytics

@Model
final class FrictionEventLog {
    @Attribute(.unique) var id: UUID
    var viewIdentifier: String
    var interactionDuration: TimeInterval
    var wasUnexpectedlyClosed: Bool
    var activeMissionContext: String
    var anonymousToken: String
    var createdAt: Date

    init(
        viewIdentifier: String,
        duration: TimeInterval,
        unexpectedlyClosed: Bool,
        missionContext: String,
        anonymousToken: String = ""
    ) {
        id = UUID()
        self.viewIdentifier = viewIdentifier
        interactionDuration = duration
        wasUnexpectedlyClosed = unexpectedlyClosed
        activeMissionContext = missionContext
        self.anonymousToken = anonymousToken
        createdAt = .now
    }
}

// MARK: - Script breakdown scene

@Model
final class ScriptSceneBreakdown {
    @Attribute(.unique) var id: UUID
    var sceneNumber: Int
    var locationSetting: String
    var sceneDescription: String
    var characterIDsJSON: String
    var departmentNotesJSON: String
    var productionTitle: String
    var updatedAt: Date

    init(
        sceneNumber: Int,
        locationSetting: String,
        sceneDescription: String,
        characters: [String] = [],
        productionTitle: String = ""
    ) {
        id = UUID()
        self.sceneNumber = sceneNumber
        self.locationSetting = locationSetting
        self.sceneDescription = sceneDescription
        characterIDsJSON = encodeStringArray(characters)
        departmentNotesJSON = "{}"
        self.productionTitle = productionTitle
        updatedAt = .now
    }

    var characterIDs: [String] {
        get { decodeStringArray(characterIDsJSON) }
        set { characterIDsJSON = encodeStringArray(newValue) }
    }

    func note(for department: IndustryDepartmentScope) -> String {
        guard let data = departmentNotesJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return "" }
        return dict[department.rawValue] ?? ""
    }

    func setNote(_ text: String, department: IndustryDepartmentScope) {
        var dict: [String: String] = [:]
        if let data = departmentNotesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        {
            dict = decoded
        }
        dict[department.rawValue] = text
        departmentNotesJSON = (try? String(data: JSONEncoder().encode(dict), encoding: .utf8)) ?? "{}"
        updatedAt = .now
    }
}

// MARK: - RFID asset

@Model
final class RFIDAssetItem {
    @Attribute(.unique) var id: UUID
    var rfidToken: String
    var assignedCharacterID: String
    var itemDescription: String
    var latitude: Double
    var longitude: Double
    var lastSeenAt: Date

    init(
        rfidToken: String,
        characterID: String,
        description: String,
        latitude: Double = 0,
        longitude: Double = 0
    ) {
        id = UUID()
        self.rfidToken = rfidToken
        assignedCharacterID = characterID
        itemDescription = description
        self.latitude = latitude
        self.longitude = longitude
        lastSeenAt = .now
    }
}

// MARK: - Trailer operational unit (TAD)

@Model
final class TrailerOperationalUnit {
    @Attribute(.unique) var id: UUID
    var trailerNumber: String
    var assignedCastID: String
    var activeTADToken: String
    var statusRaw: Int
    var updatedAt: Date

    init(
        trailerNumber: String,
        castID: String,
        tadToken: String = "TAD-OPS",
        status: TrailerLogisticsState = .standby
    ) {
        id = UUID()
        self.trailerNumber = trailerNumber
        assignedCastID = castID
        activeTADToken = tadToken
        statusRaw = status.rawValue
        updatedAt = .now
    }

    var status: TrailerLogisticsState {
        get { TrailerLogisticsState(rawValue: statusRaw) ?? .standby }
        set {
            statusRaw = newValue.rawValue
            updatedAt = .now
        }
    }
}

private func decodeStringArray(_ json: String) -> [String] {
    guard let data = json.data(using: .utf8),
          let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return decoded
}

private func encodeStringArray(_ values: [String]) -> String {
    (try? String(data: JSONEncoder().encode(values), encoding: .utf8)) ?? "[]"
}
