import Foundation

/// Lightweight currency formatter utility for performance
final class CurrencyFormatter {
    static let shared = CurrencyFormatter()
    
    private var formatters: [String: NumberFormatter] = [:]
    private let queue = DispatchQueue(label: "com.ratiovita.currencyformatter", attributes: .concurrent)
    
    private init() {}
    
    func format(_ amount: Decimal, currencyCode: String) -> String {
        return queue.sync {
            if let formatter = formatters[currencyCode] {
                return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
            }
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatters[currencyCode] = formatter
            
            return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        }
    }
}
