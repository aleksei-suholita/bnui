#if canImport(UIKit)
    import BNUICore
    import UIKit

    // MARK: - Lens geometry, item state and measurement

    //
    // Split out of the class body deliberately: driving the lens is its own concern, separate from
    // owning items and handling the gesture.

    extension BNTabBarView {
        /// Items live inside the stacks; the lens is the space every position is expressed in,
        /// since it owns both the items and the marker.
        func frameInLens(of itemView: UIView) -> CGRect {
            guard let lens else { return itemView.frame }
            return itemView.convert(itemView.bounds, to: lens)
        }

        /// Thin wrapper over the pure rule — the decision itself lives in `BNTabBarGeometry`,
        /// where it is covered by tests.
        func nearestIndex(toX positionX: CGFloat) -> Int {
            let centers = baseItemViews.map { frameInLens(of: $0).midX }
            return BNTabBarGeometry.nearestIndex(toX: positionX, in: centers) ?? 0
        }

        // MARK: - Selection

        /// Moves the lens onto the selected section and refreshes both item copies.
        ///
        /// `velocity` is the finger's speed when a gesture just let go, zero for every other
        /// reason to move the lens; the lens folds it into its spring.
        func applySelection(transition: BNTransition, velocity: CGFloat = 0) {
            guard baseItemViews.indices.contains(selectedIndex), let lens else { return }
            let itemFrame = frameInLens(of: baseItemViews[selectedIndex])
            // Nothing is laid out yet (a rebuild, or the host has not sized the bar). Placing the
            // lens on a zero-width frame is exactly the sliver seen on any change — wait for a real
            // frame instead of drawing a one-point marker.
            guard itemFrame.width > 1, lens.bounds.height > 1 else {
                setNeedsLayout()
                return
            }
            selectionSettlesAt = transition.isAnimated
                ? CACurrentMediaTime() + transition.duration
                : 0
            let selection = selectionRect(for: itemFrame)
            updateLens(selection: selection, lifted: false, velocity: velocity, transition: transition)
            refreshItemStates(transition: transition, lensFrame: selection)
            refreshAccessibilitySelection()
        }

        /// What VoiceOver hears as selected — the selection itself, not the drawing of it: under a
        /// revealing lens every base copy is drawn unselected. With a section chosen behind More,
        /// More is the selected tab and says which section that is.
        ///
        /// More also says what its dot stands for: each badged section behind it, by name, with
        /// the badge's own words — "Inbox: 3 unread". The words are the host's; the kit adds none.
        func refreshAccessibilitySelection() {
            for (index, view) in baseItemViews.enumerated() {
                view.accessibilityTraits = index == selectedIndex ? [.button, .selected] : .button
            }
            guard let moreSlotIndex, baseItemViews.indices.contains(moreSlotIndex) else { return }
            let limit = activeTheme.geometry.badgeCountLimit
            let selected = overflowItems.first { $0.id == selectedID }?.accessibilityLabel
            let badges = overflowItems.compactMap { item in
                item.badge?.spokenText(countLimit: limit).map { "\(item.accessibilityLabel): \($0)" }
            }
            let value = ([selected].compactMap(\.self) + badges).joined(separator: ", ")
            baseItemViews[moreSlotIndex].accessibilityValue = value.isEmpty ? nil : value
        }

        /// The marker wraps its section with the capsule's own padding and spans the full bar
        /// height — it is a lens over the whole surface, not a pill sitting inside one item.
        func selectionRect(for itemFrame: CGRect) -> CGRect {
            let padding = activeTheme.geometry.capsulePadding
            let height = lens?.bounds.height ?? itemFrame.height
            return CGRect(
                x: itemFrame.minX - padding,
                y: 0,
                width: itemFrame.width + 2 * padding,
                height: height,
            )
        }

        func playSelectionAnimation(at index: Int) {
            guard baseItemViews.indices.contains(index) else { return }
            // Played in both copies: with a two-layer lens only part of the animation would
            // otherwise be visible.
            baseItemViews[index].playSelectionAnimation()
            selectedItemViews[index].playSelectionAnimation()
        }

        /// With a revealing lens the item copies never change state — the mask does the work, so
        /// the colour lands exactly on the lens edge. With a single-layer lens the control has to
        /// colour the items itself.
        func refreshItemStates(transition: BNTransition, lensFrame: CGRect? = nil) {
            let reveals = lens?.revealsSelectedContent ?? false
            for (index, view) in baseItemViews.enumerated() {
                view.apply(
                    state: makeItemState(
                        index: index,
                        selected: reveals ? false : index == selectedIndex,
                        layer: .base,
                        lensFrame: lensFrame,
                    ),
                    transition: transition,
                )
            }
            for (index, view) in selectedItemViews.enumerated() {
                view.apply(
                    state: makeItemState(
                        index: index,
                        selected: true,
                        layer: .selected,
                        lensFrame: lensFrame,
                    ),
                    transition: .immediate,
                )
            }
        }

        private func makeItemState(
            index: Int,
            selected: Bool,
            layer: BNTabBarItemLayer,
            lensFrame: CGRect?,
        ) -> BNTabBarItemState {
            BNTabBarItemState(
                isSelected: selected,
                selectionProgress: selectionProgress(for: index, lensFrame: lensFrame, selected: selected),
                // Labels go either because the host asked for an icon-only bar or because the
                // solver ran out of room for them — at any text size, accessibility ones included.
                isCompact: configuration.labelMode == .never || solvedLabels == .hidden,
                titleScale: solvedLabels.titleScale,
                isPressed: isDragging,
                theme: activeTheme,
                layer: layer,
            )
        }

        /// How much of this section the lens currently covers, 0…1.
        ///
        /// Measured from the actual overlap rather than reduced to "selected or not": that is what
        /// lets a renderer interpolate while the lens travels, instead of flipping at the boundary.
        /// Without a live lens frame there is nothing to measure, so selection stands in for it.
        private func selectionProgress(for index: Int, lensFrame: CGRect?, selected: Bool) -> CGFloat {
            guard let lensFrame, baseItemViews.indices.contains(index) else {
                return selected ? 1 : 0
            }
            let item = frameInLens(of: baseItemViews[index])
            guard item.width > 0 else { return 0 }
            return min(max(item.intersection(lensFrame).width / item.width, 0), 1)
        }

        // MARK: - Drag

        /// On touch-down the marker moves to the section under the finger.
        ///
        /// To the *section*, not to the exact touch point: a tap would otherwise animate twice in
        /// a fraction of a second — once to the finger on touch-down, then again to the section
        /// centre on release — and two moves that close together read as a stutter. Aiming at the
        /// section makes a tap a single movement that is already final, while a drag still follows
        /// the finger from there.
        ///
        /// Deliberately a spring, not a jump: the marker darts to the finger and swells on the
        /// way, rather than appearing under it.
        func beginDrag(hovering index: Int) {
            guard baseItemViews.indices.contains(index) else { return }
            let target = selectionRect(for: frameInLens(of: baseItemViews[index]))
            drag = Drag(startX: target.minX, hoveredIndex: index)
            updateLens(selection: target, lifted: true, transition: .spring(activeTheme.motion.lift))
        }

        /// Positions the lens from the finger's delta, never from its absolute position — that is
        /// the difference between "grabbed and dragging" and a lens that snaps under the touch.
        ///
        /// No animation here on purpose: the finger *is* the animation, and its velocity carries
        /// into the spring that takes over on release.
        func updateDrag(translationX: CGFloat, hovering index: Int) {
            guard let drag, let lens, baseItemViews.indices.contains(index) else { return }
            // Width tracks the section under the finger; position tracks the delta.
            let hovered = selectionRect(for: frameInLens(of: baseItemViews[index]))
            let originX = BNTabBarGeometry.clampedLensOriginX(
                drag.startX + translationX,
                lensWidth: hovered.width,
                barWidth: lens.bounds.width,
            )
            let selection = CGRect(x: originX, y: 0, width: hovered.width, height: hovered.height)
            updateLens(selection: selection, lifted: true, transition: .immediate)
            // Fed every frame so `selectionProgress` tracks the lens instead of jumping with it.
            refreshItemStates(transition: .immediate, lensFrame: selection)
        }

        private func updateLens(selection: CGRect, lifted: Bool, velocity: CGFloat = 0, transition: BNTransition) {
            guard let lens else { return }
            lens.update(
                state: BNTabBarLensState(
                    size: lens.bounds.size,
                    selection: selection,
                    isLifted: lifted,
                    velocity: velocity,
                ),
                theme: activeTheme,
                transition: transition,
            )
        }

        // MARK: - Measurement

        func reportHeightIfNeeded() {
            let height = effectiveHeight
            guard reportedHeight != height else { return }
            reportedHeight = height
            onEffectiveHeightChange?(height)
        }
    }
#endif
