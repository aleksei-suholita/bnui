#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Who draws the response under the finger.
    public enum BNButtonPressResponse: Equatable, Sendable {
        /// System glass compresses and lights the touch point itself. The control keeps its own
        /// scale out of the way — two compressions at once read as a soft, laggy button.
        case system
        /// The control owns the response: it compresses the surface with its own spring.
        case control
    }

    /// What the button is doing, as far as a material needs to know.
    public struct BNButtonSurfaceState: Equatable {
        public var isPressed: Bool
        public var status: BNButtonStatus
        public var isFocused: Bool

        public init(isPressed: Bool, status: BNButtonStatus, isFocused: Bool) {
            self.isPressed = isPressed
            self.status = status
            self.isFocused = isFocused
        }
    }

    /// The backing layer a material hands the control.
    ///
    /// `contentContainer` says where the content and the indicator go, so the control never has to
    /// guess at a material's insides — on glass that is the effect's content view, where
    /// `UIVisualEffectView` wants its subviews.
    public struct BNButtonSurface {
        /// The view added under the button's content.
        public let view: UIView
        /// Where the control puts the content and the indicator.
        public let contentContainer: UIView
        /// Called whenever the state changes; the material decides what that looks like.
        public let apply: (BNButtonSurfaceState, BNTransition) -> Void

        public init(
            view: UIView,
            contentContainer: UIView,
            apply: @escaping (BNButtonSurfaceState, BNTransition) -> Void = { _, _ in },
        ) {
            self.view = view
            self.contentContainer = contentContainer
            self.apply = apply
        }
    }

    /// Swappable layer under the content. Brand and seasonal skins plug in without the control
    /// learning what they are.
    ///
    /// Every material owes the same contract: go static under Reduce Motion and Low Power, and keep
    /// one glass layer per element. Reduce Transparency is the control's to answer — it swaps in
    /// the style's opaque fallback.
    public protocol BNButtonMaterial {
        /// Distinguishes one material from another. A theme has to be `Equatable` so the control
        /// can tell a rebuild from a re-layout, and a protocol cannot be — so materials compare by
        /// this string instead.
        var identity: String { get }
        var pressResponse: BNButtonPressResponse { get }
        func makeSurface(style: BNButtonStyle, size: BNButtonSize, theme: BNButtonTheme) -> BNButtonSurface
    }

    /// Opaque fill from the style. What every translucent material degrades to under Reduce
    /// Transparency, and a complete material in its own right — a flat style passes the same
    /// checklist as a glass one.
    public struct BNSolidButtonMaterial: BNButtonMaterial {
        /// Overrides the style's fill. `nil` — take the fill from the style, which is the usual case.
        private let fill: UIColor?

        public init(fill: UIColor? = nil) {
            self.fill = fill
        }

        public var identity: String {
            guard let fill else { return "solid.style" }
            return "solid.\(fill)"
        }

        public var pressResponse: BNButtonPressResponse {
            .control
        }

        public func makeSurface(style: BNButtonStyle, size: BNButtonSize, theme _: BNButtonTheme) -> BNButtonSurface {
            let view = UIView()
            view.bnApplyShape(size.shape, maximumRadius: size.maximumCornerRadius)

            let override = fill
            return BNButtonSurface(view: view, contentContainer: view) { state, transition in
                let colour = override ?? style.fill.color(for: state.status, isPressed: state.isPressed)
                transition.run { view.backgroundColor = colour }
            }
        }
    }

    /// Real system Liquid Glass, on iOS 26 and later.
    ///
    /// The system effect is used precisely because it answers Reduce Transparency, Increase Contrast
    /// and Low Power itself, and because `isInteractive` gives the under-finger response — the light
    /// tracking the touch point — that no hand-rolled layer reproduces. What the system does not
    /// give, the control keeps: the speed reward, the haptic contract and the loading mode.
    ///
    /// There is no glass before iOS 26, so there is no glass material either. The translucent
    /// material that exists everywhere is ``BNBlurButtonMaterial``.
    @available(iOS 26.0, *)
    public struct BNGlassButtonMaterial: BNButtonMaterial {
        /// Named apart from `BNButtonStyle`: inside this type the word would otherwise mean two
        /// different things one line apart.
        private let glassStyle: UIGlassEffect.Style
        private let isInteractive: Bool
        /// Stains the glass with the style's fill.
        private let tinted: Bool

        /// - Parameters:
        ///   - style: the system glass style — `.regular` (denser) or `.clear` (thinner).
        ///   - isInteractive: the system under-finger response; the control takes the press back
        ///     without it.
        ///   - tinted: stains the glass with the style's fill.
        public init(style: UIGlassEffect.Style = .regular, isInteractive: Bool = true, tinted: Bool = false) {
            glassStyle = style
            self.isInteractive = isInteractive
            self.tinted = tinted
        }

        public var identity: String {
            "glass.\(glassStyle).\(isInteractive).\(tinted)"
        }

        /// Interactive glass compresses itself, so the control stands down. Turn `isInteractive`
        /// off and the control takes the press back — which is also the way out if the system
        /// response turns out to fight the button's own tracking.
        public var pressResponse: BNButtonPressResponse {
            isInteractive ? .system : .control
        }

        public func makeSurface(style: BNButtonStyle, size: BNButtonSize, theme _: BNButtonTheme) -> BNButtonSurface {
            let effectView = UIVisualEffectView(effect: makeEffect(tint: tinted ? style.fill.normal : nil))
            effectView.bnApplyShape(size.shape, maximumRadius: size.maximumCornerRadius)
            // Both layers stay open to touches, so a finger lands inside the glass: interactive glass
            // answers only a touch that lands there. The button's recognizer sits on the button above
            // and hears the same touch.
            effectView.isUserInteractionEnabled = true
            effectView.contentView.isUserInteractionEnabled = true

            let tinted = tinted
            let makeEffect = makeEffect
            return BNButtonSurface(view: effectView, contentContainer: effectView.contentView) { state, transition in
                guard tinted else { return }
                let target = style.fill.color(for: state.status, isPressed: state.isPressed)
                let current = (effectView.effect as? UIGlassEffect)?.tintColor
                // A tint is baked into the effect and cannot be changed afterwards, so a new colour
                // means a new effect. Skipped when the colour has not moved: rebuilding the effect
                // on every press would throw away the system's own animation.
                guard current != target else { return }
                transition.run { effectView.effect = makeEffect(target) }
            }
        }

        private func makeEffect(tint: UIColor?) -> UIGlassEffect {
            let effect = UIGlassEffect(style: glassStyle)
            effect.isInteractive = isInteractive
            if let tint {
                effect.tintColor = tint
            }
            return effect
        }
    }

    /// A system material plate — `UIBlurEffect` with a rim and a shadow — the translucent material
    /// on every iOS the kit supports.
    ///
    /// A tinted plate lays the style's colour over the material, the way a prominent button looked
    /// before glass. The plate does not answer a finger, so the press is always the control's.
    public struct BNBlurButtonMaterial: BNButtonMaterial {
        /// Named apart from `BNButtonStyle`, as in ``BNGlassButtonMaterial``.
        private let blurStyle: UIBlurEffect.Style
        /// Lays the style's fill over the material.
        private let tinted: Bool

        /// - Parameters:
        ///   - style: the system material, from `.systemUltraThinMaterial` (most of the backdrop
        ///     through) to `.systemThickMaterial` (least).
        ///   - tinted: lays the style's fill over the material.
        public init(style: UIBlurEffect.Style = .systemMaterial, tinted: Bool = false) {
            blurStyle = style
            self.tinted = tinted
        }

        public var identity: String {
            "blur.\(blurStyle.rawValue).\(tinted)"
        }

        public var pressResponse: BNButtonPressResponse {
            .control
        }

        public func makeSurface(style: BNButtonStyle, size: BNButtonSize, theme _: BNButtonTheme) -> BNButtonSurface {
            let plate = BNBlurPlateView(
                effect: blurStyle,
                shape: size.shape,
                maximumRadius: size.maximumCornerRadius,
                fill: tinted ? style.fill.normal : nil,
            )
            let tinted = tinted
            return BNButtonSurface(view: plate, contentContainer: plate.contentView) { state, transition in
                guard tinted else { return }
                let target = style.fill.color(for: state.status, isPressed: state.isPressed)
                transition.run { plate.fill = target }
            }
        }
    }

    /// Where the kit's own presets choose between glass and blur: Liquid Glass on iOS 26,
    /// `.systemMaterial` below it — the kit's one default blur, whatever the glass style. A host
    /// names its material outright, any `UIBlurEffect.Style` included.
    enum BNTranslucentButtonMaterial {
        static func make(clear: Bool = false, tinted: Bool) -> any BNButtonMaterial {
            if #available(iOS 26.0, *) {
                return BNGlassButtonMaterial(style: clear ? .clear : .regular, tinted: tinted)
            }
            return BNBlurButtonMaterial(tinted: tinted)
        }
    }
#endif
