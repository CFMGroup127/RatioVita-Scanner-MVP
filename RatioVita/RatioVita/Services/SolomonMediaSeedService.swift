import Foundation
import SwiftData

/// Seeds starter Song of Solomon + Ma'at + book nodes when the media library is empty.
@MainActor
enum SolomonMediaSeedService {
    static func seedIfEmpty(context: ModelContext) throws {
        let cards = try context.fetch(FetchDescriptor<MetadataCard>())
        if cards.isEmpty {
            try seedSolomonSamples(context: context)
        }
        let maat = try context.fetch(FetchDescriptor<MaatDeclaration>())
        if maat.isEmpty {
            try seedMaatSamples(context: context)
        }
        let nodes = try context.fetch(FetchDescriptor<HistoricalKnowledgeNode>())
        if nodes.isEmpty {
            try seedBookAnchor(context: context)
        }
        let beats = try context.fetch(FetchDescriptor<MediaProductionBeat>())
        if beats.isEmpty {
            try seedStoryboardSample(context: context)
        }
    }

    private static func seedStoryboardSample(context: ModelContext) throws {
        context.insert(
            MediaProductionBeat(
                sortIndex: 0,
                timestampStartSeconds: 0,
                timestampEndSeconds: 5,
                audioSpec: "Heavy, slow granite drum strike. Wind. Sub-bass hum.",
                visualPrompt:
                "Hyper-realistic cinematic pan across hand-chiseled limestone columns, torchlight, dust in light columns.",
                governance: .verticalMaat
            )
        )
        context.insert(
            MediaProductionBeat(
                sortIndex: 1,
                timestampStartSeconds: 5,
                timestampEndSeconds: 12,
                audioSpec: "Tube vocal, vast chamber reverb: \"I have not robbed with violence.\"",
                visualPrompt:
                "Minimalist luxury flashcard on basalt; cut to modern skyline reflected in grey water.",
                governance: .verticalMaat
            )
        )
        try context.save()
    }

    private static func seedSolomonSamples(context: ModelContext) throws {
        let rows: [(String, String, String, SolomonEchoStream)] = [
            (
                "A garden enclosed is my sister, my spouse; a spring shut up, a fountain sealed.",
                "The Principle of the Self-Owned Vineyard: your inner life is not public property. True intimacy is granted only to those who respect the gate.",
                "Song of Solomon 4:12",
                .terrestrialEcho
            ),
            (
                "Love is strong as death… its flashes are flashes of fire, the very flame of the Lord.",
                "The Fire of Equals: love operates as elemental physics—demanding mutual honor outside priestly control.",
                "Song of Solomon 8:6",
                .celestialEcho
            ),
        ]

        for (idx, row) in rows.enumerated() {
            context.insert(
                MetadataCard(
                    sortIndex: idx,
                    frontPoeticVerse: row.0,
                    backWisdomInsight: row.1,
                    scripturalReference: row.2,
                    echoStream: row.3,
                    governance: .horizontalSolomon
                )
            )
        }

        let demoAsset = MediaAsset(
            title: "Royal Wedding Dance (demo bed)",
            notes: "Tube-warm demo template for ignition → climax tempo profile.",
            distributionFormat: .ambientLoop,
            echoStream: .terrestrialEcho,
            governance: .horizontalSolomon,
            durationSeconds: 240,
            clipDurationSeconds: 30,
            analogueCharacteristics: [.ribbonMicrophoneTransients, .valvePreAmpSaturation, .magneticTapeGlue]
        )
        context.insert(demoAsset)

        context.insert(
            LyricSegment(
                sortIndex: 0,
                lyricText: "You went off to battle… I heard you were slain… you returned more whole than when you left.",
                performanceDelivery: .spokenWordCadence,
                startOffsetSeconds: 0,
                endOffsetSeconds: 45,
                mediaAsset: demoAsset
            )
        )
        context.insert(
            LyricSegment(
                sortIndex: 1,
                lyricText: "My heart exploded when I saw a figure in the distance, moving as you do.",
                performanceDelivery: .soaringMelodicDuet,
                startOffsetSeconds: 46,
                endOffsetSeconds: 120,
                mediaAsset: demoAsset
            )
        )
        try context.save()
    }

    private static func seedMaatSamples(context: ModelContext) throws {
        let maatCard = MetadataCard(
            sortIndex: 10,
            frontPoeticVerse: "I have not robbed with violence.",
            backWisdomInsight: "Internal sovereignty: I did not take by force what was not mine to claim.",
            scripturalReference: "Negative Confession (Ma'at)",
            governance: .verticalMaat,
            presentationStyle: .minimalistSovereignChant,
            spokenIntroScript: "Declaration before the scales. I have not.",
            modernExpansionScript:
            "To rob with violence was not only theft—it was the desecration of another's boundary. Today: coercion in contracts and predatory billing."
        )
        context.insert(maatCard)

        context.insert(
            MaatDeclaration(
                declarationNumber: 2,
                ancientText: "I have not robbed with violence.",
                modernExpansion: maatCard.modernExpansionScript,
                judgeName: "Usekh-nemmt",
                judgeOrigin: "Heliopolis",
                presentationStyle: .royalAccountingIntro,
                metadataCard: maatCard
            )
        )

        context.insert(
            MediaAsset(
                title: "Hall of Ma'at (sub-bass demo)",
                notes: "Heavy stone cadence + tube vocal chamber.",
                distributionFormat: .fullTrack,
                governance: .verticalMaat,
                durationSeconds: 360,
                analogueCharacteristics: [.valvePreAmpSaturation, .magneticTapeGlue]
            )
        )
        try context.save()
    }

    private static func seedBookAnchor(context: ModelContext) throws {
        context.insert(
            HistoricalKnowledgeNode(
                title: "Council of Nicaea — forensic anchor",
                bodyMarkdown: """
                Paste research nodes here. Tag with #CouncilOfNicaea #DNA #Astronomy #HumanSexuality as you ingest chat logs.

                The 4th-century consolidation whittled proactive declarations of alignment into reactive, fear-based commandments.
                """,
                tags: ["CouncilOfNicaea", "DNA", "Astronomy"],
                governance: .forensicHistory
            )
        )
        try context.save()
    }
}
