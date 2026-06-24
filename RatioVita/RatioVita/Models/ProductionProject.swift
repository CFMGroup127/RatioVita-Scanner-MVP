import Foundation
import SwiftData

/// Canonical production / “show” record so many receipts and work sessions share one title (no string fragmentation).
@Model
final class ProductionProject {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    /// Optional parent business / holding company label for registry grouping (e.g. “Catering Co.”).
    var parentBusinessTitle: String?
    /// `ProductionRegistryStatus.rawValue` — defaults to **active** for legacy rows.
    var registryStatusRaw: String
    /// Optional `RRGGBB` (no `#`) for Timeline radar accents; nil uses app accent.
    var timelineColorHex: String?

    /// EP / payroll occupation line (e.g. “Truck Supervisor”, “Set Swing”).
    var crewOccupationTitle: String?
    /// Show-level default kit **CAD per day** (auto-applied to new `CrewTimecardDay` rows when day rates are unset).
    var defaultKitPhoneRateCAD: Decimal?
    var defaultKitLaptopRateCAD: Decimal?
    var defaultKitTabletRateCAD: Decimal?
    /// Full-time kit allowance per pay week (overrides casual daily when crew day toggle is on).
    var defaultKitPhoneWeeklyRateCAD: Decimal?
    var defaultKitLaptopWeeklyRateCAD: Decimal?
    var defaultKitTabletWeeklyRateCAD: Decimal?
    var defaultKitVehicleRateCAD: Decimal?
    var defaultKitVehicleWeeklyRateCAD: Decimal?
    /// When true, vehicle / car kit lines appear on crew days and EP **OTHER RATES**.
    var payrollVehicleKitEnabled: Bool?
    /// Catering / **shop-to-shop**: treat shop departure → shop return as the paid span for OT + meal math.
    var laborCateringPortalMode: Bool
    /// `ProductionContractKind.rawValue` — corporate EP timecard vs personal contractor invoice.
    var productionContractKindRaw: String

    /// Client / network company name from outgoing invoices (forensic hint).
    var billingClientCompanyName: String?
    /// Production manager name harvested from invoices (forensic hint).
    var billingProductionManagerName: String?
    /// Purchase order # commonly used on this show’s vendor invoices.
    var billingPurchaseOrderNumber: String?
    /// `PaymentTermsMode.rawValue` — when empty, inherits from `businessEntity.paymentTermsRaw` when linked.
    var paymentTermsRaw: String
    /// `ProductionAutomationGovernance.rawValue` — union OT vs custom flat contract.
    var automationGovernanceRaw: String

    // MARK: - Payroll PDF (EP / Cast & Crew)

    /// `ProductionPayrollDocumentKind.rawValue` — default export / paperwork for this show.
    var payrollDefaultDocumentKindRaw: String?
    /// EP **DEPARTMENT** line (e.g. Costumes, Transport) when set on the production profile.
    var payrollDepartment: String?
    /// Studio / network for EP **PROD. COMPANY** (separate from show title and loan-out).
    var payrollProductionCompany: String?
    /// Optional loan-out corporation for EP **LOANOUT**; leave empty when not applicable.
    var payrollLoanoutCompany: String?
    var payrollUnionName: String?
    var payrollUnionID: String?
    /// `PayrollComplianceProfile.ResidencyTier.rawValue` override for this show.
    var payrollResidencyStatusRaw: String?
    /// `PayrollComplianceProfile.GuildTier.rawValue` override for this show.
    var payrollGuildStatusRaw: String?
    /// When true, crew initials are stamped on export for this show. Optional so existing stores migrate (`nil` → off).
    var payrollAutoStampCrewInitials: Bool?
    /// Optional per-show crew initials (overrides global initials when set).
    var payrollCrewInitialsOverride: String?

    var businessEntity: BusinessEntity?

    /// Stable sovereign production instance id — e.g. `PROD-FP-2026-0304`.
    var sovereignPUID: String?

    @Relationship(deleteRule: .nullify, inverse: \Receipt.productionProject)
    var receipts: [Receipt]

    @Relationship(deleteRule: .nullify, inverse: \WorkSession.productionProject)
    var workSessions: [WorkSession]

    @Relationship(deleteRule: .cascade, inverse: \CrewTimecardDay.productionProject)
    var crewTimecardDays: [CrewTimecardDay]

    @Relationship(deleteRule: .cascade, inverse: \ShowLaborPositionRate.productionProject)
    var laborPositionRates: [ShowLaborPositionRate]

