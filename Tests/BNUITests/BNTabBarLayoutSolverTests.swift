@testable import BNUITabBar
import CoreGraphics
import Testing

@Suite("BNTabBarLayoutSolver")
struct BNTabBarLayoutSolverTests {
    /// Roughly the standard section: a 20 pt symbol over a caption label, 4 pt inset each side.
    private static let caption = BNTabBarLayoutSolver.ItemMeasure(labelWidth: 38, iconWidth: 20, inset: 4)

    private func makeInput(
        availableWidth: CGFloat = 360,
        items: [BNTabBarLayoutSolver.ItemMeasure],
        preferredItemWidth: CGFloat = 80,
        minimumItemWidth: CGFloat = 44,
        minimumLabelScale: CGFloat = 0.8,
        maxBarWidth: CGFloat = 500,
        fillsAvailableWidth: Bool = false,
    ) -> BNTabBarLayoutSolver.Input {
        BNTabBarLayoutSolver.Input(
            availableWidth: availableWidth,
            items: items,
            itemSpacing: 4,
            capsulePadding: 6,
            preferredItemWidth: preferredItemWidth,
            minimumItemWidth: minimumItemWidth,
            minimumLabelScale: minimumLabelScale,
            maxBarWidth: maxBarWidth,
            fillsAvailableWidth: fillsAvailableWidth,
        )
    }

    private func sections(_ count: Int, _ measure: BNTabBarLayoutSolver.ItemMeasure = Self.caption) -> [BNTabBarLayoutSolver.ItemMeasure] {
        Array(repeating: measure, count: count)
    }

    private func labelOnly(_ width: CGFloat) -> BNTabBarLayoutSolver.ItemMeasure {
        BNTabBarLayoutSolver.ItemMeasure(labelWidth: width, iconWidth: 0, inset: 0)
    }

    // MARK: - Room to spare

    @Test
    func `every section takes the most demanding one's width`() {
        let output = BNTabBarLayoutSolver.solve(makeInput(
            items: [labelOnly(70), labelOnly(60), labelOnly(90)],
        ))
        #expect(output.itemWidths == [90, 90, 90])
    }

    @Test
    func `the bar is sized by content, not by the space offered`() {
        // The capsule must stay detached from the edges — otherwise there is nothing left to align.
        let output = BNTabBarLayoutSolver.solve(makeInput(availableWidth: 360, items: sections(2)))
        #expect(output.itemWidths == [80, 80])
        #expect(output.barWidth < 200)
    }

    @Test
    func `filling spreads sections across the offered width`() {
        let hugged = BNTabBarLayoutSolver.solve(makeInput(availableWidth: 360, items: sections(3)))
        let filled = BNTabBarLayoutSolver.solve(
            makeInput(availableWidth: 360, items: sections(3), fillsAvailableWidth: true),
        )
        #expect(filled.barWidth > hugged.barWidth)
        #expect(filled.barWidth <= 360 + 0.5)
    }

    @Test
    func `bar never grows past maxBarWidth`() {
        let output = BNTabBarLayoutSolver.solve(makeInput(
            availableWidth: 1200,
            items: sections(4, labelOnly(200)),
            maxBarWidth: 500,
        ))
        #expect(output.barWidth <= 500 + 0.5)
    }

    // MARK: - The ladder

    @Test
    func `a crowded bar narrows sections below the preferred width before touching labels`() {
        // Five sections on a 402 pt phone: 80 pt each no longer fits, the labels still do.
        let output = BNTabBarLayoutSolver.solve(makeInput(availableWidth: 370, items: sections(5)))
        #expect(output.fits)
        #expect(output.labels == .natural)
        #expect(output.barWidth <= 370 + 0.5)
        let narrowed = output.itemWidths.allSatisfy { $0 < 80 && $0 >= 46 }
        #expect(narrowed)
    }

    @Test
    func `labels shrink together before they disappear`() {
        // 100 pt of label in 90 pt of room: a 0.9 shrink, the same for every section.
        let output = BNTabBarLayoutSolver.solve(makeInput(
            availableWidth: 2 * 90 + 4 + 12,
            items: [labelOnly(100), labelOnly(40)],
            minimumItemWidth: 0,
        ))
        #expect(output.fits)
        #expect(output.labels == .scaled(0.9))
        #expect(output.labels.titleScale == 0.9)
        #expect(output.itemWidths == [90, 90])
    }

    @Test
    func `labels give way to icons past the minimum scale`() {
        // 100 pt of label in 70 pt of room would need a 0.7 shrink; 0.8 is the limit.
        let output = BNTabBarLayoutSolver.solve(makeInput(
            availableWidth: 2 * 70 + 4 + 12,
            items: sections(2, BNTabBarLayoutSolver.ItemMeasure(labelWidth: 100, iconWidth: 20, inset: 0)),
            minimumItemWidth: 0,
        ))
        #expect(output.fits)
        #expect(output.labels == .hidden)
        #expect(output.labels.titleScale == 1)
    }

