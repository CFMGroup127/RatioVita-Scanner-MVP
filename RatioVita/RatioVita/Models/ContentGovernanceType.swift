import Foundation

/// Unified brand streams: heart (Solomon), spine (Ma'at), forensic book assembly.
enum ContentGovernanceType: String, CaseIterable, Codable, Sendable {
    case horizontalSolomon
    case verticalMaat
    case forensicHistory

    var menuTitle: String {
        switch self {
            case .horizontalSolomon: "Song of Solomon (heart)"
            case .verticalMaat: "Declarations of Ma'at (spine)"
            case .forensicHistory: "Forensic history (book)"
        }
    }
}

/// Flashcard / reel presentation tiers for Ma'at (and optional Solomon intros).
enum MaatFlashcardPresentationStyle: String, CaseIterable, Codable, Sendable {
    case royalAccountingIntro
    case minimalistSovereignChant
    case musicAndVoiceOnly

    var menuTitle: String {
        switch self {
            case .royalAccountingIntro: "Royal accounting intro + modern expansion"
            case .minimalistSovereignChant: "Minimalist sovereign chant"
            case .musicAndVoiceOnly: "Music + voice on card only"
        }
    }
}
