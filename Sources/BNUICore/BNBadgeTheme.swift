#if canImport(UIKit)
    import UIKit

    /// How a ``BNBadge`` looks — the same on a tab bar's section and on a button. Each control's
    /// theme carries one: `BNTabBarTheme.badge`, `BNButtonTheme.badge`.
    public struct BNBadgeTheme: Equatable {
        /// The corner of what the badge marks that it hangs from — a section's icon, a button's
        /// outline — on the trailing side, which a right-to-left layout mirrors.
        public enum Position: Equatable, Sendable {
            case topTrailing
            /// Under a section's icon the badge lies over its title, when the title is shown.
            case bottomTrailing
        }

        public var position: Position
        public var background: UIColor
        public var text: UIColor
        /// Semibold `caption2` unless set, following Dynamic Type.
        public var font: UIFont
        /// The largest text size the badge follows Dynamic Type to. What it marks keeps one size,
        /// and a badge that went on growing would cover it.
        public var maximumContentSizeCategory: UIContentSizeCategory
        /// The largest count shown as is; past it, the limit and a plus — "99+". A cap on the
        /// badge's width as much as on its number.
        public var countLimit: Int
        /// How far a text badge reaches back over the point it hangs from. Pinned there, it grows
        /// away from what it marks, so a long one never covers it.
        public var overlap: CGFloat
        /// The side of a dot, which sits centred on the point it hangs from.
        public var dotSide: CGFloat
        /// The scale a badge pops in from and shrinks back to; 1 makes it only fade.
        public var appearScale: CGFloat

        public init(
            position: Position = .topTrailing,
            background: UIColor = .systemRed,
            text: UIColor = .white,
            font: UIFont? = nil,
            maximumContentSizeCategory: UIContentSizeCategory = .accessibilityMedium,
            countLimit: Int = 99,
            overlap: CGFloat = 9,
            dotSide: CGFloat = 8,
            appearScale: CGFloat = 0.5,
        ) {
            self.position = position
            self.background = background
            self.text = text
            self.font = font ?? Self.standardFont
            self.maximumContentSizeCategory = maximumContentSizeCategory
            self.countLimit = countLimit
            self.overlap = overlap
            self.dotSide = dotSide
            self.appearScale = appearScale
        }

        public static let standard = BNBadgeTheme()

        /// A count reads at a glance in a heavier weight than the text around it. Scaled through
        /// the text style's metrics, so it follows Dynamic Type as the system's own `caption2` does.
        private static var standardFont: UIFont {
            let base = UIFont.preferredFont(
                forTextStyle: .caption2,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .large),
            )
            return UIFontMetrics(forTextStyle: .caption2).scaledFont(for: .systemFont(ofSize: base.pointSize, weight: .semibold))
        }
    }
#endif
