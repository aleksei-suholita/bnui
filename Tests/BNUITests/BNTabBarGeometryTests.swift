@testable import BNUITabBar
import CoreGraphics
import Testing

@Suite("BNTabBarGeometry")
struct BNTabBarGeometryTests {
    private let centers: [CGFloat] = [50, 150, 250]

    @Test
    func `picks the section under the finger`() {
        #expect(BNTabBarGeometry.nearestIndex(toX: 48, in: centers) == 0)
        #expect(BNTabBarGeometry.nearestIndex(toX: 140, in: centers) == 1)
        #expect(BNTabBarGeometry.nearestIndex(toX: 260, in: centers) == 2)
    }

    @Test
    func `a finger past the edge still resolves to the closest section`() {
        // No cancel-by-leaving: releasing outside still commits the nearest section.
        #expect(BNTabBarGeometry.nearestIndex(toX: -400, in: centers) == 0)
        #expect(BNTabBarGeometry.nearestIndex(toX: 9999, in: centers) == 2)
    }

    @Test
    func `exact midpoint resolves without ambiguity`() {
        // 100 is equidistant from 50 and 150 — the earlier section wins, deterministically.
        #expect(BNTabBarGeometry.nearestIndex(toX: 100, in: centers) == 0)
    }

    @Test
    func `no sections means nothing to select`() {
        #expect(BNTabBarGeometry.nearestIndex(toX: 10, in: []) == nil)
    }

    @Test
    func `lens stays inside the bar`() {
        #expect(BNTabBarGeometry.clampedLensOriginX(-30, lensWidth: 80, barWidth: 300) == 0)
        #expect(BNTabBarGeometry.clampedLensOriginX(500, lensWidth: 80, barWidth: 300) == 220)
        #expect(BNTabBarGeometry.clampedLensOriginX(120, lensWidth: 80, barWidth: 300) == 120)
    }

    @Test
    func `a lens wider than the bar pins to the leading edge`() {
        #expect(BNTabBarGeometry.clampedLensOriginX(40, lensWidth: 400, barWidth: 300) == 0)
    }
}
