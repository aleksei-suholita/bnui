@testable import BNUIButton
import CoreGraphics
import Testing

/// The icon-only button: a circle sized by the step, never by the glyph.
@Suite("BNButtonLayoutSolver — lone icon")
struct BNButtonLoneIconLayoutTests {
    private func makeInput(
        titleWidth: CGFloat = 120,
        titleHeight: CGFloat = 20,
        iconWidths: [CGFloat] = [],
        iconHeight: CGFloat = 0,
        size: BNButtonSize = .medium,
        width: BNButtonWidth = .hug,
    ) -> BNButtonLayoutSolver.Input {
        BNButtonLayoutSolver.Input(
            availableWidth: 320,
            titleWidth: titleWidth,
            titleHeight: titleHeight,
            iconWidths: iconWidths,
            iconHeight: iconHeight,
            size: size,
            width: width,
        )
    }

    @Test
    func `an icon on its own makes a square button`() {
        // A capsule is only a circle while the sides match, and `minWidth` — a floor meant for
        // buttons carrying words — is what would otherwise stretch it into an oval.
        let output = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            iconWidths: [19],
            iconHeight: 17,
        ))
        #expect(output.buttonWidth == output.buttonHeight)
        #expect(output.buttonWidth == BNButtonSize.medium.height)
    }

    @Test
    func `an icon beside a title is not squared`() {
        let output = BNButtonLayoutSolver.solve(makeInput(iconWidths: [19], iconHeight: 17))
        #expect(output.buttonWidth > output.buttonHeight)
    }

    @Test
    func `an explicit width wins over the square rule`() {
        let filled = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            iconWidths: [19],
            iconHeight: 17,
            width: .fill,
        ))
        #expect(filled.buttonWidth == 320)
    }

    // Glyph sizes below are SF Symbols measured at the kit's point sizes, semibold.

    @Test
    func `icons of one size make buttons of one size whatever the glyph`() {
        // gearshape, person.2 and person.3 at 17 pt: the widest crosses the inset, and still the
        // button does not move — a row of them has to line up.
        let glyphs: [CGSize] = [
            CGSize(width: 22, height: 22),
            CGSize(width: 28, height: 20),
            CGSize(width: 37, height: 20),
        ]
        let outputs = glyphs.map { glyph in
            BNButtonLayoutSolver.solve(makeInput(
                titleWidth: 0,
                titleHeight: 0,
                iconWidths: [glyph.width],
                iconHeight: glyph.height,
            ))
        }
        for output in outputs {
            #expect(output.buttonWidth == BNButtonSize.medium.height)
            #expect(output.buttonHeight == BNButtonSize.medium.height)
        }
    }

    @Test
    func `a glyph that fits the circle is drawn at full size`() {
        let output = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            iconWidths: [22],
            iconHeight: 22,
        ))
        #expect(output.iconScale == 1)
        let inset = BNButtonSize.medium.iconOnlyInset
        #expect(output.contentInsets == BNButtonInsets(vertical: inset, horizontal: inset))
    }

    @Test
    func `a glyph wider than the circle shrinks to the inset`() {
        // person.3 at 17 pt against 44 − 2 × 8 = 28 pt of room.
        let output = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            iconWidths: [37],
            iconHeight: 20,
        ))
        let room = BNButtonSize.medium.height - 2 * BNButtonSize.medium.iconOnlyInset
        #expect(output.iconScale == room / 37)
        #expect(output.contentWidth == room)
    }

    @Test
    func `a glyph taller than the circle shrinks instead of growing the button`() {
        let output = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            iconWidths: [20],
            iconHeight: 30,
            size: .small,
        ))
        let room = BNButtonSize.small.height - 2 * BNButtonSize.small.iconOnlyInset
        #expect(output.buttonHeight == BNButtonSize.small.height)
        #expect(output.iconScale == room / 30)
    }

    @Test
    func `a view reporting no height is not scaled into nonsense`() {
        let output = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            iconWidths: [22],
            iconHeight: 0,
        ))
        #expect(output.iconScale == 1)
    }

    @Test
    func `two icons without a title size like content rather than a circle`() {
        let output = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            iconWidths: [19, 19],
            iconHeight: 17,
        ))
        #expect(output.buttonWidth > output.buttonHeight)
        #expect(output.iconScale == 1)
    }

    @Test
    func `a titled button keeps the text paddings`() {
        let output = BNButtonLayoutSolver.solve(makeInput(iconWidths: [19], iconHeight: 17))
        let size = BNButtonSize.medium
        // Sideways the text padding; vertically the room one line already has in the height.
        let paddings = BNButtonInsets(vertical: (size.height - 20) / 2, horizontal: size.horizontalPadding)
        #expect(output.contentInsets == paddings)
        #expect(output.iconScale == 1)
    }

    @Test(arguments: [BNButtonSize.small, .medium, .large])
    func `every standard circle holds the spinner inside its inset`(size: BNButtonSize) {
        // The circle no longer grows for anything, so the spinner has to fit the size as declared.
        #expect(size.indicatorSide <= size.height - 2 * size.iconOnlyInset)
    }

    @Test
    func `a small icon button is drawn small and touched large`() {
        var size = BNButtonSize.small
        size.height = 24
        size.minWidth = 24
        size.horizontalPadding = 2
        size.verticalPadding = 2
        size.iconOnlyInset = 2
        size.indicatorSide = 12
        let output = BNButtonLayoutSolver.solve(makeInput(
            titleWidth: 0,
            titleHeight: 0,
            iconWidths: [16],
            iconHeight: 16,
            size: size,
        ))
        #expect(output.buttonHeight == 24)
        #expect(output.touchSize.height == BNButtonMetrics.minimumTouchTarget)
        #expect(output.touchSize.width >= BNButtonMetrics.minimumTouchTarget)
    }
}
