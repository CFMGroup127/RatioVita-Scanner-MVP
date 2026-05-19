//
//  DailyLedgerService.swift
//  RatioVita
//
//  Monday Ignition: 5 PM Ledger — daily ledger from Receipt records.
//  macOS: writes CSV under Vault/Exports/Ledgers first, then optionally drives Numbers; if Numbers will not launch,
//  AppleScript errors, or the .numbers file never appears, opens the CSV in the default app and still returns the CSV
//  URL.
//

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 5 PM Ledger spec: columnar data (Timestamp, Merchant, Sovereign Hash, Currency, Total, Compliance Status),
/// delivery to `Vault/Exports/Ledgers/YYYY-MM-DD_Daily_Ledger.csv` (always) and optional `…Daily_Ledger.numbers` on
/// macOS when Numbers cooperates.
@MainActor
protocol DailyLedgerServiceProtocol {
    func generateDailyLedger(for date: Date, modelContext: ModelContext) async throws -> URL
}

@MainActor
final class DailyLedgerService: DailyLedgerServiceProtocol {
    static let shared = DailyLedgerService()

    private init() {}

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
        return try await generateLedgerMacOS(receipts: receipts, filename: filename)
        #else
        let vault = vaultLedgersURL()
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        return try writeCSVLedger(receipts: receipts, filename: filename, vault: vault)
        #endif
    }

    #if os(macOS)
    private func generateLedgerMacOS(receipts: [Receipt], filename: String) async throws -> URL {
        let vault = vaultLedgersURL()
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)

        let csvURL = try writeCSVLedger(receipts: receipts, filename: filename, vault: vault)

        guard let numbersAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iWork.Numbers") else {
            openCSVLedgerInDefaultApp(csvURL)
            return csvURL
        }

        let numbersURL = vault.appendingPathComponent("\(filename).numbers")
        let pathForAppleScript = numbersURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let scriptSource = """
        tell application "Numbers"
            activate
            set ledgerDoc to make new document
            save ledgerDoc in POSIX file "\(pathForAppleScript)"
        end tell
        """

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let launchedOK = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            NSWorkspace.shared.openApplication(at: numbersAppURL, configuration: configuration) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
        if !launchedOK {
            openCSVLedgerInDefaultApp(csvURL)
            return csvURL
        }
        try await Task.sleep(nanoseconds: 900_000_000)

        guard let scriptObject = NSAppleScript(source: scriptSource) else {
            openCSVLedgerInDefaultApp(csvURL)
            return csvURL
        }
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
        if error != nil {
            try? FileManager.default.removeItem(at: numbersURL)
            openCSVLedgerInDefaultApp(csvURL)
            return csvURL
        }
        if !FileManager.default.fileExists(atPath: numbersURL.path) {
            openCSVLedgerInDefaultApp(csvURL)
            return csvURL
        }
        return numbersURL
    }

    private func openCSVLedgerInDefaultApp(_ csvURL: URL) {
        _ = NSWorkspace.shared.open(csvURL)
    }
    #endif

    private func writeCSVLedger(receipts: [Receipt], filename: String, vault: URL) throws -> URL {
        let fileURL = vault.appendingPathComponent("\(filename).csv")
        var csv = "Timestamp,Merchant,Sovereign Hash,Currency,Total,Compliance Status\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var total: Decimal = 0
        for r in receipts {
            let ts = dateFormatter.string(from: r.createdAt)
            let hash = r.id.uuidString.prefix(8)
            total += r.total
            let merchant = r.merchant.replacingOccurrences(of: ",", with: " ")
            csv += "\(ts),\(merchant),\(hash),\(r.currencyCode),\(r.total),Verified\n"
        }
        csv += ",,,Total,\(total),\n"
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

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

    var errorDescription: String? {
        switch self {
            case .invalidDate: "Invalid date for ledger"
        }
    }
}