    @Relationship(deleteRule: .cascade, inverse: \ProductionKitCheckout.productionProject)
    var kitCheckouts: [ProductionKitCheckout]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        parentBusinessTitle: String? = nil,
        registryStatusRaw: String = ProductionRegistryStatus.active.rawValue,
        timelineColorHex: String? = nil,
        crewOccupationTitle: String? = nil,
        defaultKitPhoneRateCAD: Decimal? = nil,
        defaultKitLaptopRateCAD: Decimal? = nil,
        defaultKitTabletRateCAD: Decimal? = nil,
        defaultKitPhoneWeeklyRateCAD: Decimal? = nil,
        defaultKitLaptopWeeklyRateCAD: Decimal? = nil,
        defaultKitTabletWeeklyRateCAD: Decimal? = nil,
        defaultKitVehicleRateCAD: Decimal? = nil,
        defaultKitVehicleWeeklyRateCAD: Decimal? = nil,
        payrollVehicleKitEnabled: Bool? = nil,
        laborCateringPortalMode: Bool = false,
        productionContractKindRaw: String = ProductionContractKind.corporateContract.rawValue,
        billingClientCompanyName: String? = nil,
        billingProductionManagerName: String? = nil,
        billingPurchaseOrderNumber: String? = nil,
        paymentTermsRaw: String = "",
        automationGovernanceRaw: String = ProductionAutomationGovernance.unionIATSE873.rawValue,
        payrollDefaultDocumentKindRaw: String? = ProductionPayrollDocumentKind.epCrewWeekly.rawValue,
        payrollDepartment: String? = nil,
        payrollProductionCompany: String? = nil,
        payrollLoanoutCompany: String? = nil,
        payrollUnionName: String? = nil,
        payrollUnionID: String? = nil,
        payrollResidencyStatusRaw: String? = nil,
        payrollGuildStatusRaw: String? = nil,
        payrollAutoStampCrewInitials: Bool? = false,
        payrollCrewInitialsOverride: String? = nil,
        businessEntity: BusinessEntity? = nil,
        receipts: [Receipt] = [],
        workSessions: [WorkSession] = [],
        crewTimecardDays: [CrewTimecardDay] = [],
        laborPositionRates: [ShowLaborPositionRate] = [],
        kitCheckouts: [ProductionKitCheckout] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.parentBusinessTitle = parentBusinessTitle
        self.registryStatusRaw = registryStatusRaw
        self.timelineColorHex = timelineColorHex
        self.crewOccupationTitle = crewOccupationTitle
        self.defaultKitPhoneRateCAD = defaultKitPhoneRateCAD
        self.defaultKitLaptopRateCAD = defaultKitLaptopRateCAD
        self.defaultKitTabletRateCAD = defaultKitTabletRateCAD
        self.defaultKitPhoneWeeklyRateCAD = defaultKitPhoneWeeklyRateCAD
        self.defaultKitLaptopWeeklyRateCAD = defaultKitLaptopWeeklyRateCAD
        self.defaultKitTabletWeeklyRateCAD = defaultKitTabletWeeklyRateCAD
        self.defaultKitVehicleRateCAD = defaultKitVehicleRateCAD
        self.defaultKitVehicleWeeklyRateCAD = defaultKitVehicleWeeklyRateCAD
        self.payrollVehicleKitEnabled = payrollVehicleKitEnabled
        self.laborCateringPortalMode = laborCateringPortalMode
        self.productionContractKindRaw = productionContractKindRaw
        self.billingClientCompanyName = billingClientCompanyName
        self.billingProductionManagerName = billingProductionManagerName
        self.billingPurchaseOrderNumber = billingPurchaseOrderNumber
        self.paymentTermsRaw = paymentTermsRaw
        self.automationGovernanceRaw = automationGovernanceRaw
        self.payrollDefaultDocumentKindRaw = payrollDefaultDocumentKindRaw
        self.payrollDepartment = payrollDepartment
        self.payrollProductionCompany = payrollProductionCompany
        self.payrollLoanoutCompany = payrollLoanoutCompany
        self.payrollUnionName = payrollUnionName
        self.payrollUnionID = payrollUnionID
        self.payrollResidencyStatusRaw = payrollResidencyStatusRaw
        self.payrollGuildStatusRaw = payrollGuildStatusRaw
        self.payrollAutoStampCrewInitials = payrollAutoStampCrewInitials
        self.payrollCrewInitialsOverride = payrollCrewInitialsOverride
        self.businessEntity = businessEntity
        self.receipts = receipts
        self.workSessions = workSessions
        self.crewTimecardDays = crewTimecardDays
        self.laborPositionRates = laborPositionRates
        self.kitCheckouts = kitCheckouts
    }
}

