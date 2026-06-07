import Foundation

/// New Horizons program constants for vault paths, RatioVita modules, and B2B fleet defaults.
enum NewHorizonsProgramManifest {
    static let programTitle = "New Horizons"
    static let siteAddress = "176 Yonge Street, Toronto"
    static let productionBibleTitle = "New Horizons — Production Bible"

    // MARK: - Vault

    static let vaultRoot = NewHorizonsZoneCatalog.vaultPrefix
    static let manuscriptVault = "\(vaultRoot)/Project-Manuscripts-Historical-Vault"
    static let dealMemoVault = "\(vaultRoot)/Legal-Deal-Memos"
    static let fleetContractsVault = "\(vaultRoot)/Mobile-Fleet-B2B"

    // MARK: - App module epics (VitaLogic consumer / RatioVita crew / B2B studio)

    enum ModuleEpic: String, CaseIterable, Sendable {
        case vitaLogicConsumer = "VitaLogic.Consumer"
        case vitaLogicPension = "VitaLogic.PensionDiscount"
        case vitaLogicSpeakersCorner = "VitaLogic.SpeakersCorner"
        case vitaLogicPackages = "VitaLogic.ExperiencePackages"
        case ratioVitaBioInsulation = "RatioVita.BioInsulation"
        case ratioVitaGeofenceClock = "RatioVita.GeofenceClock"
        case ratioVitaBLEZones = "RatioVita.BLEZoneTelemetry"
        case b2bADPortal = "B2B.AssistantDirectorPortal"
        case b2bHoldFire = "B2B.HoldFireProtocol"
        case b2bFleetBilling = "B2B.FleetStandbyDispatch"
    }

    // MARK: - Ontario craft / catering baselines (union spreadsheet lines)

    static let craftPerHeadCAD: Decimal = 15
    static let mealPerHeadCADLow: Decimal = 25
    static let mealPerHeadCADHigh: Decimal = 30

    // MARK: - Premium fleet rider (above per-head union lines)

    static let fleet28FootDailyCAD: Decimal = 2000
    static let fleet54FootDailyCAD: Decimal = 5000
    static let standbyFeeCAD: Decimal = 1500

    // MARK: - Deal memo anchors (CAD — negotiate with counsel)

    static let phase1DevelopmentFeeLow: Decimal = 1_500_000
    static let phase1DevelopmentFeeHigh: Decimal = 2_200_000
    static let showrunnerSalaryLow: Decimal = 350_000
    static let showrunnerSalaryHigh: Decimal = 500_000
    static let flagshipGrossRoyaltyPercentLow: Decimal = 3
    static let flagshipGrossRoyaltyPercentHigh: Decimal = 5
    static let fleetGrossRoyaltyPercentLow: Decimal = 5
    static let fleetGrossRoyaltyPercentHigh: Decimal = 7
    static let ratioVitaRetainerMonthlyLow: Decimal = 25000
    static let ratioVitaRetainerMonthlyHigh: Decimal = 40000
    static let rebelFacilityCreditPercent: Decimal = 15

    // MARK: - Pension / industry discount tiers

    static let otpRetiredDiscountPercent: Decimal = 15
    static let otpActiveDiscountPercent: Decimal = 10
    static let industryPartnerDiscountPercent: Decimal = 10
}
