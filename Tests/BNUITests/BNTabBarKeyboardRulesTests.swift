@testable import BNUITabBar
import CoreGraphics
import Testing

@Suite("BNTabBarKeyboardRules")
struct BNTabBarKeyboardRulesTests {
    @Test
    func `a keyboard with a frame to stand in hides the bar`() {
        let frame = CGRect(x: 0, y: 391, width: 951, height: 278)
        #expect(BNTabBarKeyboardRules.hidesBar(keyboardEndFrame: frame))
    }

    @Test
    func `a keyboard with no height leaves the bar where it is`() {
        // What an open iPhone Duo reports as it turns, once the keyboard has been up: the bottom
        // edge of the screen, nothing high, and no `keyboardWillHide` after it.
        let frame = CGRect(x: 0, y: 951, width: 669, height: 0)
        #expect(!BNTabBarKeyboardRules.hidesBar(keyboardEndFrame: frame))
    }

    @Test
    func `a notification that names no frame is taken at its word`() {
        #expect(BNTabBarKeyboardRules.hidesBar(keyboardEndFrame: nil))
    }
}
