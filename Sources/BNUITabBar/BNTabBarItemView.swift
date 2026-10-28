#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Default item view: icon over an optional label. Its badge is the bar's to draw, hung from
    /// the icon (`badgeAnchor`); the view says it to VoiceOver.
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
        private let imageView = UIImageView()
        /// An image's box, held so a theme of another point size resizes it; empty when neither
        /// icon is a picture, and stood down while a symbol is on show.
        private var imageBoxConstraints: [NSLayoutConstraint] = []
        /// The icon on show: the item's own, or its selected one while the section is drawn
        /// selected.
        private var shownIcon: BNTabBarItem.Icon
        /// The item's selected icon, changeable in place.
        private var selectedIcon: BNTabBarItem.Icon?
        private var badge: BNBadge?
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
            shownIcon = item.icon
            selectedIcon = item.selectedIcon
            badge = item.badge
            super.init(frame: .zero)
            build()
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        // MARK: - BNTabBarItemRendering

        func apply(state: BNTabBarItemState, transition: BNTransition) {
            theme = state.theme
            isSelected = state.isSelected
            // Swapped, not animated: under a revealing lens the selected copy is the one that
            // shows it, and the lens edge is where it changes.
            show(state.isSelected ? selectedIcon ?? item.icon : item.icon)

            let changes = { [self] in
                let colour = state.isSelected ? theme.palette.selected : theme.palette.unselected
                titleLabel.textColor = colour
                imageView.tintColor = colour
                // Selection is carried by weight as well as colour — colour alone fails colour blindness.
                imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
                    pointSize: theme.icon.pointSize,
                    weight: state.isSelected ? theme.icon.selectedWeight : theme.icon.weight,
                    scale: theme.icon.scale,
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
            // Symbol effects move a symbol's layers; a picture has none. The app's own symbols come
            // as images, and move as the system's do.
            guard imageView.image?.isSymbolImage == true, !bnReducesMotion else { return }
            // Symbol effects arrive with iOS 17. Below it the icon still changes weight and colour;
            // it just does not animate.
            guard #available(iOS 17.0, *) else { return }
            // Played once: the indefinite effects (wiggle, rotate, breathe) a single cycle instead
            // of looping.
            item.selectionAnimation.play(on: imageView)
        }

        /// The bar draws the badge above its material; the view only says it.
        func updateBadge(_ badge: BNBadge?, transition _: BNTransition) -> Bool {
            self.badge = badge
            refreshBadgeAccessibility()
            return true
        }

        var badgeAnchor: UIView? {
            imageView
        }

        /// In place while the new icon takes the box the old one took; another box changes what
        /// the section measures, and the bar rebuilds it.
        func updateSelectedIcon(_ icon: BNTabBarItem.Icon?, transition: BNTransition) -> Bool {
            let box = (selectedIcon ?? item.icon).imageBox(for: theme.icon)
            guard (icon ?? item.icon).imageBox(for: theme.icon) == box else { return false }
            selectedIcon = icon
            if isSelected {
                show(icon ?? item.icon, animated: transition.isAnimated)
            }
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
            // The wider of the two icons, so swapping to the selected one moves nothing.
            let iconWidth = [item.icon, selectedIcon].compactMap(\.self)
                .map { $0.imageBox(for: theme.icon)?.width ?? theme.icon.pointSize }
                .max() ?? theme.icon.pointSize
            return BNTabBarLayoutSolver.ItemMeasure(
                labelWidth: labelWidth,
                iconWidth: iconWidth,
                inset: theme.geometry.itemSpacing,
            )
        }

        // MARK: - Build

        private func build() {
            imageView.image = shownIcon.drawnImage
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            if [item.icon, item.selectedIcon].contains(where: { $0?.imageBox(for: theme.icon) != nil }) {
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

            configureAccessibility()
            refreshBadgeAccessibility()
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

        private func refreshBadgeAccessibility() {
            guard itemLayer == .base else { return }
            accessibilityValue = badge?.spokenText(countLimit: theme.badge.countLimit)
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
        func show(_ icon: BNTabBarItem.Icon, animated: Bool = false) {
            guard icon != shownIcon else { return }
            shownIcon = icon
            if animated, let image = icon.drawnImage {
                replaceImage(with: image)
            } else {
                imageView.image = icon.drawnImage
            }
            fitImageBox()
        }

        /// A symbol gives way to a symbol by the system's replace effect — from iOS 18 the one that
        /// morphs a symbol into its relative, `bell` into `bell.slash` — and anything else
        /// cross-fades, as a symbol does before iOS 17.
        func replaceImage(with image: UIImage) {
            if #available(iOS 17.0, *), image.isSymbolImage, imageView.image?.isSymbolImage == true {
                if #available(iOS 18.0, *) {
                    imageView.setSymbolImage(image, contentTransition: .replace.magic(fallback: .replace))
                } else {
                    imageView.setSymbolImage(image, contentTransition: .replace)
                }
                return
            }
            UIView.transition(
                with: imageView,
                duration: theme.motion.crossFade.duration,
                options: [.transitionCrossDissolve, .allowUserInteraction],
            ) { [imageView] in
                imageView.image = image
            }
        }

        /// An image sits in its box, not at its own size: the box is what the bar is measured by.
        /// A symbol sizes itself, so the box stands down while one is on show.
        func fitImageBox() {
            guard imageBoxConstraints.count == 2 else { return }
            guard let box = shownIcon.imageBox(for: theme.icon) else {
                NSLayoutConstraint.deactivate(imageBoxConstraints)
                return
            }
            imageBoxConstraints[0].constant = box.width
            imageBoxConstraints[1].constant = box.height
            NSLayoutConstraint.activate(imageBoxConstraints)
        }
    }
#endif
