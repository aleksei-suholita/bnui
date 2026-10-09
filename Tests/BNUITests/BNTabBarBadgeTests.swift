@testable import BNUITabBar
import Foundation
import Testing

@Suite("BNTabBarBadge")
struct BNTabBarBadgeTests {
    private let english = Locale(identifier: "en_US")

    @Test
    func `a count of zero or less draws nothing`() {
        #expect(BNTabBarBadge.count(0).appearance(countLimit: 99, locale: english) == nil)
        #expect(BNTabBarBadge.count(-3).appearance(countLimit: 99, locale: english) == nil)
    }

    @Test
    func `a count up to the limit reads as is`() {
        #expect(BNTabBarBadge.count(7).appearance(countLimit: 99, locale: english) == .text("7"))
        #expect(BNTabBarBadge.count(99).appearance(countLimit: 99, locale: english) == .text("99"))
    }

    @Test
    func `a count past the limit reads as the limit and a plus`() {
        #expect(BNTabBarBadge.count(100).appearance(countLimit: 99, locale: english) == .text("99+"))
        #expect(BNTabBarBadge.count(12).appearance(countLimit: 9, locale: english) == .text("9+"))
    }

    @Test
    func `a count is written in the user's digits`() {
        #expect(BNTabBarBadge.count(5).appearance(countLimit: 99, locale: Locale(identifier: "fa_IR")) == .text("۵"))
    }

    @Test
    func `an empty text draws nothing`() {
        #expect(BNTabBarBadge.text("").appearance(countLimit: 99) == nil)
        #expect(BNTabBarBadge.text("New").appearance(countLimit: 99) == .text("New"))
    }

    @Test
    func `a dot draws a dot`() {
        #expect(BNTabBarBadge.dot(accessibilityLabel: "New posts").appearance(countLimit: 99) == .dot)
    }

    @Test
    func `the host's words are spoken over what is shown`() {
        let labelled = BNTabBarBadge.count(3, accessibilityLabel: "3 unread")
        #expect(labelled.spokenText(countLimit: 99, locale: english) == "3 unread")
        #expect(BNTabBarBadge.count(3).spokenText(countLimit: 99, locale: english) == "3")
        #expect(BNTabBarBadge.text("New").spokenText(countLimit: 99) == "New")
        #expect(BNTabBarBadge.dot(accessibilityLabel: "New posts").spokenText(countLimit: 99) == "New posts")
    }

    @Test
    func `a badge that draws nothing says nothing`() {
        // A label must not speak for a badge that is not on screen.
        #expect(BNTabBarBadge.count(0, accessibilityLabel: "none unread").spokenText(countLimit: 99) == nil)
    }

    @Test
    func `a menu shows what the badge shows, and a dot by its words`() {
        #expect(BNTabBarBadge.count(120).menuText(countLimit: 99, locale: english) == "99+")
        #expect(BNTabBarBadge.count(3, accessibilityLabel: "3 unread").menuText(countLimit: 99, locale: english) == "3")
        #expect(BNTabBarBadge.dot(accessibilityLabel: "New posts").menuText(countLimit: 99) == "New posts")
        #expect(BNTabBarBadge.count(0).menuText(countLimit: 99) == nil)
    }
}
