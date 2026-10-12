import CoreGraphics

/// Geometry of the bar — pure numbers, no UIKit, so the guarantees below are testable on macOS.
///
/// The theme may ask for anything; what it cannot do is shrink a touch target. That is why the
/// sizes the control actually uses are exposed as `effective*` rather than read raw.
public nonisolated struct BNTabBarMetrics: Equatable, Sendable {
    /// Apple's minimum touch target. A theme asking for less does not get it.
    public static let minimumTouchTarget: CGFloat = 44

    public var itemHeight: CGFloat
    /// Width a section takes when the bar has room. A look, not a guarantee: a crowded bar narrows
    /// sections below it, down to `minimumItemWidth`.
    public var preferredItemWidth: CGFloat
    /// Narrowest a section gets while the sections all stand in the capsule. When the width left
    /// over by the action cannot give every one of them this much, the tail goes behind More
    /// instead of the sections narrowing further. Never below the touch target.
    public var minimumItemWidth: CGFloat
    public var itemSpacing: CGFloat
    public var capsulePadding: CGFloat
    /// How much the lens is inset from the item it covers, measured at rest.
    public var lensInset: CGFloat
    /// Factor the marker grows by while a finger is on the bar, around its own centre, the way the
    /// system's glass lens swells when pressed — the same on both axes in a row, along the bar
    /// only in a column. 1 means no growth; Reduce Motion and a material that does not respond to
    /// touch resolve it to 1.
    public var liftedScale: CGFloat
    /// Keeps the bar a capsule on wide screens instead of stretching edge to edge.
    public var maxBarWidth: CGFloat
    /// The action button's side. Square rather than a pill: shape is one of the channels that
    /// keeps it from reading as another section.
    public var actionSide: CGFloat
    /// Gap between the sections capsule and the action button.
    public var actionSpacing: CGFloat
    /// From this many sections onwards the capsule stops hugging its content and fills the width
    /// left over by the action.
    public var fillWidthFromSectionCount: Int
    /// How far labels may shrink, all by one factor, before a crowded bar drops them for icons
    /// alone. 1 skips the shrinking and goes straight to icons.
    public var minimumLabelScale: CGFloat

    /// Height actually used: never below the touch target.
    public var effectiveItemHeight: CGFloat {
        max(itemHeight, Self.minimumTouchTarget)
    }

    /// Minimum section width actually used: never below the touch target.
    public var effectiveMinimumItemWidth: CGFloat {
        max(minimumItemWidth, Self.minimumTouchTarget)
    }

    public init(
        itemHeight: CGFloat = 52,
        preferredItemWidth: CGFloat = 80,
        minimumItemWidth: CGFloat = 60,
        itemSpacing: CGFloat = 4,
        capsulePadding: CGFloat = 6,
        lensInset: CGFloat = 4,
        liftedScale: CGFloat = 1.15,
        maxBarWidth: CGFloat = 500,
        actionSide: CGFloat = 56,
        actionSpacing: CGFloat = 8,
        fillWidthFromSectionCount: Int = 3,
        minimumLabelScale: CGFloat = 0.8,
    ) {
        self.itemHeight = itemHeight
        self.preferredItemWidth = preferredItemWidth
        self.minimumItemWidth = minimumItemWidth
        self.itemSpacing = itemSpacing
        self.capsulePadding = capsulePadding
        self.lensInset = lensInset
        self.liftedScale = liftedScale
        self.maxBarWidth = maxBarWidth
        self.actionSide = actionSide
        self.actionSpacing = actionSpacing
        self.fillWidthFromSectionCount = fillWidthFromSectionCount
        self.minimumLabelScale = minimumLabelScale
    }

    public static let standard = BNTabBarMetrics()
}
