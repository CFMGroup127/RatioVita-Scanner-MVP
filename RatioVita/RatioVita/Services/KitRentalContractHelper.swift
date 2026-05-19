import Foundation

/// Applies deal-memo kit rates to a crew day (casual daily vs full-time weekly).
enum KitRentalContractHelper {
    static func applyFullTimeKitContract(to day: CrewTimecardDay, project: ProductionProject) {
        day.kitRentalFullTimeMode = true
        if project.defaultKitPhoneWeeklyRateCAD != nil || project.defaultKitPhoneRateCAD != nil {
            day.ancillaryPhoneDays = max(day.ancillaryPhoneDays, 1)
            day.ancillaryPhoneRateCAD = resolvedWeeklyRate(
                weekly: project.defaultKitPhoneWeeklyRateCAD,
                daily: project.defaultKitPhoneRateCAD
            )
        }
        if project.defaultKitLaptopWeeklyRateCAD != nil || project.defaultKitLaptopRateCAD != nil {
            day.ancillaryLaptopDays = max(day.ancillaryLaptopDays, 1)
            day.ancillaryLaptopRateCAD = resolvedWeeklyRate(
                weekly: project.defaultKitLaptopWeeklyRateCAD,
                daily: project.defaultKitLaptopRateCAD
            )
        }
        if project.defaultKitTabletWeeklyRateCAD != nil || project.defaultKitTabletRateCAD != nil {
            day.ancillaryTabletDays = max(day.ancillaryTabletDays, 1)
            day.ancillaryTabletRateCAD = resolvedWeeklyRate(
                weekly: project.defaultKitTabletWeeklyRateCAD,
                daily: project.defaultKitTabletRateCAD
            )
        }
        if project.payrollVehicleKitOn,
           project.defaultKitVehicleWeeklyRateCAD != nil || project.defaultKitVehicleRateCAD != nil
        {
            day.ancillaryVehicleDays = max(day.ancillaryVehicleDays ?? 0, 1)
            day.ancillaryVehicleRateCAD = resolvedWeeklyRate(
                weekly: project.defaultKitVehicleWeeklyRateCAD,
                daily: project.defaultKitVehicleRateCAD
            )
        }
        day.updatedAt = .now
    }

    static func applyCasualKitDefaults(to day: CrewTimecardDay, project: ProductionProject) {
        day.kitRentalFullTimeMode = false
        if day.ancillaryPhoneRateCAD == nil { day.ancillaryPhoneRateCAD = project.defaultKitPhoneRateCAD }
        if day.ancillaryLaptopRateCAD == nil { day.ancillaryLaptopRateCAD = project.defaultKitLaptopRateCAD }
        if day.ancillaryTabletRateCAD == nil { day.ancillaryTabletRateCAD = project.defaultKitTabletRateCAD }
        if project.payrollVehicleKitOn, day.ancillaryVehicleRateCAD == nil {
            day.ancillaryVehicleRateCAD = project.defaultKitVehicleRateCAD
        }
        day.updatedAt = .now
    }

    private static func resolvedWeeklyRate(weekly: Decimal?, daily: Decimal?) -> Decimal? {
        if let weekly, weekly > 0 { return weekly }
        if let daily, daily > 0 { return daily * 5 }
        return nil
    }
}