extension ProductionProject {
    var payrollDefaultDocumentKind: ProductionPayrollDocumentKind {
        get { ProductionPayrollDocumentKind.fromStored(payrollDefaultDocumentKindRaw) }
        set {
            payrollDefaultDocumentKindRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var registryStatus: ProductionRegistryStatus {
        get { ProductionRegistryStatus(rawValue: registryStatusRaw) ?? .active }
        set {
            registryStatusRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    /// Titles used for grouping in pickers (nil / blank → “Other”).
    var parentBusinessGroupingTitle: String {
        if let entity = businessEntity {
            return entity.legalName
        }
        let t = parentBusinessTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Other" : t
    }

    var productionContractKind: ProductionContractKind {
        get { ProductionContractKind(rawValue: productionContractKindRaw) ?? .corporateContract }
        set {
            productionContractKindRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var isIndependentContractor: Bool {
        productionContractKind == .personalContractor
    }

    /// Fills **LOANOUT** from the linked corporate entity when the production loan-out line is still blank.
    func syncPayrollLoanoutFromCorporateEntityIfEmpty() {
        guard let entity = businessEntity else { return }
        let existing = payrollLoanoutCompany?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard existing.isEmpty else { return }
        payrollLoanoutCompany = entity.legalName
        updatedAt = .now
    }

    var payrollVehicleKitOn: Bool {
        get { payrollVehicleKitEnabled ?? false }
        set {
            payrollVehicleKitEnabled = newValue
            updatedAt = .now
        }
    }

    /// Effective payroll / AR cadence: project override, else linked corporate entity, else unspecified.
    var effectivePaymentTerms: PaymentTermsMode {
        let trimmed = paymentTermsRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return PaymentTermsMode(rawValue: paymentTermsRaw) ?? .unspecified
        }
        if let ent = businessEntity {
            return PaymentTermsMode(rawValue: ent.paymentTermsRaw) ?? .unspecified
        }
        return .unspecified
    }

    /// Latest **multi-position** combined rate (base + premium) on or before `workDay`.
    func effectiveLaborBaseRate(for workDay: Date, calendar: Calendar = .current) -> Decimal? {
        activeRateSegment(for: workDay, calendar: calendar)?.combinedHourlyRateCAD
    }

    func activeRateSegment(for workDay: Date, calendar: Calendar = .current) -> ShowLaborPositionRate? {
        activeRateSegment(for: workDay, occupation: nil, department: nil, calendar: calendar)
    }

    /// Latest rate tier on or before `workDay`, preferring occupation + department match from deal memo page 1.
    func activeRateSegment(
        for workDay: Date,
        occupation: String?,
        department: String?,
        calendar: Calendar = .current
    ) -> ShowLaborPositionRate? {
        let sod = calendar.startOfDay(for: workDay)
        let rows = laborPositionRates.filter { calendar.startOfDay(for: $0.effectiveFromDate) <= sod }
        guard !rows.isEmpty else { return nil }

        let occKey = RegistryEntityPolarity.normalizedToken(occupation ?? "")
        let deptKey = RegistryEntityPolarity.normalizedToken(department ?? "")
        if !occKey.isEmpty || !deptKey.isEmpty {
            let matched = rows.filter { row in
                let rOcc = RegistryEntityPolarity.normalizedToken(row.occupationTitle)
                let rDept = RegistryEntityPolarity.normalizedToken(row.department ?? "")
                let occHit = occKey.isEmpty || rOcc.contains(occKey) || occKey.contains(rOcc)
                let deptHit = deptKey.isEmpty || rDept.contains(deptKey) || deptKey.contains(rDept)
                return occHit && deptHit
            }
            if let best = matched.max(by: { $0.effectiveFromDate < $1.effectiveFromDate }) {
                return best
            }
        }
        return rows.max(by: { $0.effectiveFromDate < $1.effectiveFromDate })
    }

    var automationGovernance: ProductionAutomationGovernance {
        get { ProductionAutomationGovernance(rawValue: automationGovernanceRaw) ?? .unionIATSE873 }
        set {
            automationGovernanceRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var usesCustomNonUnionSentinel: Bool {
        automationGovernance == .customNonUnion
    }

    /// Occupation label from the active rate segment for `workDay`.
    func effectiveOccupationFromRateSheet(for workDay: Date, calendar: Calendar = .current) -> String? {
        activeRateSegment(for: workDay, calendar: calendar)?.occupationTitle
    }

    /// True when the show has no receipts, sessions, crew days, kit rows, or rate segments (safe for zero-link purge).
    var hasZeroLinkedItems: Bool {
        receipts.isEmpty && workSessions.isEmpty && crewTimecardDays.isEmpty && laborPositionRates.isEmpty
            && kitCheckouts.isEmpty
    }

    /// Latest user-visible activity on this show (for dormant / workspace hygiene).
    var lastForensicActivityDate: Date {
        var candidates: [Date] = [updatedAt, createdAt]
        candidates.append(contentsOf: receipts.map(\.createdAt))
        candidates.append(contentsOf: workSessions.map(\.workDate))
        candidates.append(contentsOf: crewTimecardDays.map(\.workDate))
        return candidates.max() ?? updatedAt
    }

    /// No linked work for **30+ days** — Forensic Pulse can down-rank so dormant “hopefuls” don’t clutter the deck.
    var isDormantUnused: Bool {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: lastForensicActivityDate),
            to: cal.startOfDay(for: Date())
        ).day ?? 0
        return days >= 30
    }
}

extension BusinessEntity {
    var hasZeroLinkedItems: Bool {
        productionProjects.isEmpty
    }
}
