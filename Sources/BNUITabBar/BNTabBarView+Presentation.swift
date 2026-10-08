#if canImport(UIKit)
    import BNUICore
    import UIKit

    // MARK: - Width solving and presentation state

    extension BNTabBarView {
        /// Width the sections' capsule may take. The action's slot is carved out first: the
        /// sections only ever get what is left.
        var sectionsAvailableWidth: CGFloat {
            let geometry = activeTheme.geometry
            let reserved = action == nil ? 0 : geometry.actionSide + geometry.actionSpacing
            return bounds.width - reserved
        }

        /// How many slots the current width holds, from the pure rule in `BNTabBarLayoutSolver`.
        func resolveSlotCount() {
            // Without a width there is nothing to decide from; a zero width would send every
            // section but one behind More for the first frame.
            guard bounds.width > 0 else { return }
            let geometry = activeTheme.geometry
            slotCount = BNTabBarLayoutSolver.slotCount(
                availableWidth: sectionsAvailableWidth,
                itemSpacing: geometry.itemSpacing,
                capsulePadding: geometry.capsulePadding,
                minimumItemWidth: geometry.effectiveMinimumItemWidth,
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
        @discardableResult
        func applySolvedWidths() -> Bool {
            guard !baseItemViews.isEmpty, itemWidthConstraints.count == baseItemViews.count else { return false }
            let geometry = activeTheme.geometry
            let fills = action != nil && baseItemViews.count >= geometry.fillWidthFromSectionCount
            let solution = BNTabBarLayoutSolver.solve(BNTabBarLayoutSolver.Input(
                availableWidth: sectionsAvailableWidth,
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
            for (constraint, width) in zip(itemWidthConstraints, solution.itemWidths) {
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
                // Slid past the bottom edge rather than faded in place: a bar that dissolves where
                // it stands still occupies the eye.
                transform = isHidden
                    ? CGAffineTransform(translationX: 0, y: effectiveBarHeight)
                    : .identity
                alpha = isHidden ? 0 : 1
            }

            reportHeightIfNeeded()
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
