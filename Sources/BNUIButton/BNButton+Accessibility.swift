#if canImport(UIKit)
    import UIKit

    extension BNButton {
        // MARK: - Environment

        /// Reduce Motion, as the control sees it — the system's answer unless the host forced one.
        var reducesMotion: Bool {
            accessibilityOverrides.resolvedReduceMotion(system: UIAccessibility.isReduceMotionEnabled)
        }

        var reducesTransparency: Bool {
            accessibilityOverrides.resolvedReduceTransparency(system: UIAccessibility.isReduceTransparencyEnabled)
        }

        /// The theme after accessibility has had its say. Resolved once per rebuild and stored in
        /// `activeTheme`, so no two parts of the control can disagree about the current values.
        var resolvedTheme: BNButtonTheme {
            var resolved = theme
            resolved.motion = theme.motion.resolved(reduceMotion: reducesMotion)
            resolved.geometry = theme.geometry.resolved(reduceMotion: reducesMotion)
            return resolved
        }

        /// What the host or the style asked for, before the control has its say.
        var requestedMaterial: any BNButtonMaterial {
            material ?? activeStyle.material
        }

        /// Reduce Transparency is answered by the control as a whole rather than by each material.
        /// A material can only speak for itself, and the user turned translucency off everywhere.
        /// The style gives way, never the control.
        var resolvedMaterial: any BNButtonMaterial {
            reducesTransparency ? activeStyle.opaqueFallback : requestedMaterial
        }

        func observeEnvironment() {
            let center = NotificationCenter.default
            let names: [Notification.Name] = [
                UIAccessibility.reduceMotionStatusDidChangeNotification,
                UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            ]
            for name in names {
                center.addObserver(self, selector: #selector(bnEnvironmentDidChange), name: name, object: nil)
            }

            // Below iOS 17 the same two changes arrive through `traitCollectionDidChange`.
            guard #available(iOS 17.0, *) else { return }
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (button: BNButton, _) in
                // Dynamic Type changes the fonts baked into the content view, so this is a rebuild
                // rather than a re-layout.
                button.rebuildForEnvironment()
            }

            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (button: BNButton, _) in
                // Light and dark resolve to different colours, and the border is a layer colour,
                // which does not follow the appearance by itself.
                button.rebuildForEnvironment()
            }
        }

        /// iOS 16 has no trait registration: the changes registered for above arrive here instead.
        func legacyTraitsDidChange(from previous: UITraitCollection?) {
            guard previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
                || previous?.userInterfaceStyle != traitCollection.userInterfaceStyle
            else { return }
            rebuildForEnvironment()
        }

        @objc private func bnEnvironmentDidChange() {
            rebuildForEnvironment()
        }

        /// Rebuilding tears down the views, and doing that under a finger cancels the touch. An
        /// accessibility switch is not an interaction, so it waits for the finger to lift.
        func rebuildForEnvironment() {
            guard !isTracking else {
                pendingEnvironmentRebuild = true
                return
            }
            rebuild()
        }

        func applyPendingEnvironmentRebuild() {
            guard pendingEnvironmentRebuild else { return }
            pendingEnvironmentRebuild = false
            rebuild()
        }

        // MARK: - VoiceOver

        func updateAccessibility() {
            isAccessibilityElement = true
            accessibilityLabel = content.resolvedAccessibilityLabel
            updateAccessibilityState()

            // Compiled out of release builds by the optimiser, so no `#if` is needed — and unlike
            // one, this fires no matter how the library itself was built.
            assert(
                content.resolvedAccessibilityLabel != nil,
                "BNButton without a title needs an accessibilityLabel — a symbol is not a word, "
                    + "and VoiceOver has nothing to read without one.",
            )
        }

        func updateAccessibilityState() {
            var traits: UIAccessibilityTraits = .button
            if status == .disabled {
                traits.insert(.notEnabled)
            }
            accessibilityTraits = traits
            // Loading is reported as a value rather than by disabling the button: a busy button is
            // still there, it is just not ready.
            accessibilityValue = status == .loading ? configuration.accessibility.busyValue : nil
            accessibilityHint = status == .disabled ? configuration.accessibility.disabledHint : nil
        }
    }
#endif
