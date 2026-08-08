//
//  ReceiptBatchManager.swift
//  RatioVita
//
//  Disk-backed page stack for live multi-page camera sessions (capture → Finish → OCR).
//

import Combine
import Foundation
import SwiftUI

struct ReceiptBatchPage: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    let thumbnailURL: URL
    let capturedAt: Date

    static func == (lhs: ReceiptBatchPage, rhs: ReceiptBatchPage) -> Bool {
        lhs.id == rhs.id
    }
}

/// Singleton lifecycle for one live scan session: first snap through Finish Scan.
@MainActor
final class ReceiptBatchManager: ObservableObject {
    static let shared = ReceiptBatchManager()

    @Published private(set) var pages: [ReceiptBatchPage] = []

    private var sessionDirectory: URL?

    var pageCount: Int { pages.count }

    var isEmpty: Bool { pages.isEmpty }

    /// Ordered page JPEG paths for pipeline handoff.
    var pageURLs: [URL] { pages.map(\.fileURL) }

    private init() {}

    func beginSession() throws {
        endSession(deleteFiles: true)
        sessionDirectory = try ReceiptBatchCaptureDiskCache.createSessionDirectory()
        pages = []
    }

    /// Compresses immediately to temp JPEG; does not retain the original raster in manager state.
    func appendCapturedImage(_ image: RVImage) throws {
        guard let sessionDirectory else { throw ReceiptBatchCaptureError.noActiveSession }
        let index = pages.count
        let urls: (pageURL: URL, thumbnailURL: URL) = try autoreleasepool {
            try ReceiptBatchCaptureDiskCache.writePageFiles(
                from: image,
                sessionDirectory: sessionDirectory,
                pageIndex: index
            )
        }
        pages.append(
            ReceiptBatchPage(
                id: UUID(),
                fileURL: urls.pageURL,
                thumbnailURL: urls.thumbnailURL,
                capturedAt: .now
            )
        )
    }

    func appendPage(url: URL, thumbnailURL: URL? = nil) {
        let thumb = thumbnailURL ?? url
        pages.append(
            ReceiptBatchPage(
                id: UUID(),
                fileURL: url,
                thumbnailURL: thumb,
                capturedAt: .now
            )
        )
    }

    func removePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        let page = pages[index]
        try? FileManager.default.removeItem(at: page.fileURL)
        if page.thumbnailURL != page.fileURL {
            try? FileManager.default.removeItem(at: page.thumbnailURL)
        }
        pages.remove(at: index)
    }

    func removePage(id: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        removePage(at: index)
    }

    func clearPagesOnly() {
        for page in pages {
            try? FileManager.default.removeItem(at: page.fileURL)
            if page.thumbnailURL != page.fileURL {
                try? FileManager.default.removeItem(at: page.thumbnailURL)
            }
        }
        pages.removeAll()
    }

    func endSession(deleteFiles: Bool) {
        if deleteFiles {
            clearPagesOnly()
            ReceiptBatchCaptureDiskCache.deleteSessionDirectory(sessionDirectory)
        }
        sessionDirectory = nil
    }
}
