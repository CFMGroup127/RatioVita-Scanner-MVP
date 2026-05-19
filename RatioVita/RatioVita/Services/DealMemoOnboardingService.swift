import Foundation
import SwiftData

/// When a deal memo is classified, parse page 1, stack rate tiers, and anchor corporate identity.
@MainActor
enum DealMemoOnboardingService {
    struct Result: Equatable {
        var project: ProductionProject
        var createdNewProject: Bool
        var appendedRateTier: Bool
        var harvestedSummary: String?
    }

    /// Banner-only context after onboarding ran (avoids re-stacking rate tiers).
    static func bannerPresentation(receipt: Receipt, project: ProductionProject) -> Result {
        Result(
            project: project,
            createdNewProject: false,
            appendedRateTier: false,
            harvestedSummary: bannerSummary(receipt: receipt, project: project)
        )
    }

    static func processIfDealMemo(receipt: Receipt, context: ModelContext) -> Result? {
        guard DocumentTypeOption.fromStored(receipt.documentType) == .dealMemo else { return nil }

        let page1OCR = pageOneOCR(from: receipt)
        let payload = DealMemoSniper.parsePage1(combinedOCR: page1OCR) ?? fallbackPayload(from: receipt)

        ReceiptFinancialSanity.applyDealMemoFinancialPolicy(to: receipt, combinedOCR: page1OCR, context: context)
        applyExtractedFields(to: receipt, payload: payload)

        let title = canonicalProjectTitle(from: receipt, payload: payload)
        guard !title.isEmpty else { return nil }

        let existing = fetchProject(matchingTitle: title, context: context)
        let project: ProductionProject
        let created: Bool
        if let existing {
            project = existing
            created = false
            mergeHarvestedFields(from: receipt, payload: payload, into: project)
        } else {
            project = ProductionProject(
                title: title,
                notes: "Auto-created from deal memo scan.",
                billingClientCompanyName: payload.productionCompany ?? receipt.invoiceClientCompany,
                billingProductionManagerName: payload.productionManagerName ?? receipt.invoiceProductionManagerName
            )
            context.insert(project)
            created = true
            mergeHarvestedFields(from: receipt, payload: payload, into: project)
        }

        receipt.productionProject = project
        applyTaxRegistrationAnchor(receipt: receipt, page1OCR: page1OCR, payload: payload, context: context)
        let tierAppended = stackRateTier(payload: payload, project: project, context: context)

        if receipt.notes?.contains("deal memo") != true {
            let stamp = "Deal memo page 1 archived for \(title)."
            receipt.notes = [receipt.notes, stamp].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }

        let summary = tierSummary(payload: payload)
        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: FilingCoordinator.auditKindDealMemoOnboarded,
            title: created
                ? "Production onboarded from deal memo"
                : (tierAppended ? "Deal memo rate tier stacked" : "Deal memo linked to production"),
            detail: [title, summary, project.billingProductionManagerName.map { "PM: \($0)" }]
                .compactMap { $0 }
                .joined(separator: " · ")
        )
        try? context.save()

