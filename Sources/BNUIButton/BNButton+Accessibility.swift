#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        // MARK: - Environment

        /// Reduce Motion, as the control sees it — the system's answer unless a stage above it forced
        /// one.
        var reducesMotion: Bool {
            bnReducesMotion
        }

        var reducesTransparency: Bool {
            bnReducesTransparency
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

            registerForTraitChanges(Self.bnForcedAccessibilityTraits) { (button: BNButton, _) in
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
        ///
        /// The interaction is asked rather than `isTracking`: the button declines `UIControl`
        /// tracking, so `isTracking` is always false.
        func rebuildForEnvironment() {
            guard interaction.downTime == nil else {
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

        /// The label is not set here: ``BNButton/accessibilityLabel`` answers from the host's label
        /// or the content on every read, so a rebuild cannot wipe what the host set.
        func updateAccessibility() {
            isAccessibilityElement = true
            updateAccessibilityState()
        }

        func updateAccessibilityState() {
            var traits: UIAccessibilityTraits = .button
            if status == .disabled {
                traits.insert(.notEnabled)
            }
            accessibilityTraits = traits
            // Loading is reported as a value rather than by disabling the button: a busy button is
            // still there, it is just not ready. The badge's words join it — "3 unread".
            let values = [status == .loading ? configuration.accessibility.busyValue : nil, badgeView?.spokenText]
            let value = values.compactMap(\.self).joined(separator: ", ")
            accessibilityValue = value.isEmpty ? nil : value
            accessibilityHint = status == .disabled ? configuration.accessibility.disabledHint : nil
        }
    }
#endif
