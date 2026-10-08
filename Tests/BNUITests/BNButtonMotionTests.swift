@testable import BNUIButton
@testable import BNUICore
import CoreGraphics
import Testing

@Suite("BNButtonMotion")
struct BNButtonMotionTests {
    @Test
    func `an instant tap earns the full snap`() {
        #expect(BNButtonMotion.snap(heldFor: 0, window: 0.25) == 1)
    }

    @Test
    func `holding past the window earns nothing`() {
        #expect(BNButtonMotion.snap(heldFor: 0.4, window: 0.25) == 0)
        #expect(BNButtonMotion.snap(heldFor: 0.25, window: 0.25) == 0)
    }

    @Test
    func `snap falls off linearly inside the window`() {
        #expect(BNButtonMotion.snap(heldFor: 0.125, window: 0.25) == 0.5)
    }

    @Test
    func `a zero window never divides by zero`() {
        #expect(BNButtonMotion.snap(heldFor: 0.1, window: 0) == 0)
        #expect(BNButtonMotion.snap(heldFor: 0, window: 0) == 0)
    }

    @Test
    func `a negative hold is treated as instant`() {
        // Clocks are handed in by the caller; a swapped pair of timestamps must not produce a
        // spring with a nonsense bounce.
        let snap = BNButtonMotion.snap(heldFor: -1, window: 0.25)
        #expect(snap == 1)
    }

    @Test
    func `a fast release bounces more than a slow one`() {
        let motion = BNButtonMotion.standard
        #expect(motion.releaseSpring(snap: 1).bounce > motion.releaseSpring(snap: 0).bounce)
    }

    @Test
    func `a fast release starts with more velocity than a slow one`() {
        // This is the reward itself: the quick click gets a shove into the return.
        let motion = BNButtonMotion.standard
        #expect(motion.releaseSpring(snap: 1).initialVelocity > motion.releaseSpring(snap: 0).initialVelocity)
        #expect(motion.releaseSpring(snap: 0).initialVelocity == 0)
    }

    @Test
    func `snap outside zero to one is clamped`() {
        let motion = BNButtonMotion.standard
        #expect(motion.releaseSpring(snap: 5) == motion.releaseSpring(snap: 1))
        #expect(motion.releaseSpring(snap: -5) == motion.releaseSpring(snap: 0))
    }

    @Test
    func `reduce motion removes every overshoot`() {
        let reduced = BNButtonMotion.standard.resolved(reduceMotion: true)
        #expect(reduced.press.bounce == 0)
        #expect(reduced.releaseSlow.bounce == 0)
        #expect(reduced.releaseFast.bounce == 0)
        #expect(reduced.releaseSpring(snap: 1).initialVelocity == 0)
    }

    @Test
    func `reduce motion shortens every duration`() {
        let standard = BNButtonMotion.standard
        let reduced = standard.resolved(reduceMotion: true)
        #expect(reduced.press.duration < standard.press.duration)
        #expect(reduced.releaseFast.duration < standard.releaseFast.duration)
        #expect(reduced.loading.duration < standard.loading.duration)
    }

    @Test
    func `reduce motion keeps the rules that are not effects`() {
        // The cooldown is a rule about firing, not an animation, so accessibility does not touch it.
        // Neither is the haptic merge window: Reduce Motion takes away movement, not feedback.
        var motion = BNButtonMotion.standard
        motion.cooldown = 0.4
        motion.snapWindow = 0.3
        motion.hapticMergeWindow = 0.2
        let reduced = motion.resolved(reduceMotion: true)
        #expect(reduced.cooldown == 0.4)
        #expect(reduced.snapWindow == 0.3)
        #expect(reduced.hapticMergeWindow == 0.2)
    }

    @Test
    func `motion is untouched when reduce motion is off`() {
        #expect(BNButtonMotion.standard.resolved(reduceMotion: false) == BNButtonMotion.standard)
    }

    @Test
    func `interpolation lands between the two ends and clamps outside them`() {
        let slow = BNSpring(duration: 0.3, bounce: 0.1)
        let fast = BNSpring(duration: 0.5, bounce: 0.5)
        let middle = BNSpring.interpolated(from: slow, to: fast, t: 0.5)
        #expect(abs(middle.duration - 0.4) < 0.0001)
        #expect(abs(middle.bounce - 0.3) < 0.0001)

        let beyond = BNSpring.interpolated(from: slow, to: fast, t: 2)
        #expect(abs(beyond.bounce - fast.bounce) < 0.0001)
        #expect(abs(beyond.duration - fast.duration) < 0.0001)
    }
}
