import Foundation

/// Resolves structured receipt fields from OCR using Gemini when configured, with heuristic fallback.
enum ReceiptStructuredExtractor {
    /// On-device OCR/heuristic profile with **document polarity** applied (no Gemini round-trip).
    static func polarizedHeuristic(
        _ heuristic: ExtractedData,
        supplementalOCR ocr: String?,
        registryEntityLegalNames: [String] = []
    ) -> ExtractedData {
        let trimmed = heuristic.documentKind?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedKind: String? = if let trimmed, !trimmed.isEmpty {
            heuristic.documentKind
        } else {
            ReceiptCanadianTaxSlipPolicy.inferDocumentKindSupplement(from: ocr ?? "")
        }
        let enriched = ReceiptIngestEnhancer.enrichMerged(
            heuristic.withDocumentKind(resolvedKind),
            supplementalOCR: ocr ?? "",
            registryEntityLegalNames: registryEntityLegalNames
        )
        return applyDocumentPolarity(
            enriched,
            supplementalOCR: ocr,
            registryEntityLegalNames: registryEntityLegalNames
        )
    }

    static func extractMerged(
        combinedOCRText: String,
        heuristic: ExtractedData,
        registryEntityLegalNames: [String] = []
    ) async -> (merged: ExtractedData, source: String) {
        let (apiKey, enabled, modelId) = await MainActor.run {
            (
                GeminiAPIKeyResolver.resolveAPIKeyTrimmed(),
                GeminiAPIKeyResolver.isGeminiExtractionEnabled(),
                GeminiAPIKeyResolver.resolveModelId()
            )
        }
        guard enabled, !apiKey.isEmpty else {
            #if DEBUG
            if enabled, apiKey.isEmpty {
                await MainActor.run {
                    GeminiAPIKeyResolver
                        .logGeminiKeyDiagnostics(context: "ReceiptStructuredExtractor skipped Gemini (no key)")
                }
            }
            #endif
            return (
                Self.polarizedHeuristic(
                    heuristic,
                    supplementalOCR: combinedOCRText,
                    registryEntityLegalNames: registryEntityLegalNames
                ),
                "heuristic"
            )
        }

        let trimmedOCR = combinedOCRText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOCR.isEmpty else {
            return (
                Self.polarizedHeuristic(
                    heuristic,
                    supplementalOCR: nil,
                    registryEntityLegalNames: registryEntityLegalNames
                ),
                "heuristic"
            )
        }

        do {
            let payload = try await GeminiReceiptExtractionService.extractReceiptPayload(
                combinedOCRText: combinedOCRText,
                apiKey: apiKey,
                modelId: modelId
            )
            let fromLLM = Self.mapPayloadToExtractedData(payload)
            let merged = fromLLM.fillingGaps(with: heuristic)
            let mergedKindTrimmed = merged.documentKind?.trimmingCharacters(in: .whitespacesAndNewlines)
            let refinedKind: String? = if let mergedKindTrimmed, !mergedKindTrimmed.isEmpty {
                merged.documentKind
            } else {
                ReceiptCanadianTaxSlipPolicy.inferDocumentKindSupplement(from: trimmedOCR)
            }
            let refined = merged.withDocumentKind(refinedKind)
            let enriched = await MainActor.run {
                ReceiptIngestEnhancer.enrichMerged(
                    refined,
                    supplementalOCR: trimmedOCR,
                    registryEntityLegalNames: registryEntityLegalNames
                )
            }
            let polarized = Self.applyDocumentPolarity(
                enriched,
                supplementalOCR: trimmedOCR,
                registryEntityLegalNames: registryEntityLegalNames
            )
            return (polarized, "gemini")
        } catch {
            #if DEBUG
            print("RatioVita: Gemini extraction failed: \(error.localizedDescription)")
            #endif
            let enriched = await MainActor.run {
                ReceiptIngestEnhancer.enrichMerged(
                    heuristic,
                    supplementalOCR: trimmedOCR,
                    registryEntityLegalNames: registryEntityLegalNames
                )
            }
            let fallback = Self.applyDocumentPolarity(
                enriched,
                supplementalOCR: trimmedOCR,
                registryEntityLegalNames: registryEntityLegalNames
            )
            return (fallback, "heuristic")
        }
    }

