@testable import BNUITabBar
import Testing

/// Effects are written as the system's are — `.bounce.down.byLayer` — and kept as one value an
/// item compares: equal for equal options, whatever order they were written in.
@Suite("BNTabBarSymbolAnimation — effects and their options")
struct BNTabBarSymbolAnimationTests {
    /// What an item keeps for an effect written at its parameter.
    private func kept(_ effect: some BNTabBarSymbolEffect) -> BNTabBarSymbolAnimation {
        effect.symbolAnimation
    }

    /// Every effect, and every option of each, written once.
    private var everyChoice: [BNTabBarSymbolAnimation] {
        [
            kept(.none),
            kept(.bounce), kept(.bounce.up), kept(.bounce.down), kept(.bounce.byLayer), kept(.bounce.wholeSymbol),
            kept(.pulse), kept(.pulse.byLayer), kept(.pulse.wholeSymbol),
            kept(.wiggle), kept(.wiggle.left), kept(.wiggle.right), kept(.wiggle.up), kept(.wiggle.down),
            kept(.wiggle.forward), kept(.wiggle.backward), kept(.wiggle.clockwise), kept(.wiggle.counterClockwise),
            kept(.wiggle.custom(angle: 30)), kept(.wiggle.byLayer), kept(.wiggle.wholeSymbol),
            kept(.rotate), kept(.rotate.clockwise), kept(.rotate.counterClockwise),
            kept(.rotate.byLayer), kept(.rotate.wholeSymbol),
            kept(.breathe), kept(.breathe.plain), kept(.breathe.pulse), kept(.breathe.byLayer), kept(.breathe.wholeSymbol),
            kept(.drawOn), kept(.drawOn.byLayer), kept(.drawOn.wholeSymbol), kept(.drawOn.individually),
        ]
    }

    @Test
    func `every effect and option is told apart`() {
        let choices = everyChoice
        for (index, choice) in choices.enumerated() {
            #expect(choices.firstIndex(of: choice) == index)
        }
    }

    @Test
    func `options read the same in any order`() {
        #expect(kept(.bounce.down.byLayer) == kept(.bounce.byLayer.down))
        #expect(kept(.wiggle.left.wholeSymbol) == kept(.wiggle.wholeSymbol.left))
    }

    @Test
    func `the last choice of an option wins`() {
        #expect(kept(.bounce.up.down) == kept(.bounce.down))
        #expect(kept(.drawOn.byLayer.individually) == kept(.drawOn.individually))
        #expect(kept(.wiggle.custom(angle: 30).custom(angle: 45)) == kept(.wiggle.custom(angle: 45)))
    }

    @Test
    func `a kept effect passes on as it is`() {
        let effect = kept(.breathe.pulse.byLayer)
        #expect(kept(effect) == effect)
    }

    @Test
    func `an item plays a plain bounce unless told otherwise`() {
        #expect(BNTabBarSymbolAnimation.standard == kept(.bounce))
    }
}
