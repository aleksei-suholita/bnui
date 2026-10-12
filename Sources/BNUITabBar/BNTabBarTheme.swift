#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Looks and feel of the bar. Every value the control draws comes from here — there are no
    /// literals in the control itself.
    ///
    /// Split into sub-structures rather than a flat list of fields: geometry, colour, type and
    /// motion change for different reasons and by different people. `geometry` and `motion` are
    /// UIKit-free types, so their rules stay testable without a simulator.
    ///
    /// Values are placeholders on system tokens until the design values land; swapping them
    /// changes the bar without touching its code.
    public struct BNTabBarTheme: Equatable {
        public struct Palette: Equatable {
            public var selected: UIColor
            public var unselected: UIColor
            /// Tint of the lens that marks the active section.
            public var lensTint: UIColor

            public init(
                selected: UIColor = .label,
                unselected: UIColor = .secondaryLabel,
                lensTint: UIColor = Palette.systemLensTint,
            ) {
                self.selected = selected
                self.unselected = unselected
                self.lensTint = lensTint
            }

            /// The colour of the system tab bar's lens at rest.
            ///
            /// The system lens has no fill of its own: it runs what lies under it through a colour
            /// matrix — per channel `1.13x − 0.2` in light mode, `0.958x + 0.135` in dark (UIKit's
            /// `_UITabSelectionView`, iOS 26.5). A filter over the backdrop is private API, so this
            /// is the flat fill that lands on the same colour over glass at its usual brightness.
            /// Neutral on purpose: the system lens takes no hue from the tint colour.
            public static let systemLensTint = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.15)
                    : UIColor(white: 0, alpha: 0.08)
            }

            public static let standard = Palette()
        }

        public struct Typography: Equatable {
            public var title: UIFont
            public var selectedTitle: UIFont

            public init(
                title: UIFont = .preferredFont(forTextStyle: .caption2),
                selectedTitle: UIFont? = nil,
            ) {
                self.title = title
                self.selectedTitle = selectedTitle ?? title.withWeight(.semibold)
            }

            public static let standard = Typography()
        }

        public struct IconSpec: Equatable {
            public var pointSize: CGFloat
            /// Symbol weights, not font weights — these feed `UIImage.SymbolConfiguration`.
            public var weight: UIImage.SymbolWeight
            public var selectedWeight: UIImage.SymbolWeight
            public var titleSpacing: CGFloat

            public init(
                pointSize: CGFloat = 20,
                weight: UIImage.SymbolWeight = .regular,
                selectedWeight: UIImage.SymbolWeight = .semibold,
                titleSpacing: CGFloat = 2,
            ) {
                self.pointSize = pointSize
                self.weight = weight
                self.selectedWeight = selectedWeight
                self.titleSpacing = titleSpacing
            }

            public static let standard = IconSpec()
        }

        /// True when the change needs the view tree rebuilt rather than just re-laid-out:
        /// colours, fonts, icon specs and the layout strategy are baked into the item views when
        /// they are made, while metrics and motion are read at the moment they are used.
        func requiresRebuild(comparedTo other: BNTabBarTheme) -> Bool {
            palette != other.palette
                || typography != other.typography
                || icon != other.icon
                || badge != other.badge
        }

        public var geometry: BNTabBarMetrics
        public var palette: Palette
        public var typography: Typography
        public var icon: IconSpec
        /// The sections' badges — the same look a button's badge takes from its own theme.
        public var badge: BNBadgeTheme
        public var motion: BNTabBarMotion

        public init(
            geometry: BNTabBarMetrics = .standard,
            palette: Palette = .standard,
            typography: Typography = .standard,
            icon: IconSpec = .standard,
            badge: BNBadgeTheme = .standard,
            motion: BNTabBarMotion = .standard,
        ) {
            self.geometry = geometry
            self.palette = palette
            self.typography = typography
            self.icon = icon
            self.badge = badge
            self.motion = motion
        }

        public static let standard = BNTabBarTheme()
    }

#endif
