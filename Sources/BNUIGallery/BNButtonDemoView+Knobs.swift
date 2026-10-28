#if canImport(UIKit)
    import BNUI
    import UIKit

    // MARK: - Knob hooks

    //
    // One method per knob, in an extension so the bench itself stays a view rather than a
    // control panel with a view attached.

    extension BNButtonDemoView {
        func setTitle(_ title: String) {
            titleText = title.isEmpty ? Defaults.title : title
            applyContent()
        }

        func setContentKind(index: Int) {
            contentKind = index
            applyContent()
        }

        /// One past the symbols is the picture in its own colours.
        func setIcon(index: Int) {
            guard (0 ... Self.iconNames.count).contains(index) else { return }
            iconIndex = index
            applyContent()
        }

        func setLongTitle(_ long: Bool) {
            usesLongTitle = long
            applyContent()
        }

        func setTitleBehavior(index: Int) {
            button.configuration.titleBehavior = switch index {
            case 1: .wrap(lines: 2)
            case 2: .wrap(lines: 0)
            default: .truncate
            }
        }

        /// Rebuilds the content from the knobs that feed it. One place, so the icon knob and the
        /// title knob cannot each half-apply their own version.
        private func applyContent() {
            let title = usesLongTitle ? Self.longTitle : titleText
            let icon: BNButtonIcon = Self.iconNames.indices.contains(iconIndex)
                ? .symbol(Self.iconNames[iconIndex])
                : .image(Self.picture, rendering: .original)

            // Only the custom-view case swaps the renderer; everything else goes back to standard,
            // or a stale custom renderer would keep drawing over the title.
            button.contentRenderer = contentKind == 4
                ? BNCustomViewContentRenderer(identity: "gallery.badge") { Self.makeCustomGlyph() }
                : nil

            button.content = switch contentKind {
            case 1: BNButtonContent(title: title, leadingIcon: icon)
            case 2: BNButtonContent(title: title, trailingIcon: icon)
            // An icon on its own has no words, so it carries a label the way the spec demands.
            case 3: .icon(icon, accessibilityLabel: "Settings")
            case 4: BNButtonContent(accessibilityLabel: "Custom glyph")
            default: .title(title)
            }
        }

        private static func makeCustomGlyph() -> UIView {
            let view = UIView()
            view.backgroundColor = .white.withAlphaComponent(0.9)
            view.bnApplyCapsule()
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: 22),
                view.heightAnchor.constraint(equalToConstant: 22),
            ])
            return view
        }

        func setSize(index: Int) {
            guard Self.sizes.indices.contains(index) else { return }
            var size = Self.sizes[index]
            size.shape = cornerShape
            button.size = size
        }

        func setWidth(index: Int) {
            switch index {
            case 1: button.configuration.width = .fill
            case 2: button.configuration.width = .fixed(200)
            default: button.configuration.width = .hug
            }
            applyWidthConstraints()
        }

        func setAlignment(index: Int) {
            button.configuration.alignment = switch index {
            case 0: .leading
            case 2: .trailing
            default: .center
            }
        }

        func setStyle(index: Int) {
            guard Self.styles.indices.contains(index) else { return }
            button.style = Self.styles[index]
        }

        func setMaterial(index: Int) {
            let materials = Self.materials
            guard materials.indices.contains(index) else { return }
            button.material = materials[index].material
        }

        func setCorner(index: Int) {
            cornerShape = index == 1 ? .rounded(radius: 12) : .capsule
            button.size.shape = cornerShape
        }

        func setStatus(index: Int) {
            let status: BNButtonStatus = switch index {
            case 1: .disabled
            case 2: .loading
            default: .enabled
            }
            button.setStatus(status, animated: true)
            log("status → \(index == 1 ? "disabled" : index == 2 ? "loading" : "enabled")")
        }

        func setBadge(index: Int) {
            button.badge = switch index {
            case 1: .count(3, accessibilityLabel: "3 unread")
            case 2: .count(120, accessibilityLabel: "120 unread")
            case 3: .text("New")
            case 4: .dot(accessibilityLabel: "Unread")
            default: nil
            }
        }

        func setBadgePosition(index: Int) {
            button.theme.badge.position = index == 1 ? .bottomTrailing : .topTrailing
        }

        /// None, a tap that opens the menu, or a long press that does while a tap fires.
        func setMenu(index: Int) {
            button.menu = index == 0 ? nil : makeMenu()
            button.showsMenuAsPrimaryAction = index == 1
        }

        func setCooldown(_ cooldown: Double) {
            button.theme.motion.cooldown = cooldown
        }

        func setRejection(_ enabled: Bool) {
            button.theme.motion.rejection = enabled ? .standard : .none
        }

        func setRejectionHaptic(_ enabled: Bool) {
            button.theme.motion.rejection.isHapticEnabled = enabled
        }

        func setHapticsEnabled(_ enabled: Bool) {
            button.haptics.isEnabled = enabled
        }

        /// The hold below which a tap answers with one tick instead of two. 0 — always two.
        func setHapticMergeWindow(_ window: Double) {
            button.theme.motion.hapticMergeWindow = window
        }

        func setShowsHitTarget(_ shows: Bool) {
            button.showsHitTargetOutline = shows
        }

        /// The theme goes back first: the knobs after it set what it holds.
        func reset() {
            button.theme = .standard
            setLongTitle(Defaults.usesLongTitle)
            setIcon(index: Defaults.iconIndex)
            setContentKind(index: Defaults.contentIndex)
            setTitleBehavior(index: Defaults.titleBehaviorIndex)
            setTitle(Defaults.title)
            setSize(index: Defaults.sizeIndex)
            setWidth(index: Defaults.widthIndex)
            setAlignment(index: Defaults.alignmentIndex)
            setStyle(index: Defaults.styleIndex)
            setMaterial(index: Defaults.materialIndex)
            setCorner(index: Defaults.cornerIndex)
            setStatus(index: Defaults.statusIndex)
            setBadge(index: Defaults.badgeIndex)
            setMenu(index: Defaults.menuIndex)
            setCooldown(Defaults.cooldown)
            setRejection(Defaults.rejectionEnabled)
            setRejectionHaptic(Defaults.rejectionHaptic)
            setHapticsEnabled(Defaults.hapticsEnabled)
            setHapticMergeWindow(Defaults.hapticMergeWindow)
            setShowsHitTarget(Defaults.showsHitTarget)
        }

        private func applyWidthConstraints() {
            NSLayoutConstraint.deactivate(widthConstraints)
            widthConstraints = switch button.configuration.width {
            case .fill:
                [
                    button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: BNGallerySpacing.m),
                    button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -BNGallerySpacing.m),
                ]
            // Held inside the stage the way a host's screen holds it: a hugging title too long
            // for the width meets the edge and wraps or truncates there, instead of running off.
            case .hug, .fixed:
                [
                    button.centerXAnchor.constraint(equalTo: centerXAnchor),
                    button.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: BNGallerySpacing.m),
                    button.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -BNGallerySpacing.m),
                ]
            }
            NSLayoutConstraint.activate(widthConstraints)
        }
    }
#endif
