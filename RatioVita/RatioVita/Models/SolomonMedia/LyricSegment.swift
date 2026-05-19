import Foundation
import SwiftData

/// One lyrical passage with explicit performance delivery tier.
@Model
final class LyricSegment {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var lyricText: String
    var performanceDeliveryRaw: String
    var startOffsetSeconds: Double?
    var endOffsetSeconds: Double?
    var createdAt: Date
    var updatedAt: Date

    var mediaAsset: MediaAsset?

    init(
        id: UUID = UUID(),
        sortIndex: Int = 0,
        lyricText: String,
        performanceDelivery: LyricPerformanceDelivery = .soaringMelodicDuet,
        startOffsetSeconds: Double? = nil,
        endOffsetSeconds: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        mediaAsset: MediaAsset? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.lyricText = lyricText
        performanceDeliveryRaw = performanceDelivery.rawValue
        self.startOffsetSeconds = startOffsetSeconds
        self.endOffsetSeconds = endOffsetSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mediaAsset = mediaAsset
    }
}

extension LyricSegment {
    var performanceDelivery: LyricPerformanceDelivery {
        get { LyricPerformanceDelivery(rawValue: performanceDeliveryRaw) ?? .soaringMelodicDuet }
        set { performanceDeliveryRaw = newValue.rawValue }
    }
}
