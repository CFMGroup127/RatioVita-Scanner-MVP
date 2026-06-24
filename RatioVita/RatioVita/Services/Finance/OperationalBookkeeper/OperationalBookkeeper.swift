import Foundation
import SwiftData

/// Operational bookkeeper — expense extraction, PUID stamping, mileage tracking, ledger emission.
@MainActor
enum OperationalBookkeeper {
    struct IngestionResult: Sendable {
        let passID: String
        let entriesEmitted: Int
        let mileageLogsProcessed: Int
        let anomalyCount: Int
        let findings: [String]
        let warnings: [String]
    }

    static func run(modelContext: ModelContext) throws -> IngestionResult {
        let passID = UUID().uuidString.prefix(8).lowercased()
        var findings: [String] = []
        var warnings: [String] = []
        var entriesEmitted = 0
        var mileageProcessed = 0
        var allAnomalies: [String] = []

        try ReceiptFinanceAgentsService.runAll(modelContext: modelContext)

        let scope = BookkeepingScope.fromSovereignContext(SovereignContextManager.shared, modelContext: modelContext)
        let receipts = try modelContext.fetch(FetchDescriptor<Receipt>())
        let scoped = receipts.filter {
            $0.trashedAt == nil && SovereignScopeFilter.receiptIsVisible($0, context: SovereignContextManager.shared)
        }

        applyScopeBindings(scoped, scope: scope, modelContext: modelContext)

        for receipt in scoped {
            let parsed = OperationalBookkeeperParser.parse(receipt: receipt, scope: scope)

            if receipt.taxCategory == nil, let tax = parsed.taxCategory {
                receipt.taxCategory = tax
            }
            if parsed.logisticsDocumentKind != nil {
                applyLogisticsTags(receipt: receipt, parsed: parsed)
            }

            if let mileage = MileageLogTracker.parse(receipt: receipt, parsed: parsed) {
                mileageProcessed += 1
                upsertLedgerEntry(
                    modelContext: modelContext,
                    receipt: receipt,
                    parsed: parsed,
                    mileage: mileage,
                    passID: String(passID)
                )
                entriesEmitted += 1
                allAnomalies.append(contentsOf: mileage.anomalyFlags.map { "mileage:\($0)" })
            } else {
                upsertLedgerEntry(
                    modelContext: modelContext,
                    receipt: receipt,
                    parsed: parsed,
                    mileage: nil,
                    passID: String(passID)
                )
                entriesEmitted += 1
            }

            allAnomalies.append(contentsOf: parsed.anomalyFlags)
        }

        let pending = scoped.filter { !$0.isVerified }
        findings.append("Bookkeeper pass \(passID): emitted \(entriesEmitted) ledger row(s).")
        if let puid = scope.productionPUID {
            findings.append("PUID scope: \(puid).")
        }
        if let venture = scope.ventureEntityID {
            findings.append("Venture entity scope: \(venture.uuidString.prefix(8))…")
        }
        if mileageProcessed > 0 {
            findings.append("Mileage/fuel tracker processed \(mileageProcessed) travel artifact(s).")
        }

        let uniqueAnomalies = Array(Set(allAnomalies))
        if !uniqueAnomalies.isEmpty {
            warnings.append("Anomalies flagged: \(uniqueAnomalies.prefix(4).joined(separator: ", ")).")
        }
        if pending.count > 25 {
            warnings.append("\(pending.count) unverified receipt(s) — batch verify before comptroller pass.")
        }

        if !uniqueAnomalies.isEmpty {
            Task {
                await ComptrollerAuditHook.notifyIfNeeded(
                    anomalies: uniqueAnomalies,
                    passID: String(passID)
                )
            }
        }

        return IngestionResult(
            passID: String(passID),
            entriesEmitted: entriesEmitted,
            mileageLogsProcessed: mileageProcessed,
            anomalyCount: uniqueAnomalies.count,
            findings: findings,
            warnings: warnings
        )
    }

    private static func applyScopeBindings(
        _ receipts: [Receipt],
        scope: BookkeepingScope,
        modelContext: ModelContext
    ) {
        guard scope.requiresPUID || scope.requiresVentureEntity else { return }

        let projects = (try? modelContext.fetch(FetchDescriptor<ProductionProject>())) ?? []
        let entities = (try? modelContext.fetch(FetchDescriptor<BusinessEntity>())) ?? []

        for receipt in receipts {
            if scope.requiresPUID,
               receipt.productionProject == nil,
               let productionID = SovereignContextManager.shared.activeProductionID,
               let project = projects.first(where: { $0.id == productionID })
            {
                receipt.productionProject = project
            }
            if scope.requiresVentureEntity,
               receipt.productionProject?.businessEntity == nil,
               let ventureID = scope.ventureEntityID,
               let entity = entities.first(where: { $0.id == ventureID }),
               let project = receipt.productionProject ?? projects.first(where: { $0.businessEntity?.id == ventureID })
            {
                receipt.productionProject = project
                if project.businessEntity == nil {
                    project.businessEntity = entity
                }
            }
        }
    }

