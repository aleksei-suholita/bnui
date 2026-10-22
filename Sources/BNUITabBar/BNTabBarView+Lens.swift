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
        /// where it is covered by tests. The rule is one-dimensional, so a column hands it
        /// positions along its own axis.
        func nearestIndex(to point: CGPoint) -> Int {
            let centers = baseItemViews.map { view in
                let frame = frameInLens(of: view)
                return axis.position(of: CGPoint(x: frame.midX, y: frame.midY))
            }
            return BNTabBarGeometry.nearestIndex(toX: axis.position(of: point), in: centers) ?? 0
        }

        // MARK: - Selection

        /// Puts the lens on the laid-out selection — unless the finger drives it, or a spring
        /// still carries it: something else owns its position then. That spring was aimed at the
        /// frames before this pass, and a pass that moved the sections under it would leave the
        /// lens where they used to be; so the bar looks again once it lands.
        func placeLensAfterLayout() {
            guard !isDragging else { return }
            let remaining = selectionSettlesAt - CACurrentMediaTime()
            guard remaining > 0 else {
                applySelection(transition: .immediate)
                return
            }
            guard !awaitsSettledLayout else { return }
            awaitsSettledLayout = true
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                self?.awaitsSettledLayout = false
                self?.setNeedsLayout()
            }
        }

        /// Moves the lens onto the selected section and refreshes both item copies.
        ///
        /// `velocity` is the finger's speed when a gesture just let go, zero for every other
        /// reason to move the lens; the lens folds it into its spring.
        func applySelection(transition: BNTransition, velocity: CGFloat = 0) {
            guard baseItemViews.indices.contains(selectedIndex), let lens else { return }
            // The sections sit two stacks deep and are laid out after this view, so their frames
            // are read once their own layout has run. A column has nothing to solve, and on its
            // first pass read them where the stack had not yet moved them — the lens six points
            // off its section. A row's solved length is in the engine the moment it is set, but in
            // a section's frame only once its stack lays out, and a stack is not asked to when only
            // its sections' lengths change: the lens landed on the frames of the pass before. So
            // the stacks are laid out here, after the lens has placed them.
            lens.layoutIfNeeded()
            for stack in [baseStack, selectedStack] {
                stack.setNeedsLayout()
                stack.layoutIfNeeded()
            }
            let itemFrame = frameInLens(of: baseItemViews[selectedIndex])
            // Nothing is laid out yet (a rebuild, or the host has not sized the bar). Placing the
            // lens on a zero-width frame is exactly the sliver seen on any change — wait for a real
            // frame instead of drawing a one-point marker.
            guard axis.length(of: itemFrame) > 1, axis.thickness(of: lens.bounds) > 1 else {
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
            let limit = activeTheme.badge.countLimit
            let selected = overflowItems.first { $0.id == selectedID }?.accessibilityLabel
            let badges = overflowItems.compactMap { item in
                item.badge?.spokenText(countLimit: limit).map { "\(item.accessibilityLabel): \($0)" }
            }
            let value = ([selected].compactMap(\.self) + badges).joined(separator: ", ")
            baseItemViews[moreSlotIndex].accessibilityValue = value.isEmpty ? nil : value
        }

        /// The marker wraps its section with the capsule's own padding and spans the bar across —
        /// it is a lens over the whole surface, not a pill sitting inside one item.
        func selectionRect(for itemFrame: CGRect) -> CGRect {
            let padding = activeTheme.geometry.capsulePadding
            return axis.rect(
                start: axis.start(of: itemFrame) - padding,
                length: axis.length(of: itemFrame) + 2 * padding,
                thickness: axis.thickness(of: lens?.bounds ?? itemFrame),
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
                // Labels go because the host asked for an icon-only bar, because the solver ran out
                // of room for them — at any text size, accessibility ones included — or because the
                // bar is a column, whose sections are icons.
                isCompact: configuration.labelMode == .never || solvedLabels == .hidden || axis == .vertical,
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
            guard axis.length(of: item) > 0 else { return 0 }
            return min(max(axis.length(of: item.intersection(lensFrame)) / axis.length(of: item), 0), 1)
        }

        // MARK: - Drag

        /// The finger driving the lens. One value for the whole gesture, so its pieces cannot
        /// outlive each other: everything goes when it ends, the stretch's spring included.
        struct Drag {
            /// Where the lens started along the bar when the finger landed. The lens moves by the
            /// finger's delta from here, so it never teleports under the touch.
            var start: CGFloat
            /// The section under the finger; a change plays the boundary tick.
            var hoveredIndex: Int
            /// Where the finger came down, in the lens' space — on the glass under the lens, which
            /// measures its pull from here.
            var touchStart: CGPoint
            /// Where the finger has put the lens. Each frame of the stretch is drawn over it.
            var selection: CGRect
            /// The glass' stretch on its way to the finger's pull.
            let stretch: BNTabBarStretchDriver
            /// The finger has travelled past `dragThreshold`, and the lens follows it from now on.
            var isFollowing = false
        }

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
        func beginDrag(hovering index: Int, at touch: CGPoint) {
            guard baseItemViews.indices.contains(index) else { return }
            let target = selectionRect(for: frameInLens(of: baseItemViews[index]))
            let stretch = BNTabBarStretchDriver { [weak self] stretch in self?.drawDrag(stretch: stretch) }
            drag = Drag(
                start: axis.start(of: target),
                hoveredIndex: index,
                touchStart: touch,
                selection: target,
                stretch: stretch,
            )
            updateLens(selection: target, lifted: true, transition: .spring(activeTheme.motion.lift))
        }

        /// Positions the lens from the finger's delta, never from its absolute position — that is
        /// the difference between "grabbed and dragging" and a lens that snaps under the touch.
        ///
        /// No animation here on purpose: the finger *is* the animation, and its velocity carries
        /// into the spring that takes over on release. Only the stretch has a spring of its own —
        /// the glass under the lens', which the stretch keeps step with.
        func updateDrag(translation: CGFloat, hovering index: Int, touch: CGPoint) {
            guard let drag, let lens, baseItemViews.indices.contains(index) else { return }
            // Length tracks the section under the finger; position tracks the delta. The clamp is
            // one-dimensional, so a column hands it lengths along its own axis.
            let hovered = selectionRect(for: frameInLens(of: baseItemViews[index]))
            let origin = BNTabBarGeometry.clampedLensOriginX(
                drag.start + translation,
                lensWidth: axis.length(of: hovered),
                barWidth: axis.length(of: lens.bounds),
            )
            let selection = axis.rect(
                start: origin,
                length: axis.length(of: hovered),
                thickness: axis.thickness(of: hovered),
            )
            self.drag?.selection = selection
            drag.stretch.pull(
                to: glassPull(touch: touch, from: drag.touchStart, in: lens.bounds.size),
                on: .glassTracking(for: lens.bounds.size),
            )
            updateLens(selection: selection, lifted: true, stretch: drag.stretch.stretch, transition: .immediate)
            // Fed every frame so `selectionProgress` tracks the lens instead of jumping with it.
            refreshItemStates(transition: .immediate, lensFrame: selection)
        }

        /// How the finger pulls the glass under the lens — the capsule, the lens' whole space — the
        /// way the system pulls interactive glass of that size, from where the finger came down. A
        /// column takes the finger along itself only: across, its strip is too narrow to stretch
        /// into.
        private func glassPull(touch: CGPoint, from start: CGPoint, in size: CGSize) -> BNTabBarLensStretch {
            let strength = activeTheme.geometry.lensStretch
            guard strength > 0 else { return .none }
            let finger = axis == .vertical ? CGPoint(x: start.x, y: touch.y) : touch
            return BNTabBarLensStretch.glass(touch: finger, start: start, size: size).scaled(by: strength)
        }

        /// One frame of the stretch on its spring, drawn over where the finger has put the lens.
        private func drawDrag(stretch: BNTabBarLensStretch) {
            guard let drag else { return }
            updateLens(selection: drag.selection, lifted: true, stretch: stretch, transition: .immediate)
        }

        private func updateLens(
            selection: CGRect,
            lifted: Bool,
            velocity: CGFloat = 0,
            stretch: BNTabBarLensStretch = .none,
            transition: BNTransition,
        ) {
            guard let lens else { return }
            lens.update(
                state: BNTabBarLensState(
                    size: lens.bounds.size,
                    selection: selection,
                    isLifted: lifted,
                    velocity: velocity,
                    axis: axis,
                    stretch: stretch,
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
