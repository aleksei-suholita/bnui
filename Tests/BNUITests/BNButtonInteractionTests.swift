@testable import BNUIButton
import CoreGraphics
import Testing

@Suite("BNButtonInteraction")
struct BNButtonInteractionTests {
    private func pressed(_ interaction: inout BNButtonInteraction, at time: Double = 0) -> BNButtonInteraction.Outcome {
        interaction.handle(.down(at: time), status: .enabled)
    }

    @Test
    func `a press and a release inside fire once`() {
        var interaction = BNButtonInteraction(hapticMergeWindow: 0.15)
        let down = pressed(&interaction)
        #expect(down.isPressed)
        #expect(!down.didFire)
        #expect(down.haptic == .press)

        let release = interaction.handle(.up(inside: true, at: 0.4), status: .enabled)
        #expect(release.didFire)
        #expect(!release.isPressed)
        #expect(release.haptic == .trigger)
    }

    @Test
    func `a quick tap gets one haptic, not two`() {
        // The press tick and the confirmation would land within a few dozen milliseconds of each
        // other and blur into a rattle, so the confirmation goes and the press stands for the tap.
        var interaction = BNButtonInteraction(hapticMergeWindow: 0.15)
        #expect(pressed(&interaction).haptic == .press)

        let release = interaction.handle(.up(inside: true, at: 0.08), status: .enabled)
        #expect(release.didFire)
        #expect(release.haptic == .silent)
    }

    @Test
    func `merging the haptic never swallows the action`() {
        // Silence is about the finger, not about the handler: the fastest tap still fires.
        var interaction = BNButtonInteraction(hapticMergeWindow: 0.15)
        _ = pressed(&interaction)
        #expect(interaction.handle(.up(inside: true, at: 0), status: .enabled).didFire)
    }

    @Test
    func `a merge window of zero always confirms`() {
        var interaction = BNButtonInteraction(hapticMergeWindow: 0)
        _ = pressed(&interaction)
        #expect(interaction.handle(.up(inside: true, at: 0), status: .enabled).haptic == .trigger)
    }

    @Test
    func `dragging out disarms the button`() {
        var interaction = BNButtonInteraction()
        _ = pressed(&interaction)
        let out = interaction.handle(.moved(inside: false), status: .enabled)
        #expect(!out.isPressed)
        #expect(out.haptic == .silent)
    }

    @Test
    func `dragging back in re-arms it`() {
        var interaction = BNButtonInteraction()
        _ = pressed(&interaction)
        _ = interaction.handle(.moved(inside: false), status: .enabled)
        let back = interaction.handle(.moved(inside: true), status: .enabled)
        #expect(back.isPressed)
        // Silent on re-entry: a finger resting on the edge would rattle otherwise.
        #expect(back.haptic == .silent)

        let release = interaction.handle(.up(inside: true, at: 0.2), status: .enabled)
        #expect(release.didFire)
    }

    @Test
    func `releasing outside fires nothing and stays silent`() {
        var interaction = BNButtonInteraction()
        _ = pressed(&interaction)
        _ = interaction.handle(.moved(inside: false), status: .enabled)
        let release = interaction.handle(.up(inside: false, at: 0.2), status: .enabled)
        #expect(!release.didFire)
        #expect(!release.isPressed)
        #expect(release.haptic == .silent)
    }

    @Test
    func `a cancelled touch fires nothing and stays silent`() {
        var interaction = BNButtonInteraction()
        _ = pressed(&interaction)
        let cancelled = interaction.handle(.cancelled, status: .enabled)
        #expect(!cancelled.didFire)
        #expect(!cancelled.isPressed)
        #expect(cancelled.haptic == .silent)
    }

    @Test
    func `a disabled button refuses the touch instead of pressing`() {
        var interaction = BNButtonInteraction()
        let down = interaction.handle(.down(at: 0), status: .disabled)
        #expect(!down.isPressed)
        #expect(!down.didFire)
        #expect(down.didReject)
        #expect(down.haptic == .rejected)
    }

