//
//  ReceiptPersistence.swift
//  RatioVita
//
//  Shared path for persisting a ScanResult into SwiftData (scanner, import, bundled archive).
//

import Foundation
import SwiftData

@MainActor
enum ReceiptPersistence {
    static func fetchRegistryEntityLegalNames(context: ModelContext) -> [String] {
        (try? context.fetch(FetchDescriptor<BusinessEntity>()))?
            .filter(\.isOwnedCorporation)
            .map(\.legalName)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
    }

    /// Official + active shadow names for payee-led polarity during extraction.
    static func fetchPolarityEntityLegalNames(context: ModelContext) -> [String] {
        fetchRegistryEntityLegalNames(context: context)
            + ShadowRegistryService.fetchActiveShadowLegalNames(context: context)
    }

    static func applyDocumentTypeFromKind(_ receipt: Receipt, documentKind: String?) {
        guard let dk = documentKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return }
        if dk == "time_sheet" {
            receipt.documentType = DocumentTypeOption.timeSheet.rawValue
        } else if dk == "pay_stub" {
            receipt.documentType = DocumentTypeOption.paycheck.rawValue
        } else if dk == "outgoing_invoice" || (dk.contains("outgoing") && dk.contains("invoice")) {
            receipt.documentType = DocumentTypeOption.outgoingInvoice.rawValue
        } else if dk == "income" || dk.contains("income") || dk.contains("check") || dk.contains("cheque") {
            receipt.documentType = DocumentTypeOption.incomeOrCheck.rawValue
        } else if dk == "fuel" || dk.contains("fuel_receipt") || dk.contains("gas_receipt") {
            receipt.documentType = DocumentTypeOption.fuel.rawValue
        } else if dk == "bank_statement" || dk.contains("bank_statement") {
            receipt.documentType = DocumentTypeOption.statement.rawValue
        } else if dk == "deal_memo" || dk.contains("deal_memo") || dk.contains("deal memo") {
            receipt.documentType = DocumentTypeOption.dealMemo.rawValue
        } else if dk == "project_manuscript" || dk.contains("manuscript") {
            receipt.documentType = DocumentTypeOption.manuscript.rawValue
        }
    }

    /// Saves a processed scan into the library.
    static func saveScanResult(
        _ result: ScanResult,
        context: ModelContext,
        compressionEnabled: Bool,
        createdAtOverride: Date? = nil,
        notes: String? = nil,
        pendingHumanReview: Bool = false,
        scannedViaCamera: Bool = false,
        deferGeminiRefinement: Bool = false,
        vaultPathPrefix: String? = nil
    ) async throws {
        let ocr = result.combinedOCRText
        let registryEntityNames = fetchPolarityEntityLegalNames(context: context)
        let apiKeyPresent = !GeminiAPIKeyResolver.resolveAPIKeyTrimmed().isEmpty
        let geminiOn = GeminiAPIKeyResolver.isGeminiExtractionEnabled()
        let useQuickHeuristicOnly = deferGeminiRefinement && scannedViaCamera && geminiOn && apiKeyPresent

        let merged: ExtractedData
        let source: String
        if useQuickHeuristicOnly {
            merged = ReceiptStructuredExtractor.polarizedHeuristic(
                result.extractedData,
                supplementalOCR: ocr,
                registryEntityLegalNames: registryEntityNames
            )
            source = "heuristic"
        } else {
            (merged, source) = await ReceiptStructuredExtractor.extractMerged(
                combinedOCRText: ocr,
                heuristic: result.extractedData,
                registryEntityLegalNames: registryEntityNames
            )
        }

        let currencyResolved = ReceiptCurrency.resolved(from: merged.currency).code
        let captureOrIngestInstant = createdAtOverride ?? Date()
        let transactionDate = merged.date
        // `merged` prefers Gemini JSON over heuristics (`ExtractedData.fillingGaps`); that date becomes both
        // `transactionDate` and primary `createdAt` for lists/sorts.
        let createdAt = ReceiptScanPipeline.preferredReceiptCreatedAt(
            extractedDocumentDate: transactionDate,
            captureOrImportFallback: captureOrIngestInstant
        )
        let merchantRaw = merged.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let merchant = merchantRaw.isEmpty ? "Unknown Merchant" : merchantRaw
        let sanitized = ReceiptFinancialSanity.sanitizedExtractedAmounts(
            documentKind: merged.documentKind,
            subtotal: merged.subtotal,
            taxAmount: merged.taxAmount,
            total: merged.total
        )
        let total = sanitized.total ?? 0

        let receipt = Receipt(
            createdAt: createdAt,
            merchant: merchant,
            total: total,
            currencyCode: currencyResolved,
            notes: notes,
            transactionDate: transactionDate,
            vendorAddress: merged.vendorAddress,
            documentNumber: merged.documentNumber,
            chequeNumber: merged.chequeNumber,
            internalInvoiceNumber: merged.internalInvoiceNumber,
            clientAccountingToken: merged.clientAccountingToken,
            referenceInvoiceNumber: merged.internalInvoiceNumber,
            paymentMethodSummary: merged.paymentMethodSummary,
            subtotalAmount: sanitized.subtotal,
            taxAmount: sanitized.taxAmount,
            extractionSource: source,
            documentKind: merged.documentKind,
            payeeName: merged.payee,
            payorName: merged.payor,
            invoicePurchaseOrderNumber: merged.purchaseOrderNumber,
            invoiceProductionManagerName: merged.productionManagerName,
            invoiceClientProjectTitle: merged.clientProjectTitle,
            invoiceClientCompany: merged.clientProductionCompany,
            pendingHumanReview: pendingHumanReview,
            scannedViaCamera: scannedViaCamera,
            reviewChecklistDone: false
        )

        applyDocumentTypeFromKind(receipt, documentKind: merged.documentKind)
        ReceiptCanadianTaxSlipPolicy.applyModelKindToReceiptDocumentType(
            receipt: receipt,
            documentKind: merged.documentKind
        )
        ReceiptFinancialSanity.applyDealMemoFinancialPolicy(to: receipt)

        let docType = DocumentTypeOption.fromStored(receipt.documentType)
        receipt.total = AccountingAmountPolarity.canonicalTotal(documentType: docType, amount: receipt.total)
        receipt.subtotalAmount = AccountingAmountPolarity.canonicalOptionalAmount(
            documentType: docType,
            amount: sanitized.subtotal
        )
        receipt.taxAmount = AccountingAmountPolarity.canonicalOptionalAmount(
            documentType: docType,
            amount: sanitized.taxAmount
        )
        ReceiptCabinetRouting.applyImplicitCabinetForDocumentType(receipt: receipt)

        var images: [ReceiptImage] = []
        for (idx, page) in result.scannedPages.enumerated() {
            let img = ReceiptImage(
                pageIndex: idx,
                image: page.image,
                ocrText: page.ocrText,
                receipt: receipt,
                compressionQuality: compressionEnabled ? 0.6 : 0.9
            )
            images.append(img)
        }
        receipt.images = images

        var persistedLines: [ReceiptLineItem] = []
        if let items = merged.lineItems {
            for (idx, li) in items.enumerated() {
                let row = ReceiptLineItem(
                    sortIndex: idx,
                    lineDescription: li.description,
                    quantity: li.quantity,
                    unitPrice: li.unitPrice,
                    totalPrice: li.totalPrice,
                    serialNumber: li.serialNumber,
                    receipt: receipt
                )
                persistedLines.append(row)
            }
        }
        receipt.lineItems = persistedLines

        if let p = vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            receipt.vaultPathPrefix = p.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        context.insert(receipt)
        try attachWorkRecordsFromExtractedData(merged, receipt: receipt, context: context)
        try ShadowRegistryService.applyForensicAssociations(
            receipt: receipt,
            merged: merged,
            supplementalOCR: ocr,
            context: context
        )
        CorporateAnchorRoutingEngine.apply(
            receipt: receipt,
            combinedOCR: ocr,
            merged: merged,
            context: context
        )
        try enrichProductionProjectBillingHints(merged, receipt: receipt, context: context)
        applyTaxCategoryHeuristics(receipt: receipt, merged: merged, ocr: ocr)
        try FilingCoordinator.applyMerchantFilingRulesIfNeeded(to: receipt, context: context)
        ReceiptCanadianTaxSlipPolicy.applyAutoLockIfNeeded(receipt: receipt)
        ReceiptIngestEnhancer.applyToReceipt(receipt, from: merged, context: context)
        if DocumentTypeOption.fromStored(receipt.documentType) == .dealMemo {
            _ = DealMemoOnboardingService.processIfDealMemo(receipt: receipt, context: context)
        }
        ReceiptWorkspaceBatchGuard.pinMultiPageBatchIfNeeded(receipt)
        try ModelContextMainActorSave.saveThrows(context)
        LibraryPersistenceMonitor.recordSnapshot(context: context, reason: "ingest")
        RatioVitaBackupManager.archiveAfterSignificantWrite(modelContext: context)

        if receipt.images.count >= 2 {
            try? ReceiptMultiPageStructuralIntegrity.evaluatePersistedReceipt(receipt: receipt, context: context)
        }

        if useQuickHeuristicOnly {
            ReceiptGeminiBackgroundRefinement.scheduleAfterQuickCameraSave(
                container: context.container,
                receiptID: receipt.id,
                combinedOCRText: ocr
            )
        }
    }

    /// Applies a later Gemini merge onto an existing receipt (same field coverage as `saveScanResult`, without images).
    static func applyGeminiRefinementProfile(
        merged: ExtractedData,
        extractionSource: String,
        receiptID: UUID,
        context: ModelContext
    ) throws {
        let fd = FetchDescriptor<Receipt>(predicate: #Predicate { $0.id == receiptID })
        guard let receipt = try context.fetch(fd).first else { return }

        for li in receipt.lineItems {
            context.delete(li)
        }
        for wr in receipt.workRecords {
            context.delete(wr)
        }

        let currencyResolved = ReceiptCurrency.resolved(from: merged.currency).code
        let transactionDate = merged.date
        let captureOrIngestInstant = receipt.createdAt
        let createdAt = ReceiptScanPipeline.preferredReceiptCreatedAt(
            extractedDocumentDate: transactionDate,
            captureOrImportFallback: captureOrIngestInstant
        )
        receipt.createdAt = createdAt

        let merchantRaw = merged.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let merchant = merchantRaw.isEmpty ? "Unknown Merchant" : merchantRaw
        let sanitized = ReceiptFinancialSanity.sanitizedExtractedAmounts(
            documentKind: merged.documentKind,
            subtotal: merged.subtotal,
            taxAmount: merged.taxAmount,
            total: merged.total
        )
        let total = sanitized.total ?? 0

        receipt.merchant = merchant
        receipt.total = total
        receipt.currencyCode = currencyResolved
        receipt.transactionDate = transactionDate
        receipt.vendorAddress = merged.vendorAddress
        receipt.documentNumber = merged.documentNumber
        receipt.chequeNumber = merged.chequeNumber
        receipt.internalInvoiceNumber = merged.internalInvoiceNumber
        receipt.clientAccountingToken = merged.clientAccountingToken
        if receipt.referenceInvoiceNumber == nil || receipt.referenceInvoiceNumber?.isEmpty == true {
            receipt.referenceInvoiceNumber = merged.internalInvoiceNumber
        }
        receipt.paymentMethodSummary = merged.paymentMethodSummary
        receipt.extractionSource = extractionSource
        receipt.documentKind = merged.documentKind
        receipt.payeeName = merged.payee
        receipt.payorName = merged.payor
        receipt.invoicePurchaseOrderNumber = merged.purchaseOrderNumber
        receipt.invoiceProductionManagerName = merged.productionManagerName
        receipt.invoiceClientProjectTitle = merged.clientProjectTitle
        receipt.invoiceClientCompany = merged.clientProductionCompany

        applyDocumentTypeFromKind(receipt, documentKind: merged.documentKind)
        ReceiptCanadianTaxSlipPolicy.applyModelKindToReceiptDocumentType(
            receipt: receipt,
            documentKind: merged.documentKind
        )
        ReceiptFinancialSanity.applyDealMemoFinancialPolicy(to: receipt)

        let docType = DocumentTypeOption.fromStored(receipt.documentType)
        receipt.total = AccountingAmountPolarity.canonicalTotal(documentType: docType, amount: receipt.total)
        receipt.subtotalAmount = AccountingAmountPolarity.canonicalOptionalAmount(
            documentType: docType,
            amount: sanitized.subtotal
        )
        receipt.taxAmount = AccountingAmountPolarity.canonicalOptionalAmount(
            documentType: docType,
            amount: sanitized.taxAmount
        )
        ReceiptCabinetRouting.applyImplicitCabinetForDocumentType(receipt: receipt)

        var persistedLines: [ReceiptLineItem] = []
        if let items = merged.lineItems {
            for (idx, li) in items.enumerated() {
                let row = ReceiptLineItem(
                    sortIndex: idx,
                    lineDescription: li.description,
                    quantity: li.quantity,
                    unitPrice: li.unitPrice,
                    totalPrice: li.totalPrice,
                    serialNumber: li.serialNumber,
                    receipt: receipt
                )
                persistedLines.append(row)
            }
        }
        receipt.lineItems = persistedLines

        try attachWorkRecordsFromExtractedData(merged, receipt: receipt, context: context)
        let ocr = receipt.images.compactMap(\.ocrText).joined(separator: "\n\n")
        try ShadowRegistryService.applyForensicAssociations(
            receipt: receipt,
            merged: merged,
            supplementalOCR: ocr,
            context: context
        )
        CorporateAnchorRoutingEngine.apply(
            receipt: receipt,
            combinedOCR: ocr,
            merged: merged,
            context: context
        )
        try enrichProductionProjectBillingHints(merged, receipt: receipt, context: context)
        applyTaxCategoryHeuristics(receipt: receipt, merged: merged, ocr: ocr)
        try FilingCoordinator.applyMerchantFilingRulesIfNeeded(to: receipt, context: context)
        ReceiptCanadianTaxSlipPolicy.applyAutoLockIfNeeded(receipt: receipt)
        ReceiptIngestEnhancer.applyToReceipt(receipt, from: merged, context: context)
        if DocumentTypeOption.fromStored(receipt.documentType) == .dealMemo {
            _ = DealMemoOnboardingService.processIfDealMemo(receipt: receipt, context: context)
        }
    }

    private static func applyTaxCategoryHeuristics(receipt: Receipt, merged: ExtractedData, ocr: String) {
        guard receipt.taxCategory == nil || receipt.taxCategory?.isEmpty == true else { return }
        let corpus = [receipt.merchant, merged.payee, merged.payor, ocr].compactMap { $0 }.joined(separator: " ")
        if let rd = TaxCategoryCatalog.suggestFromCorpus(corpus) {
            receipt.taxCategory = rd
        } else if let tax = ReceiptFinanceAgentsHeuristics.suggestTaxCategory(fromCorpus: corpus) {
            receipt.taxCategory = tax
        }
    }

    /// Matches `ProductionProject` from invoice / call-sheet hints and copies billing metadata onto the show row.
    private static func enrichProductionProjectBillingHints(
        _ merged: ExtractedData,
        receipt: Receipt,
        context: ModelContext
    ) throws {
        var hints: [String] = []
        if let t = merged.clientProjectTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            hints.append(t)
        }
        if let t = merged.clientProductionCompany?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            hints.append(t)
        }
        if let first = merged.workTimeEntries?.first?.showTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !first.isEmpty
        {
            hints.append(first)
        }
        guard !hints.isEmpty else { return }

        let projects = try context.fetch(FetchDescriptor<ProductionProject>())
        for hint in hints {
            let lower = hint.lowercased()
            guard let p = projects.first(where: { proj in
                let t = proj.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return false }
                let pl = t.lowercased()
                return pl == lower || pl.contains(lower) || lower.contains(pl)
            }) else { continue }

            if receipt.productionProject == nil {
                receipt.productionProject = p
            }
            if p.billingPurchaseOrderNumber == nil,
               let po = merged.purchaseOrderNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
               !po.isEmpty
            {
                p.billingPurchaseOrderNumber = po
            }
            if p.billingProductionManagerName == nil,
               let pm = merged.productionManagerName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !pm.isEmpty
            {
                p.billingProductionManagerName = pm
            }
            if p.billingClientCompanyName == nil,
               let c = merged.clientProductionCompany?.trimmingCharacters(in: .whitespacesAndNewlines),
               !c.isEmpty
            {
                p.billingClientCompanyName = c
            }
            p.updatedAt = .now
            return
        }
    }

    /// Persists `ExtractedData.workTimeEntries` as `WorkRecord` rows (Gemini time sheets / pay stubs).
    private static func attachWorkRecordsFromExtractedData(
        _ merged: ExtractedData,
        receipt: Receipt,
        context: ModelContext
    ) throws {
        guard let entries = merged.workTimeEntries, !entries.isEmpty else { return }
        let projects = try context.fetch(FetchDescriptor<ProductionProject>())
        let calendar = Calendar.current

        for entry in entries {
            guard let d = entry.workDate else { continue }
            let day = calendar.startOfDay(for: d)
            var matched: ProductionProject?
            let titleCandidates: [String] = [
                entry.showTitle,
                merged.clientProjectTitle,
                merged.clientProductionCompany,
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

            if let rawTitle = titleCandidates.first {
                let lower = rawTitle.lowercased()
                matched = projects.first { p in
                    let t = p.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return false }
                    let pl = t.lowercased()
                    return pl == lower || pl.contains(lower) || lower.contains(pl)
                }
            }
            let row = WorkRecord(
                workDate: day,
                hoursWorked: entry.hours,
                showTitle: entry.showTitle,
                productionProject: matched,
                sourceReceipt: receipt
            )
            context.insert(row)
        }
    }
}