    private static func applyDocumentPolarity(
        _ merged: ExtractedData,
        supplementalOCR: String? = nil,
        registryEntityLegalNames: [String] = []
    ) -> ExtractedData {
        var kind = merged.documentKind
        if let incomeKind = RegistryEntityPolarity.refinedDocumentKindForRegistryIncome(
            documentKind: kind,
            merchant: merged.merchant,
            payee: merged.payee,
            supplementalOCR: supplementalOCR,
            entityLegalNames: registryEntityLegalNames
        ) {
            kind = incomeKind
        }
        if let bespokeKind = RegistryEntityPolarity.bespokeForensicHardLockOutgoingInvoice(
            documentKind: kind,
            merchant: merged.merchant,
            payee: merged.payee,
            payor: merged.payor,
            supplementalOCR: supplementalOCR
        ) {
            kind = bespokeKind
        }
        let prov = AccountingAmountPolarity.provisionalDocumentType(documentKind: kind)
        var merchant = merged.merchant
        if prov == .incomeOrCheck,
           let payor = merged.payor?.trimmingCharacters(in: .whitespacesAndNewlines), !payor.isEmpty
        {
            merchant = payor
        }
        return ExtractedData(
            merchant: merchant,
            payee: merged.payee,
            payor: merged.payor,
            payorAddress: merged.payorAddress,
            total: AccountingAmountPolarity.canonicalOptionalAmount(documentType: prov, amount: merged.total),
            currency: merged.currency,
            date: merged.date,
            vendorAddress: merged.vendorAddress,
            documentNumber: merged.documentNumber,
            purchaseOrderNumber: merged.purchaseOrderNumber,
            productionManagerName: merged.productionManagerName,
            clientProjectTitle: merged.clientProjectTitle,
            clientProductionCompany: merged.clientProductionCompany,
            paymentMethodSummary: merged.paymentMethodSummary,
            lineItems: merged.lineItems,
            taxAmount: AccountingAmountPolarity.canonicalOptionalAmount(documentType: prov, amount: merged.taxAmount),
            subtotal: AccountingAmountPolarity.canonicalOptionalAmount(documentType: prov, amount: merged.subtotal),
            merchantConfidence: merged.merchantConfidence,
            totalConfidence: merged.totalConfidence,
            dateConfidence: merged.dateConfidence,
            documentKind: kind,
            workTimeEntries: merged.workTimeEntries
        )
    }

    private static func mapPayloadToExtractedData(_ p: GeminiReceiptPayload) -> ExtractedData {
        let date = parseTransactionDate(p.transactionDate)
        let lineItems: [LineItem]? = {
            guard let rows = p.lineItems, !rows.isEmpty else { return nil }
            return rows.map { line in
                LineItem(
                    description: line.description,
                    quantity: line.quantity,
                    unitPrice: decimal(from: line.unitPrice),
                    totalPrice: decimal(from: line.totalPrice),
                    serialNumber: line.serialNumber,
                    confidence: nil
                )
            }
        }()

        let workTimeEntries: [ExtractedWorkTime]? = {
            guard let days = p.workDays, !days.isEmpty else { return nil }
            return days.map { d in
                ExtractedWorkTime(
                    workDate: parseTransactionDate(d.date),
                    hours: d.hours,
                    showTitle: nonEmptyTrimmed(d.showTitle)
                )
            }
        }()

        return ExtractedData(
            merchant: nonEmptyTrimmed(p.merchant),
            payee: nonEmptyTrimmed(p.payee),
            payor: nonEmptyTrimmed(p.payor),
            payorAddress: nonEmptyTrimmed(p.payorAddress),
            total: decimal(from: p.total),
            currency: nonEmptyTrimmed(p.currency).map { $0.uppercased() },
            date: date,
            vendorAddress: nonEmptyTrimmed(p.vendorAddress),
            documentNumber: nonEmptyTrimmed(p.documentNumber),
            purchaseOrderNumber: nonEmptyTrimmed(p.purchaseOrderNumber),
            productionManagerName: nonEmptyTrimmed(p.productionManagerName),
            clientProjectTitle: nonEmptyTrimmed(p.clientProjectTitle),
            clientProductionCompany: nonEmptyTrimmed(p.clientProductionCompany),
            paymentMethodSummary: nonEmptyTrimmed(p.paymentMethod),
            lineItems: lineItems,
            taxAmount: decimal(from: p.taxAmount),
            subtotal: decimal(from: p.subtotal),
            merchantConfidence: nil,
            totalConfidence: nil,
            dateConfidence: nil,
            documentKind: nonEmptyTrimmed(p.documentKind),
            workTimeEntries: workTimeEntries,
            chequeNumber: nonEmptyTrimmed(p.chequeNumber),
            internalInvoiceNumber: nonEmptyTrimmed(p.internalInvoiceNumber),
            clientAccountingToken: nonEmptyTrimmed(p.clientAccountingToken)
        )
    }

    private static func nonEmptyTrimmed(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    private static func decimal(from double: Double?) -> Decimal? {
        guard let double else { return nil }
        return Decimal(double)
    }

    private static func parseTransactionDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_CA_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: raw)
    }
}
