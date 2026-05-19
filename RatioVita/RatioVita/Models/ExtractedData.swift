//
//  ExtractedData.swift
//  RatioVita
//
//  OCR container: merchant, total, date, confidence (Sovereign audit).
//

import Foundation

/// One calendar day of work extracted from a time sheet / pay stub (Gemini or future parsers).
struct ExtractedWorkTime: Equatable, Sendable {
    var workDate: Date?
    var hours: Double?
    var showTitle: String?
}

struct ExtractedData {
    let merchant: String?
    /// “Pay to the order of …” (your entity on incoming checks).
    let payee: String?
    /// Drawer / payer on checks.
    let payor: String?
    /// Payer street line when distinct from `vendorAddress`.
    let payorAddress: String?
    let total: Decimal?
    let currency: String?
    let date: Date?
    /// Street / city line when detected near the top of the receipt (heuristic).
    let vendorAddress: String?
    /// Receipt #, confirmation #, or invoice # when a label match is found.
    let documentNumber: String?
    /// Client / production PO when printed on catering or vendor invoices.
    let purchaseOrderNumber: String?
    /// Production manager or billing contact name when labeled (e.g. "PM: …").
    let productionManagerName: String?
    /// Project / episode title on invoice (distinct from merchant letterhead).
    let clientProjectTitle: String?
    /// Production company or network on invoice ("Production Co:", "Bill To").
    let clientProductionCompany: String?
    /// Card brand / last4, “Visa”, “E-transfer”, etc. when matched.
    let paymentMethodSummary: String?
    let lineItems: [LineItem]?
    let taxAmount: Decimal?
    let subtotal: Decimal?
    let merchantConfidence: Double?
    let totalConfidence: Double?
    let dateConfidence: Double?
    /// High-level classification when the extractor provides it (e.g. lottery vs retail receipt).
    let documentKind: String?
    /// Dates worked + hours from time sheets / pay stubs when the model returns `work_days`.
    let workTimeEntries: [ExtractedWorkTime]?
    let chequeNumber: String?
    let internalInvoiceNumber: String?
    let clientAccountingToken: String?

    init(
        merchant: String? = nil,
        payee: String? = nil,
        payor: String? = nil,
        payorAddress: String? = nil,
        total: Decimal? = nil,
        currency: String? = nil,
        date: Date? = nil,
        vendorAddress: String? = nil,
        documentNumber: String? = nil,
        purchaseOrderNumber: String? = nil,
        productionManagerName: String? = nil,
        clientProjectTitle: String? = nil,
        clientProductionCompany: String? = nil,
        paymentMethodSummary: String? = nil,
        lineItems: [LineItem]? = nil,
        taxAmount: Decimal? = nil,
        subtotal: Decimal? = nil,
        merchantConfidence: Double? = nil,
        totalConfidence: Double? = nil,
        dateConfidence: Double? = nil,
        documentKind: String? = nil,
        workTimeEntries: [ExtractedWorkTime]? = nil,
        chequeNumber: String? = nil,
        internalInvoiceNumber: String? = nil,
        clientAccountingToken: String? = nil
    ) {
        self.merchant = merchant
        self.payee = payee
        self.payor = payor
        self.payorAddress = payorAddress
        self.total = total
        self.currency = currency
        self.date = date
        self.vendorAddress = vendorAddress
        self.documentNumber = documentNumber
        self.purchaseOrderNumber = purchaseOrderNumber
        self.productionManagerName = productionManagerName
        self.clientProjectTitle = clientProjectTitle
        self.clientProductionCompany = clientProductionCompany
        self.paymentMethodSummary = paymentMethodSummary
        self.lineItems = lineItems
        self.taxAmount = taxAmount
        self.subtotal = subtotal
        self.merchantConfidence = merchantConfidence
        self.totalConfidence = totalConfidence
        self.dateConfidence = dateConfidence
        self.documentKind = documentKind
        self.workTimeEntries = workTimeEntries
        self.chequeNumber = chequeNumber
        self.internalInvoiceNumber = internalInvoiceNumber
        self.clientAccountingToken = clientAccountingToken
    }

