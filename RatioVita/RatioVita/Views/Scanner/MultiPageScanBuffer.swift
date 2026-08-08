//
//  MultiPageScanBuffer.swift
//  RatioVita
//
//  Deprecated: use ReceiptBatchManager (disk-backed temp JPEGs) for live camera sessions.
//

import Combine
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@available(*, deprecated, message: "Use ReceiptBatchManager for memory-safe live capture.")
struct MultiPageScanBufferPage: Identifiable, Equatable {
    let id = UUID()
    let image: RVImage
    let thumbnail: RVImage
    let capturedAt: Date

    static func == (lhs: MultiPageScanBufferPage, rhs: MultiPageScanBufferPage) -> Bool {
        lhs.id == rhs.id
    }
}

@available(*, deprecated, message: "Use ReceiptBatchManager for memory-safe live capture.")
@MainActor
final class MultiPageScanBuffer: ObservableObject {
    @Published private(set) var pages: [MultiPageScanBufferPage] = []

    var count: Int { pages.count }
    var isEmpty: Bool { pages.isEmpty }

    func append(_ image: RVImage) {
        autoreleasepool {
            let normalized = LiveMultiPageCaptureImagePrep.normalizedForSessionBuffer(image)
            let thumb = LiveMultiPageCaptureImagePrep.stripThumbnail(from: normalized)
            pages.append(
                MultiPageScanBufferPage(image: normalized, thumbnail: thumb, capturedAt: Date())
            )
        }
    }

    func remove(id: UUID) {
        pages.removeAll { $0.id == id }
    }

    func clear() {
        pages.removeAll()
    }

    var images: [RVImage] {
        pages.map(\.image)
    }
}
