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
            // Where the press had got to, stopped there: the new surface takes it over.
            let squeeze = surface?.view.transform

            buildHierarchy()
            // Until the next layout pass the new views stand in the button's corner, at no size:
            // a change measured on them would start from there.
            pendingLayout.afterRebuild = true
            pendingLayout.naturalWidth = true
            // Before the first state reaches the new views: the old tree's layout would hand them
            // an axis and an icon scale solved for content that is no longer there.
            invalidateSolvedLayout()
            applyState(transition: .immediate)
            carryPress(from: squeeze)
            updateAccessibility()
        }

        /// Applies the current state to every layer at once.
        ///
        /// One entry point on purpose: a press, a status change and a rebuild all pass through here,
        /// so they cannot end up disagreeing about what the button looks like.
        func applyState(transition: BNTransition) {
            let effective = pendingStatusTransition ?? transition
            applyLooks(transition: effective)
            applyPressedScale(isPressedByTouch, transition: effective)
        }

        /// What the state decides but the press: the colours of the surface and the content, the
        /// border, the spinner. A new style goes through here alone, so a press under way carries on.
        func applyLooks(transition: BNTransition) {
            let surfaceState = BNButtonSurfaceState(
                isPressed: isPressedByTouch,
                status: status,
                isFocused: isFocused,
            )
            surface?.apply(surfaceState, transition)
            contentView?.apply(state: contentState, transition: transition)
            applyBorder(transition: transition)
            applyLoading(transition: transition)
        }

        /// Puts the new surface where the old one's press had got to and lets the press go on from
        /// there. Made at rest, a surface would stand up in one frame — mid-return after a tap that
        /// changed the style, the button would jolt.
        private func carryPress(from squeeze: CGAffineTransform?) {
            guard let squeeze, let surface, window != nil, resolvedMaterial.pressResponse == .control,
                  squeeze != surface.view.transform
            else { return }
            let views = [surface.view] + [badgeHost].compactMap(\.self)
            UIView.performWithoutAnimation {
                for view in views {
                    view.transform = squeeze
                }
            }
            let motion = activeTheme.motion
            applyPressedScale(isPressedByTouch, transition: .spring(isPressedByTouch ? motion.press : motion.releaseSlow))
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