    /// Prefer non-empty values from this value (e.g. **Gemini**), then fill from `fallback` (e.g. on-device
    /// heuristics). Document **date** uses the primary side first so a model `transactionDate` overrides OCR-only
    /// guesses.
    func fillingGaps(with fallback: ExtractedData) -> ExtractedData {
        let mergedLineItems: [LineItem]? = if let lineItems, !lineItems.isEmpty {
            lineItems
        } else {
            fallback.lineItems
        }

        let mergedWorkTimes: [ExtractedWorkTime]? = if let workTimeEntries, !workTimeEntries.isEmpty {
            workTimeEntries
        } else {
            fallback.workTimeEntries
        }

        let mergedPO = purchaseOrderNumber ?? fallback.purchaseOrderNumber
        let mergedPM = productionManagerName ?? fallback.productionManagerName
        let mergedClientTitle = clientProjectTitle ?? fallback.clientProjectTitle
        let mergedClientCo = clientProductionCompany ?? fallback.clientProductionCompany

        return ExtractedData(
            merchant: merchant ?? fallback.merchant,
            payee: payee ?? fallback.payee,
            payor: payor ?? fallback.payor,
            payorAddress: payorAddress ?? fallback.payorAddress,
            total: total ?? fallback.total,
            currency: currency ?? fallback.currency,
            date: date ?? fallback.date,
            vendorAddress: vendorAddress ?? fallback.vendorAddress,
            documentNumber: documentNumber ?? fallback.documentNumber,
            purchaseOrderNumber: mergedPO,
            productionManagerName: mergedPM,
            clientProjectTitle: mergedClientTitle,
            clientProductionCompany: mergedClientCo,
            paymentMethodSummary: paymentMethodSummary ?? fallback.paymentMethodSummary,
            lineItems: mergedLineItems,
            taxAmount: taxAmount ?? fallback.taxAmount,
            subtotal: subtotal ?? fallback.subtotal,
            merchantConfidence: merchantConfidence ?? fallback.merchantConfidence,
            totalConfidence: totalConfidence ?? fallback.totalConfidence,
            dateConfidence: dateConfidence ?? fallback.dateConfidence,
            documentKind: documentKind ?? fallback.documentKind,
            workTimeEntries: mergedWorkTimes,
            chequeNumber: chequeNumber ?? fallback.chequeNumber,
            internalInvoiceNumber: internalInvoiceNumber ?? fallback.internalInvoiceNumber,
            clientAccountingToken: clientAccountingToken ?? fallback.clientAccountingToken
        )
    }

    var hasValidData: Bool {
        merchant != nil || total != nil || date != nil || vendorAddress != nil || documentNumber != nil
            || documentKind != nil
            || purchaseOrderNumber != nil
            || clientProjectTitle != nil
    }

    var overallConfidence: Double {
        let c = [merchantConfidence, totalConfidence, dateConfidence].compactMap { $0 }
        guard !c.isEmpty else { return 0.0 }
        return c.reduce(0, +) / Double(c.count)
    }

    var formattedTotal: String? {
        guard let total else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency ?? "USD"
        return f.string(from: total as NSDecimalNumber)
    }

    /// Returns a copy with `documentKind` replaced (used for OCR-inferred Canadian tax slips before polarity runs).
    func withDocumentKind(_ kind: String?) -> ExtractedData {
        ExtractedData(
            merchant: merchant,
            payee: payee,
            payor: payor,
            payorAddress: payorAddress,
            total: total,
            currency: currency,
            date: date,
            vendorAddress: vendorAddress,
            documentNumber: documentNumber,
            purchaseOrderNumber: purchaseOrderNumber,
            productionManagerName: productionManagerName,
            clientProjectTitle: clientProjectTitle,
            clientProductionCompany: clientProductionCompany,
            paymentMethodSummary: paymentMethodSummary,
            lineItems: lineItems,
            taxAmount: taxAmount,
            subtotal: subtotal,
            merchantConfidence: merchantConfidence,
            totalConfidence: totalConfidence,
            dateConfidence: dateConfidence,
            documentKind: kind,
            workTimeEntries: workTimeEntries,
            chequeNumber: chequeNumber,
            internalInvoiceNumber: internalInvoiceNumber,
            clientAccountingToken: clientAccountingToken
        )
    }
}
