import Foundation
import SwiftData

/// Imports library rows from a **`.rvsovereign`** master backup into the **current** `ModelContext`
/// (merge-by-receipt-id).
@MainActor
enum SovereignMasterRestoreService {
    struct Summary: Sendable {
        var receiptsImported: Int
        var receiptsSkippedExisting: Int
        var merchantRulesImported: Int
    }

    enum RestoreError: Error, LocalizedError {
        case missingManifest
        case missingSwiftDataStoreDirectory
        case couldNotLocateStoreFile
        case backupOpenFailed(String)
        case emptyArchive

        var errorDescription: String? {
            switch self {
                case .missingManifest: "Backup is missing manifest.json."
                case .missingSwiftDataStoreDirectory: "Backup is missing swiftdata_store."
                case .couldNotLocateStoreFile: "Could not locate the SwiftData store inside the backup."
                case let .backupOpenFailed(msg): msg
                case .emptyArchive: "Archive contained no receipts."
            }
        }
    }

    /// Decrypts `fileURL`, unpacks the inner ZIP, opens a **temporary** read-mostly SwiftData store from the backup,
    /// then copies **receipts** (and their images / line items / work rows) plus any **new** merchant filing rules.
    static func mergeArchive(fileURL: URL, password: String, into modelContext: ModelContext) throws -> Summary {
        let sealed = try Data(contentsOf: fileURL)
        let zipBytes = try SovereignBackupEncryption.unseal(sealed: sealed, password: password)

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent(
            "RatioVitaRestore-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let unpacked = work.appendingPathComponent("unpacked", isDirectory: true)
        try ZipStoreReader.unzip(data: zipBytes, to: unpacked)
        return try mergeUnpackedBundle(at: unpacked, into: modelContext, auditKind: "sovereign.archive.restored")
    }

    /// Shared merge path for `.rvsovereign` (decrypted) and `.rvvault` cleartext packages.
    @MainActor
    static func mergeUnpackedBundle(
        at unpacked: URL,
        into modelContext: ModelContext,
        auditKind: String = "vault.archive.merged"
    ) throws -> Summary {
        let fm = FileManager.default
        let manifestURL = unpacked.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else { throw RestoreError.missingManifest }
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(SovereignMasterBackupService.Manifest.self, from: manifestData)

        let storeSrcDir = unpacked.appendingPathComponent("swiftdata_store", isDirectory: true)
        guard fm.fileExists(atPath: storeSrcDir.path) else { throw RestoreError.missingSwiftDataStoreDirectory }

        let work = unpacked.deletingLastPathComponent()
        let storeRWParent = work.appendingPathComponent("store_rw-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: storeRWParent, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: storeRWParent) }
        for item in try fm.contentsOfDirectory(at: storeSrcDir, includingPropertiesForKeys: nil) {
            let dest = storeRWParent.appendingPathComponent(item.lastPathComponent)
            try fm.copyItem(at: item, to: dest)
        }

        let preferredName = manifest.storeFileNames.first(where: { !$0.isEmpty }) ?? "default.store"
        let storeRWURL = storeRWParent.appendingPathComponent(preferredName)
        guard fm.fileExists(atPath: storeRWURL.path) else { throw RestoreError.couldNotLocateStoreFile }

        let schema = LibrarySwiftDataSchema.makeSchema()
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeRWURL,
            cloudKitDatabase: .none
        )

        let backupContainer: ModelContainer
        do {
            backupContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            throw RestoreError.backupOpenFailed(error.localizedDescription)
        }

        let backupContext = ModelContext(backupContainer)
        backupContext.autosaveEnabled = false

        let backupReceipts = try backupContext.fetch(FetchDescriptor<Receipt>())
        var mainIDs = try Set(modelContext.fetch(FetchDescriptor<Receipt>()).map(\.id))

        var imported = 0
        var skipped = 0
        for src in backupReceipts {
            if mainIDs.contains(src.id) {
                skipped += 1
                continue
            }
            try cloneReceiptGraph(from: src, into: modelContext)
            mainIDs.insert(src.id)
            imported += 1
        }

        try mergeLaborAgreements(from: backupContext, into: modelContext)
        try mergeShowLaborPositionRates(from: backupContext, into: modelContext)
        try mergeCrewTimecardDays(from: backupContext, into: modelContext)
        try mergeSolomonMedia(from: backupContext, into: modelContext)

        let backupRules = try backupContext.fetch(FetchDescriptor<MerchantFilingRule>())
        let mainRules = try modelContext.fetch(FetchDescriptor<MerchantFilingRule>())
        var rulesImported = 0
        for br in backupRules {
            let duplicate = mainRules.contains { mr in
                mr.merchantContainsNormalized == br.merchantContainsNormalized
                    && mr.targetVaultPathPrefix == br.targetVaultPathPrefix
                    && mr.lineItemContainsNormalized == br.lineItemContainsNormalized
            }
            if duplicate { continue }
            let copy = MerchantFilingRule(
                createdAt: br.createdAt,
                merchantContainsNormalized: br.merchantContainsNormalized,
                lineItemContainsNormalized: br.lineItemContainsNormalized,
                targetVaultPathPrefix: br.targetVaultPathPrefix,
                priority: br.priority,
                isEnabled: br.isEnabled
            )
            modelContext.insert(copy)
            rulesImported += 1
        }

        try ModelContextMainActorSave.saveThrows(modelContext)

        FilingCoordinator.appendAudit(
            context: modelContext,
            kindRaw: auditKind,
            title: "Merged vault archive",
            detail:
            "rid:merge·imported:\(imported)·skipped:\(skipped)·rules:\(rulesImported)·from:\(manifest.createdAt.formatted(date: .abbreviated, time: .shortened))"
        )
        try ModelContextMainActorSave.saveThrows(modelContext)

        return Summary(
            receiptsImported: imported,
            receiptsSkippedExisting: skipped,
            merchantRulesImported: rulesImported
        )
    }

    private static func cloneReceiptGraph(from src: Receipt, into context: ModelContext) throws {
        let dst = Receipt(
            id: src.id,
            createdAt: src.createdAt,
            merchant: src.merchant,
            total: src.total,
            currencyCode: src.currencyCode,
            notes: src.notes,
            transactionDate: src.transactionDate,
            vendorAddress: src.vendorAddress,
            documentNumber: src.documentNumber,
            chequeNumber: src.chequeNumber,
            internalInvoiceNumber: src.internalInvoiceNumber,
            clientAccountingToken: src.clientAccountingToken,
            referenceInvoiceNumber: src.referenceInvoiceNumber,
            paymentMethodSummary: src.paymentMethodSummary,
            subtotalAmount: src.subtotalAmount,
            taxAmount: src.taxAmount,
            extractionSource: src.extractionSource,
            documentKind: src.documentKind,
            documentType: src.documentType,
            annotations: src.annotations,
            depositDate: src.depositDate,
            isVerified: src.isVerified,
            isLedgerLinked: false,
            taxCategory: src.taxCategory,
            filingCabinetKindRaw: src.filingCabinetKindRaw,
            vaultPathPrefix: src.vaultPathPrefix,
            productionType: src.productionType,
            productionProject: nil,
            department: src.department,
            businessUsePercent: src.businessUsePercent,
            businessUseSuggestedPercent: src.businessUseSuggestedPercent,
            businessUseVerifiedByTimeSheet: src.businessUseVerifiedByTimeSheet,
            images: [],
            lineItems: [],
            workSessions: [],
            workRecords: [],
            referenceLinks: [],
            incomingReferenceLinks: [],
            matchedBankTransaction: nil,
            counterpartyContact: nil,
            payeeName: src.payeeName,
            payorName: src.payorName,
            pendingHumanReview: src.pendingHumanReview,
            scannedViaCamera: src.scannedViaCamera,
            reviewChecklistDone: src.reviewChecklistDone,
            dealMemoTimecardPromptDismissed: src.dealMemoTimecardPromptDismissed,
            workspaceBatchPinned: src.workspaceBatchPinned,
            parentBatchReceiptID: src.parentBatchReceiptID,
            facilitatedThirdPartyLabor: src.facilitatedThirdPartyLabor,
            trashedAt: src.trashedAt
        )
        context.insert(dst)

        let sortedImages = src.images.sorted { $0.pageIndex < $1.pageIndex }
        for img in sortedImages {
            let copyImg = ReceiptImage(
                id: img.id,
                pageIndex: img.pageIndex,
                jpegData: img.imageData,
                ocrText: img.ocrText,
                createdAt: img.createdAt,
                receipt: dst
            )
            context.insert(copyImg)
        }

        let sortedLines = src.lineItems.sorted { $0.sortIndex < $1.sortIndex }
        for li in sortedLines {
            let nli = ReceiptLineItem(
                id: UUID(),
                sortIndex: li.sortIndex,
                lineDescription: li.lineDescription,
                quantity: li.quantity,
                unitPrice: li.unitPrice,
                totalPrice: li.totalPrice,
                serialNumber: li.serialNumber,
                barcodeValue: li.barcodeValue,
                rfidTag: li.rfidTag,
                warrantyEndDate: li.warrantyEndDate,
                glCode: li.glCode,
                receipt: dst
            )
            context.insert(nli)
        }

        let sortedSessions = src.workSessions.sorted { $0.sortIndex < $1.sortIndex }
        for ws in sortedSessions {
            let sessionProject = try resolveOrInsertProductionProject(
                ws.productionProject ?? src.productionProject,
                into: context
            )
            let nws = WorkSession(
                id: ws.id,
                sortIndex: ws.sortIndex,
                workDate: ws.workDate,
                productionTitle: ws.productionTitle,
                productionProject: sessionProject,
                departmentOrCategory: ws.departmentOrCategory,
                notes: ws.notes,
                receipt: dst
            )
            context.insert(nws)
        }

        for wr in src.workRecords {
            let wrProject = try resolveOrInsertProductionProject(
                wr.productionProject ?? src.productionProject,
                into: context
            )
            let nwr = WorkRecord(
                id: wr.id,
                workDate: wr.workDate,
                hoursWorked: wr.hoursWorked,
                showTitle: wr.showTitle,
                notes: wr.notes,
                createdAt: wr.createdAt,
                callOnSet: wr.callOnSet,
                wrapOffSet: wr.wrapOffSet,
                travelLeaveZoneStart: wr.travelLeaveZoneStart,
                travelToSetArrive: wr.travelToSetArrive,
                travelReturnLeaveSet: wr.travelReturnLeaveSet,
                travelReturnHome: wr.travelReturnHome,
                meal1Start: wr.meal1Start,
                meal1End: wr.meal1End,
                meal2Start: wr.meal2Start,
                meal2End: wr.meal2End,
                zoneTravelNotes: wr.zoneTravelNotes,
                productionProject: wrProject,
                sourceReceipt: dst
            )
            context.insert(nwr)
        }

        try FilingCoordinator.applyMerchantFilingRulesIfNeeded(to: dst, context: context)
        ReceiptCanadianTaxSlipPolicy.applyAutoLockIfNeeded(receipt: dst)
    }

    /// Re-links or inserts a `ProductionProject` so restored receipts, `WorkRecord`s, and crew days land on the
    /// Timeline with the same show UUID as the archive.
    private static func resolveOrInsertProductionProject(
        _ src: ProductionProject?,
        into context: ModelContext
    ) throws -> ProductionProject? {
        guard let src else { return nil }
        let sid = src.id
        var fd = FetchDescriptor<ProductionProject>(predicate: #Predicate { $0.id == sid })
        fd.fetchLimit = 1
        if let existing = try context.fetch(fd).first { return existing }

        let copy = ProductionProject(
            id: src.id,
            title: src.title,
            notes: src.notes,
            createdAt: src.createdAt,
            updatedAt: src.updatedAt,
            parentBusinessTitle: src.parentBusinessTitle,
            registryStatusRaw: src.registryStatusRaw,
            timelineColorHex: src.timelineColorHex,
            crewOccupationTitle: src.crewOccupationTitle,
            defaultKitPhoneRateCAD: src.defaultKitPhoneRateCAD,
            defaultKitLaptopRateCAD: src.defaultKitLaptopRateCAD,
            defaultKitTabletRateCAD: src.defaultKitTabletRateCAD,
            defaultKitPhoneWeeklyRateCAD: src.defaultKitPhoneWeeklyRateCAD,
            defaultKitLaptopWeeklyRateCAD: src.defaultKitLaptopWeeklyRateCAD,
            defaultKitTabletWeeklyRateCAD: src.defaultKitTabletWeeklyRateCAD,
            laborCateringPortalMode: src.laborCateringPortalMode,
            productionContractKindRaw: src.productionContractKindRaw,
            billingClientCompanyName: src.billingClientCompanyName,
            billingProductionManagerName: src.billingProductionManagerName,
            billingPurchaseOrderNumber: src.billingPurchaseOrderNumber,
            paymentTermsRaw: src.paymentTermsRaw,
            businessEntity: nil
        )
        context.insert(copy)
        return copy
    }

    private static func mergeLaborAgreements(from backup: ModelContext, into main: ModelContext) throws {
        let backupRows = try backup.fetch(FetchDescriptor<LaborAgreement>())
        let mainCodes = try Set(main.fetch(FetchDescriptor<LaborAgreement>()).map(\.code))
        for row in backupRows where !mainCodes.contains(row.code) {
            let copy = LaborAgreement(
                id: row.id,
                code: row.code,
                title: row.title,
                effectiveStartDate: row.effectiveStartDate,
                scaleNotes: row.scaleNotes,
                baseHourlyRateCAD: row.baseHourlyRateCAD,
                zoneTravelHourlyCAD: row.zoneTravelHourlyCAD,
                mealPenaltyHalfHourCAD: row.mealPenaltyHalfHourCAD,
                overtimeMultiplierAfter8: row.overtimeMultiplierAfter8,
                overtimeMultiplierAfter12: row.overtimeMultiplierAfter12,
                maxWorkHoursBeforeMealRequired: row.maxWorkHoursBeforeMealRequired,
                minimumRestHoursBetweenShootDays: row.minimumRestHoursBetweenShootDays,
                turnaroundGoldPayMultiplier: row.turnaroundGoldPayMultiplier,
                sentinelCalculatorKindRaw: row.sentinelCalculatorKindRaw,
                negotiatedDailyMinimumCAD: row.negotiatedDailyMinimumCAD,
                guaranteedHoursForDailyFloor: row.guaranteedHoursForDailyFloor,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
            main.insert(copy)
        }
    }

    private static func mergeShowLaborPositionRates(from backup: ModelContext, into main: ModelContext) throws {
        let backupRates = try backup.fetch(FetchDescriptor<ShowLaborPositionRate>())
        let mainIDs = try Set(main.fetch(FetchDescriptor<ShowLaborPositionRate>()).map(\.id))
        for r in backupRates {
            guard !mainIDs.contains(r.id) else { continue }
            guard let project = try resolveOrInsertProductionProject(r.productionProject, into: main) else { continue }
            let copy = ShowLaborPositionRate(
                id: r.id,
                effectiveFromDate: r.effectiveFromDate,
                occupationTitle: r.occupationTitle,
                baseHourlyRateCAD: r.baseHourlyRateCAD,
                premiumHourlyRateCAD: r.premiumHourlyRateCAD,
                createdAt: r.createdAt,
                updatedAt: r.updatedAt,
                productionProject: project
            )
            main.insert(copy)
        }
    }

    private static func mergeCrewTimecardDays(from backup: ModelContext, into main: ModelContext) throws {
        let backupDays = try backup.fetch(FetchDescriptor<CrewTimecardDay>())
        let mainIDs = try Set(main.fetch(FetchDescriptor<CrewTimecardDay>()).map(\.id))
        for d in backupDays {
            guard !mainIDs.contains(d.id) else { continue }
            guard let project = try resolveOrInsertProductionProject(d.productionProject, into: main) else { continue }
            let copy = CrewTimecardDay(
                id: d.id,
                workDate: d.workDate,
                createdAt: d.createdAt,
                updatedAt: d.updatedAt,
                productionProject: project,
                travelLeaveZoneStart: d.travelLeaveZoneStart,
                travelToSetArrive: d.travelToSetArrive,
                callOnSet: d.callOnSet,
                generalCrewCall: d.generalCrewCall,
                department: d.department,
                unitType: d.unitType,
                meal1Start: d.meal1Start,
                meal1End: d.meal1End,
                meal2Start: d.meal2Start,
                meal2End: d.meal2End,
                wrapOffSet: d.wrapOffSet,
                travelReturnLeaveSet: d.travelReturnLeaveSet,
                travelReturnHome: d.travelReturnHome,
                occupationTitle: d.occupationTitle,
                overrideBaseHourlyRateCAD: d.overrideBaseHourlyRateCAD,
                travelLogMTOVerified: d.travelLogMTOVerified,
                paperForensicAuditMode: d.paperForensicAuditMode,
                travelLogPayPeriodNote: d.travelLogPayPeriodNote,
                ancillaryPhoneDays: d.ancillaryPhoneDays,
                ancillaryLaptopDays: d.ancillaryLaptopDays,
                ancillaryTabletDays: d.ancillaryTabletDays,
                ancillaryPhoneRateCAD: d.ancillaryPhoneRateCAD,
                ancillaryLaptopRateCAD: d.ancillaryLaptopRateCAD,
                ancillaryTabletRateCAD: d.ancillaryTabletRateCAD,
                kitRentalFullTimeMode: d.kitRentalFullTimeMode,
                notes: d.notes
            )
            main.insert(copy)
        }
    }

    private static func mergeSolomonMedia(from backup: ModelContext, into main: ModelContext) throws {
        let mainAssetIDs = try Set(main.fetch(FetchDescriptor<MediaAsset>()).map(\.id))
        let backupAssets = try backup.fetch(FetchDescriptor<MediaAsset>())
        var assetMap: [UUID: MediaAsset] = [:]

        for src in backupAssets {
            guard !mainAssetIDs.contains(src.id) else { continue }
            let copy = MediaAsset(
                id: src.id,
                title: src.title,
                notes: src.notes,
                createdAt: src.createdAt,
                updatedAt: src.updatedAt,
                assetKind: src.assetKind,
                distributionFormat: src.distributionFormat,
                echoStream: src.echoStream,
                governance: src.governance,
                vaultRelativePath: src.vaultRelativePath,
                durationSeconds: src.durationSeconds,
                clipDurationSeconds: src.clipDurationSeconds,
                analogueCharacteristics: src.analogueCharacteristics
            )
            main.insert(copy)
            assetMap[src.id] = copy
        }

        let mainSegmentIDs = try Set(main.fetch(FetchDescriptor<LyricSegment>()).map(\.id))
        for seg in try backup.fetch(FetchDescriptor<LyricSegment>()) {
            guard !mainSegmentIDs.contains(seg.id) else { continue }
            let parent = seg.mediaAsset.flatMap { assetMap[$0.id] }
            let copy = LyricSegment(
                id: seg.id,
                sortIndex: seg.sortIndex,
                lyricText: seg.lyricText,
                performanceDelivery: seg.performanceDelivery,
                startOffsetSeconds: seg.startOffsetSeconds,
                endOffsetSeconds: seg.endOffsetSeconds,
                createdAt: seg.createdAt,
                updatedAt: seg.updatedAt,
                mediaAsset: parent
            )
            main.insert(copy)
        }

        let mainCardIDs = try Set(main.fetch(FetchDescriptor<MetadataCard>()).map(\.id))
        for card in try backup.fetch(FetchDescriptor<MetadataCard>()) {
            guard !mainCardIDs.contains(card.id) else { continue }
            let linked = card.linkedMediaAsset.flatMap { assetMap[$0.id] }
            let copy = MetadataCard(
                id: card.id,
                sortIndex: card.sortIndex,
                frontPoeticVerse: card.frontPoeticVerse,
                backWisdomInsight: card.backWisdomInsight,
                scripturalReference: card.scripturalReference,
                echoStream: card.echoStream,
                governance: card.governance,
                presentationStyle: card.presentationStyle,
                spokenIntroScript: card.spokenIntroScript,
                modernExpansionScript: card.modernExpansionScript,
                createdAt: card.createdAt,
                updatedAt: card.updatedAt,
                linkedMediaAsset: linked
            )
            main.insert(copy)
        }

        let mainMaatIDs = try Set(main.fetch(FetchDescriptor<MaatDeclaration>()).map(\.id))
        for decl in try backup.fetch(FetchDescriptor<MaatDeclaration>()) {
            guard !mainMaatIDs.contains(decl.id) else { continue }
            let card = decl.metadataCard.flatMap { c in
                try? main.fetch(FetchDescriptor<MetadataCard>()).first { $0.id == c.id }
            }
            let copy = MaatDeclaration(
                id: decl.id,
                declarationNumber: decl.declarationNumber,
                ancientText: decl.ancientText,
                modernExpansion: decl.modernExpansion,
                judgeName: decl.judgeName,
                judgeOrigin: decl.judgeOrigin,
                presentationStyle: decl.presentationStyle,
                createdAt: decl.createdAt,
                updatedAt: decl.updatedAt,
                metadataCard: card
            )
            main.insert(copy)
        }

        let mainNodeIDs = try Set(main.fetch(FetchDescriptor<HistoricalKnowledgeNode>()).map(\.id))
        for node in try backup.fetch(FetchDescriptor<HistoricalKnowledgeNode>()) {
            guard !mainNodeIDs.contains(node.id) else { continue }
            let copy = HistoricalKnowledgeNode(
                id: node.id,
                title: node.title,
                bodyMarkdown: node.bodyMarkdown,
                tags: node.tags,
                governance: node.governance,
                createdAt: node.createdAt,
                updatedAt: node.updatedAt
            )
            main.insert(copy)
        }

        let mainBeatIDs = try Set(main.fetch(FetchDescriptor<MediaProductionBeat>()).map(\.id))
        for beat in try backup.fetch(FetchDescriptor<MediaProductionBeat>()) {
            guard !mainBeatIDs.contains(beat.id) else { continue }
            let asset = beat.mediaAsset.flatMap { a in
                try? main.fetch(FetchDescriptor<MediaAsset>()).first { $0.id == a.id }
            }
            let copy = MediaProductionBeat(
                id: beat.id,
                sortIndex: beat.sortIndex,
                timestampStartSeconds: beat.timestampStartSeconds,
                timestampEndSeconds: beat.timestampEndSeconds,
                audioSpec: beat.audioSpec,
                visualPrompt: beat.visualPrompt,
                governance: beat.governance,
                notes: beat.notes,
                createdAt: beat.createdAt,
                updatedAt: beat.updatedAt,
                mediaAsset: asset
            )
            main.insert(copy)
        }
    }
}
