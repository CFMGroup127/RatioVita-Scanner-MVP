import Combine
import Foundation

/// Persists white-glove onboarding completion and active show context (Sprint JJJJ).
@MainActor
final class SetOSOnboardingCoordinator: ObservableObject {
    static let shared = SetOSOnboardingCoordinator()

    @Published private(set) var isComplete: Bool
    @Published var currentStep: OnboardingStep = .legalAgreements
    @Published var acceptedTerms = false
    @Published var acceptedNDA = false
    @Published var acceptedNCA = false
    @Published var legalName = ""
    @Published var mailingAddress = ""
    @Published var phoneLine = ""
    @Published var sideHustleEnabled = false
    @Published var onActiveProduction = false
    @Published var sandboxMode = false
    @Published var showCode = ""
    @Published var productionTitle = ""
    @Published var selectedDepartmentName = ""
    @Published var selectedPositionTitle = ""
    @Published var enabledQuadrants: Set<WidgetQuadrant> = [.activeProduction]
    @Published var pinnedLauncherIntents: Set<LauncherModuleIntent> = [.instantTimecard]
    @Published var developerRoleOverrideEnabled = false

    private init() {
        isComplete = UserDefaults.standard.bool(forKey: Keys.complete)
        loadDraft()
    }

    var activeDepartmentName: String {
        selectedDepartmentName
    }

    var activePositionTitle: String {
        selectedPositionTitle
    }

    var activeIndustryScope: IndustryDepartmentScope? {
        DepartmentHierarchyRegistry.department(named: selectedDepartmentName)?.industryScope
    }

    var activePosition: FilmPosition? {
        DepartmentHierarchyRegistry.position(
            title: selectedPositionTitle,
            inDepartment: selectedDepartmentName
        )
    }

    var legalGateSatisfied: Bool {
        acceptedTerms && acceptedNDA && acceptedNCA
    }

    var personalGateSatisfied: Bool {
        !legalName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func goBack() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    func skipToSandbox() {
        onActiveProduction = false
        sandboxMode = true
        productionTitle = "Sandbox · Practice show"
        selectedDepartmentName = DepartmentHierarchyRegistry.productionOfficeName
        selectedPositionTitle = DepartmentHierarchyRegistry.positions(
            forDepartmentNamed: selectedDepartmentName
        ).first?.title ?? ""
        currentStep = .widgetConfiguration
    }

    func finalizeOnboarding() {
        applySessionAndVault()
        HomeScreenWidgetDataProvider.publish(from: self)
        if sandboxMode {
            SandboxEnvironmentController.shared.activate(
                departmentName: selectedDepartmentName,
                positionTitle: selectedPositionTitle
            )
        }
        isComplete = true
        UserDefaults.standard.set(true, forKey: Keys.complete)
        persistDraft()
        ConsultantSessionManager.shared.setProgramEnabled(true)
    }

    func resetForFactoryTest() {
        isComplete = false
        currentStep = .legalAgreements
        acceptedTerms = false
        acceptedNDA = false
        acceptedNCA = false
        legalName = ""
        mailingAddress = ""
        phoneLine = ""
        sideHustleEnabled = false
        onActiveProduction = false
        sandboxMode = false
        showCode = ""
        productionTitle = ""
        selectedDepartmentName = ""
        selectedPositionTitle = ""
        enabledQuadrants = [.activeProduction]
        pinnedLauncherIntents = [.instantTimecard]
        UserDefaults.standard.removeObject(forKey: Keys.complete)
        persistDraft()
        SandboxEnvironmentController.shared.deactivate()
    }

    private func applySessionAndVault() {
        let session = ConsultantSessionManager.shared
        if let position = activePosition {
            session.setOperationalHat(position.hatRole)
        }
        if let persona = MasterVaultProfileManager.shared.personas.first(where: {
            $0.positionTitle.localizedCaseInsensitiveContains(selectedPositionTitle)
                || $0.operationalHat == activePosition?.hatRole
        }) {
            MasterVaultProfileManager.shared.selectPersona(persona)
        }
    }

    private func loadDraft() {
        let defaults = UserDefaults.standard
        if let stepRaw = defaults.object(forKey: Keys.step) as? Int,
           let step = OnboardingStep(rawValue: stepRaw)
        {
            currentStep = step
        }
        legalName = defaults.string(forKey: Keys.legalName) ?? ""
        mailingAddress = defaults.string(forKey: Keys.address) ?? ""
        selectedDepartmentName = defaults.string(forKey: Keys.department) ?? ""
        selectedPositionTitle = defaults.string(forKey: Keys.position) ?? ""
        showCode = defaults.string(forKey: Keys.showCode) ?? ""
        productionTitle = defaults.string(forKey: Keys.productionTitle) ?? ""
        sandboxMode = defaults.bool(forKey: Keys.sandbox)
    }

    func persistDraft() {
        let defaults = UserDefaults.standard
        defaults.set(currentStep.rawValue, forKey: Keys.step)
        defaults.set(legalName, forKey: Keys.legalName)
        defaults.set(mailingAddress, forKey: Keys.address)
        defaults.set(selectedDepartmentName, forKey: Keys.department)
        defaults.set(selectedPositionTitle, forKey: Keys.position)
        defaults.set(showCode, forKey: Keys.showCode)
        defaults.set(productionTitle, forKey: Keys.productionTitle)
        defaults.set(sandboxMode, forKey: Keys.sandbox)
    }

    private enum Keys {
        static let complete = "com.ratiovita.setos.onboarding.complete"
        static let step = "com.ratiovita.setos.onboarding.step"
        static let legalName = "com.ratiovita.setos.onboarding.legalName"
        static let address = "com.ratiovita.setos.onboarding.address"
        static let department = "com.ratiovita.setos.onboarding.department"
        static let position = "com.ratiovita.setos.onboarding.position"
        static let showCode = "com.ratiovita.setos.onboarding.showCode"
        static let productionTitle = "com.ratiovita.setos.onboarding.productionTitle"
        static let sandbox = "com.ratiovita.setos.onboarding.sandbox"
    }
}
