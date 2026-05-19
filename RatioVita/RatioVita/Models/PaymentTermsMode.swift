import Foundation

/// Payroll / AR cadence for **long** (union TV & features) vs **short** (commercials, music videos) formats.
enum PaymentTermsMode: String, CaseIterable, Identifiable, Codable, Hashable {
    /// Inherit from linked `BusinessEntity` when the project leaves this unset (`""`).
    case unspecified = ""
    /// Canada long-format: Thursday ~4 PM direct deposit expectation (Forensic Pulse watches bank credits).
    case longFormatCanadaThursday4pm = "long_format_ca_thursday_4pm"
    /// Short format: AR invoices treated as due **15 days** after the anchor date unless bank-linked.
    case fifteenDayShortFormat = "fifteen_day_short"

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
            case .unspecified: "Inherit from company (default)"
            case .longFormatCanadaThursday4pm: "Long format — Thursday 4 PM pay (Canada)"
            case .fifteenDayShortFormat: "Short format — 15-day invoice vigilance"
        }
    }

    var isFifteenDayShort: Bool { self == .fifteenDayShortFormat }

    var isLongFormatCanada: Bool { self == .longFormatCanadaThursday4pm }
}

extension Receipt {
    /// Payroll / AR cadence from the linked show (for Forensic Pulse).
    var effectivePaymentTerms: PaymentTermsMode {
        productionProject?.effectivePaymentTerms ?? .unspecified
    }
}
