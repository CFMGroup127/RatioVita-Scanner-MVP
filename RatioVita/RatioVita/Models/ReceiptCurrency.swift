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

    /// App default when OCR does not state a currency.
    static var defaultForLocale: ReceiptCurrency {
        AppCurrencySettings.defaultCurrency
    }

    /// Device locale fallback when no app preference is stored yet.
    static var localeFallback: ReceiptCurrency { .CAD }

    var displayLabel: String {
        switch self {
            case .CAD: "CAD ($) — Canadian Dollar"
            case .USD: "USD ($) — US Dollar"
            case .GBP: "GBP (£) — British Pound"
            case .EUR: "EUR (€) — Euro"
            case .AUD: "AUD ($) — Australian Dollar"
            case .CHF: "CHF — Swiss Franc"
            case .MXN: "MXN ($) — Mexican Peso"
            case .INR: "INR (₹) — Indian Rupee"
            case .JPY: "JPY (¥) — Japanese Yen"
        }
    }

    static func resolved(from code: String?) -> ReceiptCurrency {
        guard let c = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !c.isEmpty else {
            return .defaultForLocale
        }
        return ReceiptCurrency(rawValue: c) ?? .defaultForLocale
    }
}
