@testable import BNUITabBar
import Testing

@Suite("BNTabBarValueIDs")
struct BNTabBarValueIDsTests {
    private enum Section { case home, stats, settings }

    @Test
    func `an id is the value's own description`() {
        let ids = BNTabBarValueIDs([Section.home, .stats])
        #expect(ids.ids == ["home", "stats"])
    }

    @Test
    func `an id stays put when a tab is added beside it`() {
        // Ids by position would shift and make the bar redraw every section after the new one.
        let before = BNTabBarValueIDs([Section.home, .settings])
        let after = BNTabBarValueIDs([Section.home, .stats, .settings])
        #expect(before.id(for: .settings) == after.id(for: .settings))
    }

    @Test
    func `values that describe themselves alike get a number`() {
        struct Plain: Hashable, CustomStringConvertible {
            let key: Int
            var description: String {
                "tab"
            }
        }
        let ids = BNTabBarValueIDs([Plain(key: 1), Plain(key: 2), Plain(key: 3)])
        #expect(ids.ids == ["tab", "tab 2", "tab 3"])
    }

    @Test
    func `a reserved id is never handed out`() {
        let ids = BNTabBarValueIDs(["BNTabBar.more", "home"], reserving: ["BNTabBar.more"])
        #expect(ids.ids == ["BNTabBar.more 2", "home"])
    }

    @Test
    func `a value and its id lead back to each other`() {
        let ids = BNTabBarValueIDs([Section.home, .stats, .settings])
        for value in [Section.home, .stats, .settings] {
            let id = ids.id(for: value)
            #expect(id.flatMap(ids.value(for:)) == value)
        }
    }

    @Test
    func `an unknown value or id leads nowhere`() {
        let ids = BNTabBarValueIDs([Section.home])
        #expect(ids.id(for: .stats) == nil)
        #expect(ids.value(for: "stats") == nil)
    }
}
