import Foundation
import SwiftData

/// Re-applies **cheque stub heuristics** on saved OCR (legacy rows, no re-scan / no Gemini).
@MainActor
enum ReceiptChequeStubRefresh {
    struct Result: Equatable {
        var applied: Bool
        var message: String
    }

    static func reapplyFromSavedOCR(receipt: Receipt, context: ModelContext) throws -> Result {
        let ocr = combinedOCR(from: receipt)
        guard ocr.count >= 60 else {
            return Result(applied: false, message: "No OCR text on file for this receipt.")
        }

        let registry = ReceiptPersistence.fetchPolarityEntityLegalNames(context: context)
        let heuristic = OCRParsing.extractData(from: ocr)
        let base = receipt.displayExtractedData(fallbackFromOCR: heuristic)
        let enriched = ReceiptIngestEnhancer.enrichMerged(
            base,
            supplementalOCR: ocr,
            registryEntityLegalNames: registry
        )

        let stubDetected = ChequeStubParser.parse(combinedOCR: ocr) != nil
            || enriched.chequeNumber != nil
            || enriched.internalInvoiceNumber != nil
        guard stubDetected else {
            return Result(
                applied: false,
                message: "No corporate cheque / payout stub pattern found in saved OCR."
            )
        }

        applyEnriched(enriched, to: receipt, context: context)

        if let payorResult = PayorContactRegistry.registerPayorIfNeeded(
            payorName: enriched.payor ?? enriched.merchant,
            payorAddress: enriched.payorAddress ?? enriched.vendorAddress,
            receipt: receipt,
            context: context
        ), payorResult.created {
            FilingCoordinator.appendAudit(
                context: context,
                kindRaw: FilingCoordinator.auditKindContactHarvested,
                title: "Payor added to contacts",
                detail: "payor:\(payorResult.contact.name)"
            )
        }

        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: FilingCoordinator.auditKindChequeStubReparse,
            title: "Cheque stub re-parsed",
            detail: summary(enriched)
        )
        try context.save()

        return Result(applied: true, message: "Cheque fields updated from saved OCR. \(summary(enriched))")
    }

    private static func combinedOCR(from receipt: Receipt) -> String {
        receipt.images
            .sorted { $0.pageIndex < $1.pageIndex }
            .compactMap(\.ocrText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func applyEnriched(
        _ merged: ExtractedData,
        to receipt: Receipt,
        context: ModelContext
    ) {
        if let payor = merged.merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !payor.isEmpty {
            receipt.merchant = payor
        }
        receipt.payeeName = merged.payee
        receipt.payorName = merged.payor
        receipt.chequeNumber = merged.chequeNumber
        receipt.internalInvoiceNumber = merged.internalInvoiceNumber
        receipt.clientAccountingToken = merged.clientAccountingToken

        if let inv = merged.internalInvoiceNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !inv.isEmpty {
            receipt.documentNumber = inv
        } else if let doc = merged.documentNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !doc.isEmpty,
                  doc != merged.chequeNumber
        {
            receipt.documentNumber = doc
        } else if receipt.documentNumber == merged.chequeNumber {
            receipt.documentNumber = merged.internalInvoiceNumber
        }

        let registry = ReceiptPersistence.fetchPolarityEntityLegalNames(context: context)
        let payeeIsOwned = RegistryEntityPolarity.matchesRegistryEntity(
            merchant: nil,
            payee: merged.payee,
            supplementalOCR: combinedOCR(from: receipt),
            entityLegalNames: registry
        )
        if payeeIsOwned {
            let payorTrimmed = merged.payorAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            receipt.vendorAddress = payorTrimmed.isEmpty ? nil : payorTrimmed
        } else if let addr = merged.vendorAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !addr.isEmpty {
            receipt.vendorAddress = addr
        }

        if let date = merged.date {
            receipt.transactionDate = date
        }
        if let payment = merged.paymentMethodSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !payment.isEmpty
        {
            receipt.paymentMethodSummary = payment
        }

        receipt.documentKind = merged.documentKind ?? "income"
        ReceiptPersistence.applyDocumentTypeFromKind(receipt, documentKind: receipt.documentKind)

        let docType = DocumentTypeOption.fromStored(receipt.documentType)
        if let total = merged.total {
            receipt.total = AccountingAmountPolarity.canonicalTotal(documentType: docType, amount: total)
        }
        if let currency = merged.currency?.trimmingCharacters(in: .whitespacesAndNewlines), !currency.isEmpty {
            receipt.currencyCode = ReceiptCurrency.resolved(from: currency).code
        } else if receipt.currencyCode.uppercased() == "EUR" {
            receipt.currencyCode = ReceiptCurrency.CAD.code
        }

        if let token = merged.internalInvoiceNumber,
           receipt.referenceInvoiceNumber == nil || receipt.referenceInvoiceNumber?.isEmpty == true
        {
            receipt.referenceInvoiceNumber = token
        }

        InternalInvoicePolarityGuard.applyIfNeeded(receipt: receipt, context: context)
        ReceiptCabinetRouting.applyImplicitCabinetForDocumentType(receipt: receipt)
    }

    private static func summary(_ merged: ExtractedData) -> String {
        [
            merged.chequeNumber.map { "Cheque #\($0)" },
            merged.internalInvoiceNumber.map { "Invoice #\($0)" },
            merged.clientAccountingToken.map { "SAP/ref \($0)" },
            merged.payor.map { "Payor: \($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}
