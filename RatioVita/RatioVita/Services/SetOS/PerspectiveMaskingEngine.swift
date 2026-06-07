import Foundation
import SwiftUI

/// Filters launcher tiles and console modules by operational hat (Sprint SSS).
@MainActor
enum PerspectiveMaskingEngine {
    enum ConsoleSurface: String, CaseIterable, Sendable {
        case driverLog
        case fleetMacroGrid
        case crisisSplitCommand
        case payrollVault
        case firstLooksCapture
        case creativeMonitorFeed
        case crossUnitChatter
        case locationsGreenZones
        case pmShowrunnerMatrix
    }

    static func visibleShortcutProfiles(
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?,
        tier: ConsultantTier?,
        temporalGrant: TemporalRoleGrant?
    ) -> [LauncherShortcutProfile] {
        let effective = effectiveHat(base: hat, grant: temporalGrant)
        return DepartmentScopeController.visibleShortcutProfiles(
            hat: effective,
            department: department,
            consultantTier: tier,
            temporalGrant: temporalGrant,
            macroDomain: MasterVaultProfileManager.shared.activeMacroDomain
        )
    }

    static func effectiveHat(
        base: OperationalHatRole,
        grant: TemporalRoleGrant?
    ) -> OperationalHatRole {
        guard let grant, grant.isActive else { return base }
        return grant.temporaryRole
    }

    static func allowedLauncherIntents(
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?,
        tier: ConsultantTier?
    ) -> Set<LauncherModuleIntent> {
        DepartmentScopeController.allowedLauncherIntents(
            hat: hat,
            department: department,
            consultantTier: tier,
            macroDomain: MasterVaultProfileManager.shared.activeMacroDomain
        )
    }

    static func canAccess(
        surface: ConsoleSurface,
        hat: OperationalHatRole,
        department: IndustryDepartmentScope? = nil,
        tier: ConsultantTier? = nil,
        grant: TemporalRoleGrant?
    ) -> Bool {
        let effective = effectiveHat(base: hat, grant: grant)
        return DepartmentScopeController.canAccess(
            surface: surface,
            hat: effective,
            department: department,
            consultantTier: tier,
            grant: grant
        )
    }

    static func suppressCrossUnitNotifications(
        hat: OperationalHatRole,
        originatingUnit: ProductionUnitNode,
        viewerUnit: ProductionUnitNode
    ) -> Bool {
        guard hat != .coordinator, hat != .productionManager, hat != .showRunner else { return false }
        return originatingUnit != viewerUnit
    }
}
