import Foundation

/// Lightweight currency formatter utility for performance.
///
/// `@MainActor`-isolated so SwiftUI view bodies never hit `NSLock` or `DispatchQueue.sync`
/// (both trigger `unsafeForcedSync called from Swift Concurrent context` in Swift 6).
@MainActor
final class CurrencyFormatter {
    static let shared = CurrencyFormatter()

    private var formatters: [String: NumberFormatter] = [:]

    private init() {}

    func format(_ amount: Decimal, currencyCode: String) -> String {
        let formatter: NumberFormatter
        if let cached = formatters[currencyCode] {
            formatter = cached
        } else {
            let created = NumberFormatter()
            created.numberStyle = .currency
            created.currencyCode = currencyCode
            formatters[currencyCode] = created
            formatter = created
        }

        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
