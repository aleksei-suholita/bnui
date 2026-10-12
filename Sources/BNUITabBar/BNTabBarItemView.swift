#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Default item view: icon over an optional label, with an optional badge.
    ///
    /// Owns its accessibility identity — a button that is additionally "selected" when active,
    /// the shape VoiceOver needs to announce "Tab N of M". Only the `.base` copy is exposed to
    /// VoiceOver; the `.selected` copy is a visual duplicate and would otherwise be read twice.
    final class BNTabBarItemView: UIView, BNTabBarItemRendering {
        let item: BNTabBarItem

        private var theme: BNTabBarTheme
        private let labelMode: BNTabBarConfiguration.LabelMode
        private let itemLayer: BNTabBarItemLayer
        private let titleLabel = UILabel()
        private let badgeLabel = BNBadgeLabel()
        private let badgeDot = UIView()
        private let imageView = UIImageView()
        /// An image's box, held so a theme of another point size resizes it; empty for a symbol.
        private var imageBoxConstraints: [NSLayoutConstraint] = []
        private var isSelected = false
        /// The badge on show — the item's at first, then whatever the bar updated it to in place.
        private var badge: BNTabBarBadge?
        /// The badge's pop in or out, kept so the next change can take it over mid-flight.
        private var badgeAnimation: BNAnimation?

        init(
            item: BNTabBarItem,
            theme: BNTabBarTheme,
            labelMode: BNTabBarConfiguration.LabelMode,
            layer: BNTabBarItemLayer,
        ) {
            self.item = item
            self.theme = theme
            self.labelMode = labelMode
            itemLayer = layer
            super.init(frame: .zero)
            build()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        // MARK: - BNTabBarItemRendering

        func apply(state: BNTabBarItemState, transition: BNTransition) {
            theme = state.theme
            isSelected = state.isSelected

            let changes = { [self] in
                let colour = state.isSelected ? theme.palette.selected : theme.palette.unselected
                titleLabel.textColor = colour
                imageView.tintColor = colour
                // Selection is carried by weight as well as colour — colour alone fails colour blindness.
                imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
                    pointSize: theme.icon.pointSize,
                    weight: state.isSelected ? theme.icon.selectedWeight : theme.icon.weight,
                )
                let font = state.isSelected ? theme.typography.selectedTitle : theme.typography.title
                // Scaled here rather than left to the label, so every section in a crowded bar
                // shares one type size instead of each shrinking by its own length.
                titleLabel.font = state.titleScale < 1 ? font.withSize(font.pointSize * state.titleScale) : font
                titleLabel.isHidden = shouldHideLabel(state: state)
                fitImageBox()
            }
            // `run` applies the changes directly when the transition is immediate. The selected
            // trait is not set here: under a revealing lens the base copy is always drawn
            // unselected, so `state.isSelected` says nothing about the selection. The bar sets it.
            transition.run(changes)
        }

        func playSelectionAnimation() {
            // Symbol effects move a symbol's layers; an image has none.
            guard case .symbol = item.icon, !UIAccessibility.isReduceMotionEnabled else { return }
            // Symbol effects arrive with iOS 17. Below it the icon still changes weight and colour;
            // it just does not animate.
            guard #available(iOS 17.0, *) else { return }
            // `.nonRepeating` keeps every effect a one-shot accent: the indefinite ones (wiggle,
            // rotate, breathe) play a single cycle instead of looping.
            switch item.selectionAnimation {
            case .none:
                break
            case .bounce:
                imageView.addSymbolEffect(.bounce, options: .nonRepeating)
            case .pulse:
                imageView.addSymbolEffect(.pulse, options: .nonRepeating)
            case .wiggle, .rotate, .breathe:
                guard #available(iOS 18.0, *) else {
                    // iOS 17 has none of the three; the default accent stands in for them.
                    imageView.addSymbolEffect(.bounce, options: .nonRepeating)
                    return
                }
                playIOS18Effect()
            }
        }

        func updateBadge(_ badge: BNTabBarBadge?, transition: BNTransition) -> Bool {
            showBadge(badge, transition: transition)
            return true
        }

        func measure() -> BNTabBarLayoutSolver.ItemMeasure {
            // Measured from content, not from `systemLayoutSizeFitting`: the solver drives the
            // width constraint, so measuring through it would just echo the answer back. The
            // selected font is the wider of the two, so the label fits in either copy.
            let labelWidth: CGFloat = labelMode == .never
                ? 0
                : ceil((item.title as NSString).size(withAttributes: [
                    .font: theme.typography.selectedTitle,
                ]).width)
            return BNTabBarLayoutSolver.ItemMeasure(
                labelWidth: labelWidth,
                iconWidth: item.icon.imageBox(pointSize: theme.icon.pointSize)?.width ?? theme.icon.pointSize,
                inset: theme.geometry.itemSpacing,
            )
        }

        // MARK: - Build

        private func build() {
            imageView.image = item.icon.drawnImage
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            if item.icon.imageBox(pointSize: theme.icon.pointSize) != nil {
                imageBoxConstraints = [
                    imageView.widthAnchor.constraint(equalToConstant: 0),
                    imageView.heightAnchor.constraint(equalToConstant: 0),
                ]
                NSLayoutConstraint.activate(imageBoxConstraints)
                fitImageBox()
            }

            titleLabel.text = item.title
            titleLabel.font = theme.typography.title
            titleLabel.adjustsFontForContentSizeCategory = true
            titleLabel.textAlignment = .center
            // A safety net under the solver's scale, not a second strategy: text does not narrow
            // exactly in proportion to its size, and the last few percent would otherwise be an
            // ellipsis.
            titleLabel.adjustsFontSizeToFitWidth = true
            titleLabel.minimumScaleFactor = 0.9
            titleLabel.isHidden = labelMode == .never

            let stack = UIStackView(arrangedSubviews: [imageView, titleLabel])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = theme.icon.titleSpacing
            stack.isUserInteractionEnabled = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)

            // Transparent padding counts towards the touch target, so the guarantee holds even
            // when the glyph and the label are small.
            //
            // Not required priority, though: when the bar folds, sections are driven to zero
            // width, and a required floor here would fight that. The 44 pt guarantee is enforced
            // where it matters anyway — the layout solver clamps every expanded width to it.
            let minWidth = widthAnchor.constraint(greaterThanOrEqualToConstant: BNTabBarMetrics.minimumTouchTarget)
            minWidth.priority = .defaultHigh

            NSLayoutConstraint.activate([
                heightAnchor.constraint(greaterThanOrEqualToConstant: theme.geometry.effectiveItemHeight),
                minWidth,
                stack.centerXAnchor.constraint(equalTo: centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: centerYAnchor),
                stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: theme.geometry.itemSpacing),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -theme.geometry.itemSpacing),
                stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            ])

            buildBadge()
            configureAccessibility()
            showBadge(item.badge, transition: .immediate)
        }

        private func shouldHideLabel(state: BNTabBarItemState) -> Bool {
            switch labelMode {
            case .never: true
            case .always: state.isCompact
            // The selected copy always shows its label: it is only ever visible inside the lens.
            case .selectedOnly: state.isCompact || !(state.isSelected || itemLayer == .selected)
            }
        }

        // MARK: - Badge

        /// Both kinds of badge are made once, hidden, so that a badge arriving later — or changing
        /// kind — is shown in place instead of the view being made again.
        private func buildBadge() {
            badgeLabel.font = theme.typography.badge
            badgeLabel.adjustsFontForContentSizeCategory = true
            badgeLabel.maximumContentSizeCategory = theme.typography.badgeMaximumContentSizeCategory
            badgeLabel.textColor = theme.palette.badgeText
            badgeLabel.backgroundColor = theme.palette.badgeBackground
            badgeLabel.textAlignment = .center
            badgeLabel.bnApplyCapsule()
            badgeLabel.clipsToBounds = true

            badgeDot.backgroundColor = theme.palette.badgeBackground
            badgeDot.bnApplyCapsule()

            for view in [badgeLabel, badgeDot] {
                view.isHidden = true
                view.isUserInteractionEnabled = false
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
            }
            let geometry = theme.geometry
            NSLayoutConstraint.activate([
                // Pinned by its leading edge just inside the icon's top-trailing corner: a longer
                // badge grows away from the glyph instead of over it.
                badgeLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -geometry.badgeOverlap),
                badgeLabel.centerYAnchor.constraint(equalTo: imageView.topAnchor),
                badgeLabel.widthAnchor.constraint(greaterThanOrEqualTo: badgeLabel.heightAnchor),
                // A dot does not grow, so it sits centred on the corner itself.
                badgeDot.centerXAnchor.constraint(equalTo: imageView.trailingAnchor),
                badgeDot.centerYAnchor.constraint(equalTo: imageView.topAnchor),
                badgeDot.widthAnchor.constraint(equalToConstant: geometry.badgeDotSide),
                badgeDot.heightAnchor.constraint(equalTo: badgeDot.widthAnchor),
            ])
        }

        private func showBadge(_ newBadge: BNTabBarBadge?, transition: BNTransition) {
            let limit = theme.geometry.badgeCountLimit
            let old = badge?.appearance(countLimit: limit)
            let new = newBadge?.appearance(countLimit: limit)
            badge = newBadge
            refreshBadgeAccessibility()
            guard old != new else { return }

            badgeAnimation?.interrupt()
            switch new {
            case let .text(text)?:
                if case .text? = old {
                    changeBadgeText(to: text, transition: transition)
                } else {
                    badgeLabel.text = text
                    hideBadgeView(badgeDot, transition: transition)
                    showBadgeView(badgeLabel, transition: transition)
                }
            case .dot?:
                hideBadgeView(badgeLabel, transition: transition)
                showBadgeView(badgeDot, transition: transition)
            case nil:
                hideBadgeView(badgeLabel, transition: transition)
                hideBadgeView(badgeDot, transition: transition)
            }
        }

        /// A badge arriving pops in from the theme's appear scale.
        private func showBadgeView(_ view: UIView, transition: BNTransition) {
            view.isHidden = false
            guard transition != .immediate else {
                view.alpha = 1
                view.transform = .identity
                return
            }
            let scale = theme.geometry.badgeAppearScale
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            badgeAnimation = transition.run {
                view.alpha = 1
                view.transform = .identity
            }
        }

        /// A badge leaving shrinks back the way it came. Hidden only once the animation reached
        /// its end: one taken over by a badge arriving again must not hide the new one.
        private func hideBadgeView(_ view: UIView, transition: BNTransition) {
            guard !view.isHidden else { return }
            guard transition != .immediate else {
                view.isHidden = true
                return
            }
            let scale = theme.geometry.badgeAppearScale
            badgeAnimation = transition.run {
                view.alpha = 0
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
            } completion: { finished in
                guard finished else { return }
                view.isHidden = true
                view.transform = .identity
            }
        }

        /// A number changing cross-fades, and the capsule follows the new width.
        private func changeBadgeText(to text: String, transition: BNTransition) {
            guard transition != .immediate else {
                badgeLabel.text = text
                return
            }
            UIView.transition(
                with: badgeLabel,
                duration: theme.motion.crossFade.duration,
                options: [.transitionCrossDissolve, .allowUserInteraction],
            ) { [badgeLabel] in
                badgeLabel.text = text
            }
            transition.run { [weak self] in
                self?.layoutIfNeeded()
            }
        }

        private func refreshBadgeAccessibility() {
            guard itemLayer == .base else { return }
            accessibilityValue = badge?.spokenText(countLimit: theme.geometry.badgeCountLimit)
        }

        private func configureAccessibility() {
            guard itemLayer == .base else {
                // The duplicate must stay invisible to assistive technology.
                isAccessibilityElement = false
                accessibilityElementsHidden = true
                return
            }
            isAccessibilityElement = true
            accessibilityTraits = .button
            accessibilityLabel = item.accessibilityLabel
        }
    }

    private extension BNTabBarItemView {
        @available(iOS 18.0, *)
        func playIOS18Effect() {
            switch item.selectionAnimation {
            case .wiggle:
                imageView.addSymbolEffect(.wiggle, options: .nonRepeating)
            case .rotate:
                imageView.addSymbolEffect(.rotate, options: .nonRepeating)
            case .breathe:
                imageView.addSymbolEffect(.breathe, options: .nonRepeating)
            case .none, .bounce, .pulse:
                break
            }
        }

        /// An image sits in its box, not at its own size: the box is what the bar is measured by.
        func fitImageBox() {
            guard imageBoxConstraints.count == 2, let box = item.icon.imageBox(pointSize: theme.icon.pointSize) else { return }
            imageBoxConstraints[0].constant = box.width
            imageBoxConstraints[1].constant = box.height
        }
    }
#endif
