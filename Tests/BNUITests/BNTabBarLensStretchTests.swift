@testable import BNUITabBar
import CoreGraphics
import Testing

@Suite("BNTabBarLensStretch")
struct BNTabBarLensStretchTests {
    /// Glass under 120 pt, held at its centre.
    private let size = CGSize(width: 80, height: 54)
    private let start = CGPoint(x: 40, y: 27)

    private func isClose(_ value: CGFloat, _ expected: CGFloat) -> Bool {
        abs(value - expected) < 1e-9
    }

    @Test
    func `a finger where it landed does not pull`() {
        #expect(BNTabBarLensStretch.glass(touch: start, start: start, size: size) == .none)
    }

    @Test
    func `a finger on the glass barely moves it`() {
        // 20 pt inside: a quarter of the stretch the same travel would give past the edge.
        let stretch = BNTabBarLensStretch.glass(touch: CGPoint(x: 60, y: 27), start: start, size: size)
        #expect(isClose(stretch.scale.dx, 20.0 / 8000))
        #expect(isClose(stretch.scale.dy, -20.0 / 8000))
    }

    @Test
    func `a finger past the trailing edge stretches it along and squeezes it across`() {
        // 40 pt to the edge, 100 pt past it.
        let stretch = BNTabBarLensStretch.glass(touch: CGPoint(x: 180, y: 27), start: start, size: size)
        let pull = 100.0 / 2000 + 40.0 / 8000
        #expect(isClose(stretch.scale.dx, pull))
        #expect(isClose(stretch.scale.dy, -pull))
        #expect(isClose(stretch.offset.dx, pull * 80))
        #expect(stretch.offset.dy == 0)
    }

    @Test
    func `the centre moves toward the finger on either side`() {
        let leading = BNTabBarLensStretch.glass(touch: CGPoint(x: -100, y: 27), start: start, size: size)
        let trailing = BNTabBarLensStretch.glass(touch: CGPoint(x: 180, y: 27), start: start, size: size)
        #expect(isClose(leading.scale.dx, trailing.scale.dx))
        #expect(isClose(leading.offset.dx, -trailing.offset.dx))
        #expect(leading.offset.dx < 0)
    }

    @Test
    func `a finger above the glass stretches it up`() {
        // 27 pt to the top edge, 73 pt past it.
        let stretch = BNTabBarLensStretch.glass(touch: CGPoint(x: 40, y: -73), start: start, size: size)
        let pull = 73.0 / 2000 + 27.0 / 8000
        #expect(isClose(stretch.scale.dy, pull))
        #expect(isClose(stretch.scale.dx, -pull))
        #expect(isClose(stretch.offset.dy, -pull * 54))
    }

    @Test
    func `the stretch grows with the finger and has no ceiling`() {
        let near = BNTabBarLensStretch.glass(touch: CGPoint(x: 180, y: 27), start: start, size: size)
        let far = BNTabBarLensStretch.glass(touch: CGPoint(x: 1080, y: 27), start: start, size: size)
        #expect(isClose(far.scale.dx - near.scale.dx, 900.0 / 2000))
    }

    @Test
    func `larger glass stretches less`() {
        #expect(BNTabBarLensStretch.glassDistance(for: CGSize(width: 80, height: 54)) == 2000)
        #expect(BNTabBarLensStretch.glassDistance(for: CGSize(width: 119, height: 100)) == 2000)
        #expect(BNTabBarLensStretch.glassDistance(for: CGSize(width: 120, height: 44)) == 6000)
        #expect(BNTabBarLensStretch.glassDistance(for: CGSize(width: 300, height: 102)) == 15000)
        #expect(BNTabBarLensStretch.glassDistance(for: CGSize(width: 300, height: 200)) == 24000)
    }

    @Test
    func `strength scales the stretch and zero turns it off`() {
        let stretch = BNTabBarLensStretch.glass(touch: CGPoint(x: 180, y: -20), start: start, size: size)
        #expect(stretch.scaled(by: 0) == .none)
        let doubled = stretch.scaled(by: 2)
        #expect(isClose(doubled.scale.dx, stretch.scale.dx * 2))
        #expect(isClose(doubled.offset.dy, stretch.offset.dy * 2))
    }

    @Test
    func `glass under the lens follows the finger on its size's spring`() {
        let small = BNTabBarStretchMotion.Spring.glassTracking(for: CGSize(width: 80, height: 54))
        #expect(small == .init(dampingRatio: 0.625, response: 0.262))
        let capsule = BNTabBarStretchMotion.Spring.glassTracking(for: CGSize(width: 140, height: 62))
        #expect(isClose(capsule.response, 0.262 + 0.052 * (96.0 / 116)))
        let wide = BNTabBarStretchMotion.Spring.glassTracking(for: CGSize(width: 370, height: 62))
        #expect(wide == .init(dampingRatio: 0.625, response: 0.314))
    }

    @Test
    func `the stretch follows the pull on its spring and settles on it`() {
        let pull = BNTabBarLensStretch.glass(touch: CGPoint(x: 180, y: 27), start: start, size: size)
        let spring = BNTabBarStretchMotion.Spring.glassTracking(for: size)
        var motion = BNTabBarStretchMotion()
        motion.advance(toward: pull, on: spring, by: 1.0 / 60)
        // Under way after a frame, nowhere near arrived.
        #expect(motion.value.scale.dx > 0)
        #expect(motion.value.scale.dx < pull.scale.dx / 2)
        #expect(!motion.isSettled(at: pull))
        motion.advance(toward: pull, on: spring, by: 3)
        #expect(motion.isSettled(at: pull))
        motion.settle(at: pull)
        #expect(motion.value == pull)
    }

    @Test
    func `no time moves nothing`() {
        var motion = BNTabBarStretchMotion()
        let pull = BNTabBarLensStretch(scale: CGVector(dx: 0.1, dy: -0.1), offset: CGVector(dx: 8, dy: 0))
        motion.advance(toward: pull, on: .init(dampingRatio: 0.625, response: 0.262), by: 0)
        #expect(motion.value == .none)
        #expect(motion.isSettled(at: .none))
    }
}
