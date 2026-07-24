//
//  MultiPageScanBuffer.swift
//  RatioVita
//
//  In-memory page stack for live camera sessions (images only until pipeline OCR).
//

import Combine
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct MultiPageScanBufferPage: Identifiable, Equatable {
    let id = UUID()
    /// Downsampled page for batch OCR (not full sensor resolution).
    let image: RVImage
    /// Small raster for the live session thumbnail strip.
    let thumbnail: RVImage
    let capturedAt: Date

    static func == (lhs: MultiPageScanBufferPage, rhs: MultiPageScanBufferPage) -> Bool {
        lhs.id == rhs.id
    }
}

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

    func move(fromOffsets: IndexSet, toOffset: Int) {
        pages.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func clear() {
        pages.removeAll()
    }

    var images: [RVImage] {
        pages.map(\.image)
    }
}
