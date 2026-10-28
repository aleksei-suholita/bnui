@testable import BNUITabBar
import CoreGraphics
import Testing

@Suite("BNTabBarControllerRules")
struct BNTabBarControllerRulesTests {
    // MARK: - Insets

    @Test
    func `a tab reaches the bar's top from what it inherits`() {
        // The system's place on iOS 26: 21 pt off the edge and a 62 pt bar — 83 pt — over a
        // 34 pt home indicator.
        #expect(BNTabBarControllerRules.bottomInset(barTop: 83, inherited: 34, hidesBar: false) == 49)
    }

    @Test
    func `a hidden bar adds nothing`() {
        #expect(BNTabBarControllerRules.bottomInset(barTop: 83, inherited: 34, hidesBar: true) == 0)
    }

    @Test
    func `a tab that inherits more than the bar takes adds nothing`() {
        #expect(BNTabBarControllerRules.bottomInset(barTop: 83, inherited: 300, hidesBar: false) == 0)
    }

    // MARK: - Tabs changing

    @Test
    func `the tab on screen stays when it is still among the tabs`() {
        #expect(BNTabBarControllerRules.selection(keeping: "games", in: ["home", "games", "profile"]) == "games")
    }

    @Test
    func `the first tab takes the place of one that is gone`() {
        #expect(BNTabBarControllerRules.selection(keeping: "games", in: ["home", "profile"]) == "home")
    }

    @Test
    func `no tabs select nothing`() {
        #expect(BNTabBarControllerRules.selection(keeping: "home", in: []) == nil)
    }
}
