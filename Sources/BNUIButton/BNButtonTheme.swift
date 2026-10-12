#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Look and feel of the button. Every value the control draws comes from here — there are no
    /// literals in the control itself.
    ///
    /// Split into sub-structures rather than a flat list: geometry, type, motion and focus
    /// change for different reasons and by different people. `geometry` and `motion` are UIKit-free
    /// types, so their rules stay testable without a simulator.
    ///
    /// Values are placeholders on system tokens until the design values land; swapping them
    /// changes the button without touching its code.
    public struct BNButtonTheme: Equatable {
        public struct Typography: Equatable {
            /// Fonts by size id. A size the theme has not heard of falls back rather than
            /// collapsing to nothing — a host may pass its own step of the scale.
            public var titles: [String: UIFont]
            public var fallback: UIFont

            public init(
                titles: [String: UIFont] = [
                    BNButtonSize.small.id: .preferredFont(forTextStyle: .subheadline),
                    BNButtonSize.medium.id: .preferredFont(forTextStyle: .body),
                    BNButtonSize.large.id: .preferredFont(forTextStyle: .headline),
                ],
                fallback: UIFont = .preferredFont(forTextStyle: .body),
            ) {
                self.titles = titles
                self.fallback = fallback
            }

            public func font(for size: BNButtonSize) -> UIFont {
                titles[size.id] ?? fallback
            }

            public static let standard = Typography()
        }

        public struct IconSpec: Equatable {
            /// Symbol weights, not font weights — these feed `UIImage.SymbolConfiguration`.
            public var weight: UIImage.SymbolWeight
            /// Deliberately the same weight when pressed: a symbol that thickens under the finger
            /// reads as a second, competing animation next to the compression.
            public var pressedWeight: UIImage.SymbolWeight
            public var scale: UIImage.SymbolScale

            public init(
                weight: UIImage.SymbolWeight = .semibold,
                pressedWeight: UIImage.SymbolWeight = .semibold,
                scale: UIImage.SymbolScale = .medium,
            ) {
                self.weight = weight
                self.pressedWeight = pressedWeight
                self.scale = scale
            }

            public static let standard = IconSpec()
        }

        public struct Focus: Equatable {
            /// Use the system halo. Off, and the theme's own ring is drawn instead.
            public var usesSystemHalo: Bool
            public var ringColor: UIColor
            public var ringWidth: CGFloat

            public init(usesSystemHalo: Bool = true, ringColor: UIColor = .tintColor, ringWidth: CGFloat = 2) {
                self.usesSystemHalo = usesSystemHalo
                self.ringColor = ringColor
                self.ringWidth = ringWidth
            }

            public static let standard = Focus()
        }

        public var geometry: BNButtonMetrics
        public var motion: BNButtonMotion
        public var typography: Typography
        public var icon: IconSpec
        public var focus: Focus
        /// The badge — the same look a tab bar's badge takes from its own theme.
        public var badge: BNBadgeTheme
        /// Colour of the flash when a disabled button refuses a touch. The shape of that refusal
        /// lives in ``BNButtonMotion/rejection``; this is only what it is painted with.
        public var rejectionColor: UIColor

        /// True when a change needs the view tree rebuilt rather than just re-laid-out: fonts and
        /// icon specs are baked into the views when they are made, while metrics and motion are
        /// read at the moment they are used.
        public func requiresRebuild(comparedTo other: BNButtonTheme) -> Bool {
            typography != other.typography
                || icon != other.icon
                || focus != other.focus
                || badge != other.badge
                || rejectionColor != other.rejectionColor
        }

        public init(
            geometry: BNButtonMetrics = .standard,
            motion: BNButtonMotion = .standard,
            typography: Typography = .standard,
            icon: IconSpec = .standard,
            focus: Focus = .standard,
            badge: BNBadgeTheme = .standard,
            rejectionColor: UIColor = .systemRed,
        ) {
            self.geometry = geometry
            self.motion = motion
            self.typography = typography
            self.icon = icon
            self.focus = focus
            self.badge = badge
            self.rejectionColor = rejectionColor
        }

        public static let standard = BNButtonTheme()
    }
#endif