    @Test
    func `a minimum scale of 1 skips straight to icons`() {
        let output = BNTabBarLayoutSolver.solve(makeInput(
            availableWidth: 2 * 95 + 4 + 12,
            items: sections(2, labelOnly(100)),
            minimumItemWidth: 0,
            minimumLabelScale: 1,
        ))
        #expect(output.labels == .hidden)
    }

    @Test
    func `steps arrive in order as the width runs out`() {
        // Sweeping from roomy to cramped, the bar may only ever step down the ladder: labels at full
        // size, then shrinking steadily, then gone — never back up on the way.
        let long = BNTabBarLayoutSolver.ItemMeasure(labelWidth: 60, iconWidth: 20, inset: 4)
        var previousScale: CGFloat = 1
        var sawScaled = false
        var sawHidden = false
        for available in stride(from: CGFloat(400), through: 150, by: -2) {
            let labels = BNTabBarLayoutSolver.solve(makeInput(availableWidth: available, items: sections(5, long))).labels
            if labels == .hidden {
                sawHidden = true
                continue
            }
            #expect(!sawHidden, "labels came back at \(available) pt after going")
            #expect(labels.titleScale <= previousScale)
            previousScale = labels.titleScale
            sawScaled = sawScaled || labels.titleScale < 1
        }
        #expect(sawScaled)
        #expect(sawHidden)
    }

    // MARK: - The touch-target floor

    @Test
    func `the touch-target floor survives any theme`() {
        // A theme asking for tiny sections must not shrink the touch target.
        let output = BNTabBarLayoutSolver.solve(makeInput(
            items: sections(3, labelOnly(10)),
            preferredItemWidth: 10,
        ))
        let allMeetTouchTarget = output.itemWidths.allSatisfy { $0 >= 44 }
        #expect(allMeetTouchTarget)
    }

    @Test
    func `filling still honours the touch-target floor`() {
        let output = BNTabBarLayoutSolver.solve(
            makeInput(availableWidth: 40, items: sections(2, labelOnly(20)), fillsAvailableWidth: true),
        )
        let allMeetTouchTarget = output.itemWidths.allSatisfy { $0 >= 44 }
        #expect(allMeetTouchTarget)
    }

    @Test
    func `the floor is kept even when that means not fitting`() {
        // Seven sections on a zoomed SE: icons at 44 pt need more than the 288 pt on offer. The bar
        // says so instead of handing out targets too small to hit.
        let output = BNTabBarLayoutSolver.solve(makeInput(availableWidth: 288, items: sections(7)))
        #expect(!output.fits)
        #expect(output.labels == .hidden)
        let allAtTouchTarget = output.itemWidths.allSatisfy { $0 == 44 }
        #expect(allAtTouchTarget)
        #expect(output.barWidth > 288)
    }

    @Test(arguments: [
        // (sections, offered width): screen − 2 × 16 pt margins, − 64 pt when an action sits beside.
        (5, CGFloat(288)), // 320 pt, zoomed SE
        (5, CGFloat(279)), // 375 pt with an action
        (6, CGFloat(343)), // 375 pt
        (6, CGFloat(297)), // 393 pt with an action
    ])
    func `sections fit a phone at or above the touch target`(sections count: Int, available: CGFloat) {
        let output = BNTabBarLayoutSolver.solve(makeInput(availableWidth: available, items: sections(count)))
        #expect(output.fits)
        #expect(output.barWidth <= available + 0.5)
        let allMeetTouchTarget = output.itemWidths.allSatisfy { $0 >= 44 }
        #expect(allMeetTouchTarget)
    }

    // MARK: - Degenerate input

    @Test
    func `degenerate inputs do not crash or produce NaN`() {
        let empty = BNTabBarLayoutSolver.solve(makeInput(items: []))
        #expect(empty.itemWidths.isEmpty)
        #expect(empty.barWidth == 0)

        let zeroWidth = BNTabBarLayoutSolver.solve(makeInput(availableWidth: 0, items: sections(2)))
        let zeroWidthIsFinite = zeroWidth.itemWidths.allSatisfy(\.isFinite)
        #expect(zeroWidthIsFinite)
        #expect(zeroWidth.labels == .hidden)

        let unmeasured = BNTabBarLayoutSolver.solve(makeInput(items: sections(3, labelOnly(0))))
        let unmeasuredIsFinite = unmeasured.itemWidths.allSatisfy(\.isFinite)
        #expect(unmeasuredIsFinite)
        #expect(unmeasured.labels.titleScale.isFinite)

        #expect(slotCount(.nan) == BNTabBarLayoutSolver.maximumSlots)
        let nothingToDivideBy = BNTabBarLayoutSolver.slotCount(
            availableWidth: 360, itemSpacing: 0, capsulePadding: 6, minimumItemWidth: 0, maxBarWidth: 500,
        )
        #expect(nothingToDivideBy == BNTabBarLayoutSolver.maximumSlots)
    }
}

