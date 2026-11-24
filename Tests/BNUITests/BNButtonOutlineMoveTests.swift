@testable import BNUIButton
import BNUICore
import CoreGraphics
import Testing

@Suite("BNButtonOutlineMove")
struct BNButtonOutlineMoveTests {
    private let move = BNButtonOutlineMove(
        size: CGSize(width: 140, height: 44),
        centreInWindow: CGPoint(x: 200, y: 400),
        transition: .spring(BNSpring(duration: 0.4, bounce: 0.12)),
        deadline: 10,
    )

    @Test
    func `a pass that keeps the old size waits for the host`() {
        #expect(!move.isDue(forSize: CGSize(width: 140, height: 44)))
    }

    @Test
    func `a pass with a new width or height brings the frame`() {
        #expect(move.isDue(forSize: CGSize(width: 90, height: 44)))
        #expect(move.isDue(forSize: CGSize(width: 140, height: 64)))
    }

    @Test
    func `a frame that comes after the change has settled is not followed`() {
        #expect(!move.hasExpired(at: 10))
        #expect(move.hasExpired(at: 10.01))
    }

    @Test
    func `a button that jumped to its frame starts the outline where it stood on screen`() {
        let converted = CGPoint(x: 95, y: 22)
        #expect(move.startCentre(converted: converted, isCarried: false) == converted)
    }

    @Test
    func `a button carried to its frame is still drawn where it stood`() {
        #expect(move.startCentre(converted: CGPoint(x: 95, y: 22), isCarried: true) == CGPoint(x: 70, y: 22))
    }

    @Test
    func `nothing is owed until a change asks`() {
        let pending = BNButtonPendingLayout()
        #expect(!pending.naturalWidth)
        #expect(!pending.afterRebuild)
        #expect(pending.outlineMove == nil)
    }
}
