import Foundation
import SwiftData

/// One **EP-style crew day**: travel, meals, set times, and kit / phone allowances for Sentinel + PDF export.
@Model
final class CrewTimecardDay {
    @Attribute(.unique) var id: UUID
    var workDate: Date
    var createdAt: Date
    var updatedAt: Date

    /// Owning production; `@Relationship` + inverse lives on `ProductionProject.crewTimecardDays`.
    var productionProject: ProductionProject?

    var travelLeaveZoneStart: Date?
    var travelToSetArrive: Date?
    var callOnSet: Date?
    /// Department-wide call from the callsheet (meal penalties may reference this vs. individual start).
    var generalCrewCall: Date?
    /// EP department line (Costumes, Transport, Set Dec, etc.).
    var department: String?
    /// Main / 2nd / Splinter / Office — drives split EP PDF export.
    var unitType: String?
    var meal1Start: Date?
    var meal1End: Date?
    var meal2Start: Date?
    var meal2End: Date?
    var wrapOffSet: Date?
    var travelReturnLeaveSet: Date?
    var travelReturnHome: Date?

    /// Per-day classification (overrides show default / rate-sheet label for EP rows when set).
    var occupationTitle: String?
    /// Optional **hourly** override for this day (skips show rate-sheet lookup when set).
    var overrideBaseHourlyRateCAD: Decimal?

    /// MTO / portal travel log cross-check for this day’s pay window.
    var travelLogMTOVerified: Bool
    /// Handwritten / paper timecard: you entered hours manually; Sentinel still models gross for forensic pay tracking.
    var paperForensicAuditMode: Bool
    /// Freeform pay-period anchor (e.g. “2026-05-09 EP cycle”) for disputes.
    var travelLogPayPeriodNote: String?

    var ancillaryPhoneDays: Int
    var ancillaryLaptopDays: Int
    var ancillaryTabletDays: Int
    /// Nil after migration from stores that predate vehicle kit; treat as 0 in UI and export.
    var ancillaryVehicleDays: Int?
    var ancillaryPhoneRateCAD: Decimal?
    var ancillaryLaptopRateCAD: Decimal?
    var ancillaryTabletRateCAD: Decimal?
    var ancillaryVehicleRateCAD: Decimal?
    /// When true, kit lines use weekly contract rates (full-time position) instead of casual daily.
    var kitRentalFullTimeMode: Bool

    var notes: String?

    init(
        id: UUID = UUID(),
        workDate: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        productionProject: ProductionProject? = nil,
        travelLeaveZoneStart: Date? = nil,
        travelToSetArrive: Date? = nil,
        callOnSet: Date? = nil,
        generalCrewCall: Date? = nil,
        department: String? = nil,
        unitType: String? = nil,
        meal1Start: Date? = nil,
        meal1End: Date? = nil,
        meal2Start: Date? = nil,
        meal2End: Date? = nil,
        wrapOffSet: Date? = nil,
        travelReturnLeaveSet: Date? = nil,
        travelReturnHome: Date? = nil,
        occupationTitle: String? = nil,
        overrideBaseHourlyRateCAD: Decimal? = nil,
        travelLogMTOVerified: Bool = false,
        paperForensicAuditMode: Bool = false,
        travelLogPayPeriodNote: String? = nil,
        ancillaryPhoneDays: Int = 0,
        ancillaryLaptopDays: Int = 0,
        ancillaryTabletDays: Int = 0,
        ancillaryVehicleDays: Int? = nil,
        ancillaryPhoneRateCAD: Decimal? = nil,
        ancillaryLaptopRateCAD: Decimal? = nil,
        ancillaryTabletRateCAD: Decimal? = nil,
        ancillaryVehicleRateCAD: Decimal? = nil,
        kitRentalFullTimeMode: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.workDate = workDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productionProject = productionProject
        self.travelLeaveZoneStart = travelLeaveZoneStart
        self.travelToSetArrive = travelToSetArrive
        self.callOnSet = callOnSet
        self.generalCrewCall = generalCrewCall
        self.department = department
        self.unitType = unitType
        self.meal1Start = meal1Start
        self.meal1End = meal1End
        self.meal2Start = meal2Start
        self.meal2End = meal2End
        self.wrapOffSet = wrapOffSet
        self.travelReturnLeaveSet = travelReturnLeaveSet
        self.travelReturnHome = travelReturnHome
        self.occupationTitle = occupationTitle
        self.overrideBaseHourlyRateCAD = overrideBaseHourlyRateCAD
        self.travelLogMTOVerified = travelLogMTOVerified
        self.paperForensicAuditMode = paperForensicAuditMode
        self.travelLogPayPeriodNote = travelLogPayPeriodNote
        self.ancillaryPhoneDays = ancillaryPhoneDays
        self.ancillaryLaptopDays = ancillaryLaptopDays
        self.ancillaryTabletDays = ancillaryTabletDays
        self.ancillaryVehicleDays = ancillaryVehicleDays
        self.ancillaryPhoneRateCAD = ancillaryPhoneRateCAD
        self.ancillaryLaptopRateCAD = ancillaryLaptopRateCAD
        self.ancillaryTabletRateCAD = ancillaryTabletRateCAD
        self.ancillaryVehicleRateCAD = ancillaryVehicleRateCAD
        self.kitRentalFullTimeMode = kitRentalFullTimeMode
        self.notes = notes
    }
}
