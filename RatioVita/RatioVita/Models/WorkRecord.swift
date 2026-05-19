import Foundation
import SwiftData

/// A single **dates worked** anchor extracted from a time sheet / pay stub (Sprint E). Distinct from `WorkSession`
/// (per-day UI rows on a receipt); `WorkRecord` powers forensic business-use matching against spend dates.
@Model
final class WorkRecord {
    @Attribute(.unique) var id: UUID
    /// Calendar day the crew member worked (normalized to start-of-day in local time when inserted).
    var workDate: Date
    var hoursWorked: Double?
    /// Show / production title as read from the document (may be linked to `ProductionProject` heuristically).
    var showTitle: String?
    var notes: String?
    var createdAt: Date

    /// Optional call / wrap / travel / meals when parsed from a time sheet (maps to EP twin columns).
    var callOnSet: Date?
    var wrapOffSet: Date?
    var travelLeaveZoneStart: Date?
    var travelToSetArrive: Date?
    var travelReturnLeaveSet: Date?
    var travelReturnHome: Date?
    var meal1Start: Date?
    var meal1End: Date?
    var meal2Start: Date?
    var meal2End: Date?
    /// Freeform zone / location notes (e.g. “Cobourg / outside zone”).
    var zoneTravelNotes: String?
    /// Main, 2nd Unit, Splinter, Office — drives split PDF export.
    var unitType: String?
    var department: String?

    @Relationship(deleteRule: .nullify) var productionProject: ProductionProject?

    /// Persisted inverse of `Receipt.workRecords` (macro only on `Receipt` to avoid SwiftData circular
    /// `@Relationship`).
    var sourceReceipt: Receipt?

    init(
        id: UUID = UUID(),
        workDate: Date,
        hoursWorked: Double? = nil,
        showTitle: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        callOnSet: Date? = nil,
        wrapOffSet: Date? = nil,
        travelLeaveZoneStart: Date? = nil,
        travelToSetArrive: Date? = nil,
        travelReturnLeaveSet: Date? = nil,
        travelReturnHome: Date? = nil,
        meal1Start: Date? = nil,
        meal1End: Date? = nil,
        meal2Start: Date? = nil,
        meal2End: Date? = nil,
        zoneTravelNotes: String? = nil,
        unitType: String? = nil,
        department: String? = nil,
        productionProject: ProductionProject? = nil,
        sourceReceipt: Receipt? = nil
    ) {
        self.id = id
        self.workDate = workDate
        self.hoursWorked = hoursWorked
        self.showTitle = showTitle
        self.notes = notes
        self.createdAt = createdAt
        self.callOnSet = callOnSet
        self.wrapOffSet = wrapOffSet
        self.travelLeaveZoneStart = travelLeaveZoneStart
        self.travelToSetArrive = travelToSetArrive
        self.travelReturnLeaveSet = travelReturnLeaveSet
        self.travelReturnHome = travelReturnHome
        self.meal1Start = meal1Start
        self.meal1End = meal1End
        self.meal2Start = meal2Start
        self.meal2End = meal2End
        self.zoneTravelNotes = zoneTravelNotes
        self.unitType = unitType
        self.department = department
        self.productionProject = productionProject
        self.sourceReceipt = sourceReceipt
    }
}
