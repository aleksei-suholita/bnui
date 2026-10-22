#if canImport(UIKit)
    import BNUICore
    import UIKit

    // MARK: - Accessibility settings and the keyboard

    extension BNTabBarView {
        /// iOS 16 has no trait registration: the text size registered for in `init` arrives here.
        func legacyTraitsDidChange(from previous: UITraitCollection?) {
            guard previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory else { return }
            rebuild()
        }

        /// Motion actually used, after Reduce Motion has had its say.
        ///
        /// Movement itself never stops — the lens travelling *is* the navigation, not decoration
        /// on top of it — only the springs degrade.
        var resolvedMotion: BNTabBarMotion {
            theme.motion.resolved(reduceMotion: UIAccessibility.isReduceMotionEnabled)
        }

        /// Theme after accessibility overrides.
        var resolvedTheme: BNTabBarTheme {
            var resolved = theme
            resolved.motion = resolvedMotion
            return resolved
        }

        /// Reduce Transparency is decided **here**, not inside the material.
        ///
        /// A material can only speak for itself, and the lens is translucent too — leaving each
        /// piece to opt out separately is how you end up with an opaque bar and a see-through
        /// marker on it. So the control overrides both together, whatever the host asked for.
        var reducesTransparency: Bool {
            UIAccessibility.isReduceTransparencyEnabled
        }

        var resolvedMaterial: any BNTabBarMaterial {
            reducesTransparency ? BNSolidTabBarMaterial() : material
        }

        var resolvedLensRenderer: any BNTabBarLensRenderer {
            reducesTransparency ? BNMaskedLensRenderer() : lensRenderer
        }

        // MARK: - Observation

        /// One place to re-read the environment. Settings changes arrive as notifications, text
        /// size as a trait change; both end in the same rebuild.
        func startObservingEnvironment() {
            let centre = NotificationCenter.default
            for name in [
                UIAccessibility.reduceMotionStatusDidChangeNotification,
                UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            ] {
                centre.addObserver(
                    self,
                    selector: #selector(environmentDidChange),
                    name: name,
                    object: nil,
                )
            }
            centre.addObserver(
                self,
                selector: #selector(keyboardWillShow),
                name: UIResponder.keyboardWillShowNotification,
                object: nil,
            )
            centre.addObserver(
                self,
                selector: #selector(keyboardWillHide),
                name: UIResponder.keyboardWillHideNotification,
                object: nil,
            )
        }

        @objc private func environmentDidChange() {
            rebuild()
        }

        // MARK: - Keyboard

        /// The bar steps aside for the keyboard on its own — one of the three hiding cases the
        /// spec assigns to the control rather than the host.
        @objc private func keyboardWillShow(_ notification: Notification) {
            setKeyboardHidden(true, notification: notification)
        }

        @objc private func keyboardWillHide(_ notification: Notification) {
            setKeyboardHidden(false, notification: notification)
        }

        private func setKeyboardHidden(_ hidden: Bool, notification: Notification) {
            guard isHiddenByKeyboard != hidden else { return }
            isHiddenByKeyboard = hidden
            // Ride the keyboard's own timing, so the two move together instead of racing.
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
            applyPresentation(
                transition: .curve(BNCurve(duration: duration ?? theme.motion.visibility.duration)),
            )
        }
    }
#endif
