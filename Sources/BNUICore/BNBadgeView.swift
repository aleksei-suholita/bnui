#if canImport(UIKit)
    import UIKit

    /// A ``BNBadge`` drawn over a control — a tab bar's section, a button — the way the kit's
    /// controls draw theirs.
    ///
    /// The view has no size of its own: it is the point the badge hangs from, and the control
    /// pins its centre there — a trailing corner of a section's icon, the rim of a button, at the
    /// top or the bottom as the theme's ``BNBadgeTheme/position`` says.
    /// A dot sits centred on that point; a text reaches back over it by the theme's overlap and
    /// grows away from it, so a long one never covers what it marks. Both are made once, hidden,
    /// so that a badge arriving later — or changing kind — is shown in place instead of the view
    /// being made again.
    ///
    /// It takes no touches and says nothing to VoiceOver: the control it marks speaks for it, with
    /// ``spokenText`` in its value.
    ///
    /// A tab bar's own item renderer draws its sections' badges with it, and so can one of the
    /// host's:
    ///
    /// ```swift
    /// let badge = BNBadgeView(theme: theme.badge, crossFade: theme.motion.crossFade)
    /// addSubview(badge)
    /// badge.pin(toCornerOf: iconView)
    /// badge.keepInside(self)
    /// badge.show(item.badge, transition: .immediate)
    /// ```
    public final class BNBadgeView: UIView {
        /// The badge on show.
        public private(set) var badge: BNBadge?

        private let theme: BNBadgeTheme
        /// How long a changed number cross-fades — the control's own cross-fade.
        private let crossFade: BNCurve
        private let label = BNBadgeLabel()
        private let dot = UIView()
        /// The pop in or out, kept so the next change can take it over mid-flight.
        private var animation: BNAnimation?

        /// A badge view showing nothing yet.
        ///
        /// - Parameters:
        ///   - theme: How the badge looks — the theme's own for the control it marks, such as
        ///     `BNTabBarTheme.badge`.
        ///   - crossFade: How long a changed number cross-fades: the control's own cross-fade,
        ///     such as `BNTabBarTheme.motion.crossFade`.
        public init(theme: BNBadgeTheme, crossFade: BNCurve) {
            self.theme = theme
            self.crossFade = crossFade
            super.init(frame: .zero)
            build()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        /// Hangs the badge from `view`'s trailing corner — the top or the bottom, as the theme's
        /// ``BNBadgeTheme/position`` says — the way a tab bar's section hangs it from its icon.
        /// Both views must already share a superview.
        public func pin(toCornerOf view: UIView) {
            let corner = theme.position == .bottomTrailing ? view.bottomAnchor : view.topAnchor
            NSLayoutConstraint.activate([
                centerXAnchor.constraint(equalTo: view.trailingAnchor),
                centerYAnchor.constraint(equalTo: corner),
            ])
        }

        /// Keeps a text from reaching past `view`'s trailing edge — a section of a bar, beside which
        /// the next one starts. Where there is no room to grow away from the point, the text slides
        /// back over what it marks: covering a little of one's own icon reads better than lying on
        /// the neighbour's.
        public func keepInside(_ view: UIView) {
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor).isActive = true
        }

        /// What VoiceOver says for the badge on show: the host's label, or else what it shows.
        /// `nil` when nothing is drawn. The control the badge marks says it in its
        /// `accessibilityValue`.
        public var spokenText: String? {
            badge?.spokenText(countLimit: theme.countLimit)
        }

        /// Shows `newBadge`, or none: popping in or out, a changed number cross-fading. An
        /// immediate transition puts it on screen at once.
        public func show(_ newBadge: BNBadge?, transition: BNTransition) {
            let old = badge?.appearance(countLimit: theme.countLimit)
            let new = newBadge?.appearance(countLimit: theme.countLimit)
            badge = newBadge
            guard old != new else { return }

            animation?.interrupt()
            switch new {
            case let .text(text)?:
                if case .text? = old {
                    changeText(to: text, transition: transition)
                } else {
                    label.text = text
                    hide(dot, transition: transition)
                    reveal(label, transition: transition)
                }
            case .dot?:
                hide(label, transition: transition)
                reveal(dot, transition: transition)
            case nil:
                hide(label, transition: transition)
                hide(dot, transition: transition)
            }
        }

        // MARK: - Building

        private func build() {
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            accessibilityElementsHidden = true

            label.font = theme.font
            label.adjustsFontForContentSizeCategory = true
            label.maximumContentSizeCategory = theme.maximumContentSizeCategory
            label.textColor = theme.text
            label.backgroundColor = theme.background
            label.textAlignment = .center
            label.bnApplyCapsule()
            label.clipsToBounds = true

            dot.backgroundColor = theme.background
            dot.bnApplyCapsule()

            for view in [label, dot] {
                view.isHidden = true
                view.isUserInteractionEnabled = false
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
            }
            translatesAutoresizingMaskIntoConstraints = false
            // Below required, so a bound from ``keepInside(_:)`` can move the text back.
            let pinned = label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -theme.overlap)
            pinned.priority = .defaultHigh
            NSLayoutConstraint.activate([
                pinned,
                // A point: its leading edge is its centre, so the text is pinned by the same
                // leading anchors a right-to-left layout mirrors.
                widthAnchor.constraint(equalToConstant: 0),
                heightAnchor.constraint(equalToConstant: 0),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
                label.widthAnchor.constraint(greaterThanOrEqualTo: label.heightAnchor),
                dot.centerXAnchor.constraint(equalTo: centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: theme.dotSide),
                dot.heightAnchor.constraint(equalTo: dot.widthAnchor),
            ])
        }

        // MARK: - Showing

        /// A badge arriving pops in from the theme's appear scale.
        private func reveal(_ view: UIView, transition: BNTransition) {
            view.isHidden = false
            guard transition != .immediate else {
                view.alpha = 1
                view.transform = .identity
                return
            }
            let scale = theme.appearScale
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            animation = transition.run {
                view.alpha = 1
                view.transform = .identity
            }
        }

        /// A badge leaving shrinks back the way it came. Hidden only once the animation reached
        /// its end: one taken over by a badge arriving again must not hide the new one.
        private func hide(_ view: UIView, transition: BNTransition) {
            guard !view.isHidden else { return }
            guard transition != .immediate else {
                view.isHidden = true
                return
            }
            let scale = theme.appearScale
            animation = transition.run {
                view.alpha = 0
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
            } completion: { finished in
                guard finished else { return }
                view.isHidden = true
                view.transform = .identity
            }
        }

        /// A number changing cross-fades, and the capsule follows the new width.
        private func changeText(to text: String, transition: BNTransition) {
            guard transition != .immediate else {
                label.text = text
                return
            }
            UIView.transition(
                with: label,
                duration: crossFade.duration,
                options: [.transitionCrossDissolve, .allowUserInteraction],
            ) { [label] in
                label.text = text
            }
            transition.run { [weak self] in
                self?.layoutIfNeeded()
            }
        }
    }
#endif
