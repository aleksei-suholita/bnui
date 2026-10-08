@testable import BNUIButton
@testable import BNUICore
import CoreGraphics
import Testing

@Suite("BNButtonMetrics")
struct BNButtonMetricsTests {
    @Test
    func `a theme cannot shrink the touch target`() {
        // An icon button drawn at 24 pt is still touched at 44 — the whole point of keeping the
        // visual size and the touch size apart.
        let outsets = BNButtonMetrics.standard.hitOutsets(forVisualSize: CGSize(width: 24, height: 24))
        #expect(24 + outsets.leading + outsets.trailing == BNButtonMetrics.minimumTouchTarget)
        #expect(24 + outsets.top + outsets.bottom == BNButtonMetrics.minimumTouchTarget)
    }

    @Test
    func `a generous visual size gets no outsets`() {
        let outsets = BNButtonMetrics.standard.hitOutsets(forVisualSize: CGSize(width: 120, height: 56))
        #expect(outsets.isZero)
    }

    @Test
    func `a wide but short button is only grown vertically`() {
        let outsets = BNButtonMetrics.standard.hitOutsets(forVisualSize: CGSize(width: 200, height: 32))
        #expect(outsets.leading == 0)
        #expect(outsets.trailing == 0)
        #expect(outsets.top == 6)
        #expect(outsets.bottom == 6)
    }

    @Test
    func `the loading indicator always fits the minimum width`() {
        // A theme that asks for a 10 pt button with a 20 pt spinner would jolt its width the
        // moment it started loading. It does not get to.
        var size = BNButtonSize.medium
        size.minWidth = 10
        size.indicatorSide = 20
        size.horizontalPadding = 12
        #expect(size.effectiveMinWidth == 44)
    }

    @Test
    func `a generous minimum width passes through untouched`() {
        var size = BNButtonSize.medium
        size.minWidth = 200
        #expect(size.effectiveMinWidth == 200)
    }

    @Test
    func `reduce motion removes the press scale`() {
        #expect(BNButtonMetrics.standard.resolved(reduceMotion: true).pressedScale == 1)
        #expect(BNButtonMetrics.standard.resolved(reduceMotion: false).pressedScale < 1)
    }

    @Test
    func `a capsule follows the height it ends up with`() {
        // Dynamic Type grows the button; a capsule that kept a baked radius would stop being one.
        #expect(BNShape.capsule.cornerRadius(forHeight: 44) == 22)
        #expect(BNShape.capsule.cornerRadius(forHeight: 80) == 40)
        #expect(BNShape.rounded(radius: 12).cornerRadius(forHeight: 80) == 12)
    }
}
