//
//  ExtractedData.swift
//  RatioVita
//
//  OCR container: merchant, total, date, confidence (Sovereign audit).
//

import Foundation

struct ExtractedData {
    let merchant: String?
    let total: Decimal?
    let currency: String?
    let date: Date?
    let lineItems: [LineItem]?
    let taxAmount: Decimal?
    let subtotal: Decimal?
    let merchantConfidence: Double?
    let totalConfidence: Double?
    let dateConfidence: Double?

    init(
        merchant: String? = nil,
        total: Decimal? = nil,
        currency: String? = nil,
        date: Date? = nil,
        lineItems: [LineItem]? = nil,
        taxAmount: Decimal? = nil,
        subtotal: Decimal? = nil,
        merchantConfidence: Double? = nil,
        totalConfidence: Double? = nil,
        dateConfidence: Double? = nil
    ) {
        self.merchant = merchant
        self.total = total
        self.currency = currency
        self.date = date
        self.lineItems = lineItems
        self.taxAmount = taxAmount
        self.subtotal = subtotal
        self.merchantConfidence = merchantConfidence
        self.totalConfidence = totalConfidence
        self.dateConfidence = dateConfidence
    }

    var hasValidData: Bool {
        merchant != nil || total != nil || date != nil
    }

    var overallConfidence: Double {
        let c = [merchantConfidence, totalConfidence, dateConfidence].compactMap { $0 }
        guard !c.isEmpty else { return 0.0 }
        return c.reduce(0, +) / Double(c.count)
    }

    var formattedTotal: String? {
        guard let total = total else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency ?? "USD"
        return f.string(from: total as NSDecimalNumber)
    }
}
