@testable import BNUITabBar
import Testing

@Suite("BNTabBarPresentation")
struct BNTabBarPresentationTests {
    @Test
    func `only the hidden bar reports itself hidden`() {
        // A hidden bar reports zero effective height, and the host drops its inset on this flag.
        #expect(BNTabBarPresentation.hidden.isHidden)
        #expect(!BNTabBarPresentation.expanded.isHidden)
    }
}
