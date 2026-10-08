#if canImport(UIKit)
    import UIKit

    // MARK: - Light and dark from the material

    extension BNTabBarView {
        /// The sections take their light or dark appearance from the material, not from the screen.
        ///
        /// System glass tracks the brightness of what lies beneath it and flips between light and
        /// dark to keep its content legible, handing the flip to the views inside it as an ordinary
        /// trait change — verified on device with the gallery's glass probe. The sections are not
        /// inside the glass: the lens draws them beside it, so the flip would pass them by and leave
        /// dark icons on glass that has gone dark. A probe inside the material reads what the
        /// material hands its content, and the lens is told the same.
        ///
        /// A material that does not adapt — the solid one — hands back the bar's own appearance, so
        /// following it changes nothing there.
        func followAppearance(of surface: BNTabBarSurface) {
            // Only glass adapts, and glass arrives with iOS 26. Before it every material hands back
            // the bar's own appearance, which the lens has anyway.
            guard #available(iOS 26.0, *) else { return }
            // Zero-sized and never drawn: it exists only to inherit what the material gives its
            // content.
            let probe = UIView()
            probe.isUserInteractionEnabled = false
            surface.contentContainer.addSubview(probe)
            probe.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (probe: UIView, _) in
                self?.applyAppearance(probe.traitCollection.userInterfaceStyle, animated: true)
            }
            applyAppearance(probe.traitCollection.userInterfaceStyle, animated: false)
        }

        private func applyAppearance(_ style: UIUserInterfaceStyle, animated: Bool) {
            guard let lens, lens.overrideUserInterfaceStyle != style else { return }
            guard animated, window != nil else {
                lens.overrideUserInterfaceStyle = style
                return
            }
            // The glass changes look gradually; the sections fade with it rather than snap.
            UIView.transition(
                with: lens,
                duration: activeTheme.motion.crossFade.duration,
                options: [.transitionCrossDissolve, .allowUserInteraction],
            ) {
                lens.overrideUserInterfaceStyle = style
            }
        }
    }
#endif
