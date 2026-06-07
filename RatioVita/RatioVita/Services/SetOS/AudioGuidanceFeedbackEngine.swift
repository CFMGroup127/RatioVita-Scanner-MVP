import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Localized audio correction + arrival handshake copy (Sprint UUU).
@MainActor
enum AudioGuidanceFeedbackEngine {
    static func speak(_ text: String) {
        #if canImport(AVFoundation)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        let synth = AVSpeechSynthesizer()
        synth.speak(utterance)
        #else
        #if DEBUG
        print("Vita audio: \(text)")
        #endif
        #endif
    }

    static func deliverCorrection(_ payload: VoiceIntentPayload) {
        speak(payload.spokenCorrection)
    }

    static func arrivalHandshakeMessage(supervisorName: String, etaSeconds: Int = 90) -> String {
        "\(supervisorName) en route with gear · ETA \(etaSeconds)s"
    }
}
