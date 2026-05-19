import Foundation
import SwiftData

/// Seeds the default **873 Sentinel** `LaborAgreement` once per library (rates are placeholders — user must align to
/// scale).
enum LaborSentinelBootstrap {
    static let defaultAgreementCode = "IATSE873_SENTINEL_V1"
    static let chef411AgreementCode = "IATSE411_CHEF_V1"

    @MainActor
    static func ensureDefault873(modelContext: ModelContext) throws {
        let code = defaultAgreementCode
        var fd = FetchDescriptor<LaborAgreement>(predicate: #Predicate { $0.code == code })
        fd.fetchLimit = 1
        if try modelContext.fetch(fd).first != nil { return }

        let cal = Calendar(identifier: .gregorian)
        var dc = DateComponents()
        dc.year = 2026
        dc.month = 3
        dc.day = 29
        let effective = cal.date(from: dc) ?? .now

        let agreement = LaborAgreement(
            code: code,
            title: "IATSE 873 Sentinel (placeholder scale)",
            effectiveStartDate: effective,
            scaleNotes: "Placeholder base/travel/meal rates for Sentinel math. Replace with your classification + "
                + "CMPA scale (e.g. March 29, 2026 +3.5% where applicable). Not legal or payroll advice.",
            baseHourlyRateCAD: 45,
            zoneTravelHourlyCAD: 45,
            mealPenaltyHalfHourCAD: Decimal(string: "22.50") ?? 22.5,
            overtimeMultiplierAfter8: 1.5,
            overtimeMultiplierAfter12: 2.0,
            maxWorkHoursBeforeMealRequired: 6
        )
        modelContext.insert(agreement)
        try modelContext.save()
    }

    /// Catering / **411 Chef** profile: negotiated daily floor with divisor hours for derived OT / meal-penalty base.
    @MainActor
    static func ensureDefault411Chef(modelContext: ModelContext) throws {
        let code = chef411AgreementCode
        var fd = FetchDescriptor<LaborAgreement>(predicate: #Predicate { $0.code == code })
        fd.fetchLimit = 1
        if try modelContext.fetch(fd).first != nil { return }

        let cal = Calendar(identifier: .gregorian)
        var dc = DateComponents()
        dc.year = 2026
        dc.month = 3
        dc.day = 29
        let effective = cal.date(from: dc) ?? .now

        let daily: Decimal = 600
        let gh: Double = 14
        let derivedD = (daily as NSDecimalNumber).doubleValue / gh
        let mealHalf = Decimal(derivedD * 0.5)
        let derivedDec = Decimal(string: String(format: "%.4f", derivedD)) ?? 43

        let agreement = LaborAgreement(
            code: code,
            title: "IATSE 411 Chef / Catering (daily floor)",
            effectiveStartDate: effective,
            scaleNotes: "Chef profile: daily minimum with \(Int(gh))h divisor for implied OT base (\(daily) CAD ÷ \(Int(gh))h ≈ \(String(format: "%.2f", derivedD)) CAD/h). "
                + "Adjust `negotiatedDailyMinimumCAD` and `guaranteedHoursForDailyFloor` to your deal. "
                + "Portal-to-portal uses the show’s catering toggle + shop travel hooks. Not legal advice.",
            baseHourlyRateCAD: derivedDec,
            zoneTravelHourlyCAD: 45,
            mealPenaltyHalfHourCAD: mealHalf,
            overtimeMultiplierAfter8: 1.5,
            overtimeMultiplierAfter12: 2.0,
            maxWorkHoursBeforeMealRequired: 6,
            minimumRestHoursBetweenShootDays: 10,
            turnaroundGoldPayMultiplier: 2.5,
            sentinelCalculatorKindRaw: SentinelCalculatorKind.iatse411Chef.rawValue,
            negotiatedDailyMinimumCAD: daily,
            guaranteedHoursForDailyFloor: gh
        )
        modelContext.insert(agreement)
        try modelContext.save()
    }
}