/// Slots and More sit in an extension: one suite, two bodies short enough to read.
extension BNTabBarLayoutSolverTests {
    // MARK: - More

    @Test(arguments: [(0, 0), (2, 2), (6, 6), (7, 5), (12, 5)])
    func `up to six sections stand in the capsule, past that five and More`(sections: Int, visible: Int) {
        #expect(BNTabBarLayoutSolver.visibleSectionCount(of: sections) == visible)
    }

    @Test(arguments: [
        // (sections, slots, visible)
        (4, 4, 4), // exactly as many as the slots: no More
        (5, 4, 3), // one over: More takes the last slot and hides two
        (6, 5, 4),
        (3, 2, 1), // the fewest slots still keep a section beside More
        (3, 0, 1), // fewer than that is read as the fewest
        (9, 9, 5), // more than the capsule ever holds is read as the most
    ])
    func `sections past the slots go behind More`(sections: Int, slots: Int, visible: Int) {
        #expect(BNTabBarLayoutSolver.visibleSectionCount(of: sections, slots: slots) == visible)
    }

    private func slotCount(_ available: CGFloat, minimum: CGFloat = 60, maxBarWidth: CGFloat = 500) -> Int {
        BNTabBarLayoutSolver.slotCount(
            availableWidth: available,
            itemSpacing: 4,
            capsulePadding: 6,
            minimumItemWidth: minimum,
            maxBarWidth: maxBarWidth,
        )
    }

    @Test(arguments: [
        // (offered width, slots): screen − 2 × 16 pt margins, − 64 pt when an action sits beside.
        (CGFloat(288), 4), // 320 pt, zoomed SE
        (CGFloat(343), 5), // 375 pt
        (CGFloat(370), 5), // 402 pt
        (CGFloat(408), 6), // 440 pt
        (CGFloat(279), 4), // 375 pt with an action
        (CGFloat(306), 4), // 402 pt with an action
        (CGFloat(344), 5), // 440 pt with an action
    ])
    func `a phone holds as many slots as fit at the minimum width`(available: CGFloat, slots: Int) {
        #expect(slotCount(available) == slots)
    }

    @Test
    func `a slot exactly at the minimum width still counts`() {
        // Five slots at 60 pt: 5 × 60 + 4 × 4 spacing + 2 × 6 padding.
        #expect(slotCount(328) == 5)
        #expect(slotCount(327) == 4)
    }

    @Test
    func `the action takes its width first, so More arrives with fewer sections`() {
        // Five sections on a 402 pt phone all stand; the action beside them sends two behind More.
        let alone = BNTabBarLayoutSolver.visibleSectionCount(of: 5, slots: slotCount(370))
        let besideAction = BNTabBarLayoutSolver.visibleSectionCount(of: 5, slots: slotCount(306))
        #expect(alone == 5)
        #expect(besideAction == 3)
    }

    @Test
    func `slots stay between two and six however wide the bar`() {
        #expect(slotCount(1200) == BNTabBarLayoutSolver.maximumSlots)
        #expect(slotCount(1200, maxBarWidth: 2000) == BNTabBarLayoutSolver.maximumSlots)
        #expect(slotCount(100) == BNTabBarLayoutSolver.minimumSlots)
        #expect(slotCount(0) == BNTabBarLayoutSolver.minimumSlots)
    }

    @Test
    func `no section standing in the capsule is narrower than the minimum`() {
        // The two rules together: whatever the width and the count, the slots that stand are
        // sized at the minimum or wider — as long as the fewest slots fit at it at all.
        let minimum: CGFloat = 60
        let fewestFit = 2 * minimum + 4 + 12
        for count in 2 ... 12 {
            for available in stride(from: fewestFit, through: 520, by: 3) {
                let slots = slotCount(available, minimum: minimum)
                let visible = BNTabBarLayoutSolver.visibleSectionCount(of: count, slots: slots)
                let standing = visible + (visible < count ? 1 : 0)
                let output = BNTabBarLayoutSolver.solve(makeInput(
                    availableWidth: available,
                    items: sections(standing),
                    fillsAvailableWidth: true,
                ))
                let allAtMinimum = output.itemWidths.allSatisfy { $0 >= minimum - 0.5 }
                #expect(allAtMinimum, "\(count) sections at \(available) pt")
                #expect(output.barWidth <= available + 0.5, "\(count) sections at \(available) pt")
            }
        }
    }
}
