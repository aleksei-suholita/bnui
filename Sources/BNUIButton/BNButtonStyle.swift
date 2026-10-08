#if canImport(UIKit)
    import UIKit

    public struct BNButtonColorSet: Equatable {
        public var normal: UIColor
        public var pressed: UIColor
        public var disabled: UIColor

        public init(normal: UIColor, pressed: UIColor, disabled: UIColor) {
            self.normal = normal
            self.pressed = pressed
            self.disabled = disabled
        }

        public init(_ normal: UIColor, pressed: UIColor? = nil, disabled: UIColor? = nil) {
            self.init(
                normal: normal,
                pressed: pressed ?? normal,
                disabled: disabled ?? normal.withAlphaComponent(0.35),
            )
        }

        public func color(for status: BNButtonStatus, isPressed: Bool) -> UIColor {
            switch status {
            case .disabled: disabled
            case .loading: normal
            case .enabled: isPressed ? pressed : normal
            }
        }
    }

    public struct BNButtonBorder: Equatable {
        public var color: UIColor
        public var width: CGFloat

        public init(color: UIColor, width: CGFloat = 1) {
            self.color = color
            self.width = width
        }
    }

    /// How a button looks and how loudly it answers — colours, material, border, haptic weight.
    ///
    /// Styles are plain values, not cases of a closed set. The kit ships `primary`, `secondary`,
    /// `ghost` and `destructive`; a host adds its own the same way, as a `static let` in an
    /// extension of `BNButtonStyle`, and hands it to the button. Nothing in the control or the
    /// theme has to change for it to work. The material belongs here
    /// because the spec degrades by style — when glass will not fit the budget, the style goes
    /// flat and the control stays exactly as it was.
    public struct BNButtonStyle {
        /// Matches the name of this variant in Figma.
        public var id: String
        public var fill: BNButtonColorSet
        public var title: BNButtonColorSet
        /// `nil` — the icon follows the title.
        public var icon: BNButtonColorSet?
        public var border: BNButtonBorder?
        public var material: any BNButtonMaterial
        /// Where the style lands under Reduce Transparency.
        public var opaqueFallback: any BNButtonMaterial
        public var hapticEmphasis: BNButtonHapticEmphasis
        /// `nil` — the spinner follows the title.
        public var indicatorColor: UIColor?

        public init(
            id: String,
            fill: BNButtonColorSet,
            title: BNButtonColorSet,
            icon: BNButtonColorSet? = nil,
            border: BNButtonBorder? = nil,
            material: any BNButtonMaterial = BNSolidButtonMaterial(),
            opaqueFallback: any BNButtonMaterial = BNSolidButtonMaterial(),
            hapticEmphasis: BNButtonHapticEmphasis = .standard,
            indicatorColor: UIColor? = nil,
        ) {
            self.id = id
            self.fill = fill
            self.title = title
            self.icon = icon
            self.border = border
            self.material = material
            self.opaqueFallback = opaqueFallback
            self.hapticEmphasis = hapticEmphasis
            self.indicatorColor = indicatorColor
        }

        /// Colours for the icon: its own set when the style has one, the title's otherwise.
        public var resolvedIcon: BNButtonColorSet {
            icon ?? title
        }
    }

    extension BNButtonStyle: Equatable {
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
                && lhs.fill == rhs.fill
                && lhs.title == rhs.title
                && lhs.icon == rhs.icon
                && lhs.border == rhs.border
                && lhs.material.identity == rhs.material.identity
                && lhs.opaqueFallback.identity == rhs.opaqueFallback.identity
                && lhs.hapticEmphasis == rhs.hapticEmphasis
                && lhs.indicatorColor == rhs.indicatorColor
        }
    }

    public extension BNButtonStyle {
        static let primary = BNButtonStyle(
            id: "primary",
            fill: BNButtonColorSet(.tintColor),
            title: BNButtonColorSet(.white, disabled: UIColor.white.withAlphaComponent(0.55)),
            material: BNTranslucentButtonMaterial.make(tinted: true),
        )

        static let secondary = BNButtonStyle(
            id: "secondary",
            fill: BNButtonColorSet(.secondarySystemFill),
            title: BNButtonColorSet(.label, disabled: .tertiaryLabel),
            material: BNTranslucentButtonMaterial.make(clear: true, tinted: false),
        )

        static let ghost = BNButtonStyle(
            id: "ghost",
            fill: BNButtonColorSet(.clear),
            title: BNButtonColorSet(.tintColor, disabled: .tertiaryLabel),
            border: nil,
            material: BNSolidButtonMaterial(fill: .clear),
            opaqueFallback: BNSolidButtonMaterial(fill: .clear),
        )

        static let destructive = BNButtonStyle(
            id: "destructive",
            fill: BNButtonColorSet(.systemRed),
            title: BNButtonColorSet(.white, disabled: UIColor.white.withAlphaComponent(0.55)),
            material: BNSolidButtonMaterial(),
            hapticEmphasis: .pronounced,
        )
    }
#endif
