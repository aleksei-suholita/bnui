@testable import BNUITabBar
import CoreGraphics
import Testing

@Suite("BNTabBarMotion")
struct BNTabBarMotionTests {
    @Test
    func `reduce motion removes every overshoot`() {
        let reduced = BNTabBarMotion.standard.resolved(reduceMotion: true)
        #expect(reduced.selection.bounce == 0)
        #expect(reduced.lift.bounce == 0)
        #expect(reduced.unlift.bounce == 0)
        #expect(reduced.itemAccent.bounce == 0)
    }

    @Test
    func `reduce motion shortens every duration`() {
        let standard = BNTabBarMotion.standard
        let reduced = standard.resolved(reduceMotion: true)
        #expect(reduced.selection.duration < standard.selection.duration)
        #expect(reduced.lift.duration < standard.lift.duration)
        #expect(reduced.unlift.duration < standard.unlift.duration)
        #expect(reduced.visibility.duration < standard.visibility.duration)
    }

    @Test
    func `the lens reaches the finger faster than it settles`() {
        // The system's asymmetry: a quick rise under the finger, a slow settle after it.
        let standard = BNTabBarMotion.standard
        #expect(standard.lift.duration < standard.unlift.duration)
    }

    @Test
    func `motion is untouched when reduce motion is off`() {
        #expect(BNTabBarMotion.standard.resolved(reduceMotion: false) == BNTabBarMotion.standard)
    }

    @Test
    func `reduce motion still moves the lens`() {
        // Movement survives: the lens travelling is navigation, not decoration.
        let reduced = BNTabBarMotion.reduced
        #expect(reduced.selection.duration > 0)
    }

    @Test
    func `visibility keeps its authored curve`() {
        guard case let .controlPoints(x1, y1, x2, y2) = BNTabBarMotion.standard.visibility.timing else {
            Issue.record("visibility should use control points")
            return
        }
        #expect(x1 == 0.33)
        #expect(y1 == 0.52)
        #expect(x2 == 0.25)
        #expect(y2 == 0.99)
    }
}

@Suite("BNTabBarMetrics")
struct BNTabBarMetricsTests {
    @Test
    func `a theme cannot shrink the touch target`() {
        var metrics = BNTabBarMetrics.standard
        metrics.itemHeight = 10
        metrics.minimumItemWidth = 10
        #expect(metrics.effectiveItemHeight == BNTabBarMetrics.minimumTouchTarget)
        #expect(metrics.effectiveMinimumItemWidth == BNTabBarMetrics.minimumTouchTarget)
    }

    @Test
    func `generous values pass through untouched`() {
        var metrics = BNTabBarMetrics.standard
        metrics.itemHeight = 60
        metrics.minimumItemWidth = 72
        #expect(metrics.effectiveItemHeight == 60)
        #expect(metrics.effectiveMinimumItemWidth == 72)
    }
}
