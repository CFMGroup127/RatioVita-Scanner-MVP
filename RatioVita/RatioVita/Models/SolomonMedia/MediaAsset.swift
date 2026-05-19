import Foundation
import SwiftData

/// High-fidelity audio or video binary tracked by the Songs of Solomon / Media Core engine.
@Model
final class MediaAsset {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    var assetKindRaw: String
    var distributionFormatRaw: String
    var echoStreamRaw: String
    var governanceTypeRaw: String = ContentGovernanceType.horizontalSolomon.rawValue

    /// Relative path under app media vault (e.g. `MediaCore/audio/track-01.m4a`).
    var vaultRelativePath: String?
    var durationSeconds: Double?
    /// Suggested clip length for promotional exports.
    var clipDurationSeconds: Double?

    /// Comma-separated `MediaAnalogueCharacteristic` raw values.
    var analogueCharacteristicsRaw: String

    @Relationship(deleteRule: .cascade, inverse: \LyricSegment.mediaAsset)
    var lyricSegments: [LyricSegment]

    @Relationship(deleteRule: .nullify, inverse: \MetadataCard.linkedMediaAsset)
    var metadataCards: [MetadataCard]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        assetKind: MediaAssetKind = .audio,
        distributionFormat: SolomonDistributionFormat = .fullTrack,
        echoStream: SolomonEchoStream = .terrestrialEcho,
        governance: ContentGovernanceType = .horizontalSolomon,
        vaultRelativePath: String? = nil,
        durationSeconds: Double? = nil,
        clipDurationSeconds: Double? = nil,
        analogueCharacteristics: [MediaAnalogueCharacteristic] = [],
        lyricSegments: [LyricSegment] = [],
        metadataCards: [MetadataCard] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        assetKindRaw = assetKind.rawValue
        distributionFormatRaw = distributionFormat.rawValue
        echoStreamRaw = echoStream.rawValue
        governanceTypeRaw = governance.rawValue
        self.vaultRelativePath = vaultRelativePath
        self.durationSeconds = durationSeconds
        self.clipDurationSeconds = clipDurationSeconds
        analogueCharacteristicsRaw = Self.encodeCharacteristics(analogueCharacteristics)
        self.lyricSegments = lyricSegments
        self.metadataCards = metadataCards
    }
}

extension MediaAsset {
    var assetKind: MediaAssetKind {
        get { MediaAssetKind(rawValue: assetKindRaw) ?? .audio }
        set { assetKindRaw = newValue.rawValue }
    }

    var distributionFormat: SolomonDistributionFormat {
        get { SolomonDistributionFormat(rawValue: distributionFormatRaw) ?? .fullTrack }
        set { distributionFormatRaw = newValue.rawValue }
    }

    var echoStream: SolomonEchoStream {
        get { SolomonEchoStream(rawValue: echoStreamRaw) ?? .terrestrialEcho }
        set { echoStreamRaw = newValue.rawValue }
    }

    var governance: ContentGovernanceType {
        get { ContentGovernanceType(rawValue: governanceTypeRaw) ?? .horizontalSolomon }
        set { governanceTypeRaw = newValue.rawValue }
    }

    var analogueCharacteristics: [MediaAnalogueCharacteristic] {
        get { Self.decodeCharacteristics(analogueCharacteristicsRaw) }
        set { analogueCharacteristicsRaw = Self.encodeCharacteristics(newValue) }
    }

    static func encodeCharacteristics(_ traits: [MediaAnalogueCharacteristic]) -> String {
        traits.map(\.rawValue).joined(separator: ",")
    }

    static func decodeCharacteristics(_ raw: String) -> [MediaAnalogueCharacteristic] {
        raw.split(separator: ",").compactMap { part in
            MediaAnalogueCharacteristic(rawValue: String(part).trimmingCharacters(in: .whitespaces))
        }
    }
}
