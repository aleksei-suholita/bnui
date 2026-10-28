import BNUICore
import CoreGraphics

/// One step of the theme's size scale, carried as a value rather than as a key into a table.
///
/// A theme extends the scale by declaring another static; the control never learns the list, so a
/// host can pass a size the kit has never heard of. `height` is the *visual* height — the touch
/// target is a separate guarantee in ``BNButtonMetrics``, because a 32 pt toolbar button has to
/// stay 32 pt tall and still be 44 pt wide to a finger.
public nonisolated struct BNButtonSize: Equatable, Sendable {
    /// Matches the name of this step in Figma. Shown by the gallery; nothing branches on it.
    public var id: String
    public var height: CGFloat
    public var horizontalPadding: CGFloat
    /// Used only once the content has outgrown `height` — see ``BNButtonLayoutSolver``.
    public var verticalPadding: CGFloat
    /// How close a lone icon may come to the edge of its circle before it is shrunk to fit.
    ///
    /// Separate from the paddings, which are measured for words: `horizontalPadding` would leave a
    /// 44 pt circle twelve points for a glyph twice that wide. 0 lets the icon reach the edge.
    public var iconOnlyInset: CGFloat
    public var iconSpacing: CGFloat
    /// A symbol's point size at the default text size. Beside a title it grows with Dynamic Type
    /// as the title does; a lone icon keeps it, as its circle keeps the size's height.
    public var iconPointSize: CGFloat
    public var minWidth: CGFloat
    /// Room set aside for the loading indicator.
    public var indicatorSide: CGFloat
    public var shape: BNShape

    /// The roundest the button's corners get: the shape's radius at the step's own height.
    ///
    /// A button grown taller than its step — a wrapped title, accessibility type — keeps this
    /// radius instead of rounding on, so a capsule becomes a rounded rectangle rather than growing
    /// ends that cut into the text. On one line a capsule is a capsule.
    public var maximumCornerRadius: CGFloat {
        shape.cornerRadius(forHeight: height)
    }

    /// The width the button never goes below: the spinner has to fit inside the padding, or
    /// entering `loading` would jolt the width — which the acceptance checklist forbids.
    public var effectiveMinWidth: CGFloat {
        max(minWidth, indicatorSide + 2 * horizontalPadding)
    }

    public init(
        id: String,
        height: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        iconOnlyInset: CGFloat = 0,
        iconSpacing: CGFloat,
        iconPointSize: CGFloat,
        minWidth: CGFloat,
        indicatorSide: CGFloat,
        shape: BNShape = .capsule,
    ) {
        self.id = id
        self.height = height
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.iconOnlyInset = iconOnlyInset
        self.iconSpacing = iconSpacing
        self.iconPointSize = iconPointSize
        self.minWidth = minWidth
        self.indicatorSide = indicatorSide
        self.shape = shape
    }

    // Starting values, to be calibrated on device beside the system button. They are placeholders
    // in the same sense as the ones in `Tokens.swift`, not measurements.
    //
    // `iconOnlyInset` is the exception with a reason behind it: it leaves the common symbols at
    // full size — at `small` the widest everyday ones (`keyboard`, `arrow.up.arrow.down`) run
    // 22–23 pt — and shrinks only the genuinely wide ones such as `person.2` and `person.3`.

    public static let small = BNButtonSize(
        id: "small",
        height: 32,
        horizontalPadding: 12,
        verticalPadding: 6,
        iconOnlyInset: 5,
        iconSpacing: 6,
        iconPointSize: 15,
        minWidth: 44,
        indicatorSide: 16,
    )

    public static let medium = BNButtonSize(
        id: "medium",
        height: 44,
        horizontalPadding: 16,
        verticalPadding: 8,
        iconOnlyInset: 8,
        iconSpacing: 8,
        iconPointSize: 17,
        minWidth: 64,
        indicatorSide: 20,
    )

    public static let large = BNButtonSize(
        id: "large",
        height: 56,
        horizontalPadding: 20,
        verticalPadding: 10,
        iconOnlyInset: 10,
        iconSpacing: 10,
        iconPointSize: 20,
        minWidth: 88,
        indicatorSide: 24,
    )
}
