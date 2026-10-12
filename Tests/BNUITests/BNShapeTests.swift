@testable import BNUIButton
@testable import BNUICore
import CoreGraphics
import Testing

@Suite("BNShape")
struct BNShapeTests {
    @Test
    func `a capsule stops rounding at its limit`() {
        // Four lines of title make the button about a hundred points tall; ends rounding at 50
        // would cut into the first and the last line.
        #expect(BNShape.capsule.cornerRadius(forHeight: 104, maximumRadius: 22) == 22)
        #expect(BNShape.capsule.cornerRadius(forHeight: 30, maximumRadius: 22) == 15)
    }

    @Test
    func `no limit leaves a capsule following its height`() {
        #expect(BNShape.capsule.cornerRadius(forHeight: 104) == 52)
    }

    @Test
    func `a fixed radius is never rounder than the limit either`() {
        #expect(BNShape.rounded(radius: 12).cornerRadius(forHeight: 104, maximumRadius: 22) == 12)
        #expect(BNShape.rounded(radius: 30).cornerRadius(forHeight: 104, maximumRadius: 22) == 22)
    }

    @Test(arguments: [BNButtonSize.small, .medium, .large])
    func `a size step rounds no further than it does on one line`(size: BNButtonSize) {
        #expect(size.maximumCornerRadius == size.height / 2)
        var rounded = size
        rounded.shape = .rounded(radius: 12)
        #expect(rounded.maximumCornerRadius == 12)
    }
}

@Suite("BNShape corner inset")
struct BNShapeCornerInsetTests {
    @Test
    func `a circle's inset lands on its rim at 45 degrees`() {
        // A 44 pt circle: the rim at 45° is 22 − 22·cos 45° in from the top and from the side.
        let inset = BNShape.capsule.cornerInset(forHeight: 44)
        let point = CGPoint(x: 44 - inset, y: inset)
        let distance = ((point.x - 22) * (point.x - 22) + (point.y - 22) * (point.y - 22)).squareRoot()
        #expect(abs(distance - 22) < 0.0001)
    }

    @Test
    func `square corners leave the badge on the corner itself`() {
        #expect(BNShape.rounded(radius: 0).cornerInset(forHeight: 44) == 0)
    }

    @Test
    func `the inset follows the radius the shape is drawn with`() {
        let limited = BNShape.capsule.cornerInset(forHeight: 104, maximumRadius: 22)
        #expect(limited == BNShape.rounded(radius: 22).cornerInset(forHeight: 104))
    }
}
