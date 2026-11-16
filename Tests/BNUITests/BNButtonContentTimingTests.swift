@testable import BNUIButton
import Foundation
import Testing

@Suite("BNButtonContentTiming")
struct BNButtonContentTimingTests {
    @Test
    func `an animated change on screen takes the kit's spring`() {
        let timing = BNButtonContentTiming.resolve(
            animated: true, isInWindow: true, animationsEnabled: true, inheritedDuration: 0,
        )
        #expect(timing == .own)
    }

    @Test
    func `inside the host's animation the change joins it`() {
        let timing = BNButtonContentTiming.resolve(
            animated: true, isInWindow: true, animationsEnabled: true, inheritedDuration: 0.5,
        )
        #expect(timing == .inherited(duration: 0.5))
    }

    @Test
    func `an explicit no wins over the host's animation`() {
        let timing = BNButtonContentTiming.resolve(
            animated: false, isInWindow: true, animationsEnabled: true, inheritedDuration: 0.5,
        )
        #expect(timing == .immediate)
    }

    @Test
    func `off screen nothing animates`() {
        let timing = BNButtonContentTiming.resolve(
            animated: true, isInWindow: false, animationsEnabled: true, inheritedDuration: 0.5,
        )
        #expect(timing == .immediate)
    }

    @Test
    func `animations turned off for the moment win too`() {
        // `UIView.performWithoutAnimation` — the host's way to say no for a whole block of calls.
        let timing = BNButtonContentTiming.resolve(
            animated: true, isInWindow: true, animationsEnabled: false, inheritedDuration: 0,
        )
        #expect(timing == .immediate)
    }
}

@Suite("BNButtonContentTransitionTuning speed")
struct BNButtonContentTransitionSpeedTests {
    @Test
    func `without a duration the tuning stays as it is`() {
        let tuning = BNButtonContentTransitionTuning()
        #expect(tuning.scaled(toDuration: nil) == tuning)
        #expect(tuning.scaled(toDuration: 0) == tuning)
    }

    @Test
    func `the longer spring takes the duration and the other keeps its share`() {
        let tuning = BNButtonContentTransitionTuning()
        let slow = tuning.scaled(toDuration: 0.8)
        #expect(abs(slow.size.duration - 0.8) < 1e-9)
        #expect(abs(slow.content.duration - 0.7) < 1e-9)
        #expect(slow.size.bounce == tuning.size.bounce)
        #expect(slow.content.bounce == tuning.content.bounce)
    }
}

@Suite("BNButtonRollDirection")
struct BNButtonNumericDirectionTests {
    @Test
    func `a smaller number rolls down and a larger one up`() {
        #expect(BNButtonRollDirection.countsDown(from: "12 items", to: "9 items"))
        #expect(!BNButtonRollDirection.countsDown(from: "1 item", to: "2 items"))
        #expect(BNButtonRollDirection.countsDown(from: "$19.99", to: "$9.99"))
    }

    @Test
    func `a title without a number rolls up, as the system does`() {
        #expect(!BNButtonRollDirection.countsDown(from: "Save", to: "Saved"))
        #expect(!BNButtonRollDirection.countsDown(from: "3 items", to: "Checkout"))
        #expect(!BNButtonRollDirection.countsDown(from: nil, to: "1"))
    }

    @Test
    func `separators between digits are skipped and a separator elsewhere ends the number`() {
        #expect(BNButtonRollDirection.number(in: "Pay 1,500.00") == Decimal(150_000))
        #expect(BNButtonRollDirection.number(in: "1, 5") == Decimal(1))
        #expect(BNButtonRollDirection.number(in: "Buy 3.") == Decimal(3))
        #expect(BNButtonRollDirection.number(in: "Buy") == nil)
    }
}

@Suite("BNButtonContentMoves")
struct BNButtonContentMovesTests {
    @Test
    func `a slide up leaves upwards and arrives from below, a slide down the other way`() {
        let up = BNButtonContentMoves(sliding: .up, travel: 12, leavingShare: 0.35, arrivalDelayShare: 0.15)
        #expect(up.leavesTo.ty == -12)
        #expect(up.arrivesFrom.ty == 12)
        let down = BNButtonContentMoves(sliding: .down, travel: 12, leavingShare: 0.35, arrivalDelayShare: 0.15)
        #expect(down.leavesTo.ty == 12)
        #expect(down.arrivesFrom.ty == -12)
        #expect(down.leavesTo.tx == 0 && down.arrivesFrom.tx == 0)
    }
}
