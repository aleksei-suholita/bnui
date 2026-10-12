#if canImport(UIKit)
    import UIKit

    /// The plate every blur material draws: a system material clipped to the shape, a hairline rim
    /// on the edge and a soft shadow outside — the translucent plate floating controls wore before
    /// Liquid Glass.
    ///
    /// The material is the system's own `UIBlurEffect` — `.systemUltraThinMaterial` through
    /// `.systemThickMaterial` — so its tint, its saturation, light and dark, Reduce Transparency and
    /// Increase Contrast are the system's too. The rim and the shadow are the kit's: a floating
    /// control on a backdrop of its own colour needs an edge, and the system material has none.
    /// Unlike glass it exists on every iOS the kit supports; on iOS 26 it is one more material to
    /// choose, not a stand-in for glass.
    ///
    /// The rim and shadow values follow apps that drew this look by hand before iOS 26 and are a
    /// starting point, to be settled on a device over real content.
    package final class BNBlurPlateView: UIView {
        /// The hairline on the edge that catches the light.
        private static let rim = UIColor { traits in
            UIColor(white: 1, alpha: traits.userInterfaceStyle == .dark ? 0.3 : 0.6)
        }

        private static let rimWidth: CGFloat = 0.8
        private static let shadow = UIColor(white: 0, alpha: 0.04)
        private static let shadowRadius: CGFloat = 20
        private static let shadowOffset = CGSize(width: 0, height: 1)

        /// Where the material's owner puts its content — above the fill, inside the clip.
        package let contentView: UIView
        private let effectView: UIVisualEffectView
        private let fillView = UIView()

        package var shape: BNShape {
            didSet { setNeedsLayout() }
        }

        /// The roundest the corners get — see ``BNShape/cornerRadius(forHeight:maximumRadius:)``.
        package var maximumRadius: CGFloat {
            didSet { setNeedsLayout() }
        }

        /// A colour laid over the material: the tint of a tinted plate, which changes with the
        /// control's state. `nil` — the material as the system draws it.
        package var fill: UIColor? {
            didSet { fillView.backgroundColor = fill }
        }

        package init(effect: UIBlurEffect.Style, shape: BNShape, maximumRadius: CGFloat = .infinity, fill: UIColor? = nil) {
            self.shape = shape
            self.maximumRadius = maximumRadius
            self.fill = fill
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: effect))
            contentView = effectView.contentView
            super.init(frame: .zero)

            // Every layer stays open to touches, so a touch on the plate lands in the content view,
            // where a control may keep its recognizers.
            isUserInteractionEnabled = true
            effectView.isUserInteractionEnabled = true
            contentView.isUserInteractionEnabled = true

            effectView.frame = bounds
            effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            effectView.clipsToBounds = true
            effectView.layer.cornerCurve = .continuous
            effectView.layer.borderWidth = Self.rimWidth
            addSubview(effectView)

            fillView.frame = contentView.bounds
            fillView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            fillView.isUserInteractionEnabled = false
            fillView.backgroundColor = fill
            contentView.addSubview(fillView)

            layer.shadowOpacity = 1
            layer.shadowRadius = Self.shadowRadius
            layer.shadowOffset = Self.shadowOffset
            applyColours()
            if #available(iOS 17.0, *) {
                registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: BNBlurPlateView, _) in
                    view.applyColours()
                }
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override package func layoutSubviews() {
            super.layoutSubviews()
            // By the shorter side, as `UICornerConfiguration.capsule()` rounds: a capsule standing
            // upright — a tab bar turned into a column — rounds by its width.
            let radius = shape.cornerRadius(forHeight: min(bounds.width, bounds.height), maximumRadius: maximumRadius)
            effectView.layer.cornerRadius = radius
            // A shadow without a path is worked out from the rendered pixels on every frame.
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        }

        override package func traitCollectionDidChange(_ previous: UITraitCollection?) {
            super.traitCollectionDidChange(previous)
            // iOS 16 has no trait registration; the same change arrives here instead.
            guard #unavailable(iOS 17.0) else { return }
            if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
                applyColours()
            }
        }

        /// Layer colours are fixed values and do not follow light and dark by themselves.
        private func applyColours() {
            effectView.layer.borderColor = Self.rim.resolvedColor(with: traitCollection).cgColor
            layer.shadowColor = Self.shadow.resolvedColor(with: traitCollection).cgColor
        }
    }
#endif
