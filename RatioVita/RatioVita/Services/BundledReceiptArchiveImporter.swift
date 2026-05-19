//
//  BundledReceiptArchiveImporter.swift
//  RatioVita
//
//  Imports real scanned receipts shipped in the app bundle as `RVArchive2020__*` (see
//  `Scripts/sync_bundled_scanned_receipts.sh` and repo folder `Scanned receips PDF format?/`).
//  Same path as file import: ReceiptScanPipeline + Vision + OCRParsing.
//

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum BundledReceiptArchiveImporter {
    /// Bundled historical samples use this prefix so we can find them after Xcode copies resources flat.
    static let bundledArchiveFilenamePrefix = "RVArchive2020__"
    private static let supportedExtensions: Set<String> = ["pdf", "jpg", "jpeg", "png", "heic"]

    /// Sorted list of receipt assets (PDF + images) shipped for QA / DEBUG import.
    static func bundledReceiptFileURLs(in bundle: Bundle = .main) -> [URL] {
        guard let resourceURL = bundle.resourceURL else { return [] }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: resourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents
            .filter { $0.lastPathComponent.hasPrefix(bundledArchiveFilenamePrefix) }
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Human-readable path decoded from a flattened bundle filename (`__` was `/`).
    static func displayPath(forBundledFile url: URL) -> String {
        let name = url.lastPathComponent
        guard name.hasPrefix(bundledArchiveFilenamePrefix) else {
            return name
        }
        let stripped = String(name.dropFirst(bundledArchiveFilenamePrefix.count))
        let withoutExt = (stripped as NSString).deletingPathExtension
        return withoutExt.replacingOccurrences(of: "__", with: "/")
    }

    /// Imports up to `limit` files (nil = all). Returns count successfully saved.
    @MainActor
    static func importArchive(
        into context: ModelContext,
        bundle: Bundle = .main,
        limit: Int? = nil,
        ocrEnabled: Bool,
        compressionEnabled: Bool
    ) async throws -> Int {
        var files = bundledReceiptFileURLs(in: bundle)
        if let limit, files.count > limit {
            files = Array(files.prefix(limit))
        }

        guard !files.isEmpty else {
            throw ArchiveImporterError.noBundledFiles
        }

        var saved = 0
        var failures: [String] = []

        for url in files {
            do {
                let ext = url.pathExtension.lowercased()
                let result: ScanResult
                if ext == "pdf" {
                    result = try await ReceiptScanPipeline.processImportedPDF(
                        at: url,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                } else {
                    let image = try rasterizeReceiptAsset(at: url)
                    result = try await ReceiptScanPipeline.processImported(
                        image: image,
                        ocrEnabled: ocrEnabled,
                        compressionEnabled: compressionEnabled
                    )
                }

                let relativeNote = "2020 archive · \(displayPath(forBundledFile: url))"

                try await ReceiptPersistence.saveScanResult(
                    result,
                    context: context,
                    compressionEnabled: compressionEnabled,
                    createdAtOverride: nil,
                    notes: relativeNote,
                    pendingHumanReview: false,
                    scannedViaCamera: false
                )
                saved += 1
            } catch {
                failures.append(url.lastPathComponent)
            }
        }

        if saved == 0, !failures.isEmpty {
            throw ArchiveImporterError.allFailed(sample: failures.prefix(3).joined(separator: ", "))
        }

        return saved
    }

    // MARK: - Rasterize

    /// Loads a raster image or renders the first page of a PDF to a bitmap for Vision.
    static func rasterizeReceiptAsset(at url: URL) throws -> RVImage {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            let pages = try ReceiptPDFRendering.images(fromDocumentAt: url, maxPages: 1)
            guard let first = pages.first else {
                throw ArchiveImporterError.pdfHasNoPages(url.lastPathComponent)
            }
            return first
        }
        guard let data = try? Data(contentsOf: url) else {
            throw ArchiveImporterError.unreadableFile(url.lastPathComponent)
        }
        #if canImport(UIKit)
        guard let img = UIImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
            throw ArchiveImporterError.unreadableFile(url.lastPathComponent)
        }
        return img
        #elseif canImport(AppKit)
        guard let img = RVImage.rv_decodedNormalizingEXIFOrientation(from: data) ?? NSImage(data: data) else {
            throw ArchiveImporterError.unreadableFile(url.lastPathComponent)
        }
        return img
        #else
        throw ArchiveImporterError.unsupportedPlatform
        #endif
    }
}

enum ArchiveImporterError: LocalizedError {
    case noBundledFiles
    case unreadableFile(String)
    case pdfHasNoPages(String)
    case pdfRenderFailed(String)
    case unsupportedPlatform
    case allFailed(sample: String)

    var errorDescription: String? {
        switch self {
            case .noBundledFiles:
                let prefix = BundledReceiptArchiveImporter.bundledArchiveFilenamePrefix
                return "No bundled historical receipts found (expected files named \(prefix)* in the app Resources)."
            case let .unreadableFile(name):
                return "Could not read image: \(name)"
            case let .pdfHasNoPages(name):
                return "PDF has no pages: \(name)"
            case let .pdfRenderFailed(name):
                return "Could not render PDF: \(name)"
            case .unsupportedPlatform:
                return "Raster import is not supported on this platform."
            case let .allFailed(sample):
                return "No receipts could be imported. Examples: \(sample)"
        }
    }
}
