import Foundation
import SwiftData

/// Post-extraction enrichment: cheque stubs, deal memos, payor/payee address correction.
@MainActor
enum ReceiptIngestEnhancer {
    static func enrichMerged(
        _ merged: ExtractedData,
        supplementalOCR: String,
        registryEntityLegalNames: [String]
    ) -> ExtractedData {
        var data = merged
        let auto = DocumentKindAutoClassifier.classify(
            combinedOCR: supplementalOCR,
            currentDocumentKind: data.documentKind
        )
        if let kind = auto.documentKind {
            data = data.withDocumentKind(kind)
        }

        if let stub = ChequeStubParser.parse(combinedOCR: supplementalOCR) {
            data = applyChequeStub(stub, to: data, registryEntityLegalNames: registryEntityLegalNames)
        }

        data = correctPayorPayeeAddresses(
            data,
            supplementalOCR: supplementalOCR,
            registryEntityLegalNames: registryEntityLegalNames
        )
        return data
    }

    static func applyToReceipt(
        _ receipt: Receipt,
        from merged: ExtractedData,
        context: ModelContext
    ) {
        receipt.payeeName = merged.payee
        receipt.payorName = merged.payor
        receipt.chequeNumber = merged.chequeNumber
        receipt.internalInvoiceNumber = merged.internalInvoiceNumber
        receipt.clientAccountingToken = merged.clientAccountingToken

        let auto = DocumentKindAutoClassifier.classify(
            combinedOCR: receipt.images.compactMap(\.ocrText).joined(separator: "\n\n"),
            currentDocumentKind: receipt.documentKind
        )
        if let kind = auto.documentKind {
            receipt.documentKind = kind
        }
        if let dt = auto.documentType {
            receipt.documentType = dt.rawValue
        }

        InternalInvoicePolarityGuard.applyIfNeeded(receipt: receipt, context: context)
        FacilitatedThirdPartyInvoiceClassifier.applyIfNeeded(to: receipt)
    }

    private static func applyChequeStub(
        _ stub: ChequeStubPayload,
        to merged: ExtractedData,
        registryEntityLegalNames _: [String]
    ) -> ExtractedData {
        let payor = stub.payorName ?? merged.payor ?? merged.merchant
        let payee = stub.payeeName ?? merged.payee
        let date = stub.paymentDate ?? merged.date
        let total = stub.netAmount ?? merged.total
        return ExtractedData(
            merchant: payor ?? merged.merchant,
            payee: payee,
            payor: payor,
            payorAddress: merged.payorAddress,
            total: total,
            currency: merged.currency ?? "CAD",
            date: date,
            vendorAddress: merged.vendorAddress,
            documentNumber: stub.internalInvoiceNumber ?? merged.documentNumber,
            purchaseOrderNumber: merged.purchaseOrderNumber,
            productionManagerName: merged.productionManagerName,
            clientProjectTitle: merged.clientProjectTitle,
            clientProductionCompany: stub.payorName ?? merged.clientProductionCompany,
            paymentMethodSummary: merged.paymentMethodSummary ?? "Cheque",
            lineItems: merged.lineItems,
            taxAmount: merged.taxAmount,
            subtotal: merged.subtotal,
            merchantConfidence: merged.merchantConfidence,
            totalConfidence: merged.totalConfidence,
            dateConfidence: merged.dateConfidence,
            documentKind: "income",
            workTimeEntries: merged.workTimeEntries,
            chequeNumber: stub.chequeNumber,
            internalInvoiceNumber: stub.internalInvoiceNumber,
            clientAccountingToken: stub.clientAccountingToken
        )
    }

    private static func correctPayorPayeeAddresses(
        _ merged: ExtractedData,
        supplementalOCR: String,
        registryEntityLegalNames: [String]
    ) -> ExtractedData {
        let payeeIsOwned = RegistryEntityPolarity.matchesRegistryEntity(
            merchant: nil,
            payee: merged.payee,
            supplementalOCR: supplementalOCR,
            entityLegalNames: registryEntityLegalNames
        )
        guard payeeIsOwned else { return merged }

        let payorTrimmed = merged.payorAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let vendorAddress: String? = payorTrimmed.isEmpty ? nil : payorTrimmed

        let payor = merged.payor ?? merged.merchant
        return ExtractedData(
            merchant: payor ?? merged.merchant,
            payee: merged.payee,
            payor: payor,
            payorAddress: merged.payorAddress,
            total: merged.total,
            currency: merged.currency,
            date: merged.date,
            vendorAddress: vendorAddress,
            documentNumber: merged.documentNumber,
            purchaseOrderNumber: merged.purchaseOrderNumber,
            productionManagerName: merged.productionManagerName,
            clientProjectTitle: merged.clientProjectTitle,
            clientProductionCompany: merged.clientProductionCompany,
            paymentMethodSummary: merged.paymentMethodSummary,
            lineItems: merged.lineItems,
            taxAmount: merged.taxAmount,
            subtotal: merged.subtotal,
            merchantConfidence: merged.merchantConfidence,
            totalConfidence: merged.totalConfidence,
            dateConfidence: merged.dateConfidence,
            documentKind: merged.documentKind ?? "income",
            workTimeEntries: merged.workTimeEntries,
            chequeNumber: merged.chequeNumber,
            internalInvoiceNumber: merged.internalInvoiceNumber,
            clientAccountingToken: merged.clientAccountingToken
        )
    }
}