        return Result(
            project: project,
            createdNewProject: created,
            appendedRateTier: tierAppended,
            harvestedSummary: summary
        )
    }

    private static func pageOneOCR(from receipt: Receipt) -> String {
        let pages = receipt.images.sorted { $0.pageIndex < $1.pageIndex }
        if let first = pages.first?.ocrText, !first.isEmpty {
            return first
        }
        return receipt.images.compactMap(\.ocrText).filter { !$0.isEmpty }.first ?? ""
    }

    private static func fallbackPayload(from receipt: Receipt) -> DealMemoPage1Payload {
        DealMemoPage1Payload(
            showTitle: receipt.invoiceClientProjectTitle,
            productionCompany: receipt.invoiceClientCompany,
            positionTitle: receipt.department,
            department: receipt.department,
            effectiveStartDate: receipt.transactionDate,
            rateKind: .hourly,
            hourlyRateCAD: nil,
            flatDailyRateCAD: nil,
            flatGuaranteeHours: nil,
            isNonUnion: false,
            loanOutCompanyName: nil,
            gstHstRegistrationRaw: nil,
            productionManagerName: receipt.invoiceProductionManagerName,
            workerName: nil
        )
    }

    private static func applyTaxRegistrationAnchor(
        receipt: Receipt,
        page1OCR: String,
        payload: DealMemoPage1Payload,
        context: ModelContext
    ) {
        var matched: BusinessEntity?
        if let entity = TaxRegistrationAnchor.matchOwnedEntity(in: page1OCR, context: context) {
            matched = entity
        } else if let raw = payload.gstHstRegistrationRaw,
                  let core = TaxRegistrationAnchor.normalizedBusinessNumber(from: raw)
        {
            let entities =
                (try? context.fetch(FetchDescriptor<BusinessEntity>()))?
                    .filter(\.isOwnedCorporation) ?? []
            matched = entities.first(where: { $0.normalizedTaxRegistrationCore == core })
        }
        if matched == nil,
           let loan = payload.loanOutCompanyName?.trimmingCharacters(in: .whitespacesAndNewlines), !loan.isEmpty
        {
            let key = RegistryEntityPolarity.normalizedToken(loan)
            let entities =
                (try? context.fetch(FetchDescriptor<BusinessEntity>()))?
                    .filter(\.isOwnedCorporation) ?? []
            matched = entities.first(where: {
                RegistryEntityPolarity.normalizedToken($0.legalName) == key
                    || RegistryEntityPolarity.normalizedToken($0.legalName).contains(key)
            })
        }
        if let entity = matched {
            if let p = receipt.productionProject {
                p.businessEntity = entity
                p.updatedAt = .now
            }
            receiptAnchorNote(receipt: receipt, entity: entity)
        }
    }

    private static func receiptAnchorNote(receipt: Receipt, entity: BusinessEntity) {
        let bn = entity.normalizedTaxRegistrationCore ?? entity.legalName
        let line = "Corporate anchor: \(entity.legalName) (BN \(bn))."
        if receipt.notes?.contains("Corporate anchor:") != true {
            receipt.notes = [receipt.notes, line].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }

    private static func applyExtractedFields(to receipt: Receipt, payload: DealMemoPage1Payload) {
        if let t = payload.showTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            receipt.invoiceClientProjectTitle = t
        }
        if let c = payload.productionCompany?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            receipt.invoiceClientCompany = c
        }
        if let pm = payload.productionManagerName?.trimmingCharacters(in: .whitespacesAndNewlines), !pm.isEmpty {
            receipt.invoiceProductionManagerName = pm
        }
        if let d = payload.department?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            receipt.department = d
        }
        if let start = payload.effectiveStartDate {
            receipt.transactionDate = start
        }
        if let pos = payload.positionTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !pos.isEmpty {
            let lower = pos.lowercased()
            if !lower.contains("agreement"), !lower.contains("personnel services") {
                receipt.merchant = pos
            }
        }
    }

    private static func canonicalProjectTitle(from receipt: Receipt, payload: DealMemoPage1Payload) -> String {
        let candidates = [
            payload.showTitle,
            receipt.invoiceClientProjectTitle,
            payload.productionCompany,
            receipt.invoiceClientCompany,
            receipt.productionProject?.title,
        ]
        for raw in candidates {
            let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard t.count >= 3 else { continue }
            let lower = t.lowercased()
            if lower.contains("agreement") || lower.contains("personnel services") { continue }
            if lower.contains("film inc"), !lower.contains("see for me") { continue }
            return t
        }
        return ""
    }

    private static func fetchProject(matchingTitle title: String, context: ModelContext) -> ProductionProject? {
        let key = RegistryEntityPolarity.normalizedToken(title)
        guard !key.isEmpty else { return nil }
        let all = (try? context.fetch(FetchDescriptor<ProductionProject>())) ?? []
        return all.first { RegistryEntityPolarity.normalizedToken($0.title) == key }
            ?? all.first {
                let p = RegistryEntityPolarity.normalizedToken($0.title)
                return p.contains(key) || key.contains(p)
            }
    }

    private static func mergeHarvestedFields(
        from receipt: Receipt,
        payload: DealMemoPage1Payload,
        into project: ProductionProject
    ) {
        if let co = payload.productionCompany?.trimmingCharacters(in: .whitespacesAndNewlines), !co.isEmpty {
            project.billingClientCompanyName = co
            if project.parentBusinessTitle == nil { project.parentBusinessTitle = co }
        } else if let co = receipt.invoiceClientCompany?.trimmingCharacters(in: .whitespacesAndNewlines), !co.isEmpty {
            project.billingClientCompanyName = co
        }
        if let pm = payload.productionManagerName?.trimmingCharacters(in: .whitespacesAndNewlines), !pm.isEmpty {
            project.billingProductionManagerName = pm
        }
        if let pos = payload.positionTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !pos.isEmpty {
            project.crewOccupationTitle = pos
        }
        if payload.isNonUnion {
            project.automationGovernance = .customNonUnion
        }
        if let r = payload.kitPhoneRateCAD, r > 0 {
            project.defaultKitPhoneRateCAD = r
            if project.defaultKitPhoneWeeklyRateCAD == nil {
                project.defaultKitPhoneWeeklyRateCAD = r * 5
            }
        }
        if let r = payload.kitLaptopRateCAD, r > 0 {
            project.defaultKitLaptopRateCAD = r
            if project.defaultKitLaptopWeeklyRateCAD == nil {
                project.defaultKitLaptopWeeklyRateCAD = r * 5
            }
        }
        if let r = payload.kitTabletRateCAD, r > 0 {
            project.defaultKitTabletRateCAD = r
            if project.defaultKitTabletWeeklyRateCAD == nil {
                project.defaultKitTabletWeeklyRateCAD = r * 5
            }
        }
        project.updatedAt = .now
    }

    private static func bannerSummary(receipt: Receipt, project: ProductionProject) -> String? {
        if let latest = project.laborPositionRates.sorted(by: { $0.effectiveFromDate > $1.effectiveFromDate }).first {
            return "\(latest.occupationTitle) · \(latest.displayRateSummary)"
        }
        if let title = project.crewOccupationTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let t = receipt.invoiceClientProjectTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        return nil
    }

    @discardableResult
    private static func stackRateTier(
        payload: DealMemoPage1Payload,
        project: ProductionProject,
        context: ModelContext
    ) -> Bool {
        let effective = payload.effectiveStartDate ?? Calendar.current.startOfDay(for: Date())
        let title = payload.positionTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Position"
        guard title.count >= 2 else { return false }

        let hourly: Decimal
        let kind = payload.rateKind
        let flat = payload.flatDailyRateCAD
        let guarantee = payload.flatGuaranteeHours

        switch kind {
            case .hourly:
                guard let h = payload.hourlyRateCAD, h > 0 else { return false }
                hourly = h
            case .flatDaily:
                guard let f = flat, f > 0 else { return false }
                let g = max(guarantee ?? 14, 1)
                hourly = f / Decimal(g)
        }

        let duplicate = project.laborPositionRates.contains { row in
            Calendar.current.isDate(row.effectiveFromDate, inSameDayAs: effective)
                && RegistryEntityPolarity.normalizedToken(row.occupationTitle)
                == RegistryEntityPolarity.normalizedToken(title)
                && row.rateKind == kind
                && abs((row.baseHourlyRateCAD as NSDecimalNumber).doubleValue - (hourly as NSDecimalNumber).doubleValue)
                < 0.01
        }
        guard !duplicate else { return false }

        let tier = ShowLaborPositionRate(
            effectiveFromDate: effective,
            occupationTitle: title,
            baseHourlyRateCAD: hourly,
            rateKindRaw: kind.rawValue,
            flatDailyRateCAD: flat,
            flatGuaranteeHours: guarantee,
            department: payload.department,
            productionProject: project
        )
        context.insert(tier)
        project.laborPositionRates.append(tier)
        project.updatedAt = .now
        return true
    }

    private static func tierSummary(payload: DealMemoPage1Payload) -> String? {
        guard let pos = payload.positionTitle else { return nil }
        switch payload.rateKind {
            case .hourly:
                guard let h = payload.hourlyRateCAD else { return pos }
                return "\(pos) @ \(h) CAD/hr"
            case .flatDaily:
                guard let f = payload.flatDailyRateCAD else { return pos }
                let g = payload.flatGuaranteeHours ?? 14
                return "\(pos) @ \(f) CAD / \(g)h"
        }
    }
}
