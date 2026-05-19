import Foundation
import SwiftData

@MainActor
enum KitCheckoutService {
    static func checkout(
        asset: EquipmentAsset,
        to project: ProductionProject,
        kind: ProductionKitDeviceKind? = nil,
        context: ModelContext
    ) throws -> ProductionKitCheckout {
        let inferred = kind ?? ProductionKitDeviceKind.infer(from: asset.displayName)
        let row = ProductionKitCheckout(
            deviceKindRaw: inferred.rawValue,
            productionProject: project,
            equipmentAsset: asset
        )
        context.insert(row)
        try context.save()
        return row
    }

    static func checkIn(_ checkout: ProductionKitCheckout, context: ModelContext) throws {
        checkout.checkedInAt = .now
        try context.save()
    }

    /// Sets each crew day’s kit day-count + rate from active checkouts (EP `CELL x5` style aggregation).
    static func applyActiveCheckoutsToCrewDays(
        project: ProductionProject,
        days: [CrewTimecardDay],
        context: ModelContext
    ) throws {
        let fd = FetchDescriptor<ProductionKitCheckout>()
        let all = (try? context.fetch(fd)) ?? []
        let active = all.filter {
            $0.isActive && $0.productionProject?.id == project.id
        }
        guard !active.isEmpty else { return }

        for day in days {
            for co in active {
                let rate = co.equipmentAsset?.dailyRentalRateCAD
                    ?? defaultRate(for: co.deviceKind, project: project)
                switch co.deviceKind {
                    case .phone:
                        if day.ancillaryPhoneDays < 1 { day.ancillaryPhoneDays = 1 }
                        if day.ancillaryPhoneRateCAD == nil { day.ancillaryPhoneRateCAD = rate }
                    case .laptop, .computer:
                        if day.ancillaryLaptopDays < 1 { day.ancillaryLaptopDays = 1 }
                        if day.ancillaryLaptopRateCAD == nil { day.ancillaryLaptopRateCAD = rate }
                    case .tablet:
                        if day.ancillaryTabletDays < 1 { day.ancillaryTabletDays = 1 }
                        if day.ancillaryTabletRateCAD == nil { day.ancillaryTabletRateCAD = rate }
                    case .vehicle:
                        break
                }
            }
        }
        try context.save()
    }

    private static func defaultRate(
        for kind: ProductionKitDeviceKind,
        project: ProductionProject
    ) -> Decimal? {
        switch kind {
            case .phone: project.defaultKitPhoneRateCAD
            case .laptop, .computer: project.defaultKitLaptopRateCAD
            case .tablet: project.defaultKitTabletRateCAD
            case .vehicle: nil
        }
    }
}
