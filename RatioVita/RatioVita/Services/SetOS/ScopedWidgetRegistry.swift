import Foundation
import SwiftUI

/// Contextual console tiles keyed by department + structural rank (Sprint AAAA / DDDD).
@MainActor
enum ScopedWidgetRegistry {
    struct ContextualConsoleTile: Identifiable, Sendable {
        let id: String
        let title: String
        let systemImage: String
        let surface: PerspectiveMaskingEngine.ConsoleSurface
        let tint: Color
    }

    static func tiles(
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?,
        consultantTier: ConsultantTier?,
        grant: TemporalRoleGrant?
    ) -> [ContextualConsoleTile] {
        let candidates: [ContextualConsoleTile] = [
            ContextualConsoleTile(
                id: "driver_log",
                title: "Truck log & vouchers",
                systemImage: "fuelpump.fill",
                surface: .driverLog,
                tint: .orange
            ),
            ContextualConsoleTile(
                id: "fleet_grid",
                title: "Fleet & picture cars",
                systemImage: "truck.box.fill",
                surface: .fleetMacroGrid,
                tint: .blue
            ),
            ContextualConsoleTile(
                id: "crisis",
                title: "Crisis matrix",
                systemImage: "exclamationmark.triangle.fill",
                surface: .crisisSplitCommand,
                tint: .red
            ),
            ContextualConsoleTile(
                id: "first_looks",
                title: "First Looks capture",
                systemImage: "camera.viewfinder",
                surface: .firstLooksCapture,
                tint: .purple
            ),
            ContextualConsoleTile(
                id: "creative",
                title: "Creative monitor",
                systemImage: "paintpalette.fill",
                surface: .creativeMonitorFeed,
                tint: .indigo
            ),
            ContextualConsoleTile(
                id: "locations",
                title: "Green zones & mesh",
                systemImage: "mappin.and.ellipse",
                surface: .locationsGreenZones,
                tint: .green
            ),
            ContextualConsoleTile(
                id: "pm_matrix",
                title: "PM / Showrunner matrix",
                systemImage: "chart.bar.doc.horizontal.fill",
                surface: .pmShowrunnerMatrix,
                tint: .mint
            ),
            ContextualConsoleTile(
                id: "payroll",
                title: "Payroll vault",
                systemImage: "lock.shield.fill",
                surface: .payrollVault,
                tint: .teal
            ),
        ]
        return candidates.filter {
            DepartmentScopeController.canAccess(
                surface: $0.surface,
                hat: hat,
                department: department,
                consultantTier: consultantTier,
                grant: grant
            )
        }
    }

    static func rankLabel(
        hat: OperationalHatRole,
        department: IndustryDepartmentScope?,
        consultantTier: ConsultantTier?
    ) -> String {
        DepartmentScopeController.structuralRank(
            hat: hat,
            department: department,
            consultantTier: consultantTier
        ).displayName
    }
}
