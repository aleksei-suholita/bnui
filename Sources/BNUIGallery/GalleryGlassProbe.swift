#if canImport(UIKit)
    import BNUI
    import UIKit

    /// An invisible view dropped into a glass effect's content view, reporting the appearance the
    /// glass hands to what sits inside it.
    ///
    /// System glass flips between light and dark with the backdrop. Whether a plain
    /// `UIVisualEffectView` with `UIGlassEffect` passes that flip on to its content is not
    /// documented, and there is no public API for it; the probe asked the only public question
    /// left — what the trait collection inside the glass says — and on device it does flip. The
    /// tab bar follows it now, and the probe stays so the feed shows when the glass flips.
    ///
    /// Reports once when it lands in a window, then only when the answer changes.
    final class GalleryGlassProbe: UIView {
        var onChange: ((String) -> Void)?
        private var lastReport: String?

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            // Every trait that can change how a colour resolves, not only the interface style:
            // the glass may flip through a trait of its own, and resolving `label` catches that.
            // Glass arrives with iOS 26, so there is nothing to probe before it but the screen's own
            // appearance — reported once, when the probe reaches a window.
            guard #available(iOS 17.0, *) else { return }
            let traits = UITraitCollection.systemTraitsAffectingColorAppearance
            registerForTraitChanges(traits) { (probe: GalleryGlassProbe, _) in
                probe.report()
            }
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            report()
        }

        private func report() {
            let style = switch traitCollection.userInterfaceStyle {
            case .light: "light"
            case .dark: "dark"
            case .unspecified: "unspecified"
            @unknown default: "unknown"
            }
            var white: CGFloat = 0
            UIColor.label.resolvedColor(with: traitCollection).getWhite(&white, alpha: nil)
            let text = "glass content: \(style), label \(white > 0.5 ? "light" : "dark")"
            guard text != lastReport else { return }
            lastReport = text
            onChange?(text)
        }
    }

    /// Any tab-bar material with a `GalleryGlassProbe` inside its content view — the kit's own
    /// glass, so the bench tests the surface the bar really draws.
    struct GalleryProbedTabBarMaterial: BNTabBarMaterial {
        let base: any BNTabBarMaterial
        let onChange: (String) -> Void

        var allowsLensSwell: Bool {
            base.allowsLensSwell
        }

        func makeSurface() -> BNTabBarSurface {
            let surface = base.makeSurface()
            let probe = GalleryGlassProbe()
            probe.onChange = onChange
            surface.contentContainer.addSubview(probe)
            return surface
        }

        func makeActionMaterial(prominent: Bool) -> any BNButtonMaterial {
            base.makeActionMaterial(prominent: prominent)
        }
    }
#endif
