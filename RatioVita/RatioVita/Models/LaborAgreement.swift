import Foundation
import SwiftData

/// Persisted **labor agreement / rate card** template used by the IATSE Sentinel calculator (873 + CMPA-style
/// OT/meals).
/// Rates are **editable**; bundled defaults are a starting point only—not legal advice.
@Model
final class LaborAgreement {
    @Attribute(.unique) var id: UUID
    /// Stable seed key, e.g. `IATSE873_SENTINEL_V1`.
    @Attribute(.unique) var code: String
    var title: String
    var effectiveStartDate: Date
    /// Notes shown in UI (e.g. March 2026 scale placeholder).
    var scaleNotes: String?

    /// Straight-time base (CAD) for classification covered by this template.
    var baseHourlyRateCAD: Decimal
    /// Paid travel outside zone (CAD / hour).
    var zoneTravelHourlyCAD: Decimal
    /// First / second meal-penalty half-hour cash equivalents (CAD each); progressive tiers can be split later.
    var mealPenaltyHalfHourCAD: Decimal
    var overtimeMultiplierAfter8: Double
    var overtimeMultiplierAfter12: Double
    /// Work span without a completed meal end triggers at least one half-hour penalty (simplified sentinel).
    var maxWorkHoursBeforeMealRequired: Double
    /// Minimum **rest** between prior wrap and next call (hours); below this triggers turnaround “gold pay” on the
    /// following day (Sentinel model — verify against your agreement).
    var minimumRestHoursBetweenShootDays: Double
    /// Multiplier applied to **labor** (straight + OT + travel + meal penalties) on the day **after** a short-turn
    /// when rest < `minimumRestHoursBetweenShootDays` (e.g. 2.5 or 3.0).
    var turnaroundGoldPayMultiplier: Double

    /// `SentinelCalculatorKind.rawValue` — `iatse873` (default) or `iatse411_chef` for catering daily-floor math.
    var sentinelCalculatorKindRaw: String
    /// Negotiated **daily** minimum (CAD) for the 411 Chef profile; nil = not used.
    var negotiatedDailyMinimumCAD: Decimal?
    /// Divisor hours for the implied OT base from the daily floor (e.g. **14** for a 14h guarantee).
    var guaranteedHoursForDailyFloor: Double?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        code: String,
        title: String,
        effectiveStartDate: Date,
        scaleNotes: String? = nil,
        baseHourlyRateCAD: Decimal,
        zoneTravelHourlyCAD: Decimal,
        mealPenaltyHalfHourCAD: Decimal,
        overtimeMultiplierAfter8: Double = 1.5,
        overtimeMultiplierAfter12: Double = 2.0,
        maxWorkHoursBeforeMealRequired: Double = 6,
        minimumRestHoursBetweenShootDays: Double = 10,
        turnaroundGoldPayMultiplier: Double = 2.5,
        sentinelCalculatorKindRaw: String = "iatse873",
        negotiatedDailyMinimumCAD: Decimal? = nil,
        guaranteedHoursForDailyFloor: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.effectiveStartDate = effectiveStartDate
        self.scaleNotes = scaleNotes
        self.baseHourlyRateCAD = baseHourlyRateCAD
        self.zoneTravelHourlyCAD = zoneTravelHourlyCAD
        self.mealPenaltyHalfHourCAD = mealPenaltyHalfHourCAD
        self.overtimeMultiplierAfter8 = overtimeMultiplierAfter8
        self.overtimeMultiplierAfter12 = overtimeMultiplierAfter12
        self.maxWorkHoursBeforeMealRequired = maxWorkHoursBeforeMealRequired
        self.minimumRestHoursBetweenShootDays = minimumRestHoursBetweenShootDays
        self.turnaroundGoldPayMultiplier = turnaroundGoldPayMultiplier
        self.sentinelCalculatorKindRaw = sentinelCalculatorKindRaw
        self.negotiatedDailyMinimumCAD = negotiatedDailyMinimumCAD
        self.guaranteedHoursForDailyFloor = guaranteedHoursForDailyFloor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Which Sentinel payroll engine to run for a `LaborAgreement`.
enum SentinelCalculatorKind: String, CaseIterable, Identifiable {
    case iatse873
    case iatse411Chef = "iatse411_chef"

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
            case .iatse873: "IATSE 873 (hourly scale)"
            case .iatse411Chef: "IATSE 411 Chef (daily floor + derived OT)"
        }
    }
}

extension LaborAgreement {
    /// Effective engine: 411 Chef only when floor + divisor hours are configured.
    var effectiveCalculatorKind: SentinelCalculatorKind {
        let raw = sentinelCalculatorKindRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw == SentinelCalculatorKind.iatse411Chef.rawValue,
           negotiatedDailyMinimumCAD != nil,
           let gh = guaranteedHoursForDailyFloor,
           gh > 0.000_1
        {
            return .iatse411Chef
        }
        return .iatse873
    }
}
