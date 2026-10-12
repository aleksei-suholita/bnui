#if canImport(UIKit)
    import BNUICore
    import UIKit

    // MARK: - Width solving and presentation state

    extension BNTabBarView {
        /// Length along the bar the sections' capsule may take — a row's width, a column's height.
        /// The action's slot is carved out first: the sections only ever get what is left.
        var sectionsAvailableLength: CGFloat {
            let geometry = activeTheme.geometry
            let reserved = action == nil ? 0 : geometry.actionSide + geometry.actionSpacing
            return axis.length(of: bounds) - reserved
        }

        /// How many slots the current length holds, from the pure rule in `BNTabBarLayoutSolver`.
        ///
        /// A column's sections are squares as wide as the row is high and never narrow, so its
        /// slots are counted at that side rather than at a row's minimum width.
        func resolveSlotCount() {
            // Without a length there is nothing to decide from; a zero length would send every
            // section but one behind More for the first frame.
            guard axis.length(of: bounds) > 0 else { return }
            let geometry = activeTheme.geometry
            slotCount = BNTabBarLayoutSolver.slotCount(
                availableWidth: sectionsAvailableLength,
                itemSpacing: geometry.itemSpacing,
                capsulePadding: geometry.capsulePadding,
                minimumItemWidth: axis == .vertical ? geometry.effectiveItemHeight : geometry.effectiveMinimumItemWidth,
                maxBarWidth: geometry.maxBarWidth,
            )
        }

        /// Re-lays the slots when the width moved a section into More or out of it. Returns
        /// whether it did — the widths are solved on the next pass, over the slots that now stand.
        ///
        /// Asked on every pass rather than on each event that can change it: the bar's width, the
        /// action and the theme all end in a layout pass, and the answer is the same until one of
        /// them changes.
        @discardableResult
        func applySlotCount() -> Bool {
            resolveSlotCount()
            let slots = visibleItems.count + (moreSlotIndex == nil ? 0 : 1)
            guard slots != baseItemViews.count else { return false }
            rebuildSlots()
            return true
        }

        /// Feeds measured content into the pure solver and applies the widths and label fit it
        /// returns. Returns whether anything changed — the caller waits a pass before placing the
        /// lens when it did, so the lens lands on resolved frames rather than stale ones, and the
        /// items pick up the new label fit with it.
        ///
        /// A column has nothing to solve: its sections are squares from the start, and it shows no
        /// labels.
        @discardableResult
        func applySolvedWidths() -> Bool {
            guard axis == .horizontal, !baseItemViews.isEmpty, itemLengthConstraints.count == baseItemViews.count
            else { return false }
            let geometry = activeTheme.geometry
            let fills = action != nil && baseItemViews.count >= geometry.fillWidthFromSectionCount
            let solution = BNTabBarLayoutSolver.solve(BNTabBarLayoutSolver.Input(
                availableWidth: sectionsAvailableLength,
                items: baseItemViews.map { $0.measure() },
                itemSpacing: geometry.itemSpacing,
                capsulePadding: geometry.capsulePadding,
                preferredItemWidth: geometry.preferredItemWidth,
                minimumItemWidth: BNTabBarMetrics.minimumTouchTarget,
                minimumLabelScale: geometry.minimumLabelScale,
                maxBarWidth: geometry.maxBarWidth,
                fillsAvailableWidth: fills,
            ))

            var changed = solution.labels != solvedLabels
            solvedLabels = solution.labels
            for (constraint, width) in zip(itemLengthConstraints, solution.itemWidths) {
                guard abs(constraint.constant - width) > 0.5 else { continue }
                constraint.constant = width
                changed = true
            }
            // Only ask for another pass when something actually moved, otherwise this loops forever.
            if changed {
                setNeedsLayout()
            }
            return changed
        }

        // MARK: - Presentation

        /// Hiding moves the bar, it does not reshape it: widths, spacing and the lens stay exactly
        /// as they were, so coming back is the same journey in reverse with nothing to re-lay-out.
        func applyPresentation(transition: BNTransition) {
            let isHidden = isEffectivelyHidden
            accessibilityElementsHidden = isHidden

            transition.run { [weak self] in
                guard let self else { return }
                // Slid past the edge rather than faded in place: a bar that dissolves where it
                // stands still occupies the eye.
                transform = isHidden ? hiddenTransform : .identity
                alpha = isHidden ? 0 : 1
            }

            reportHeightIfNeeded()
        }

        /// Past the edge the bar stands by: a row down past the bottom, a column sideways past the
        /// side of the screen its strip is on.
        private var hiddenTransform: CGAffineTransform {
            guard axis == .vertical else { return CGAffineTransform(translationX: 0, y: effectiveBarHeight) }
            let towardRight = superview.map { center.x >= $0.bounds.midX } ?? true
            return CGAffineTransform(translationX: towardRight ? bounds.width : -bounds.width, y: 0)
        }

        /// Height used to push the bar off screen — the laid-out one, falling back to the theme
        /// before the first layout pass.
        private var effectiveBarHeight: CGFloat {
            bounds.height > 0
                ? bounds.height
                : activeTheme.geometry.effectiveItemHeight + 2 * activeTheme.geometry.capsulePadding
        }
    }
#endif
