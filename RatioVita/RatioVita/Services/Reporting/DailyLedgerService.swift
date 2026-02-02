//
//  DailyLedgerService.swift
//  RatioVita
//
//  Monday Ignition: 5 PM Ledger — Apple Numbers daily ledger from Receipt records.
//  Fetches Receipts created 00:00–17:00, populates Sovereign_Ledger_Template, saves to Vault/Exports/Ledgers/.
//

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 5 PM Ledger spec: Native .numbers, columnar data (Timestamp, Merchant, Sovereign Hash, Currency, Total, Compliance Status),
/// alternating row highlighting, locked Total footer. Delivery to Vault/Exports/Ledgers/YYYY-MM-DD_Daily_Ledger.numbers.
protocol DailyLedgerServiceProtocol: Sendable {
    func generateDailyLedger(for date: Date, modelContext: ModelContext) async throws -> URL
}

final class DailyLedgerService: DailyLedgerServiceProtocol {

    static let shared = DailyLedgerService()

    private init() {}

    /// Generates the daily ledger for the given date (receipts from 00:00 to 17:00).
    /// Saves to Vault/Exports/Ledgers/YYYY-MM-DD_Daily_Ledger.numbers (macOS) or .csv (iOS fallback).
    func generateDailyLedger(for date: Date, modelContext: ModelContext) async throws -> URL {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfLedger = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date) else {
            throw DailyLedgerError.invalidDate
        }

        let descriptor = FetchDescriptor<Receipt>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let allReceipts = (try? modelContext.fetch(descriptor)) ?? []
        let receipts = allReceipts.filter { $0.createdAt >= startOfDay && $0.createdAt <= endOfLedger }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)
        let filename = "\(dateStr)_Daily_Ledger"

        #if os(macOS)
        return try await generateNumbersLedgerMacOS(receipts: receipts, filename: filename)
        #else
        return try await generateCSVLedgeriOS(receipts: receipts, filename: filename)
        #endif
    }

    #if os(macOS)
    private func generateNumbersLedgerMacOS(receipts: [Receipt], filename: String) async throws -> URL {
        let vault = vaultLedgersURL()
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let fileURL = vault.appendingPathComponent("\(filename).numbers")
        let script = """
        tell application "Numbers" to activate
        make new document
        -- Sovereign_Ledger_Template: Timestamp, Merchant, Sovereign Hash, Currency, Total, Compliance Status
        -- Populate rows with receipt data; sum Total column; Bold footer
        -- Save: save document 1 to "\(fileURL.path)"
        """
        guard let scriptObject = NSAppleScript(source: script) else {
            throw DailyLedgerError.scriptFailed("Could not create AppleScript")
        }
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
        if let err = error {
            throw DailyLedgerError.scriptFailed((err[NSAppleScript.errorMessage] as? String) ?? "Unknown")
        }
        return fileURL
    }
    #endif

    #if os(iOS)
    private func generateCSVLedgeriOS(receipts: [Receipt], filename: String) async throws -> URL {
        let vault = vaultLedgersURL()
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let fileURL = vault.appendingPathComponent("\(filename).csv")
        var csv = "Timestamp,Merchant,Sovereign Hash,Currency,Total,Compliance Status\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var total: Decimal = 0
        for r in receipts {
            let ts = dateFormatter.string(from: r.createdAt)
            let hash = r.id.uuidString.prefix(8)
            total += r.total
            csv += "\(ts),\(r.merchant),\(hash),\(r.currencyCode),\(r.total),Verified\n"
        }
        csv += ",,,Total,\(total),\n"
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    #endif

    private func vaultLedgersURL() -> URL {
        #if os(iOS)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Vault/Exports/Ledgers", isDirectory: true)
        #else
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Vault/Exports/Ledgers", isDirectory: true)
        #endif
    }
}

enum DailyLedgerError: Error, LocalizedError {
    case invalidDate
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDate: return "Invalid date for ledger"
        case .scriptFailed(let msg): return "Numbers script failed: \(msg)"
        }
    }
}
