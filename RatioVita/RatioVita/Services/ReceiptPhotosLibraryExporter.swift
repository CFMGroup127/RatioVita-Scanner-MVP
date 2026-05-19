//
//  ReceiptPhotosLibraryExporter.swift
//  RatioVita
//
//  After OCR + save, optionally copies receipt images into the Photos library under a
//  single naming scheme so iCloud Photos can surface them across iPhone, iPad, and Mac.
//
//  Note: Apple’s Photos API does not expose a full Finder-style path. We use one album
//  per vendor + calendar month, titled: "RatioVita — Vendor — Year — Month".
//

import Foundation
import Photos

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ReceiptPhotosLibraryExporter {
    private static let rootPrefix = "RatioVita"

    /// Saves each page’s **original** image into a user album, using OCR date when available.
    @MainActor
    static func mirrorReceiptAfterSave(scan: ScanResult) async {
        guard await requestAddAccess() else { return }

        let receiptDate = scan.extractedData.date ?? scan.createdAt
        let merchant = scan.extractedData.merchant
        let title = albumTitle(merchant: merchant, receiptDate: receiptDate)

        do {
            let album = try await ensureAlbum(named: title)
            for page in scan.scannedPages {
                let assetDate = page.capturedAt ?? scan.extractedData.date ?? scan.createdAt
                try await addOriginalImage(page.originalImage, album: album, creationDate: assetDate)
            }
        } catch {
            #if DEBUG
            print("ReceiptPhotosLibraryExporter: \(error.localizedDescription)")
            #endif
        }
    }

    /// After filing from the Review tab: copy stored receipt images into Photos (camera-origin only).
    @MainActor
    static func mirrorSavedReceipt(_ receipt: Receipt) async {
        guard await requestAddAccess() else { return }
        let title = albumTitle(merchant: receipt.merchant, receiptDate: receipt.createdAt)
        do {
            let album = try await ensureAlbum(named: title)
            let sorted = receipt.images.sorted { $0.pageIndex < $1.pageIndex }
            for img in sorted {
                guard let platform = img.platformImage else { continue }
                try await addOriginalImage(platform, album: album, creationDate: img.createdAt)
            }
        } catch {
            #if DEBUG
            print("ReceiptPhotosLibraryExporter: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Authorization

    private static func requestAddAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
            case .authorized:
                return true
            case .notDetermined:
                let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                return newStatus == .authorized
            default:
                return false
        }
    }

    // MARK: - Album naming

    private static func albumTitle(merchant: String?, receiptDate: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: receiptDate)
        let monthIndex = calendar.component(.month, from: receiptDate)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let monthName = formatter.monthSymbols[max(0, min(11, monthIndex - 1))]
        let vendor = sanitizeSegment(merchant?.isEmpty == false ? merchant! : "Unknown vendor")
        return "\(rootPrefix) — \(vendor) — \(year) — \(monthName)"
    }

    private static func sanitizeSegment(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let blocked = CharacterSet(charactersIn: "/:\\?%*|\"<>#")
        let scalars = trimmed.unicodeScalars.map { blocked.contains($0) ? "_" : Character($0) }
        let joined = String(scalars)
        let capped = String(joined.prefix(72))
        return capped.isEmpty ? "Unknown vendor" : capped
    }

    // MARK: - Photos writes

    private static func fetchAlbum(named title: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.fetchLimit = 1
        options.predicate = NSPredicate(format: "localizedTitle == %@", title)
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        return result.firstObject
    }

    private static func ensureAlbum(named title: String) async throws -> PHAssetCollection {
        if let existing = fetchAlbum(named: title) {
            return existing
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
        }
        guard let created = fetchAlbum(named: title) else {
            throw ExporterError.albumCreationFailed
        }
        return created
    }

    private static func addOriginalImage(
        _ image: RVImage,
        album: PHAssetCollection,
        creationDate: Date
    ) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let creation: PHAssetChangeRequest?
            #if canImport(UIKit)
            creation = PHAssetChangeRequest.creationRequestForAsset(from: image)
            #elseif canImport(AppKit)
            creation = PHAssetChangeRequest.creationRequestForAsset(from: image)
            #else
            creation = nil
            #endif

            guard let creation else { return }
            creation.creationDate = creationDate

            guard let change = PHAssetCollectionChangeRequest(for: album) else { return }
            guard let placeholder = creation.placeholderForCreatedAsset else { return }
            change.addAssets([placeholder] as NSArray)
        }
    }

    private enum ExporterError: Error {
        case albumCreationFailed
    }
}
