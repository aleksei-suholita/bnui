@testable import BNUIButton
import CoreGraphics
import Testing

/// An icon beside a title, or beside another icon: the size's height holds whatever the icon's own
/// size, as it does for a lone icon. An 80 pt asset shrinks instead of growing the button to a
/// hundred points.
@Suite("BNButtonLayoutSolver — icon beside a title")
struct BNButtonIconBesideTitleLayoutTests {
    private func solve(
        iconWidths: [CGFloat],
        iconHeight: CGFloat,
        titleWidth: CGFloat = 60,
        titleHeight: CGFloat = 22,
        size: BNButtonSize = .medium,
        isAccessibilitySize: Bool = false,
    ) -> BNButtonLayoutSolver.Output {
        BNButtonLayoutSolver.solve(BNButtonLayoutSolver.Input(
            availableWidth: 320,
            titleWidth: titleWidth,
            titleHeight: titleHeight,
            iconWidths: iconWidths,
            iconHeight: iconHeight,
            size: size,
            isAccessibilitySize: isAccessibilitySize,
        ))
    }

    /// What one line holds in the size: its height less the vertical padding.
    private func room(_ size: BNButtonSize) -> CGFloat {
        size.height - 2 * size.verticalPadding
    }

    @Test(arguments: [BNButtonSize.small, .medium, .large])
    func `an oversized icon beside a title leaves the height to the size`(size: BNButtonSize) {
        // A title one line of the smallest size holds, so only the icon could grow the button.
        let output = solve(iconWidths: [80], iconHeight: 80, titleHeight: 18, size: size)
        #expect(output.buttonHeight == size.height)
        #expect(output.iconScale == room(size) / 80)
    }

    @Test
    func `the width is made of the shrunk icon`() {
        let output = solve(iconWidths: [80], iconHeight: 80)
        let expected = 80 * output.iconScale + BNButtonSize.medium.iconSpacing + 60
        #expect(abs(output.contentWidth - expected) < 0.001)
    }

    @Test
    func `an icon that fits keeps its size`() {
        let output = solve(iconWidths: [22], iconHeight: 22)
        #expect(output.iconScale == 1)
        #expect(output.buttonHeight == BNButtonSize.medium.height)
    }

    @Test
    func `two icons without a title shrink together by the taller`() {
        let output = solve(iconWidths: [80, 19], iconHeight: 80, titleWidth: 0, titleHeight: 0)
        #expect(output.buttonHeight == BNButtonSize.medium.height)
        #expect(output.iconScale == room(.medium) / 80)
    }

    @Test
    func `a title grown by Dynamic Type still grows the button`() {
        // The text is what the height gives way to; the icon keeps the size's limit beside it.
        let output = solve(iconWidths: [80], iconHeight: 80, titleHeight: 60)
        #expect(output.buttonHeight == 60 + 2 * BNButtonSize.medium.verticalPadding)
        #expect(output.iconScale == room(.medium) / 80)
    }

    @Test
    func `stacked at accessibility sizes the icon keeps the same limit`() {
        let size = BNButtonSize.medium
        let output = solve(iconWidths: [80], iconHeight: 80, titleWidth: 400, titleHeight: 40, isAccessibilitySize: true)
        #expect(output.axis == .vertical)
        let expected = 80 * output.iconScale + size.iconSpacing + 40 + 2 * size.verticalPadding
        #expect(abs(output.buttonHeight - expected) < 0.001)
    }
}
