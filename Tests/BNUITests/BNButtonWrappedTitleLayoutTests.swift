@testable import BNUIButton
import CoreGraphics
import Testing

/// A title that wraps: the first line stays where one line sits, and the rest add their height.
@Suite("BNButtonLayoutSolver — wrapped title")
struct BNButtonWrappedTitleLayoutTests {
    private let line: CGFloat = 20

    private func solve(
        lines: Int,
        iconHeight: CGFloat = 0,
        size: BNButtonSize = .medium,
        isAccessibilitySize: Bool = false,
    ) -> BNButtonLayoutSolver.Output {
        BNButtonLayoutSolver.solve(BNButtonLayoutSolver.Input(
            availableWidth: 200,
            titleWidth: 160,
            titleHeight: line * CGFloat(lines),
            titleLineHeight: line,
            iconWidths: iconHeight > 0 ? [iconHeight] : [],
            iconHeight: iconHeight,
            size: size,
            titleBehavior: .wrap(lines: 0),
            isAccessibilitySize: isAccessibilitySize,
        ))
    }

    @Test(arguments: [BNButtonSize.small, .medium, .large])
    func `every line past the first adds exactly its own height`(size: BNButtonSize) {
        for lines in 1 ... 4 {
            #expect(solve(lines: lines, size: size).buttonHeight == size.height + line * CGFloat(lines - 1))
        }
    }

    @Test
    func `the first line keeps the room one line has in the height`() {
        // The plain padding is 8 at medium; a single line already sits 12 from the top, and
        // dropping to 8 the moment a second line arrives is what made the first one jump.
        let output = solve(lines: 3)
        #expect(output.contentInsets.top == (BNButtonSize.medium.height - line) / 2)
        #expect(output.contentInsets.top > BNButtonSize.medium.verticalPadding)
    }

    @Test
    func `an icon taller than a line leaves one line at the size height`() {
        #expect(solve(lines: 1, iconHeight: 24).buttonHeight == BNButtonSize.medium.height)
    }

    @Test
    func `type too large for the size falls back to the vertical padding`() {
        var size = BNButtonSize.medium
        size.height = line + 2
        let output = solve(lines: 2, size: size)
        #expect(output.contentInsets.top == size.verticalPadding)
        #expect(output.buttonHeight == 2 * line + 2 * size.verticalPadding)
    }

    @Test
    func `a stack keeps the plain padding`() {
        // Icon over title has no single line to hold in place.
        let output = BNButtonLayoutSolver.solve(BNButtonLayoutSolver.Input(
            availableWidth: 120,
            titleWidth: 200,
            titleHeight: 40,
            iconWidths: [28],
            iconHeight: 28,
            isAccessibilitySize: true,
        ))
        #expect(output.axis == .vertical)
        #expect(output.contentInsets.top == BNButtonSize.medium.verticalPadding)
    }
}
