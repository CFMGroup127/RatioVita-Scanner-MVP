@testable import RatioVita
import XCTest

final class WeddingDanceTempoProfileTests: XCTestCase {
    func testPhaseBoundaries() {
        XCTAssertEqual(WeddingDanceTempoProfile.phase(at: 0.1), .theIgnition)
        XCTAssertEqual(WeddingDanceTempoProfile.phase(at: 0.4), .theAcceleration)
        XCTAssertEqual(WeddingDanceTempoProfile.phase(at: 0.9), .theClimax)
    }

    func testTempoIncreasesMonotonicallyAcrossIgnitionAndAcceleration() {
        let early = WeddingDanceTempoProfile.tempoBPM(at: 0.05)
        let mid = WeddingDanceTempoProfile.tempoBPM(at: 0.5)
        let late = WeddingDanceTempoProfile.tempoBPM(at: 0.95)
        XCTAssertLessThan(early, mid)
        XCTAssertLessThan(mid, late)
    }

    func testClimaxTriggersHapticPulse() {
        let config = WeddingDanceTempoProfile.Configuration(hapticPulseInterval: 0.1)
        XCTAssertTrue(
            WeddingDanceTempoProfile.shouldTriggerHaptic(at: 0.71, previousProgress: 0.69, config: config)
        )
        XCTAssertFalse(
            WeddingDanceTempoProfile.shouldTriggerHaptic(at: 0.4, previousProgress: 0.38, config: config)
        )
    }
}
