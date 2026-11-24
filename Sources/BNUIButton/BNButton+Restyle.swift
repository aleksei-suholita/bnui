#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        /// Carries a new ``style`` or ``material`` into the views.
        ///
        /// In place when the surface can take it — the same material in other colours, glass in
        /// another glass with the same answer to a finger: the colours move on the theme's
        /// state-change curve, and a press under way carries on. Otherwise the views are made
        /// again, and the new surface takes the press over from where it had got to.
        func restyle() {
            activeStyle = style
            guard let surface, surface.restyle(activeStyle, resolvedMaterial) else {
                rebuild()
                return
            }
            updateBorderView()
            applyLooks(transition: window == nil ? .immediate : .curve(activeTheme.motion.stateChange))
        }

        /// The border comes and goes with the style.
        private func updateBorderView() {
            guard let container = surface?.contentContainer else { return }
            if activeStyle.border == nil {
                borderView?.removeFromSuperview()
                borderView = nil
            } else if borderView == nil {
                borderView = makeBorderView(in: container)
            }
        }
    }
#endif
