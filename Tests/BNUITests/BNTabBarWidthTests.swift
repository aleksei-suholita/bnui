@testable import BNUITabBar
import CoreGraphics
import Testing

/// When the sections share all the room the bar has rather than stopping at their preferred width:
/// a bar set to fill does so whatever stands beside it; one that hugs fills only beside an action,
/// from the theme's count of sections on.
@Suite("BNTabBarLayoutSolver — filling the width")
struct BNTabBarWidthTests {
    @Test(arguments: [false, true], [2, 3, 6])
    func `a bar set to fill fills with an action or without one`(hasAction: Bool, sections: Int) {
        #expect(BNTabBarLayoutSolver.fillsAvailableWidth(
            fillsWidth: true,
            hasAction: hasAction,
            sectionCount: sections,
            fillFromSectionCount: 3,
        ))
    }

    @Test
    func `a hugging bar without an action hugs`() {
        #expect(!BNTabBarLayoutSolver.fillsAvailableWidth(
            fillsWidth: false,
            hasAction: false,
            sectionCount: 6,
            fillFromSectionCount: 3,
        ))
    }

    @Test
    func `a hugging bar beside an action fills from the theme's count on`() {
        let fills = { (sections: Int) in
            BNTabBarLayoutSolver.fillsAvailableWidth(
                fillsWidth: false,
                hasAction: true,
                sectionCount: sections,
                fillFromSectionCount: 3,
            )
        }
        #expect(!fills(2))
        #expect(fills(3))
    }

    @Test
    func `filling shares the room equally up to the bar's limit`() {
        let output = BNTabBarLayoutSolver.solve(BNTabBarLayoutSolver.Input(
            availableWidth: 348,
            items: Array(repeating: BNTabBarLayoutSolver.ItemMeasure(labelWidth: 30, iconWidth: 20, inset: 6), count: 2),
            itemSpacing: 0,
            capsulePadding: 4,
            preferredItemWidth: 80,
            minimumItemWidth: 44,
            minimumLabelScale: 0.8,
            maxBarWidth: 500,
            fillsAvailableWidth: true,
        ))
        #expect(output.itemWidths == [170, 170])
        #expect(output.barWidth == 348)
    }
}
