import Foundation

/// Dispatches **873** vs **411 Chef** Sentinel math from `LaborAgreement.effectiveCalculatorKind`.
enum SentinelPayrollEngine {
    static let defaultPaycheckVarianceToleranceCAD: Decimal = 20

    static func estimatesWithTurnaround(
        projectDays: [CrewTimecardDay],
        agreement: LaborAgreement,
        calendar: Calendar = .current
    ) -> [UUID: SentinelPayEstimate] {
        switch agreement.effectiveCalculatorKind {
            case .iatse411Chef:
                IATSE411SentinelCalculator.estimatesWithTurnaround(
                    projectDays: projectDays,
                    agreement: agreement,
                    calendar: calendar
                )
            case .iatse873:
                IATSE873SentinelCalculator.estimatesWithTurnaround(
                    projectDays: projectDays,
                    agreement: agreement,
                    calendar: calendar
                )
        }
    }

    static func estimate(day: CrewTimecardDay, agreement: LaborAgreement, calendar: Calendar = .current)
        -> SentinelPayEstimate
    {
        if day.productionProject?.usesCustomNonUnionSentinel == true {
            return CustomNonUnionSentinelCalculator.estimate(day: day, calendar: calendar)
        }
        switch agreement.effectiveCalculatorKind {
            case .iatse411Chef:
                return IATSE411SentinelCalculator.estimate(day: day, agreement: agreement, calendar: calendar)
            case .iatse873:
                return IATSE873SentinelCalculator.estimate(day: day, agreement: agreement, calendar: calendar)
        }
    }

    static func estimate(
        for day: CrewTimecardDay,
        inProjectDays projectDays: [CrewTimecardDay],
        agreement: LaborAgreement,
        calendar: Calendar = .current
    ) -> SentinelPayEstimate {
        if day.productionProject?.usesCustomNonUnionSentinel == true {
            return CustomNonUnionSentinelCalculator.estimate(day: day, calendar: calendar)
        }
        switch agreement.effectiveCalculatorKind {
            case .iatse411Chef:
                return IATSE411SentinelCalculator.estimate(
                    for: day,
                    inProjectDays: projectDays,
                    agreement: agreement,
                    calendar: calendar
                )
            case .iatse873:
                return IATSE873SentinelCalculator.estimate(
                    for: day,
                    inProjectDays: projectDays,
                    agreement: agreement,
                    calendar: calendar
                )
        }
    }

    static func paycheckShowsVariance(
        paycheck: Receipt,
        allDays: [CrewTimecardDay],
        agreement: LaborAgreement,
        toleranceCAD: Decimal = defaultPaycheckVarianceToleranceCAD,
        calendar: Calendar = .current
    ) -> Bool {
        guard DocumentTypeOption.fromStored(paycheck.documentType) == .paycheck else { return false }
        guard let project = paycheck.productionProject else { return false }
        let anchor = paycheck.transactionDate ?? paycheck.createdAt
        guard let week = calendar.dateInterval(of: .weekOfYear, for: anchor) else { return false }

        let projectDays = allDays.filter { $0.productionProject?.id == project.id }
        let chain = estimatesWithTurnaround(projectDays: projectDays, agreement: agreement, calendar: calendar)

        let relevant = projectDays.filter { day in
            let sod = FraturdayCalendar.payrollAnchorStartOfDay(for: day, calendar: calendar)
            return sod >= week.start && sod < week.end
        }
        guard !relevant.isEmpty else { return false }

        var model = Decimal.zero
        for d in relevant {
            if let e = chain[d.id] {
                model += e.modelTotalCAD
            } else {
                model += estimate(day: d, agreement: agreement, calendar: calendar).modelTotalCAD
            }
        }

        let stub = abs(paycheck.total)
        // 411 Chef: treat variance as **underpayment** vs the Sentinel model (max of floor vs earned is already in
        // `modelTotalCAD`). Over-stated paychecks are intentionally ignored for the orange badge.
        if agreement.effectiveCalculatorKind == .iatse411Chef {
            return model - stub > toleranceCAD
        }
        return abs(stub - model) > toleranceCAD
    }
}
