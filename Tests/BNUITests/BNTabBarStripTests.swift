@testable import BNUITabBar
import CoreGraphics
import Testing

@Suite("BNTabBarStrip")
struct BNTabBarStripTests {
    /// An outer display in portrait: an 84 pt strip on the right, the home indicator below.
    private let bounds = CGRect(x: 0, y: 0, width: 466, height: 678)

    private func column(
        side: BNTabBarStrip.Side = .right,
        width: CGFloat = 84,
        reserved: [CGRect] = [],
        minimumLength: CGFloat = 200,
    ) -> CGRect? {
        BNTabBarStrip(side: side, width: width, reserved: reserved)
            .column(in: bounds, top: 0, bottom: 34, thickness: 64, minimumLength: minimumLength)
    }

    @Test
    func `an empty strip gives the bar its whole length above the home indicator`() {
        #expect(column() == CGRect(x: 382, y: 0, width: 84, height: 644))
    }

    @Test
    func `the strip on the left starts at the left edge`() {
        #expect(column(side: .left)?.minX == 0)
    }

    @Test
    func `a strip narrower than the bar holds no bar`() {
        #expect(column(width: 60) == nil)
    }

    @Test
    func `the status bar above shortens the stretch`() {
        let statusBar = CGRect(x: 382, y: 0, width: 84, height: 170)
        #expect(column(reserved: [statusBar]) == CGRect(x: 382, y: 170, width: 84, height: 474))
    }

    @Test
    func `the bar keeps a gap from what is reserved`() {
        let buttons = CGRect(x: 382, y: 170, width: 84, height: 100)
        let strip = BNTabBarStrip(side: .right, width: 84, reserved: [buttons])
        let column = strip.column(in: bounds, top: 0, bottom: 34, thickness: 64, minimumLength: 200, gap: 8)
        #expect(column == CGRect(x: 382, y: 278, width: 84, height: 366))
    }

    @Test
    func `the bar keeps to the stretch below the camera, never the one above it`() {
        // The camera half way down the strip, as on the outer display in landscape.
        let camera = CGRect(x: 382, y: 300, width: 84, height: 120)
        #expect(column(reserved: [camera]) == CGRect(x: 382, y: 420, width: 84, height: 224))
        // Too short below the camera: the bar does not climb over it.
        #expect(column(reserved: [camera], minimumLength: 300) == nil)
    }

    @Test
    func `something on the bottom of the strip lifts the stretch above it`() {
        let low = CGRect(x: 382, y: 560, width: 84, height: 100)
        let lower = CGRect(x: 382, y: 520, width: 84, height: 60)
        #expect(column(reserved: [lower, low]) == CGRect(x: 382, y: 0, width: 84, height: 520))
    }

    @Test
    func `a fold with no width still divides the strip`() {
        let fold = CGRect(x: 382, y: 339, width: 84, height: 0)
        #expect(column(reserved: [fold]) == CGRect(x: 382, y: 339, width: 84, height: 305))
        let crossing = CGRect(x: 424, y: 0, width: 0, height: 678)
        #expect(column(reserved: [crossing]) == nil)
    }

    @Test
    func `what lies outside the strip is ignored`() {
        let content = CGRect(x: 0, y: 300, width: 300, height: 120)
        #expect(column(reserved: [content]) == CGRect(x: 382, y: 0, width: 84, height: 644))
    }

    @Test
    func `no room between the insets means no bar`() {
        let strip = BNTabBarStrip(side: .right, width: 84, reserved: [])
        #expect(strip.column(in: bounds, top: 400, bottom: 300, thickness: 64, minimumLength: 1) == nil)
    }
}
