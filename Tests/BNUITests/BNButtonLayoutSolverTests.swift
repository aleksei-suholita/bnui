@testable import BNUIButton
import CoreGraphics
import Testing

@Suite("BNButtonLayoutSolver")
struct BNButtonLayoutSolverTests {
    private func makeInput(
        availableWidth: CGFloat = 320,
        titleWidth: CGFloat = 120,
        titleHeight: CGFloat = 20,
        iconWidths: [CGFloat] = [],
        iconHeight: CGFloat = 0,
        size: BNButtonSize = .medium,
        width: BNButtonWidth = .hug,
        titleBehavior: BNButtonConfiguration.TitleBehavior = .truncate,
        isAccessibilitySize: Bool = false,
        allowsVerticalStack: Bool = true,
    ) -> BNButtonLayoutSolver.Input {
        BNButtonLayoutSolver.Input(
            availableWidth: availableWidth,
            titleWidth: titleWidth,
            titleHeight: titleHeight,
            iconWidths: iconWidths,
            iconHeight: iconHeight,
            size: size,
            width: width,
            titleBehavior: titleBehavior,
            isAccessibilitySize: isAccessibilitySize,
            allowsVerticalStack: allowsVerticalStack,
        )
    }

    @Test
    func `content stays horizontal at standard text sizes`() {
        let output = BNButtonLayoutSolver.solve(makeInput(iconWidths: [20], iconHeight: 20))
        #expect(output.axis == .horizontal)
    }

    @Test
    func `an icon and a title stack once they overflow at accessibility sizes`() {
        let output = BNButtonLayoutSolver.solve(makeInput(
            availableWidth: 200,
            titleWidth: 200,
            titleHeight: 40,
            iconWidths: [28],
            iconHeight: 28,
            isAccessibilitySize: true,
        ))
        #expect(output.axis == .vertical)
        // Stacked content is as wide as its widest piece, not the sum.
        #expect(output.contentWidth <= 200)
    }

    @Test
    func `an icon and a title that still fit do not stack`() {
        let output = BNButtonLayoutSolver.solve(makeInput(
            availableWidth: 400,
            titleWidth: 120,
            iconWidths: [28],
            iconHeight: 28,
            isAccessibilitySize: true,
        ))
        #expect(output.axis == .horizontal)
    }

    @Test
    func `a lone title never stacks`() {
        // Stacking one item has nothing to stack — a long title wraps or truncates instead.
        let output = BNButtonLayoutSolver.solve(makeInput(
            availableWidth: 100,
            titleWidth: 400,
            isAccessibilitySize: true,
        ))
        #expect(output.axis == .horizontal)
    }

    @Test
    func `a host that forbids stacking gets none`() {
        let output = BNButtonLayoutSolver.solve(makeInput(
            availableWidth: 100,
            titleWidth: 300,
            iconWidths: [28],
            iconHeight: 28,
            isAccessibilitySize: true,
            allowsVerticalStack: false,
        ))
        #expect(output.axis == .horizontal)
    }

    @Test
    func `truncate keeps one line and wrap keeps the configured count`() {
        #expect(BNButtonLayoutSolver.solve(makeInput(titleBehavior: .truncate)).numberOfLines == 1)
        #expect(BNButtonLayoutSolver.solve(makeInput(titleBehavior: .wrap(lines: 3))).numberOfLines == 3)
        // 0 is UIKit's "no limit", and the solver passes it through rather than inventing a cap.
        #expect(BNButtonLayoutSolver.solve(makeInput(titleBehavior: .wrap(lines: 0))).numberOfLines == 0)
    }

    @Test
    func `the button grows past its size height rather than clipping the content`() {
        let output = BNButtonLayoutSolver.solve(makeInput(titleHeight: 60))
        #expect(output.buttonHeight > BNButtonSize.medium.height)
        #expect(output.buttonHeight == 60 + 2 * BNButtonSize.medium.verticalPadding)
    }

    @Test
    func `an ordinary title leaves the size height alone`() {
        let output = BNButtonLayoutSolver.solve(makeInput(titleHeight: 20))
        #expect(output.buttonHeight == BNButtonSize.medium.height)
    }

    @Test
    func `fill takes the offered width and hug takes the content width`() {
        let filled = BNButtonLayoutSolver.solve(makeInput(availableWidth: 320, width: .fill))
        #expect(filled.buttonWidth == 320)

        let hugged = BNButtonLayoutSolver.solve(makeInput(availableWidth: 320, titleWidth: 120, width: .hug))
        #expect(hugged.buttonWidth == 120 + 2 * BNButtonSize.medium.horizontalPadding)
    }

    @Test
    func `hug never spills past the offered width`() {
        let output = BNButtonLayoutSolver.solve(makeInput(availableWidth: 120, titleWidth: 400, width: .hug))
        #expect(output.buttonWidth == 120)
    }

    @Test
    func `a fixed width still honours the spinner floor`() {
        let output = BNButtonLayoutSolver.solve(makeInput(width: .fixed(10)))
        #expect(output.buttonWidth == BNButtonSize.medium.effectiveMinWidth)
    }

    @Test
    func `zero available width does not produce a negative size`() {
        let output = BNButtonLayoutSolver.solve(makeInput(availableWidth: 0, width: .fill))
        #expect(output.buttonWidth > 0)
        #expect(output.contentWidth >= 0)
        #expect(output.buttonHeight > 0)

        let finite = [output.buttonWidth, output.contentWidth, output.buttonHeight].allSatisfy(\.isFinite)
        #expect(finite)
    }

    @Test
    func `no content at all still leaves a 44 pt touch target`() {
        let output = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            size: .small,
        ))
        #expect(output.touchSize.width >= BNButtonMetrics.minimumTouchTarget)
        #expect(output.touchSize.height >= BNButtonMetrics.minimumTouchTarget)
    }
}
