import Foundation

/// Terrestrial lover dialogue vs celestial / divine echo streams.
enum SolomonEchoStream: String, CaseIterable, Codable, Sendable {
    case terrestrialEcho
    case celestialEcho

    var menuTitle: String {
        switch self {
            case .terrestrialEcho: "Terrestrial echo (Lover & Beloved)"
            case .celestialEcho: "Celestial echo (King & Divine)"
        }
    }
}

enum MediaAssetKind: String, CaseIterable, Codable, Sendable {
    case audio
    case video
}

/// Distribution target for the RatioVita media engine matrix.
enum SolomonDistributionFormat: String, CaseIterable, Codable, Sendable {
    /// 15–60s promotional hook (reels / shorts).
    case promotionalClip
    /// Full streaming master.
    case fullTrack
    /// Ambient loop beneath flashcard / slide decks.
    case ambientLoop

    var menuTitle: String {
        switch self {
            case .promotionalClip: "Promotional clip (15–60s)"
            case .fullTrack: "Full track"
            case .ambientLoop: "Ambient loop (slides)"
        }
    }

    var suggestedDurationSeconds: ClosedRange<Double>? {
        switch self {
            case .promotionalClip: 15...60
            case .fullTrack: nil
            case .ambientLoop: 30...120
        }
    }
}

/// All-tube analogue signal-chain characteristics (ribbon → valve → tape).
enum MediaAnalogueCharacteristic: String, CaseIterable, Codable, Sendable {
    case ribbonMicrophoneTransients
    case valvePreAmpSaturation
    case magneticTapeGlue

    var menuTitle: String {
        switch self {
            case .ribbonMicrophoneTransients: "Ribbon microphone transients"
            case .valvePreAmpSaturation: "Valve pre-amp saturation"
            case .magneticTapeGlue: "Magnetic tape glue"
        }
    }
}

enum LyricPerformanceDelivery: String, CaseIterable, Codable, Sendable {
    case spokenWordCadence
    case soaringMelodicDuet

    var menuTitle: String {
        switch self {
            case .spokenWordCadence: "Spoken word (raspy letter / camp)"
            case .soaringMelodicDuet: "Soaring melodic duet"
        }
    }
}

/// Wedding dance progressive tempo phases (ignition → acceleration → climax).
enum WeddingDanceTempoPhase: String, CaseIterable, Codable, Sendable {
    case theIgnition
    case theAcceleration
    case theClimax

    var menuTitle: String {
        switch self {
            case .theIgnition: "The ignition (slow, heavy)"
            case .theAcceleration: "The acceleration (swirling strings)"
            case .theClimax: "The climax (polyrhythmic celebration)"
        }
    }
}
