#if canImport(UIKit)
    import BNUIButton
    import BNUICore
    import UIKit

    // MARK: - Composition

    // Building the pieces and deciding where they sit: the sections capsule, the optional action
    // beside it, and the two item stacks the lens reveals between.

    extension BNTabBarView {
        func buildAction() {
            actionView = nil
            guard let action else { return }

            // The kit's own button rather than a system one: the action is the bar's most prominent
            // tap, and it should answer with the same physics and the same haptic contract as every
            // other button in the app.
            let side = max(activeTheme.geometry.actionSide, BNTabBarMetrics.minimumTouchTarget)
            let button = BNButton(
                content: .icon(action.buttonIcon, accessibilityLabel: action.accessibilityLabel),
                style: action.makeButtonStyle(foreground: activeTheme.palette.selected, material: resolvedMaterial),
                size: action.makeButtonSize(side: side, iconPointSize: activeTheme.icon.pointSize),
            )
            // The bar owns this button's haptics, so the button's own generators stay quiet — see
            // `makeButtonStyle`.
            button.haptics.isEnabled = false
            button.translatesAutoresizingMaskIntoConstraints = false
            button.onTap = { [weak self] in self?.handleAction() }

            // No size constraints: an icon-only button sizes itself square from the step above, and
            // pinning it as well would be two sources for one number.
            addSubview(button)
            actionView = button
        }

        private func handleAction() {
            haptics.actionTriggered()
            onAction?()
        }

        /// Places the accessory above the row and points the row guide's top at it. Without an
        /// accessory the guide's top is the view's top, and the layout is a single row again.
        func buildAccessory() {
            barRowTopConstraint?.isActive = false

            // A column stands in a strip with no room across for an accessory; it shows none.
            guard let accessory, axis == .horizontal else {
                let top = barRowGuide.topAnchor.constraint(equalTo: topAnchor)
                top.isActive = true
                barRowTopConstraint = top
                return
            }

            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            accessory.view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(accessory.view)
            NSLayoutConstraint.activate([
                accessory.view.topAnchor.constraint(equalTo: container.topAnchor),
                accessory.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                accessory.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                accessory.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            addSubview(container)

            var constraints = [container.topAnchor.constraint(equalTo: topAnchor)]
            switch accessory.width {
            case .matchBar:
                constraints += [
                    container.leadingAnchor.constraint(equalTo: leadingAnchor),
                    container.trailingAnchor.constraint(equalTo: trailingAnchor),
                ]
            case .hug:
                constraints += [
                    container.centerXAnchor.constraint(equalTo: centerXAnchor),
                    container.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
                    container.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
                ]
            }
            let top = barRowGuide.topAnchor.constraint(equalTo: container.bottomAnchor, constant: accessory.spacing)
            constraints.append(top)
            NSLayoutConstraint.activate(constraints)
            barRowTopConstraint = top

            if onAccessoryTap != nil {
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleAccessoryTap))
                // The host view keeps its own gestures; this only reports the tap.
                tap.cancelsTouchesInView = false
                container.addGestureRecognizer(tap)
            }

            animateAccessoryAppearanceIfNeeded(container)
        }

        @objc private func handleAccessoryTap() {
            onAccessoryTap?()
        }

        /// A fade-and-rise, but only when the accessory first appears — a rebuild for a theme or
        /// selection change must not replay it.
        private func animateAccessoryAppearanceIfNeeded(_ container: UIView) {
            guard animateAccessoryIn else { return }
            animateAccessoryIn = false
            layoutIfNeeded()
            container.alpha = 0
            container.transform = CGAffineTransform(translationX: 0, y: activeTheme.geometry.effectiveItemHeight / 2)
            BNTransition.curve(activeTheme.motion.visibility).run {
                container.alpha = 1
                container.transform = .identity
            }
        }

        func alignmentConstraints(for capsule: UIView) -> [NSLayoutConstraint] {
            guard axis == .horizontal else { return columnConstraints(for: capsule) }
            // Anchored to the row guide, not the view: an accessory changes where the row sits
            // without changing how the row is composed. Leading/trailing use the guide too — it
            // spans the full width — so RTL mirrors both schemes for free.
            var constraints = [
                capsule.topAnchor.constraint(equalTo: barRowGuide.topAnchor),
                capsule.bottomAnchor.constraint(equalTo: barRowGuide.bottomAnchor),
                capsule.leadingAnchor.constraint(greaterThanOrEqualTo: barRowGuide.leadingAnchor),
                capsule.trailingAnchor.constraint(lessThanOrEqualTo: barRowGuide.trailingAnchor),
            ]

            // With an action the composition is fixed rather than chosen: sections lead, action
            // trails, gap between. Host alignment only applies when the bar is sections alone.
            if let actionView {
                constraints += [
                    capsule.leadingAnchor.constraint(equalTo: barRowGuide.leadingAnchor),
                    actionView.centerYAnchor.constraint(equalTo: barRowGuide.centerYAnchor),
                    actionView.trailingAnchor.constraint(equalTo: barRowGuide.trailingAnchor),
                    actionView.leadingAnchor.constraint(
                        greaterThanOrEqualTo: capsule.trailingAnchor,
                        constant: activeTheme.geometry.actionSpacing,
                    ),
                ]
                return constraints
            }

            switch configuration.alignment {
            case .leading:
                constraints.append(capsule.leadingAnchor.constraint(equalTo: barRowGuide.leadingAnchor))
            case .center:
                constraints.append(capsule.centerXAnchor.constraint(equalTo: barRowGuide.centerXAnchor))
            case .trailing:
                constraints.append(capsule.trailingAnchor.constraint(equalTo: barRowGuide.trailingAnchor))
            }
            return constraints
        }

        /// A column stands at the bottom of its strip, where the system keeps its own tab bar:
        /// centred across the strip, the action under the sections — the row's order, turned. The
        /// host's alignment is a row's; a column has one place.
        private func columnConstraints(for capsule: UIView) -> [NSLayoutConstraint] {
            let constraints = [
                capsule.centerXAnchor.constraint(equalTo: barRowGuide.centerXAnchor),
                capsule.topAnchor.constraint(greaterThanOrEqualTo: barRowGuide.topAnchor),
            ]
            guard let actionView else {
                return constraints + [capsule.bottomAnchor.constraint(equalTo: barRowGuide.bottomAnchor)]
            }
            return constraints + [
                actionView.centerXAnchor.constraint(equalTo: barRowGuide.centerXAnchor),
                actionView.bottomAnchor.constraint(equalTo: barRowGuide.bottomAnchor),
                actionView.topAnchor.constraint(
                    equalTo: capsule.bottomAnchor,
                    constant: activeTheme.geometry.actionSpacing,
                ),
            ]
        }

        /// Re-lays the slots alone, when the width moved a section into More or out of it. The
        /// material, the lens and the action stay as they are: only which sections stand changed.
        func rebuildSlots() {
            guard let lens else { return }
            // Off their containers first, so the stacks' edge constraints go with them instead of
            // doubling up when `buildItems` pins them again.
            baseStack.removeFromSuperview()
            selectedStack.removeFromSuperview()
            moreButton?.removeFromSuperview()
            baseItemViews.removeAll()
            selectedItemViews.removeAll()

            buildItems(in: lens)
            buildMoreButton()
            applySelection(transition: .immediate)
            refreshLongPressActions()
        }

        /// Shows new badges on the sections already built, when nothing but badges changed.
        /// `false` when anything else did, or when a renderer cannot draw a badge in place — the
        /// caller rebuilds then.
        func updateBadgesInPlace(from oldItems: [BNTabBarItem]) -> Bool {
            guard !baseItemViews.isEmpty,
                  oldItems.count == items.count,
                  zip(oldItems, items).allSatisfy({ old, new in new.differsOnlyInBadge(from: old) })
            else { return false }
            let slots = Array(visibleItems) + (moreSlotIndex == nil ? [] : [moreSlotItem])
            guard slots.count == baseItemViews.count, slots.count == selectedItemViews.count else { return false }

            // The pop is decoration, so Reduce Motion shows the new badge at once.
            let transition: BNTransition = UIAccessibility.isReduceMotionEnabled
                ? .immediate
                : .spring(activeTheme.motion.itemAccent)
            for (index, item) in slots.enumerated() {
                guard baseItemViews[index].updateBadge(item.badge, transition: transition),
                      selectedItemViews[index].updateBadge(item.badge, transition: transition)
                else { return false }
            }
            // More's spoken value names the badges behind it, so it is said anew.
            refreshAccessibilitySelection()
            return true
        }

        func buildItems(in lens: any BNTabBarLens) {
            let renderer = itemRenderer
                ?? BNStandardTabBarItemRenderer(theme: activeTheme, labelMode: configuration.labelMode)
            itemLengthConstraints.removeAll()

            configure(stack: baseStack, in: lens.contentView)
            configure(stack: selectedStack, in: lens.selectedContentView)

            // More is drawn by the same renderer as a section, so the lens marks it and a crowded
            // bar shrinks it like any other slot.
            let slots = Array(visibleItems) + (moreSlotIndex == nil ? [] : [moreSlotItem])
            for item in slots {
                let base = renderer.makeItemView(for: item, layer: .base)
                baseItemViews.append(base)
                baseStack.addArrangedSubview(base)
                let length = lengthAnchor(of: base).constraint(equalToConstant: initialItemLength)
                length.isActive = true
                itemLengthConstraints.append(length)
                if axis == .vertical {
                    // Icons in a column, so a section is a square as wide as the row is high.
                    base.widthAnchor.constraint(equalToConstant: initialItemLength).isActive = true
                }

                // The second copy is laid out identically; the lens decides where it shows.
                let selected = renderer.makeItemView(for: item, layer: .selected)
                selectedItemViews.append(selected)
                selectedStack.addArrangedSubview(selected)
                lengthAnchor(of: selected).constraint(equalTo: lengthAnchor(of: base)).isActive = true
            }

            // The container carries the tab-bar trait and is not an element itself — the only
            // configuration in which VoiceOver announces "Tab N of M".
            baseStack.isAccessibilityElement = false
            baseStack.accessibilityContainerType = .semanticGroup
            baseStack.accessibilityTraits = .tabBar
            baseStack.accessibilityElements = baseItemViews
            selectedStack.accessibilityElementsHidden = true
        }

        /// An invisible button over the More slot, reaching to the capsule's end — its trailing
        /// edge, a column's bottom — so a touch in the padding beside it opens the menu too. The
        /// slot's look stays with the lens.
        ///
        /// A button because a system menu has no public way to open on its own: it opens from a
        /// control's touch-down, or from `performPrimaryAction()` when a drag lets go on More.
        ///
        /// Kept out of the material, on top of the lens. A menu button inside the glass has the
        /// capsule itself morph into the menu, which leaves the sections — drawn by the lens, above
        /// the glass — floating with no backdrop. Being on top, it also takes a touch that lands on
        /// More outright: the drag never sees it, so the lens cannot chase a finger under the open
        /// menu. A drag that only arrives on More is still the bar's; letting go there opens the
        /// menu too.
        func buildMoreButton() {
            moreButton = nil
            guard let lens, let moreSlotIndex, baseItemViews.indices.contains(moreSlotIndex) else { return }

            let button = UIButton(type: .custom)
            button.showsMenuAsPrimaryAction = true
            // The host's order, top to bottom — not reversed for a menu that opens upwards.
            button.preferredMenuElementOrder = .fixed
            // Built at every opening, so the tick lands on whatever is selected by then.
            button.menu = UIMenu(children: [
                UIDeferredMenuElement.uncached { [weak self] completion in
                    completion(self?.overflowMenuActions() ?? [])
                },
            ])
            button.addAction(UIAction { [weak self] _ in self?.haptics.overflowOpened() }, for: .menuActionTriggered)
            // VoiceOver reaches the menu through the slot, which it announces as a tab; the
            // button stays silent so More is not read twice.
            button.isAccessibilityElement = false
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)

            // The lens spans the capsule exactly, so it stands in for the capsule's edges.
            let slot = baseItemViews[moreSlotIndex]
            let vertical = axis == .vertical
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: vertical ? slot.topAnchor : lens.topAnchor),
                button.bottomAnchor.constraint(equalTo: lens.bottomAnchor),
                button.leadingAnchor.constraint(equalTo: vertical ? lens.leadingAnchor : slot.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: lens.trailingAnchor),
            ])
            moreButton = button
        }

        /// The sections behind More. The active one is ticked; a badge has no place of its own in
        /// a system menu, so it goes under the title — a dot as its words, since a menu cannot
        /// draw one.
        private func overflowMenuActions() -> [UIMenuElement] {
            let limit = activeTheme.badge.countLimit
            return overflowItems.map { item in
                UIAction(
                    title: item.title,
                    subtitle: item.badge?.menuText(countLimit: limit),
                    image: item.icon.menuImage(pointSize: activeTheme.icon.pointSize),
                    state: item.id == selectedID ? .on : .off,
                ) { [weak self] _ in
                    self?.commitOverflowSelection(item.id)
                }
            }
        }

        /// A section's extent along the bar.
        private func lengthAnchor(of view: UIView) -> NSLayoutDimension {
            axis == .vertical ? view.heightAnchor : view.widthAnchor
        }

        /// What a section is laid out at before anything is solved: a row's preferred width, which
        /// the solver then fits to the room; a column's square, which stays.
        private var initialItemLength: CGFloat {
            axis == .vertical ? activeTheme.geometry.effectiveItemHeight : activeTheme.geometry.preferredItemWidth
        }

        func configure(stack: UIStackView, in container: UIView) {
            stack.axis = axis
            stack.alignment = .fill
            // Widths come from BNTabBarLayoutSolver, not from the stack: fillEqually clips a long
            // label instead of letting it take room from its neighbours.
            stack.distribution = .fill
            stack.spacing = activeTheme.geometry.itemSpacing
            stack.isUserInteractionEnabled = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            container.addSubview(stack)
            let padding = activeTheme.geometry.capsulePadding
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
                stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding),
                stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
                stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            ])
        }
    }
#endif