    @Test
    func `only the landing refuses, not the lift`() {
        // One refusal per touch: the gesture was turned down when the finger arrived, and repeating
        // the shake on the way up would read as two separate rejections of one tap.
        var interaction = BNButtonInteraction()
        _ = interaction.handle(.down(at: 0), status: .disabled)
        let release = interaction.handle(.up(inside: true, at: 0.1), status: .disabled)
        #expect(!release.didFire)
        #expect(!release.didReject)
        #expect(release.haptic == .silent)
    }

    @Test
    func `a loading button swallows the touch without refusing it`() {
        // Busy is not forbidden: shaking here would tell the user their tap was wrong, when it was
        // merely early.
        var interaction = BNButtonInteraction()
        let down = interaction.handle(.down(at: 0), status: .loading)
        #expect(!down.didReject)
        #expect(down.haptic == .silent)

        let release = interaction.handle(.up(inside: true, at: 0.1), status: .loading)
        #expect(!release.didFire)
    }

    @Test
    func `a button disabled mid press does not fire when the finger lifts`() {
        var interaction = BNButtonInteraction()
        _ = pressed(&interaction)
        _ = interaction.handle(.moved(inside: true), status: .disabled)
        let release = interaction.handle(.up(inside: true, at: 0.1), status: .enabled)
        #expect(!release.didFire)
    }

    @Test
    func `the release carries the snap of the hold`() {
        var interaction = BNButtonInteraction(snapWindow: 0.25)
        _ = pressed(&interaction)
        let quick = interaction.handle(.up(inside: true, at: 0), status: .enabled)
        #expect(quick.snap == 1)

        var slow = BNButtonInteraction(snapWindow: 0.25)
        _ = pressed(&slow)
        let held = slow.handle(.up(inside: true, at: 1), status: .enabled)
        #expect(held.snap == 0)
    }

    @Test
    func `a cancelled release still carries the snap so the button springs back`() {
        var interaction = BNButtonInteraction(snapWindow: 0.25)
        _ = pressed(&interaction)
        let outside = interaction.handle(.up(inside: false, at: 0), status: .enabled)
        #expect(outside.snap == 1)
        #expect(!outside.didFire)
    }

    @Test
    func `the cooldown swallows the second tap but not the first`() {
        var interaction = BNButtonInteraction(cooldown: 0.5)
        _ = pressed(&interaction)
        #expect(interaction.handle(.up(inside: true, at: 0.05), status: .enabled).didFire)

        _ = interaction.handle(.down(at: 0.1), status: .enabled)
        let swallowed = interaction.handle(.up(inside: true, at: 0.15), status: .enabled)
        #expect(!swallowed.didFire)
        // No haptic: the finger must not be told an action happened when it did not.
        #expect(swallowed.haptic == .silent)

        _ = interaction.handle(.down(at: 1), status: .enabled)
        #expect(interaction.handle(.up(inside: true, at: 1.05), status: .enabled).didFire)
    }

    @Test
    func `a cooldown of zero swallows nothing`() {
        var interaction = BNButtonInteraction(cooldown: 0)
        _ = pressed(&interaction)
        #expect(interaction.handle(.up(inside: true, at: 0), status: .enabled).didFire)
        _ = interaction.handle(.down(at: 0), status: .enabled)
        #expect(interaction.handle(.up(inside: true, at: 0), status: .enabled).didFire)
    }

    @Test
    func `a release without a press is ignored`() {
        var interaction = BNButtonInteraction()
        let release = interaction.handle(.up(inside: true, at: 0.1), status: .enabled)
        #expect(!release.didFire)
        #expect(release.haptic == .silent)
    }

    @Test
    func `a drag with no press behind it changes nothing`() {
        var interaction = BNButtonInteraction()
        let moved = interaction.handle(.moved(inside: true), status: .enabled)
        #expect(!moved.isPressed)
        #expect(!moved.didFire)
    }
}
