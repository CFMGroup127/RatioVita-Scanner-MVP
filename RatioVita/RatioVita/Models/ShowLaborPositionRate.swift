import Foundation
import SwiftData

/// One **rate / classification change** on a show (e.g. Truck Supervisor through Tuesday, Set Swing from Wednesday).
/// The Sentinel picks the latest segment with `effectiveFromDate` on or before each `CrewTimecardDay.workDate`.
@Model
final class ShowLaborPositionRate {
    @Attribute(.unique) var id: UUID
    /// First calendar day this rate applies (normalized to start-of-day when saved from UI).
    var effectiveFromDate: Date
    var occupationTitle: String
    var baseHourlyRateCAD: Decimal
    /// Negotiated add-on (equipment, driver, etc.) — **stacked** on base for Sentinel OT / meal math.
    var premiumHourlyRateCAD: Decimal
    /// `DealMemoRateKind.rawValue` — hourly vs flat daily guarantee.
    var rateKindRaw: String
    var flatDailyRateCAD: Decimal?
    var flatGuaranteeHours: Int?
    var department: String?
    var createdAt: Date
    var updatedAt: Date

    /// Owning show; `@Relationship` + inverse lives on `ProductionProject.laborPositionRates`.
    var productionProject: ProductionProject?

    init(
        id: UUID = UUID(),
        effectiveFromDate: Date,
        occupationTitle: String,
        baseHourlyRateCAD: Decimal,
        premiumHourlyRateCAD: Decimal = 0,
        rateKindRaw: String = DealMemoRateKind.hourly.rawValue,
        flatDailyRateCAD: Decimal? = nil,
        flatGuaranteeHours: Int? = nil,
        department: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        productionProject: ProductionProject? = nil
    ) {
        self.id = id
        self.effectiveFromDate = effectiveFromDate
        self.occupationTitle = occupationTitle
        self.baseHourlyRateCAD = baseHourlyRateCAD
        self.premiumHourlyRateCAD = premiumHourlyRateCAD
        self.rateKindRaw = rateKindRaw
        self.flatDailyRateCAD = flatDailyRateCAD
        self.flatGuaranteeHours = flatGuaranteeHours
        self.department = department
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productionProject = productionProject
    }
}

extension ShowLaborPositionRate {
    var rateKind: DealMemoRateKind {
        get { DealMemoRateKind(rawValue: rateKindRaw) ?? .hourly }
        set { rateKindRaw = newValue.rawValue }
    }

    /// Base + premium — or implied hourly from flat ÷ guarantee for union overlay math.
    var combinedHourlyRateCAD: Decimal {
        if rateKind == .flatDaily, let flat = flatDailyRateCAD {
            let g = max(flatGuaranteeHours ?? 14, 1)
            return flat / Decimal(g)
        }
        return baseHourlyRateCAD + premiumHourlyRateCAD
    }

    var displayRateSummary: String {
        switch rateKind {
            case .hourly:
                return String(format: "%.2f CAD/hr", NSDecimalNumber(decimal: combinedHourlyRateCAD).doubleValue)
            case .flatDaily:
                let flat = flatDailyRateCAD.map { "\($0)" } ?? "—"
                let g = flatGuaranteeHours.map { "\($0)h" } ?? "—"
                return "\(flat) CAD / \(g) guarantee"
        }
    }
}
