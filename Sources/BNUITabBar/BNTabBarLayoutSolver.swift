import CoreGraphics

/// Pure geometry of the bar — no UIKit, so it compiles and is tested on macOS via `swift test`.
///
/// Deliberately knows nothing about views: it takes numbers and returns numbers, which is what
/// makes the layout rules verifiable without a simulator.
///
/// How many slots the capsule holds is decided first, by the width alone: `slotCount` stands as
/// many as the width gives the minimum section width each, and the sections past them go behind
/// More. Over the slots that stand, a bar short of room gives way in a fixed order, each step
/// taken only once the one before it is spent:
///
/// 1. Sections narrow from the preferred width towards what their labels need.
/// 2. Labels shrink, all by one factor, down to `minimumLabelScale`.
/// 3. Labels go, and the bar is icons only.
/// 4. Sections narrow to the touch target and stop there — reached only when even the fewest
///    slots do not fit at the minimum width. Past it the bar reports that it does not fit
///    rather than hand out targets too small to hit.
public nonisolated enum BNTabBarLayoutSolver {
    /// Most slots the capsule holds, however wide the bar is. Past this many sections the last
    /// slot goes to More, which opens the rest.
    public static let maximumSlots = 6

    /// Fewest slots a capsule keeps: one section beside More.
    public static let minimumSlots = 2

    /// How many slots at least `minimumItemWidth` wide fit across the offered width.
    ///
    /// The width alone decides, not what the sections hold: labels are the ladder's business, and
    /// a count that moved with them would move sections in and out of More as the text size
    /// changes. Capped at `maximumSlots`, and never under `minimumSlots`, so a bar too narrow for
    /// anything still keeps a section beside More.
    public static func slotCount(
        availableWidth: CGFloat,
        itemSpacing: CGFloat,
        capsulePadding: CGFloat,
        minimumItemWidth: CGFloat,
        maxBarWidth: CGFloat,
    ) -> Int {
        let ceiling = min(max(availableWidth, 0), max(maxBarWidth, 0))
        let spacing = max(itemSpacing, 0)
        // n slots take n widths and n − 1 gaps, so one gap is added back before dividing.
        let fitting = ((ceiling - 2 * max(capsulePadding, 0) + spacing) / (max(minimumItemWidth, 0) + spacing))
            .rounded(.down)
        // A zero minimum with no spacing, or a width that is not a number, leaves nothing to
        // divide by: nothing then limits the slots.
        guard fitting.isFinite else { return maximumSlots }
        return Int(min(max(fitting, CGFloat(minimumSlots)), CGFloat(maximumSlots)))
    }

    /// How many sections stand in a capsule of `slots`; the rest go behind More in the last slot.
    ///
    /// More only ever hides two sections or more: in place of a single one it would win no room.
    public static func visibleSectionCount(of count: Int, slots: Int = maximumSlots) -> Int {
        let slots = min(max(slots, minimumSlots), maximumSlots)
        return count > slots ? slots - 1 : max(count, 0)
    }

    /// Whether the sections share all the room they have rather than stopping at their preferred
    /// width: always on a bar set to fill it, and beside an action from the theme's count of
    /// sections on.
    static func fillsAvailableWidth(fillsWidth: Bool, hasAction: Bool, sectionCount: Int, fillFromSectionCount: Int) -> Bool {
        fillsWidth || (hasAction && sectionCount >= fillFromSectionCount)
    }

    /// What one section's content needs across, as its renderer measures it. The label is
    /// reported apart from the icon because the solver shrinks and drops it on its own.
    public struct ItemMeasure: Equatable, Sendable {
        /// The label at full size; 0 for a section that shows none.
        public var labelWidth: CGFloat
        public var iconWidth: CGFloat
        /// Transparent padding on each side of the content.
        public var inset: CGFloat

        public init(labelWidth: CGFloat, iconWidth: CGFloat, inset: CGFloat) {
            self.labelWidth = labelWidth
            self.iconWidth = iconWidth
            self.inset = inset
        }
    }

    public struct Input: Sendable {
        /// Width the host offers the bar. An upper bound, not a target — the capsule is sized by
        /// its content and only shrinks to fit when the content would not.
        public var availableWidth: CGFloat
        public var items: [ItemMeasure]
        public var itemSpacing: CGFloat
        public var capsulePadding: CGFloat
        /// Width a section takes when there is room. A look, not a guarantee: a crowded bar
        /// narrows sections below it.
        public var preferredItemWidth: CGFloat
        /// The floor no crowding and no theme gets under — the touch target lives here.
        public var minimumItemWidth: CGFloat
        /// How far labels may shrink before they give way to icons. 1 skips straight to icons.
        public var minimumLabelScale: CGFloat
        /// Upper bound so the bar stays a capsule on wide screens instead of stretching.
        public var maxBarWidth: CGFloat
        /// Fill the offered width instead of hugging the content.
        ///
        /// A couple of sections beside an action look better compact, but from three onwards the
        /// leftover gap starts reading as a mistake, so the capsule takes the room it is given.
        public var fillsAvailableWidth: Bool

        public init(
            availableWidth: CGFloat,
            items: [ItemMeasure],
            itemSpacing: CGFloat,
            capsulePadding: CGFloat,
            preferredItemWidth: CGFloat,
            minimumItemWidth: CGFloat,
            minimumLabelScale: CGFloat,
            maxBarWidth: CGFloat,
            fillsAvailableWidth: Bool = false,
        ) {
            self.availableWidth = availableWidth
            self.items = items
            self.itemSpacing = itemSpacing
            self.capsulePadding = capsulePadding
            self.preferredItemWidth = preferredItemWidth
            self.minimumItemWidth = minimumItemWidth
            self.minimumLabelScale = minimumLabelScale
            self.maxBarWidth = maxBarWidth
            self.fillsAvailableWidth = fillsAvailableWidth
        }
    }

    /// How labels are drawn at the solved width.
    public enum Labels: Equatable, Sendable {
        case natural
        /// Every label shrunk by the same factor, so the bar keeps a single type size.
        case scaled(CGFloat)
        case hidden

        /// Factor the labels are drawn at: below 1 only while they are shrunk.
        public var titleScale: CGFloat {
            if case let .scaled(scale) = self {
                scale
            } else {
                1
            }
        }
    }

    public struct Output: Equatable, Sendable {
        public var itemWidths: [CGFloat]
        /// Width of the items plus the gaps between them.
        public var contentWidth: CGFloat
        /// Width of the whole capsule, padding included.
        public var barWidth: CGFloat
        public var labels: Labels
        /// False when even icons at the touch target do not fit. The widths then stay at the
        /// touch target and the bar runs past the offered width.
        public var fits: Bool
    }

    /// Every section gets the same width, sized for the most demanding one, so the bar reads as
    /// evenly spaced and the marker is uniform whichever section it sits on.
    ///
    /// Sized by content, not by the space on offer: a capsule that always spans the screen would
    /// have nothing left to align, and the spec asks for a bar detached from the edges. The
    /// available width only acts as a ceiling.
    public static func solve(_ input: Input) -> Output {
        let count = input.items.count
        guard count > 0 else {
            return Output(itemWidths: [], contentWidth: 0, barWidth: 0, labels: .natural, fits: true)
        }

        let spacingTotal = input.itemSpacing * CGFloat(count - 1)
        let capsuleTotal = 2 * input.capsulePadding
        let label = max(input.items.map(\.labelWidth).max() ?? 0, 0)
        let icon = max(input.items.map(\.iconWidth).max() ?? 0, 0)
        let inset = max(input.items.map(\.inset).max() ?? 0, 0)
        let floor = max(input.minimumItemWidth, 0)

        let ceiling = min(max(input.availableWidth, 0), max(input.maxBarWidth, 0))
        let share = max(ceiling - capsuleTotal - spacingTotal, 0) / CGFloat(count)
        let natural = max(label, icon) + 2 * inset

        let labels: Labels
        let target: CGFloat
        if share >= natural {
            labels = .natural
            let desired = max(natural, input.preferredItemWidth)
            target = input.fillsAvailableWidth ? share : min(desired, share)
        } else {
            labels = shrunkLabels(label: label, icon: icon, room: share - 2 * inset, input: input)
            target = share
        }
        // The touch-target floor is applied last, so it holds on every step.
        let itemWidth = max(target, floor)

        let widths = Array(repeating: itemWidth, count: count)
        let contentWidth = widths.reduce(0, +) + spacingTotal
        return Output(
            itemWidths: widths,
            contentWidth: contentWidth,
            barWidth: contentWidth + capsuleTotal,
            labels: labels,
            fits: share >= max(floor, icon + 2 * inset),
        )
    }

    /// Labels shrink together while they still read at `minimumLabelScale`, and go below it.
    /// `room` is what a section has inside its insets.
    private static func shrunkLabels(label: CGFloat, icon: CGFloat, room: CGFloat, input: Input) -> Labels {
        guard label > 0, room >= icon else { return .hidden }
        let scale = room / label
        let minimumScale = min(max(input.minimumLabelScale, 0), 1)
        return scale >= minimumScale ? .scaled(scale) : .hidden
    }
}
