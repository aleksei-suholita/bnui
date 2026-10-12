#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        /// Builds the badge's place, empty or not, so a badge arriving later is shown in place.
        ///
        /// The badge hangs half outside the outline, so it lives outside the material, which may
        /// keep what it holds inside its shape. Its host is a twin of the surface instead: the same
        /// frame, above it, taking the same press compression.
        func makeBadge() {
            let host = UIView()
            host.isUserInteractionEnabled = false
            host.translatesAutoresizingMaskIntoConstraints = false
            addSubview(host)

            let view = BNBadgeView(theme: activeTheme.badge, crossFade: activeTheme.motion.stateChange)
            host.addSubview(view)
            let offsets = badgeOffsets
            // The badge view is a point, so its leading edge is its centre — and leading to
            // trailing is a pair a right-to-left layout mirrors.
            badgeAnchors = [
                view.leadingAnchor.constraint(equalTo: host.trailingAnchor, constant: offsets.horizontal),
                activeTheme.badge.position == .bottomTrailing
                    ? view.centerYAnchor.constraint(equalTo: host.bottomAnchor, constant: offsets.vertical)
                    : view.centerYAnchor.constraint(equalTo: host.topAnchor, constant: offsets.vertical),
            ]
            NSLayoutConstraint.activate([
                host.topAnchor.constraint(equalTo: topAnchor),
                host.bottomAnchor.constraint(equalTo: bottomAnchor),
                host.leadingAnchor.constraint(equalTo: leadingAnchor),
                host.trailingAnchor.constraint(equalTo: trailingAnchor),
            ] + badgeAnchors)

            badgeHost = host
            badgeView = view
            view.show(badge, transition: .immediate)
        }

        func showBadge(transition: BNTransition) {
            badgeView?.show(badge, transition: transition)
            updateAccessibilityState()
        }

        /// Keeps the badge on the outline as the button changes height: a capsule's ends round
        /// with it.
        func updateBadgeAnchors() {
            let offsets = badgeOffsets
            guard badgeAnchors.count == 2, badgeAnchors[1].constant != offsets.vertical else { return }
            badgeAnchors[0].constant = offsets.horizontal
            badgeAnchors[1].constant = offsets.vertical
        }

        /// From the trailing edge and from the top or the bottom to where the outline crosses the
        /// corner's diagonal. A capsule rounds by its shorter side, as the shape is drawn.
        private var badgeOffsets: (horizontal: CGFloat, vertical: CGFloat) {
            let inset = size.shape.cornerInset(
                forHeight: min(bounds.width, bounds.height),
                maximumRadius: size.maximumCornerRadius,
            )
            return (-inset, activeTheme.badge.position == .bottomTrailing ? -inset : inset)
        }
    }
#endif
