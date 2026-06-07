import Foundation

/// Lightweight currency formatter utility for performance.
///
/// Caches one `NumberFormatter` per currency code. Cache access is guarded by an
/// `NSLock` instead of a concurrent `DispatchQueue.sync` barrier: a value-returning
/// `queue.sync` invoked from a `@MainActor` context (SwiftUI view bodies are the
/// primary caller here) is flagged by the Swift concurrency runtime as
/// `unsafeForcedSync called from Swift Concurrent context`. The lock provides the
/// same mutual exclusion without forcing a synchronous hop across a Dispatch queue.
final class CurrencyFormatter: @unchecked Sendable {
    static let shared = CurrencyFormatter()

    private var formatters: [String: NumberFormatter] = [:]
    private let lock = NSLock()

    private init() {}

    func format(_ amount: Decimal, currencyCode: String) -> String {
        lock.lock()
        defer { lock.unlock() }

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
