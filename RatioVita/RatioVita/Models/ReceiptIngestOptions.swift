//
//  ReceiptIngestOptions.swift
//  RatioVita
//
//  Controls whether a new receipt waits in the human review queue and whether it originated
//  from the device camera (Photos mirror only after review, and only for camera captures).
//

import Foundation

struct ReceiptIngestOptions: Sendable, Equatable {
    /// When true, the receipt appears only under Review until the user files it.
    var pendingHumanReview: Bool
    /// When true, filing from Review may copy images into the Photos library (if enabled in Settings).
    var scannedViaCamera: Bool
    /// Optional Arctic prefix for new captures (from **Scan into folder**).
    var vaultPathPrefix: String?

    /// Bundled archive / normal library saves: filed immediately, no Photos mirror from app.
    static let filedImportOrBundle = ReceiptIngestOptions(
        pendingHumanReview: false,
        scannedViaCamera: false,
        vaultPathPrefix: nil
    )

    /// User import from Files or Photos: review queue, no Photos mirror (asset already in library or disk).
    static let reviewQueueImport = ReceiptIngestOptions(
        pendingHumanReview: true,
        scannedViaCamera: false,
        vaultPathPrefix: nil
    )

    /// Device camera capture path: review queue, then Photos mirror on file from Review.
    static let reviewQueueCamera = ReceiptIngestOptions(
        pendingHumanReview: true,
        scannedViaCamera: true,
        vaultPathPrefix: nil
    )

    /// Direct save (e.g. legacy toolbar scan) without review step.
    static func filedImmediateCamera(_ camera: Bool) -> ReceiptIngestOptions {
        ReceiptIngestOptions(pendingHumanReview: false, scannedViaCamera: camera, vaultPathPrefix: nil)
    }
}
