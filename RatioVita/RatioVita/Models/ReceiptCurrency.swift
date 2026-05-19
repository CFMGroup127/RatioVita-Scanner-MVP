import Foundation

/// ISO 4217 codes used for receipt display, extraction, and formatting.
enum ReceiptCurrency: String, CaseIterable, Identifiable, Codable, Hashable {
    case CAD
    case USD
    case GBP
    case EUR
    case AUD
    case CHF
    case MXN
    case INR
    case JPY

    var id: String { rawValue }

    var code: String { rawValue }

    /// Toronto / Ontario default when OCR does not state a currency.
    static let defaultForLocale: ReceiptCurrency = .CAD

    static func resolved(from code: String?) -> ReceiptCurrency {
        guard let c = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !c.isEmpty else {
            return .defaultForLocale
        }
        return ReceiptCurrency(rawValue: c) ?? .defaultForLocale
    }
}
