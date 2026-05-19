import Foundation

/// Playback calculator for the royal wedding dance tempo arc (ignition → acceleration → climax).
enum WeddingDanceTempoProfile {
    struct Snapshot: Equatable, Sendable {
        var phase: WeddingDanceTempoPhase
        var tempoBPM: Double
        var progress: Double
        var stringSwirlIntensity: Double
        var shouldPulseHaptic: Bool
    }

    struct Configuration: Equatable, Sendable {
        var ignitionBPM: Double = 72
        var climaxBPM: Double = 128
        var ignitionPhaseEnd: Double = 0.33
        var accelerationPhaseEnd: Double = 0.66
        var hapticPulseInterval: Double = 0.08
    }

    /// Normalized timeline position `0...1` across track duration.
    static func phase(at progress: Double, config: Configuration = Configuration()) -> WeddingDanceTempoPhase {
        let p = progress.clamped01
        if p < config.ignitionPhaseEnd { return .theIgnition }
        if p < config.accelerationPhaseEnd { return .theAcceleration }
        return .theClimax
    }

    static func tempoBPM(at progress: Double, config: Configuration = Configuration()) -> Double {
        let p = progress.clamped01
        switch phase(at: p, config: config) {
            case .theIgnition:
                let t = p / max(config.ignitionPhaseEnd, 0.001)
                return lerp(config.ignitionBPM, config.ignitionBPM + 12, t)
            case .theAcceleration:
                let start = config.ignitionPhaseEnd
                let end = config.accelerationPhaseEnd
                let t = (p - start) / max(end - start, 0.001)
                return lerp(config.ignitionBPM + 12, config.climaxBPM - 8, t)
            case .theClimax:
                let start = config.accelerationPhaseEnd
                let t = (p - start) / max(1 - start, 0.001)
                return lerp(config.climaxBPM - 8, config.climaxBPM, t)
        }
    }

    /// String-layer swirl amount for visual / mix automation (0…1).
    static func stringSwirlIntensity(at progress: Double, config: Configuration = Configuration()) -> Double {
        switch phase(at: progress, config: config) {
            case .theIgnition: 0.15
            case .theAcceleration: 0.15 + 0.55 * ((progress - config.ignitionPhaseEnd) / max(
                    config.accelerationPhaseEnd - config.ignitionPhaseEnd,
                    0.001
                )).clamped01
            case .theClimax: 0.85 + 0.15 * sin(progress * .pi * 6)
        }
    }

    static func snapshot(
        at progress: Double,
        previousProgress: Double? = nil,
        config: Configuration = Configuration()
    ) -> Snapshot {
        let p = progress.clamped01
        let prev = previousProgress?.clamped01
        let pulse = shouldTriggerHaptic(at: p, previousProgress: prev, config: config)
        return Snapshot(
            phase: phase(at: p, config: config),
            tempoBPM: tempoBPM(at: p, config: config),
            progress: p,
            stringSwirlIntensity: stringSwirlIntensity(at: p, config: config),
            shouldPulseHaptic: pulse
        )
    }

    static func shouldTriggerHaptic(
        at progress: Double,
        previousProgress: Double?,
        config: Configuration = Configuration()
    ) -> Bool {
        guard phase(at: progress, config: config) == .theClimax else { return false }
        guard let prev = previousProgress else { return progress > config.accelerationPhaseEnd }
        let interval = config.hapticPulseInterval
        let prevBucket = Int(prev / interval)
        let curBucket = Int(progress.clamped01 / interval)
        return curBucket > prevBucket
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t.clamped01
    }
}

extension Double {
    fileprivate var clamped01: Double { min(1, max(0, self)) }
}
