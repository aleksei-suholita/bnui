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
        private let imageView = UIImageView()
        private var isSelected = false

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
            }
            // `run` applies the changes directly when the transition is immediate. The selected
            // trait is not set here: under a revealing lens the base copy is always drawn
            // unselected, so `state.isSelected` says nothing about the selection. The bar sets it.
            transition.run(changes)
        }

        func playSelectionAnimation() {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
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

        @available(iOS 18.0, *)
        private func playIOS18Effect() {
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
                iconWidth: theme.icon.pointSize,
                inset: theme.geometry.itemSpacing,
            )
        }

        // MARK: - Build

        private func build() {
            imageView.image = item.icon.templateImage
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false

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

            buildBadgeIfNeeded()
            configureAccessibility()
        }

        private func shouldHideLabel(state: BNTabBarItemState) -> Bool {
            switch labelMode {
            case .never: true
            case .always: state.isCompact
            // The selected copy always shows its label: it is only ever visible inside the lens.
            case .selectedOnly: state.isCompact || !(state.isSelected || itemLayer == .selected)
            }
        }

        private func buildBadgeIfNeeded() {
            guard let badge = item.badge else { return }
            badgeLabel.text = badge
            badgeLabel.font = theme.typography.badge
            badgeLabel.adjustsFontForContentSizeCategory = true
            badgeLabel.textColor = theme.palette.badgeText
            badgeLabel.backgroundColor = theme.palette.badgeBackground
            badgeLabel.textAlignment = .center
            badgeLabel.bnApplyCapsule()
            badgeLabel.clipsToBounds = true
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(badgeLabel)
            NSLayoutConstraint.activate([
                // Perched on the icon's top-trailing corner, the way a badge is expected to sit.
                badgeLabel.centerXAnchor.constraint(equalTo: imageView.trailingAnchor),
                badgeLabel.centerYAnchor.constraint(equalTo: imageView.topAnchor),
                badgeLabel.widthAnchor.constraint(greaterThanOrEqualTo: badgeLabel.heightAnchor),
            ])
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
            if let badge = item.badge {
                accessibilityValue = badge
            }
        }
    }
#endif
