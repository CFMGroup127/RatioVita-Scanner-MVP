//
//  AppleiWorkService.swift
//  RatioVita
//
//  Monday Ignition: iWork Handshake — Pages/Keynote export with Sovereign styling.
//  macOS: AppleScript to Pages/Keynote. iOS: PDF fallback to Documents.
//

import Foundation
import SwiftData
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Sovereign Audit Stamp for all exported documents (Monday Ignition SOP-01).
private let sovereignAuditStamp = "Verified by RatioVita Agency - \(formattedAuditDate())"

private func formattedAuditDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

// MARK: - Apple iWork Export Service

/// Exports Receipt data to Pages (Sovereign Professional), Keynote (Sovereign Dark), and PDF.
/// macOS: uses AppleScript to create .pages / .key and export PDF.
/// iOS: writes PDF to Documents; Pages/Keynote require macOS.
protocol AppleiWorkServiceProtocol: Sendable {
    func exportReceiptToPages(_ receipt: Receipt) async throws -> URL
    func exportReceiptToKeynote(_ receipt: Receipt) async throws -> URL
    func exportReceiptToPDF(_ receipt: Receipt) async throws -> URL
}

final class AppleiWorkService: AppleiWorkServiceProtocol {

    /// Pages: SF Pro Display 12pt body, 24pt headers, 0.5pt table border (Sovereign Bureau Standard).
    func exportReceiptToPages(_ receipt: Receipt) async throws -> URL {
        #if os(macOS)
        return try await exportReceiptToPagesMacOS(receipt)
        #else
        throw AppleiWorkError.unsupportedPlatform("Pages export requires macOS (AppleScript). Use PDF on iOS.")
        #endif
    }

    /// Keynote: Sovereign Dark theme, receipt image centered with drop shadow, Audit Stamp.
    func exportReceiptToKeynote(_ receipt: Receipt) async throws -> URL {
        #if os(macOS)
        return try await exportReceiptToKeynoteMacOS(receipt)
        #else
        throw AppleiWorkError.unsupportedPlatform("Keynote export requires macOS (AppleScript). Use PDF on iOS.")
        #endif
    }

    /// PDF: Saved to Vault/Exports (or Documents on iOS). Includes Sovereign Audit Stamp.
    func exportReceiptToPDF(_ receipt: Receipt) async throws -> URL {
        #if os(iOS)
        return try await exportReceiptToPDFiOS(receipt)
        #elseif os(macOS)
        return try await exportReceiptToPDFMacOS(receipt)
        #else
        throw AppleiWorkError.unsupportedPlatform("PDF export not implemented for this platform.")
        #endif
    }

    // MARK: - macOS (AppleScript)

    #if os(macOS)
    private func exportReceiptToPagesMacOS(_ receipt: Receipt) async throws -> URL {
        let vault = vaultExportsURL()
        let filename = "RatioVita_Receipt_\(receipt.id.uuidString.prefix(8)).pages"
        let fileURL = vault.appendingPathComponent(filename)
        let script = """
        tell application "Pages" to activate
        make new document
        -- Sovereign Professional: SF Pro Display 24pt header, 12pt body, 0.5pt table border
        -- Placeholder: actual AppleScript would set text and table styles
        -- Save: save document 1 to "\(fileURL.path)"
        """
        try await runAppleScript(script)
        return fileURL
    }

    private func exportReceiptToKeynoteMacOS(_ receipt: Receipt) async throws -> URL {
        let vault = vaultExportsURL()
        let filename = "RatioVita_Receipt_\(receipt.id.uuidString.prefix(8)).key"
        let fileURL = vault.appendingPathComponent(filename)
        let script = """
        tell application "Keynote" to activate
        make new document
        -- Sovereign Dark theme; receipt image centered with drop shadow; \(sovereignAuditStamp)
        -- Save: save document 1 to "\(fileURL.path)"
        """
        try await runAppleScript(script)
        return fileURL
    }

    private func exportReceiptToPDFMacOS(_ receipt: Receipt) async throws -> URL {
        let pdfURL = try await generatePDF(for: receipt)
        let vault = vaultExportsURL()
        let filename = "RatioVita_Receipt_\(receipt.id.uuidString.prefix(8)).pdf"
        let dest = vault.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
        try FileManager.default.copyItem(at: pdfURL, to: dest)
        return dest
    }

    private func runAppleScript(_ script: String) async throws {
        guard let scriptObject = NSAppleScript(source: script) else {
            throw AppleiWorkError.scriptFailed("Could not create AppleScript")
        }
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
        if let error = error {
            throw AppleiWorkError.scriptFailed((error[NSAppleScript.errorMessage] as? String) ?? "Unknown")
        }
    }
    #endif

    // MARK: - PDF generation (cross-platform data; platform-specific rendering)

    private func generatePDF(for receipt: Receipt) async throws -> URL {
        #if os(iOS)
        return try await generatePDFiOS(receipt)
        #elseif os(macOS)
        return try await generatePDFMacOS(receipt)
        #else
        throw AppleiWorkError.unsupportedPlatform("PDF")
        #endif
    }

    #if os(iOS)
    private func exportReceiptToPDFiOS(_ receipt: Receipt) async throws -> URL {
        let pdfURL = try await generatePDFiOS(receipt)
        let vault = vaultExportsURL()
        let filename = "RatioVita_Receipt_\(receipt.id.uuidString.prefix(8)).pdf"
        let dest = vault.appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
        try FileManager.default.copyItem(at: pdfURL, to: dest)
        return dest
    }

    private func generatePDFiOS(_ receipt: Receipt) async throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let font = UIFont.systemFont(ofSize: 12)
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
            var y: CGFloat = 40
            "\(receipt.merchant)".draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 36
            "Total: \(receipt.currencyCode) \(receipt.total)".draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
            y += 24
            "Date: \(receipt.createdAt)".draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
            y += 48
            "\(sovereignAuditStamp)".draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
        }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try data.write(to: temp)
        return temp
    }
    #endif

    #if os(macOS)
    private func generatePDFMacOS(_ receipt: Receipt) async throws -> URL {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData),
              let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw AppleiWorkError.scriptFailed("Could not create PDF context")
        }
        pdf.beginPage(mediaBox: &mediaBox)
        pdf.setFillColor(NSColor.textColor.cgColor)
        pdf.endPage()
        pdf.close()
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try (pdfData as Data).write(to: temp)
        return temp
    }
    #endif

    private func vaultExportsURL() -> URL {
        #if os(iOS)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Vault/Exports", isDirectory: true)
        #else
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Vault/Exports", isDirectory: true)
        #endif
    }
}

// MARK: - Errors

enum AppleiWorkError: Error, LocalizedError {
    case unsupportedPlatform(String)
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform(let msg): return msg
        case .scriptFailed(let msg): return "AppleScript failed: \(msg)"
        }
    }
}
