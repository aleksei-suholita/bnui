@testable import BNUIButton
import CoreGraphics
import Testing

@Suite("BNButtonRejection")
struct BNButtonRejectionTests {
    @Test
    func `the shake starts and ends at rest`() {
        let offsets = BNButtonRejection.standard.offsets
        #expect(offsets.first == 0)
        #expect(offsets.last == 0)
    }

    @Test
    func `the shake decays rather than repeating`() {
        // A constant amplitude reads as a glitch; a head shake loses energy.
        let offsets = BNButtonRejection(travel: 10, cycles: 3).offsets
        let peaks = offsets.map(abs).filter { $0 > 0 }
        let firstPair = peaks.prefix(2).max() ?? 0
        let lastPair = peaks.suffix(2).max() ?? 0
        #expect(lastPair < firstPair)
    }

    @Test
    func `each cycle is one trip out and back`() {
        let offsets = BNButtonRejection(cycles: 2).offsets
        // rest + two cycles of two + rest
        #expect(offsets.count == 6)
    }

    @Test
    func `the flash holds before it fades`() {
        // Fading straight from the peak is what made the colour read as a flicker: the eye only
        // ever caught the tail of it.
        let rejection = BNButtonRejection.standard
        #expect(rejection.flashHold > 0)
        #expect(rejection.flashTotalDuration == rejection.flashHold + rejection.flashFade)
        // Long enough to register as an answer rather than a glitch.
        #expect(rejection.flashTotalDuration > rejection.duration)
    }

    @Test
    func `reduce motion removes the movement and keeps the refusal`() {
        let reduced = BNButtonRejection.standard.resolved(reduceMotion: true)
        #expect(reduced.offsets.isEmpty)
        // The flash and the haptic still carry the answer — the button refuses, it just stays put.
        #expect(reduced.isEnabled)
        #expect(reduced.isHapticEnabled)
        #expect(reduced.flashAlpha > 0)
    }

    @Test
    func `a disabled refusal produces no movement at all`() {
        #expect(BNButtonRejection.none.offsets.isEmpty)
        #expect(!BNButtonRejection.none.isEnabled)
        #expect(!BNButtonRejection.none.isHapticEnabled)
    }

    @Test
    func `degenerate settings do not produce a shake`() {
        #expect(BNButtonRejection(travel: 0).offsets.isEmpty)
        #expect(BNButtonRejection(cycles: 0).offsets.isEmpty)
        #expect(BNButtonRejection(travel: -5).offsets.isEmpty)
    }

    @Test
    func `motion carries the refusal and reduce motion stills it`() {
        var motion = BNButtonMotion.standard
        motion.rejection = BNButtonRejection(travel: 9, cycles: 2)
        let reduced = motion.resolved(reduceMotion: true)
        #expect(reduced.rejection.isEnabled)
        #expect(reduced.rejection.offsets.isEmpty)
    }
}
