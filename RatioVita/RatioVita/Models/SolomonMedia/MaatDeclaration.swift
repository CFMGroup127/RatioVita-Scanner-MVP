import Foundation
import SwiftData

/// One of the 42 Negative Confessions / Declarations of Ma'at.
@Model
final class MaatDeclaration {
    @Attribute(.unique) var id: UUID
    var declarationNumber: Int
    var ancientText: String
    var modernExpansion: String?
    var judgeName: String?
    var judgeOrigin: String?
    var presentationStyleRaw: String
    var createdAt: Date
    var updatedAt: Date

    var metadataCard: MetadataCard?

    init(
        id: UUID = UUID(),
        declarationNumber: Int,
        ancientText: String,
        modernExpansion: String? = nil,
        judgeName: String? = nil,
        judgeOrigin: String? = nil,
        presentationStyle: MaatFlashcardPresentationStyle = .royalAccountingIntro,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        metadataCard: MetadataCard? = nil
    ) {
        self.id = id
        self.declarationNumber = declarationNumber
        self.ancientText = ancientText
        self.modernExpansion = modernExpansion
        self.judgeName = judgeName
        self.judgeOrigin = judgeOrigin
        presentationStyleRaw = presentationStyle.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadataCard = metadataCard
    }
}

extension MaatDeclaration {
    var presentationStyle: MaatFlashcardPresentationStyle {
        get { MaatFlashcardPresentationStyle(rawValue: presentationStyleRaw) ?? .royalAccountingIntro }
        set { presentationStyleRaw = newValue.rawValue }
    }
}
