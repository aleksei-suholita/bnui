#if canImport(UIKit)
    import BNUIButton
    import BNUICore
    import UIKit

    /// The backing surface a material hands to the control.
    ///
    /// `contentContainer` matters: the glass spike proved the system response and
    /// touch handling coexist only while the interactive layer lives *inside* the effect's
    /// content view. Materials must keep that topology, so they say where content goes rather
    /// than letting the control guess.
    public struct BNTabBarSurface {
        /// The view added to the hierarchy.
        public let view: UIView
        /// Where the control puts items, indicator and the touch layer.
        public let contentContainer: UIView

        /// - Parameters:
        ///   - view: the view added to the hierarchy.
        ///   - contentContainer: where the control puts its content — `view` itself, or the
        ///     effect's content view for a visual-effect material.
        public init(view: UIView, contentContainer: UIView) {
            self.view = view
            self.contentContainer = contentContainer
        }
    }

    /// Swappable backdrop. The bar never learns whether glass, metal or flat paint is under it,
    /// so brand and seasonal skins plug in without touching the control.
    ///
    /// Every material owes the same contract: go static under Reduce Motion and keep one glass
    /// layer per element. Reduce Transparency is the control's to answer — it swaps the solid
    /// material in.
    public protocol BNTabBarMaterial {
        /// Whether the lens swells under the finger over this surface. The swell mimics glass
        /// reacting to a touch, so it suits system glass with its interactive response on; over
        /// flat glass or matte paint it reads as a wobble. Reduce Motion drops it regardless.
        var allowsLensSwell: Bool { get }

        /// A new surface for the capsule. The bar asks again on every rebuild, so each call
        /// returns fresh views.
        func makeSurface() -> BNTabBarSurface

        /// The material of the action button beside the capsule, so the action is made of what the
        /// bar is made of — glass beside glass, a blurred plate beside a blurred plate, paint beside
        /// paint. `prominent` asks for the tinted variant; the colour itself comes from the action's
        /// button style, whose fill a tinted material takes.
        func makeActionMaterial(prominent: Bool) -> any BNButtonMaterial
    }

    /// Real system Liquid Glass, on iOS 26 and later — the bar's material there by default.
    ///
    /// System glass is used precisely because it handles Reduce Transparency, Increase Contrast
    /// and Reduce Motion itself — a hand-rolled imitation would owe all three by hand and still
    /// miss the refraction and the dark-mode behaviour. There is no glass before iOS 26, so there
    /// is no glass material either; the bar's default there is ``BNBlurTabBarMaterial``.
    @available(iOS 26.0, *)
    public struct BNGlassTabBarMaterial: BNTabBarMaterial {
        private let style: UIGlassEffect.Style
        private let isInteractive: Bool
        private let tintColor: UIColor?

        /// - Parameters:
        ///   - style: the system glass style — `.regular` (denser) or `.clear` (thinner).
        ///   - isInteractive: the system under-finger response (light tracking the touch, the
        ///     shape stretching with it). Verified on device to coexist with taps and drags.
        ///   - tintColor: an optional stained-glass tint; `nil` leaves the glass untinted.
        public init(
            style: UIGlassEffect.Style = .regular,
            isInteractive: Bool = true,
            tintColor: UIColor? = nil,
        ) {
            self.style = style
            self.isInteractive = isInteractive
            self.tintColor = tintColor
        }

        /// The swell repeats the glass's own response, so it is there exactly when that is.
        public var allowsLensSwell: Bool {
            isInteractive
        }

        public func makeSurface() -> BNTabBarSurface {
            let glass = UIGlassEffect(style: style)
            glass.isInteractive = isInteractive
            if let tintColor {
                glass.tintColor = tintColor
            }
            let effectView = UIVisualEffectView(effect: glass)
            effectView.bnApplyCapsule()
            return BNTabBarSurface(view: effectView, contentContainer: effectView.contentView)
        }

        /// Glass of the bar's own thickness, and as interactive as the bar is.
        public func makeActionMaterial(prominent: Bool) -> any BNButtonMaterial {
            BNGlassButtonMaterial(style: style, isInteractive: isInteractive, tinted: prominent)
        }
    }

    /// A system material capsule — `UIBlurEffect` with a rim and a shadow — the bar's default below
    /// iOS 26, and a material of its own on every version.
    public struct BNBlurTabBarMaterial: BNTabBarMaterial {
        private let style: UIBlurEffect.Style
        private let tintColor: UIColor?

        /// - Parameters:
        ///   - style: the system material, from `.systemUltraThinMaterial` (most of the backdrop
        ///     through) to `.systemThickMaterial` (least).
        ///   - tintColor: a colour laid over the material; `nil` leaves the material as it is.
        public init(style: UIBlurEffect.Style = .systemMaterial, tintColor: UIColor? = nil) {
            self.style = style
            self.tintColor = tintColor
        }

        public var allowsLensSwell: Bool {
            false
        }

        public func makeSurface() -> BNTabBarSurface {
            let plate = BNBlurPlateView(effect: style, shape: .capsule, fill: tintColor)
            return BNTabBarSurface(view: plate, contentContainer: plate.contentView)
        }

        /// A plate of the bar's own material.
        public func makeActionMaterial(prominent: Bool) -> any BNButtonMaterial {
            BNBlurButtonMaterial(style: style, tinted: prominent)
        }
    }

    /// Opaque fallback: same checklist as glass, no translucency. Useful for contrast-critical
    /// surfaces.
    public struct BNSolidTabBarMaterial: BNTabBarMaterial {
        private let color: UIColor

        public init(color: UIColor = .secondarySystemBackground) {
            self.color = color
        }

        public var allowsLensSwell: Bool {
            false
        }

        public func makeSurface() -> BNTabBarSurface {
            let view = UIView()
            view.backgroundColor = color
            view.bnApplyCapsule()
            return BNTabBarSurface(view: view, contentContainer: view)
        }

        /// The bar's own paint; a prominent action takes its fill from its style instead.
        public func makeActionMaterial(prominent: Bool) -> any BNButtonMaterial {
            prominent ? BNSolidButtonMaterial() : BNSolidButtonMaterial(fill: color)
        }
    }

    public extension BNTabBarView {
        /// The material a bar takes when none is given: Liquid Glass on iOS 26, the blur plate
        /// below it.
        static var standardMaterial: any BNTabBarMaterial {
            if #available(iOS 26.0, *) {
                return BNGlassTabBarMaterial()
            }
            return BNBlurTabBarMaterial()
        }
    }
#endif
