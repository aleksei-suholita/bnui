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
    /// A badge of ``Material/glass`` lies on the system's glass tinted the theme's background
    /// instead of paint, from iOS 26 — the badge to draw inside system glass, which blends paint
    /// into itself and washes its colour out.
    ///
    /// A tab bar draws its sections' badges with it, of glass and inside its material, and a
    /// renderer of the host's own can draw them inside its sections the same way:
    ///
    /// ```swift
    /// let badge = BNBadgeView(theme: theme.badge, crossFade: theme.motion.crossFade, material: .glass)
    /// addSubview(badge)
    /// badge.pin(toCornerOf: iconView)
    /// badge.keepInside(self)
    /// badge.show(item.badge, transition: .immediate)
    /// ```
    public final class BNBadgeView: UIView {
        /// What a badge is made of.
        public enum Material: Equatable, Sendable {
            /// Paint of the theme's ``BNBadgeTheme/background``.
            case paint
            /// The system's glass tinted the theme's ``BNBadgeTheme/background``, on iOS 26 and
            /// later; paint before it.
            case glass
        }

        /// The badge on show.
        public private(set) var badge: BNBadge?

        private let theme: BNBadgeTheme
        private let material: Material
        /// How long a changed number cross-fades — the control's own cross-fade.
        private let crossFade: BNCurve
        private let label = BNBadgeLabel()
        private let dot = UIView()
        /// Each part's pop in or out, kept so the next change can take that part over mid-flight.
        /// One per part: a dot giving way to a text runs two at once, and one left unkept would
        /// finish later and hide the part that had come back.
        private var animations: [UIView: BNAnimation] = [:]
        /// The glass under each part, for a glass badge; empty for paint.
        private var glasses: [UIView: UIVisualEffectView] = [:]

        /// A badge view showing nothing yet.
        ///
        /// - Parameters:
        ///   - theme: How the badge looks — the theme's own for the control it marks, such as
        ///     `BNTabBarTheme.badge`.
        ///   - crossFade: How long a changed number cross-fades: the control's own cross-fade,
        ///     such as `BNTabBarTheme.motion.crossFade`.
        ///   - material: Paint, or glass for a badge inside system glass.
        public init(theme: BNBadgeTheme, crossFade: BNCurve, material: Material = .paint) {
            self.theme = theme
            self.material = material
            self.crossFade = crossFade
            super.init(frame: .zero)
            build()
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        /// Hangs the badge from `view`'s trailing corner — the top or the bottom, as the theme's
        /// ``BNBadgeTheme/position`` says — the way a tab bar's section hangs it from its icon.
        /// Both views must already be in one hierarchy; the badge may lie in another branch of it,
        /// above a material its anchor is inside.
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

            // Nothing is stopped up front: a part that keeps its place keeps its pop, so a number
            // changing while it pops in still arrives whole.
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
            label.backgroundColor = usesGlass ? .clear : theme.background
            label.textAlignment = .center
            label.bnApplyCapsule()
            label.clipsToBounds = true

            dot.backgroundColor = usesGlass ? .clear : theme.background
            dot.bnApplyCapsule()

            for view in [label, dot] {
                view.isHidden = true
                view.isUserInteractionEnabled = false
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
            }
            if #available(iOS 26.0, *), usesGlass {
                addGlass(under: label)
                addGlass(under: dot)
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

        /// Glass where the theme asks for it and the system has it.
        private var usesGlass: Bool {
            guard #available(iOS 26.0, *) else { return false }
            return material == .glass
        }

        /// A capsule of glass under `part`, its size and shape, shown and hidden with it.
        @available(iOS 26.0, *)
        private func addGlass(under part: UIView) {
            let glass = UIVisualEffectView()
            glass.isHidden = true
            glass.isUserInteractionEnabled = false
            glass.bnApplyCapsule()
            glass.translatesAutoresizingMaskIntoConstraints = false
            insertSubview(glass, belowSubview: part)
            NSLayoutConstraint.activate([
                glass.topAnchor.constraint(equalTo: part.topAnchor),
                glass.bottomAnchor.constraint(equalTo: part.bottomAnchor),
                glass.leadingAnchor.constraint(equalTo: part.leadingAnchor),
                glass.trailingAnchor.constraint(equalTo: part.trailingAnchor),
            ])
            glasses[part] = glass
        }

        // MARK: - Showing

        /// A badge arriving pops in from the theme's appear scale. One still on its way out turns
        /// back from where it is: its leaving is stopped there, so it neither jumps to the start
        /// nor hides at the end.
        private func reveal(_ view: UIView, transition: BNTransition) {
            animations[view]?.interrupt()
            let wasHidden = view.isHidden
            setHidden(false, view)
            guard transition != .immediate else {
                setShown(true, view)
                return
            }
            if wasHidden {
                setShown(false, view)
            }
            animations[view] = transition.run { [weak self] in
                self?.setShown(true, view)
            }
        }

        /// A badge leaving shrinks back the way it came. Hidden only once the animation reached
        /// its end: one taken over by a badge arriving again must not hide the new one.
        private func hide(_ view: UIView, transition: BNTransition) {
            guard !view.isHidden else { return }
            animations[view]?.interrupt()
            guard transition != .immediate else {
                setHidden(true, view)
                return
            }
            animations[view] = transition.run { [weak self] in
                self?.setShown(false, view)
            } completion: { [weak self] finished in
                guard finished else { return }
                self?.setHidden(true, view)
                view.transform = .identity
                self?.glasses[view]?.transform = .identity
            }
        }

        /// A part at rest on show, or shrunk away to the appear scale. Its glass shrinks with it,
        /// but comes and goes by its effect rather than by its alpha: glass does not fade.
        private func setShown(_ shown: Bool, _ part: UIView) {
            let scale = shown ? 1 : theme.appearScale
            part.alpha = shown ? 1 : 0
            part.transform = CGAffineTransform(scaleX: scale, y: scale)
            guard let glass = glasses[part] else { return }
            glass.transform = part.transform
            if #available(iOS 26.0, *) {
                glass.effect = shown ? tintedGlass() : nil
            }
        }

        private func setHidden(_ hidden: Bool, _ part: UIView) {
            part.isHidden = hidden
            glasses[part]?.isHidden = hidden
        }

        @available(iOS 26.0, *)
        private func tintedGlass() -> UIGlassEffect {
            let glass = UIGlassEffect(style: .regular)
            glass.tintColor = theme.background
            return glass
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
