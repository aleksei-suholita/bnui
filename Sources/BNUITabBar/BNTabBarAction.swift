#if canImport(UIKit)
    import BNUIButton
    import UIKit

    /// The optional action button that sits beside the sections.
    ///
    /// Deliberately its own type rather than another `BNTabBarItem`: an action is not a sixth
    /// section, and sharing the model is how the two start to blur.
    public struct BNTabBarAction: Equatable {
        /// How loud the button is. What it is made of is not the action's choice: the bar's
        /// material makes it, so the action is glass beside a glass capsule and a blurred plate
        /// beside a blurred one — see ``BNTabBarMaterial/makeActionMaterial(prominent:)``.
        public enum Style: Equatable {
            /// The bar's own surface, with the bar's label colour on it.
            case standard
            /// Stained with `fill` and carrying the glyph in `glyph`. The two come as a pair: the
            /// kit does not check their contrast, so a light fill needs a dark glyph from the host.
            case prominent(fill: UIColor, glyph: UIColor)

            /// Stained with the accent and carrying a light glyph, the way the system's prominent
            /// configurations are.
            public static var prominent: Style {
                .prominent(fill: .tintColor, glyph: .white)
            }
        }

        public let icon: BNTabBarItem.Icon
        /// Spoken name. Required: an icon-only button is silent otherwise.
        public let accessibilityLabel: String
        public let style: Style

        public init(icon: BNTabBarItem.Icon, accessibilityLabel: String, style: Style = .standard) {
            self.icon = icon
            self.accessibilityLabel = accessibilityLabel
            self.style = style
        }

        /// The button style this action dresses itself in.
        ///
        /// - Parameters:
        ///   - foreground: the bar's own label colour, so a plain action reads as part of the bar
        ///     rather than as a coloured control parked beside it.
        ///   - material: the bar's material, which makes the action's.
        func makeButtonStyle(foreground: UIColor, material: any BNTabBarMaterial) -> BNButtonStyle {
            let (fill, glyph): (UIColor?, UIColor) = switch style {
            case .standard: (nil, foreground)
            case let .prominent(fill, glyph): (fill, glyph)
            }
            return BNButtonStyle(
                id: "tabBarAction",
                // The fill doubles as the tint of a tinted material, so a plain action stains nothing.
                fill: BNButtonColorSet(fill ?? .clear),
                title: BNButtonColorSet(glyph),
                material: material.makeActionMaterial(prominent: fill != nil),
                opaqueFallback: BNSolidButtonMaterial(fill: fill ?? .secondarySystemBackground),
                // Silence from the button: the bar plays the action's own haptic, which has to stay
                // distinguishable from changing a section. Two generators would sound like both.
                hapticEmphasis: .silent,
            )
        }

        /// A square step of the size scale — square so a capsule corner draws a circle, a shape the
        /// sections' pill never takes, and one of the channels keeping the action from reading as a
        /// tab.
        func makeButtonSize(side: CGFloat, iconPointSize: CGFloat) -> BNButtonSize {
            BNButtonSize(
                id: "tabBarAction",
                height: side,
                horizontalPadding: 0,
                verticalPadding: 0,
                iconSpacing: 0,
                iconPointSize: iconPointSize,
                minWidth: side,
                // The action never loads, so no room is set aside for a spinner.
                indicatorSide: 0,
            )
        }

        var buttonIcon: BNButtonIcon {
            switch icon {
            case let .symbol(name): .symbol(name)
            case let .image(image): .image(image)
            }
        }
    }
#endif