    private static func applyLogisticsTags(receipt: Receipt, parsed: OperationalBookkeeperParser.ParsedExpense) {
        if receipt.department == nil || receipt.department?.isEmpty == true,
           let firstCode = parsed.departmentalCostCodes.first
        {
            receipt.department = firstCode
        }
        if receipt.productionType == nil || receipt.productionType?.isEmpty == true,
           let kind = parsed.logisticsDocumentKind
        {
            receipt.productionType = kind
        }
    }

    private static func upsertLedgerEntry(
        modelContext: ModelContext,
        receipt: Receipt,
        parsed: OperationalBookkeeperParser.ParsedExpense,
        mileage: MileageLogTracker.MileageParseResult?,
        passID: String
    ) {
        let existing = (try? modelContext.fetch(FetchDescriptor<SovereignLedgerEntry>()))?
            .first(where: { $0.sourceReceiptID == receipt.id })

        let lineSummary = ledgerLineSummary(parsed: parsed, mileage: mileage)
        let kind = mileage?.entryKind ?? .expense
        let flags = parsed.anomalyFlags + (mileage?.anomalyFlags ?? [])
        let taxCategory = mileage?.estimatedDeduction != nil
            ? mileage?.travelDeductionCategory
            : parsed.taxCategory

        if let row = existing {
            row.vendorName = parsed.vendorName
            row.netAmount = parsed.netAmount
            row.taxAmount = parsed.taxAmount
            row.grossAmount = parsed.grossAmount
            row.currencyCode = parsed.currencyCode
            row.transactionTimestamp = parsed.transactionTimestamp
            row.lineItemSummary = lineSummary.isEmpty ? nil : lineSummary
            row.productionPUID = parsed.productionPUID
            row.ventureEntityID = parsed.ventureEntityID
            row.taxCategory = taxCategory
            row.glCode = parsed.glCode
            row.mileageKilometers = mileage?.distanceKilometers
            row.odometerReading = mileage?.odometerReading
            row.routeDescription = mileage?.routeDescription
            row.deductionRatePerUnit = mileage?.deductionRatePerUnit
            row.estimatedDeductionAmount = mileage?.estimatedDeduction
            row.anomalyFlagsRaw = flags.isEmpty ? nil : flags.joined(separator: ",")
            row.bookkeepingPassID = passID
            row.entryKindRaw = kind.rawValue
        } else {
            let row = SovereignLedgerEntry(
                entryKind: kind,
                vendorName: parsed.vendorName,
                netAmount: parsed.netAmount,
                taxAmount: parsed.taxAmount,
                grossAmount: parsed.grossAmount,
                currencyCode: parsed.currencyCode,
                transactionTimestamp: parsed.transactionTimestamp,
                lineItemSummary: lineSummary.isEmpty ? nil : lineSummary,
                productionPUID: parsed.productionPUID,
                ventureEntityID: parsed.ventureEntityID,
                taxCategory: taxCategory,
                glCode: parsed.glCode,
                mileageKilometers: mileage?.distanceKilometers,
                odometerReading: mileage?.odometerReading,
                routeDescription: mileage?.routeDescription,
                deductionRatePerUnit: mileage?.deductionRatePerUnit,
                estimatedDeductionAmount: mileage?.estimatedDeduction,
                anomalyFlags: flags,
                sourceReceiptID: receipt.id,
                bookkeepingPassID: passID
            )
            modelContext.insert(row)
        }
    }

    private static func ledgerLineSummary(
        parsed: OperationalBookkeeperParser.ParsedExpense,
        mileage: MileageLogTracker.MileageParseResult?
    ) -> String {
        var segments: [String] = []
        segments.append(contentsOf: parsed.lineItemDescriptions.prefix(6))
        if !parsed.departmentalCostCodes.isEmpty {
            segments.append("codes: \(parsed.departmentalCostCodes.prefix(4).joined(separator: ", "))")
        }
        if !parsed.crewNameTokens.isEmpty {
            segments.append("crew: \(parsed.crewNameTokens.prefix(4).joined(separator: ", "))")
        }
        if let route = mileage?.routeDescription, !route.isEmpty {
            segments.append("route: \(route)")
        }
        if let kind = parsed.logisticsDocumentKind {
            segments.append("doc: \(kind)")
        }
        let joined = segments.joined(separator: " · ")
        return joined.isEmpty ? "" : joined
    }
}
