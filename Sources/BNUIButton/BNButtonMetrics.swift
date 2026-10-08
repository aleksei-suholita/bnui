import CoreGraphics

/// Directional insets, kept UIKit-free so the touch-target rule stays testable on macOS.
public nonisolated struct BNButtonInsets: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init(vertical: CGFloat, horizontal: CGFloat) {
        self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    public static let zero = BNButtonInsets(vertical: 0, horizontal: 0)

    public var isZero: Bool {
        self == .zero
    }
}

/// Rules that hold across every size and style — pure numbers, no UIKit.
///
/// The theme may ask for anything; what it cannot do is shrink a touch target. That guarantee is a
/// calculation here rather than a hint to the control, which is why ``hitOutsets(forVisualSize:)``
/// exists at all: the visual size and the touchable size are different quantities, and the control
/// keeps them apart on the theme's behalf.
public nonisolated struct BNButtonMetrics: Equatable, Sendable {
    /// Apple's minimum touch target. A theme asking for less does not get it.
    public static let minimumTouchTarget: CGFloat = 44

    /// How far the button compresses under a finger. 1 means no compression.
    public var pressedScale: CGFloat
    /// Slack before a finger counts as having left: leaving is a cancel, and a cancel triggered by
    /// a pixel of tremor would read as the button ignoring the tap.
    public var dragHysteresis: CGFloat
    /// How far the focus ring sits outside the visual bounds.
    public var focusHaloPadding: CGFloat

    /// How far the touch area extends past the visual bounds.
    ///
    /// This is the exact point where the control stops obeying the theme: a style sized 28 pt draws
    /// at 28 pt and is touched at 44.
    public func hitOutsets(forVisualSize size: CGSize) -> BNButtonInsets {
        BNButtonInsets(
            vertical: max(0, (Self.minimumTouchTarget - size.height) / 2),
            horizontal: max(0, (Self.minimumTouchTarget - size.width) / 2),
        )
    }

    /// Reduce Motion: the compression disappears as a *value*, so no view has to branch on the
    /// setting. The press still registers — through colour and haptics — it just stops moving.
    public func resolved(reduceMotion: Bool) -> BNButtonMetrics {
        guard reduceMotion else { return self }
        var copy = self
        copy.pressedScale = 1
        return copy
    }

    public init(
        pressedScale: CGFloat = 0.96,
        dragHysteresis: CGFloat = 4,
        focusHaloPadding: CGFloat = 3,
    ) {
        self.pressedScale = pressedScale
        self.dragHysteresis = dragHysteresis
        self.focusHaloPadding = focusHaloPadding
    }

    public static let standard = BNButtonMetrics()
}
