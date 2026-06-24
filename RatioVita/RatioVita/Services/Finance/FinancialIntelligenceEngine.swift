import Foundation
import SwiftData

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Specialized financial expert squad — three operational strategies behind one orchestrator.
@MainActor
enum FinancialIntelligenceEngine {
    static func runAll(modelContext: ModelContext) throws -> [FinancialIntelligenceReport] {
        #if canImport(FirebaseCore)
        if FirebaseApp.allApps?.isEmpty ?? true {
            #if DEBUG
            print("[WARN] FinancialIntelligenceEngine: Skipping background pass. Firebase not yet configured.")
            #endif
            return []
        }
        #endif

        var reports: [FinancialIntelligenceReport] = []
        reports.append(try runOperationalBookkeeper(modelContext: modelContext))
        reports.append(try TaxationAuditorStrategy.run(modelContext: modelContext))
        reports.append(try CorporateComptrollerStrategy.run(modelContext: modelContext))
        try modelContext.save()

        let summary = reports.flatMap(\.warnings).prefix(3).joined(separator: " · ")
        if !summary.isEmpty {
            Task {
                _ = await HybridAgentBrokerService.shared.submit(
                    kind: .financialAnalysis,
                    targetExpertName: "Sophia Vance",
                    targetExpertEmail: "sophia.vance@ratiovita.com",
                    productionId: SovereignContextManager.shared.activeProductionID?.uuidString,
                    financialStrategy: .corporateComptroller,
                    payloadSummary: summary
                )
            }
        }
        return reports
    }

    private static func runOperationalBookkeeper(modelContext: ModelContext) throws -> FinancialIntelligenceReport {
        let result = try OperationalBookkeeper.run(modelContext: modelContext)
        return FinancialIntelligenceReport(
            strategy: .operationalBookkeeper,
            findings: result.findings,
            warnings: result.warnings,
            processedAt: .now
        )
    }
}

// MARK: - Taxation auditor

enum TaxationAuditorStrategy {
    static func run(modelContext: ModelContext) throws -> FinancialIntelligenceReport {
        var findings: [String] = []
        var warnings: [String] = []

        let receipts = try modelContext.fetch(FetchDescriptor<Receipt>())
        let scoped = receipts.filter {
            $0.trashedAt == nil && SovereignScopeFilter.receiptIsVisible($0, context: SovereignContextManager.shared)
        }

        let missingCategory = scoped.filter { $0.taxCategory == nil || $0.taxCategory?.isEmpty == true }
        if !missingCategory.isEmpty {
            warnings.append("CRA/IRS: \(missingCategory.count) receipt(s) missing tax category — deduction risk.")
        }

        let freelancerKeywords = ["home office", "kit", "equipment", "professional", "union", "iatse"]
        var deductionHints = 0
        for receipt in scoped where receipt.taxCategory == nil {
            let corpus = [receipt.merchant, receipt.notes ?? "", receipt.department ?? ""].joined(separator: " ").lowercased()
            if freelancerKeywords.contains(where: { corpus.contains($0) }) {
                deductionHints += 1
            }
        }
        if deductionHints > 0 {
            findings.append("Taxation auditor surfaced \(deductionHints) likely freelancer deduction candidate(s).")
        }

        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let installmentMonths = [3, 6, 9, 12]
        if installmentMonths.contains(month) {
            let quarterSpend = scoped.reduce(Decimal.zero) { partial, receipt in
                guard calendar.isDate(receipt.createdAt, equalTo: Date(), toGranularity: .quarter) else { return partial }
                return partial + receipt.total
            }
            if quarterSpend > 5_000 {
                warnings.append("Quarterly installment vulnerability: \(month)/\(calendar.component(.year, from: Date())) — review CRA/IRS estimated payments.")
            } else {
                findings.append("Quarterly tax window open — spend within expected freelancer threshold.")
            }
        }

        return FinancialIntelligenceReport(
            strategy: .taxationAuditor,
            findings: findings,
            warnings: warnings,
            processedAt: .now
        )
    }
}

// MARK: - Corporate comptroller

enum CorporateComptrollerStrategy {
    static func run(modelContext: ModelContext) throws -> FinancialIntelligenceReport {
        var findings: [String] = []
        var warnings: [String] = []

        let entities = try modelContext.fetch(FetchDescriptor<BusinessEntity>())
        let projects = try modelContext.fetch(FetchDescriptor<ProductionProject>())
        let assets = try modelContext.fetch(FetchDescriptor<EquipmentAsset>())
        let ledgerRows = try modelContext.fetch(FetchDescriptor<SovereignLedgerEntry>())

        let ventureLinked = projects.filter { $0.businessEntity != nil }
        findings.append("Corporate comptroller tracking \(entities.count) entity(ies), \(ventureLinked.count) linked production(s).")
        findings.append("Sovereign ledger: \(ledgerRows.count) normalized row(s) from bookkeeper pipeline.")

        let flaggedLedger = ledgerRows.filter { !$0.anomalyFlags.isEmpty }
        if !flaggedLedger.isEmpty {
            warnings.append("Comptroller queue: \(flaggedLedger.count) ledger row(s) carry anomaly flags.")
        }

        let personalHub = SovereignContextManager.shared.activeHub == .personal
        let ventureHub = SovereignContextManager.shared.activeHub == .ventures
        if personalHub {
            findings.append("Dual-layer mode: personal hub — suppressing venture capital asset roll-forward.")
        }
        if ventureHub {
            let ventureID = SovereignContextManager.shared.activeVentureEntityID
            let scopedProjects = projects.filter { $0.businessEntity?.id == ventureID }
            findings.append("Venture hub isolation: \(scopedProjects.count) production(s) under active venture entity.")
        }

        let capitalAssets = assets.filter { asset in
            (asset.sourceReceipt?.total ?? .zero) > 1_000 || (asset.dailyRentalRateCAD ?? .zero) > 0
        }
        if !capitalAssets.isEmpty {
            findings.append("Capital asset register: \(capitalAssets.count) tracked equipment item(s).")
        }

        let unlinkedVentureReceipts = try modelContext.fetch(FetchDescriptor<Receipt>())
            .filter { $0.trashedAt == nil && $0.productionProject?.businessEntity == nil && $0.total > 500 }
        if unlinkedVentureReceipts.count > 5 {
            warnings.append("Inter-company gap: \(unlinkedVentureReceipts.count) high-value receipt(s) not linked to a corporate entity.")
        }

        return FinancialIntelligenceReport(
            strategy: .corporateComptroller,
            findings: findings,
            warnings: warnings,
            processedAt: .now
        )
    }
}
