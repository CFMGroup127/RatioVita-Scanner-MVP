//
//  AppCurrencySettings.swift
//  RatioVita
//
//  App-wide default ISO 4217 currency for new receipts, bank imports, and display.
//

import Foundation

enum AppCurrencySettings {
    static let userDefaultsKey = "com.ratiovita.defaultCurrencyCode"

    /// Baseline currency for new documents when OCR does not resolve a code.
    static var defaultCurrencyCode: String {
        get {
            let stored = UserDefaults.standard.string(forKey: userDefaultsKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if let stored, !stored.isEmpty, ReceiptCurrency(rawValue: stored) != nil {
                return stored
            }
            return ReceiptCurrency.localeFallback.code
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard ReceiptCurrency(rawValue: trimmed) != nil else { return }
            UserDefaults.standard.set(trimmed, forKey: userDefaultsKey)
        }
    }

    static var defaultCurrency: ReceiptCurrency {
        ReceiptCurrency.resolved(from: defaultCurrencyCode)
    }
}
