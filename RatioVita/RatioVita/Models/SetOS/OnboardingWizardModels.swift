import Foundation

enum OnboardingStep: Int, Comparable, CaseIterable, Sendable {
    case legalAgreements = 1
    case personalRegistration = 2
    case sideHustleSetup = 3
    case productionContext = 4
    case showCodeEntry = 5
    case departmentSelection = 6
    case positionSelection = 7
    case widgetConfiguration = 8

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
            case .legalAgreements: "Legal"
            case .personalRegistration: "Personal profile"
            case .sideHustleSetup: "Businesses"
            case .productionContext: "Production"
            case .showCodeEntry: "Show code"
            case .departmentSelection: "Department"
            case .positionSelection: "Position"
            case .widgetConfiguration: "Widgets"
        }
    }
}

enum WidgetQuadrant: String, Codable, CaseIterable, Identifiable, Sendable {
    case personalVault = "PERSONAL"
    case sideHustle = "SIDE_HUSTLE"
    case unionGuild = "UNION_GUILD"
    case activeProduction = "ACTIVE_SHOW"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .personalVault: "Personal vault"
            case .sideHustle: "Side-hustle business"
            case .unionGuild: "Union / guild"
            case .activeProduction: "Active show"
        }
    }
}

struct WidgetContextState: Identifiable, Codable, Sendable {
    var id: UUID
    var selectedProductionName: String
    var activeDepartment: String
    var userPositionTitle: String
    var operationalHatRaw: String
    var industryScopeRaw: String
    var sandboxMode: Bool
    var enabledQuadrants: [String]
    var pinnedLauncherIntents: [String]

    var currentCallTime: Date?
    var currentWrapTime: Date?
    var mealOneStart: Date?
    var mealOneEnd: Date?
    var mealTwoStart: Date?
    var mealTwoEnd: Date?
    var travelStart: Date?
    var travelEnd: Date?

    var sideHustleInvoiceCount: Int
    var sideHustleRevenueStatus: Double

    init(
        id: UUID = UUID(),
        selectedProductionName: String = "",
        activeDepartment: String = "",
        userPositionTitle: String = "",
        operationalHatRaw: String = OperationalHatRole.driver.rawValue,
        industryScopeRaw: String = IndustryDepartmentScope.transport.rawValue,
        sandboxMode: Bool = false,
        enabledQuadrants: [String] = [WidgetQuadrant.activeProduction.rawValue],
        pinnedLauncherIntents: [String] = []
    ) {
        self.id = id
        self.selectedProductionName = selectedProductionName
        self.activeDepartment = activeDepartment
        self.userPositionTitle = userPositionTitle
        self.operationalHatRaw = operationalHatRaw
        self.industryScopeRaw = industryScopeRaw
        self.sandboxMode = sandboxMode
        self.enabledQuadrants = enabledQuadrants
        self.pinnedLauncherIntents = pinnedLauncherIntents
        sideHustleInvoiceCount = 0
        sideHustleRevenueStatus = 0
    }
}
