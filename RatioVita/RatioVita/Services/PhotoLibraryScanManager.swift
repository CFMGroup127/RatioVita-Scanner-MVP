//
//  PhotoLibraryScanManager.swift
//  RatioVita
//
//  Bulk import from Apple Photos with a persistent “already imported” registry (resume-safe).
//

import Foundation

#if os(iOS)
import Photos
import SwiftData
import UIKit

struct PhotoLibraryImportSummary: Sendable {
    var imported: Int = 0
    var skippedAlreadyImported: Int = 0
    var failed: Int = 0
}

/// Scans the user's Photo Library for images not yet ingested into RatioVita.
enum PhotoLibraryScanManager {
    private static let importedIdentifiersKey = "com.ratiovita.photoLibrary.importedLocalIdentifiers"

    /// How many library images are not yet in the import registry (estimate; requires Photos access).
    @MainActor
    static func pendingAssetCount(createdAfter: Date? = nil) async -> Int {
        guard await ensureReadAccess() else { return 0 }
        return enumeratePendingAssets(createdAfter: createdAfter).count
    }

    @MainActor
    static func importedIdentifierCount() -> Int {
        importedLocalIdentifiers().count
    }

    @MainActor
    static func resetImportRegistry() {
        UserDefaults.standard.removeObject(forKey: importedIdentifiersKey)
    }

    /// Imports not-yet-seen photos serially (memory-safe). Each image becomes its own receipt in Review.
    @MainActor
    static func importPending(
        createdAfter: Date? = nil,
        maxCount: Int? = nil,
        ocrEnabled: Bool,
        compressionEnabled: Bool,
        options: ReceiptIngestOptions,
        ingest: @MainActor (ScanResult, ReceiptIngestOptions) async throws -> Void,
        onProgress: @MainActor (_ processed: Int, _ total: Int, _ summary: PhotoLibraryImportSummary) -> Void
    ) async -> PhotoLibraryImportSummary {
        guard await ensureReadAccess() else {
            UserMessageCenter.shared.present(
                title: "Photos access needed",
                message: "Allow RatioVita to read your Photo Library in Settings → Privacy → Photos."
            )
            return PhotoLibraryImportSummary()
        }

        var pending = enumeratePendingAssets(createdAfter: createdAfter)
        if let maxCount, maxCount > 0, pending.count > maxCount {
            pending = Array(pending.prefix(maxCount))
        }

        let total = pending.count
        var summary = PhotoLibraryImportSummary()
        guard total > 0 else {
            onProgress(0, 0, summary)
            return summary
        }

        for (idx, asset) in pending.enumerated() {
            onProgress(idx, total, summary)
            do {
                guard let image = try await loadUIImage(for: asset) else {
                    summary.failed += 1
                    continue
                }
                let scan = try await ReceiptScanPipeline.processImported(
                    image: image,
                    ocrEnabled: ocrEnabled,
                    compressionEnabled: compressionEnabled
                )
                try await ingest(scan, options)
                markImported(localIdentifier: asset.localIdentifier)
                summary.imported += 1
            } catch {
                summary.failed += 1
            }
            onProgress(idx + 1, total, summary)
        }

        return summary
    }

    // MARK: - Authorization

    @MainActor
    private static func ensureReadAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
            case .authorized, .limited:
                return true
            case .notDetermined:
                let updated = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                return updated == .authorized || updated == .limited
            default:
                return false
        }
    }

    // MARK: - Asset enumeration

    @MainActor
    private static func enumeratePendingAssets(createdAfter: Date?) -> [PHAsset] {
        let imported = importedLocalIdentifiers()
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        if let createdAfter {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                options.predicate!,
                NSPredicate(format: "creationDate >= %@", createdAfter as NSDate),
            ])
        }

        let result = PHAsset.fetchAssets(with: options)
        var pending: [PHAsset] = []
        pending.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            guard !imported.contains(asset.localIdentifier) else { return }
            pending.append(asset)
        }
        return pending
    }

    // MARK: - Registry

    @MainActor
    private static func importedLocalIdentifiers() -> Set<String> {
        let list = UserDefaults.standard.stringArray(forKey: importedIdentifiersKey) ?? []
        return Set(list)
    }

    @MainActor
    private static func markImported(localIdentifier: String) {
        var set = importedLocalIdentifiers()
        guard set.insert(localIdentifier).inserted else { return }
        UserDefaults.standard.set(Array(set), forKey: importedIdentifiersKey)
    }

    // MARK: - Loading

    @MainActor
    private static func loadUIImage(for asset: PHAsset) async throws -> UIImage? {
        try await withCheckedThrowingContinuation { continuation in
            let requestOptions = PHImageRequestOptions()
            requestOptions.isNetworkAccessAllowed = true
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.resizeMode = .fast
            requestOptions.isSynchronous = false

            let target = CGSize(
                width: ReceiptImageRasterOps.importMaxLongEdge,
                height: ReceiptImageRasterOps.importMaxLongEdge
            )
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, info in
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(returning: nil)
                    return
                }
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}
#endif
