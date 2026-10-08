#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        /// Rebuilds the view tree.
        ///
        /// Called when something baked into the views changes — the style, the material, the fonts —
        /// and never for a value that is read at the moment it is used. That split is what lets the
        /// gallery drag a spring slider without the button flickering: motion and metrics take a
        /// re-layout, colours and fonts take a rebuild.
        func rebuild() {
            activeTheme = resolvedTheme
            activeStyle = style
            interaction.snapWindow = activeTheme.motion.snapWindow
            interaction.hapticMergeWindow = activeTheme.motion.hapticMergeWindow
            interaction.cooldown = activeTheme.motion.cooldown

            scaleAnimation?.interrupt()
            scaleAnimation = nil

            buildHierarchy()
            // Before the first state reaches the new views: the old tree's layout would hand them
            // an axis and an icon scale solved for content that is no longer there.
            invalidateSolvedLayout()
            applyState(transition: .immediate)
            updateAccessibility()
        }

        /// Applies the current state to every layer at once.
        ///
        /// One entry point on purpose: a press, a status change and a rebuild all pass through here,
        /// so they cannot end up disagreeing about what the button looks like.
        func applyState(transition: BNTransition) {
            let effective = pendingStatusTransition ?? transition
            let surfaceState = BNButtonSurfaceState(
                isPressed: isPressedByTouch,
                status: status,
                isFocused: isFocused,
            )
            surface?.apply(surfaceState, effective)
            contentView?.apply(state: contentState, transition: effective)
            applyPressedScale(isPressedByTouch, transition: effective)
            applyBorder(transition: effective)
            applyLoading(transition: effective)
        }

        var contentState: BNButtonContentState {
            // Solved on the spot between an invalidation and the next layout pass. A default in its
            // place would be wrong for a lone icon: a scale of 1 pushes a shrunk glyph back across
            // the edge, and Auto Layout breaks a constraint for the frame it takes to notice.
            let output = solvedOutput ?? solveLayout(availableWidth: bounds.width)
            return BNButtonContentState(
                isPressed: isPressedByTouch,
                status: status,
                isFocused: isFocused,
                axis: output.axis,
                numberOfLines: output.numberOfLines,
                iconScale: output.iconScale,
                alignment: configuration.alignment,
                style: activeStyle,
                size: size,
                theme: activeTheme,
            )
        }
    }
#endif
