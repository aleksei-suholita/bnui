@testable import BNUIButton
import Foundation
import Testing

@Suite("BNSymbolReplaceTiming")
struct BNSymbolReplaceTimingTests {
    @Test
    func `a slash added in a sixth of a second plays four times as fast`() {
        let speed = BNSymbolReplaceTiming.speed(toTake: 1.0 / 6.0, natural: BNSymbolReplaceTiming.magicReplace)
        #expect(abs(speed - 4) < 0.0001)
    }

    @Test
    func `a longer duration than the system's slows the effect down`() {
        #expect(BNSymbolReplaceTiming.speed(toTake: 1, natural: BNSymbolReplaceTiming.replace) == 0.5)
    }

    @Test
    func `a duration that is not a real one keeps the system's speed`() {
        #expect(BNSymbolReplaceTiming.speed(toTake: 0, natural: BNSymbolReplaceTiming.replace) == 1)
        #expect(BNSymbolReplaceTiming.speed(toTake: -1, natural: BNSymbolReplaceTiming.replace) == 1)
        #expect(BNSymbolReplaceTiming.speed(toTake: .infinity, natural: BNSymbolReplaceTiming.replace) == 1)
    }

    @Test
    func `the measured durations stay what RenderBox plays`() {
        #expect(BNSymbolReplaceTiming.magicReplace == 2.0 / 3.0)
        #expect(BNSymbolReplaceTiming.replace == 0.5)
    }
}
