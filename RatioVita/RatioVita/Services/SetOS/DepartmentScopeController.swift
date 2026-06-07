import Foundation
import SwiftUI

/// Role-based scope multiplier — maps hat + department to launcher tiles and console surfaces (Sprint AAAA).
@MainActor
enum DepartmentScopeController {
    static func structuralRank(
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?,
        consultantTier: ConsultantTier?
    ) -> StructuralRankTier {
        switch hat {
            case .productionManager, .showRunner, .coordinator, .locationsManager:
                return .administrative
            case .captain, .coCaptain, .pictureCar, .costumeDesignerRemote, .setSupervisor:
                return .departmentHead
            case .costumeTruckSupervisor:
                return department == .costume ? .departmentHead : .fieldCrew
            default:
                break
        }
        if consultantTier == .accountingVault { return .administrative }
        if consultantTier == .departmentHead { return .departmentHead }
        return .fieldCrew
    }

    static func contextHat(
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?
    ) -> DepartmentContextHat {
        let dept = department ?? inferredDepartment(for: hat)
        let rank = structuralRank(hat: hat, department: department, consultantTier: nil)
        return DepartmentContextHat(
            department: dept.rawValue,
            tier: rank,
            assignedRoleTitle: hat.displayName
        )
    }

    static func inferredDepartment(for hat: OperationalHatRole) -> IndustryDepartmentScope {
        switch hat {
            case .driver, .swamper, .captain, .coCaptain, .coordinator, .castProducerDriver,
                 .unitMover, .pictureCar:
                .transport
            case .costumeTruckSupervisor, .costumeDesignerRemote:
                .costume
            case .setSupervisor:
                .artSetDec
            case .locationsManager:
                .locations
            case .productionManager, .showRunner:
                .accounting
        }
    }

    static func visibleShortcutProfiles(
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?,
        consultantTier: ConsultantTier?,
        temporalGrant: TemporalRoleGrant?,
        macroDomain: MacroTenantDomain?
    ) -> [LauncherShortcutProfile] {
        let effective = PerspectiveMaskingEngine.effectiveHat(base: hat, grant: temporalGrant)
        let intents = allowedLauncherIntents(
            hat: effective,
            department: department,
            consultantTier: consultantTier,
            macroDomain: macroDomain
        )
        return AppIconAssetRegistry.allShortcutProfiles.filter { intents.contains($0.moduleIntent) }
    }

    static func allowedLauncherIntents(
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?,
        consultantTier: ConsultantTier?,
        macroDomain: MacroTenantDomain?
    ) -> Set<LauncherModuleIntent> {
        if macroDomain == .systemArchitecture {
            return Set(LauncherModuleIntent.allCases)
        }
        if macroDomain == .performerGuilds {
            return [.instantTimecard, .firstLooks, .administrativeMaster]
        }
        if macroDomain == .commercialCulinary || macroDomain == .realEstateFacility {
            return [.instantTimecard, .tadConsole, .administrativeMaster]
        }

        let dept = department ?? inferredDepartment(for: hat)
        let rank = structuralRank(hat: hat, department: department, consultantTier: consultantTier)

        switch (dept, rank) {
            case (.transport, .fieldCrew):
                var base: Set<LauncherModuleIntent> = [.driverTransit, .instantTimecard]
                if hat == .swamper { base.insert(.swamperTerminal) }
                if hat == .pictureCar { base.insert(.firstLooks) }
                return base
            case (.transport, .departmentHead):
                return [
                    .driverTransit, .instantTimecard, .swamperTerminal,
                    .tadConsole, .firstLooks,
                ]
            case (.transport, .administrative):
                return Set(LauncherModuleIntent.allCases)
            case (.costume, .fieldCrew):
                return [.costumeContinuity, .instantTimecard, .firstLooks]
            case (.costume, .departmentHead), (.costume, .administrative):
                return [.costumeContinuity, .firstLooks, .instantTimecard, .apPayroll]
            case (.cameraDIT, .fieldCrew):
                return [.instantTimecard, .firstLooks]
            case (.cameraDIT, .departmentHead):
                return [.instantTimecard, .firstLooks, .tadConsole]
            case (.cameraDIT, .administrative):
                return [.instantTimecard, .firstLooks, .apPayroll, .administrativeMaster]
            case (.accounting, _), (.tadAD, _):
                if rank == .fieldCrew {
                    return [.tadConsole, .swamperTerminal, .instantTimecard]
                }
                return [.apPayroll, .instantTimecard, .tadConsole, .administrativeMaster]
            case (.locations, .administrative), (.locations, .departmentHead):
                return [.instantTimecard, .tadConsole, .administrativeMaster, .firstLooks]
            case (.locations, .fieldCrew):
                return [.instantTimecard, .firstLooks]
            case (.artSetDec, .fieldCrew):
                return [.instantTimecard, .firstLooks]
            case (.artSetDec, .departmentHead):
                return [.instantTimecard, .firstLooks, .tadConsole, .costumeContinuity]
            case (.artSetDec, .administrative):
                return [.instantTimecard, .apPayroll, .administrativeMaster]
            case (.culinaryCraft, .fieldCrew):
                return [.instantTimecard, .tadConsole]
            case (.culinaryCraft, .departmentHead), (.culinaryCraft, .administrative):
                return [.instantTimecard, .tadConsole, .administrativeMaster]
        }
    }

    static func canAccess(
        surface: PerspectiveMaskingEngine.ConsoleSurface,
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?,
        consultantTier: ConsultantTier?,
        grant: TemporalRoleGrant?
    ) -> Bool {
        let effective = PerspectiveMaskingEngine.effectiveHat(base: hat, grant: grant)
        let rank = structuralRank(hat: effective, department: department, consultantTier: consultantTier)
        switch surface {
            case .driverLog:
                return rank == .fieldCrew && (department ?? inferredDepartment(for: effective)) == .transport
            case .fleetMacroGrid, .crisisSplitCommand:
                return rank >= .departmentHead
                    && (department ?? inferredDepartment(for: effective)) == .transport
            case .payrollVault:
                return rank == .administrative
            case .firstLooksCapture:
                return rank >= .departmentHead || effective == .costumeTruckSupervisor
            case .creativeMonitorFeed:
                return effective.isCreativeMonitor || rank >= .departmentHead
            case .crossUnitChatter:
                return rank == .administrative
            case .locationsGreenZones:
                return effective == .locationsManager || rank >= .departmentHead
            case .pmShowrunnerMatrix:
                return effective == .productionManager || effective == .showRunner
        }
    }
}
