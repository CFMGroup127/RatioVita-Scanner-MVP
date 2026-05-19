import Foundation
import SwiftData

/// Etymological wisdom flashcard (front verse + back insight).
@Model
final class MetadataCard {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var frontPoeticVerse: String
    var backWisdomInsight: String
    var scripturalReference: String?
    var echoStreamRaw: String
    var governanceTypeRaw: String = ContentGovernanceType.horizontalSolomon.rawValue
    var presentationStyleRaw: String?
    /// Optional spoken intro before the card (Solomon wisdom track or Ma'at scribe).
    var spokenIntroScript: String?
    /// Ma'at style-1: bring the declaration home to the modern era.
    var modernExpansionScript: String?
    var createdAt: Date
    var updatedAt: Date

    var linkedMediaAsset: MediaAsset?

    init(
        id: UUID = UUID(),
        sortIndex: Int = 0,
        frontPoeticVerse: String,
        backWisdomInsight: String,
        scripturalReference: String? = nil,
        echoStream: SolomonEchoStream = .terrestrialEcho,
        governance: ContentGovernanceType = .horizontalSolomon,
        presentationStyle: MaatFlashcardPresentationStyle? = nil,
        spokenIntroScript: String? = nil,
        modernExpansionScript: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        linkedMediaAsset: MediaAsset? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.frontPoeticVerse = frontPoeticVerse
        self.backWisdomInsight = backWisdomInsight
        self.scripturalReference = scripturalReference
        echoStreamRaw = echoStream.rawValue
        governanceTypeRaw = governance.rawValue
        presentationStyleRaw = presentationStyle?.rawValue
        self.spokenIntroScript = spokenIntroScript
        self.modernExpansionScript = modernExpansionScript
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedMediaAsset = linkedMediaAsset
    }
}

extension MetadataCard {
    var echoStream: SolomonEchoStream {
        get { SolomonEchoStream(rawValue: echoStreamRaw) ?? .terrestrialEcho }
        set { echoStreamRaw = newValue.rawValue }
    }

    var governance: ContentGovernanceType {
        get { ContentGovernanceType(rawValue: governanceTypeRaw) ?? .horizontalSolomon }
        set { governanceTypeRaw = newValue.rawValue }
    }

    var presentationStyle: MaatFlashcardPresentationStyle? {
        get {
            guard let raw = presentationStyleRaw else { return nil }
            return MaatFlashcardPresentationStyle(rawValue: raw)
        }
        set { presentationStyleRaw = newValue?.rawValue }
    }
}
