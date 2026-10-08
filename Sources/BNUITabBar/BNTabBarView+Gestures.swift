#if canImport(UIKit)
    import BNUICore
    import UIKit

    // MARK: - Gestures and commit rules

    //
    // Kept apart from the class body: recognising touches and deciding what a touch means is its
    // own concern, separate from owning items and driving the lens.

    extension BNTabBarView {
        func attachGesture(to content: UIView) {
            content.gestureRecognizers?.forEach { content.removeGestureRecognizer($0) }
            let drag = BNTabBarDragRecognizer(target: self, action: #selector(handleDrag))
            drag.delegate = self
            content.addGestureRecognizer(drag)

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            // Past this much movement it is a drag, not a press — the gesture hands over rather
            // than firing a menu under a travelling finger.
            longPress.allowableMovement = 10
            longPress.delegate = self
            content.addGestureRecognizer(longPress)
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let onLongPress, let lens, !presentation.isHidden else { return }
            let index = nearestIndex(toX: gesture.location(in: lens).x)
            guard visibleItems.indices.contains(index), baseItemViews.indices.contains(index) else { return }
            onLongPress(visibleItems[index].id, baseItemViews[index])
        }

        /// Counts consecutive taps on one section. The run breaks on a different section or on a
        /// pause longer than the window.
        func tapRunPosition(for id: String) -> Int {
            let now = CACurrentMediaTime()
            if id == tapRunID, now - tapRunTime <= Self.multiTapWindow {
                tapRunCount += 1
            } else {
                tapRunCount = 1
            }
            tapRunID = id
            tapRunTime = now
            return tapRunCount
        }

        // MARK: - Gesture

        @objc private func handleDrag(_ gesture: BNTabBarDragRecognizer) {
            // Folded or gone, there is nothing to drag along: the other sections are not on screen,
            // so a gesture could only select something invisible. A drag already under way is
            // dropped rather than ignored: ignoring its release would leave the bar mid-drag — the
            // lens lifted, the sections pressed — until the next touch.
            guard !presentation.isHidden, !baseItemViews.isEmpty, let lens else {
                abandonDrag(transition: .immediate)
                return
            }
            // Which section is meant is decided by the finger's absolute position, while where the
            // lens sits is decided by how far the finger travelled since it was pulled under the
            // touch. Both are asked in the lens' coordinate space, where the items live.
            let locationX = gesture.location(in: lens).x
            let index = nearestIndex(toX: locationX)

            switch gesture.state {
            case .began:
                haptics.prepare()
                if index != selectedIndex {
                    haptics.pressedDown()
                }
                beginDrag(hovering: index)
            case .changed:
                // A drag dropped mid-gesture stays dropped.
                guard let hovered = drag?.hoveredIndex else { return }
                if index != hovered {
                    drag?.hoveredIndex = index
                    haptics.crossedBoundary()
                }
                // Follows for the whole gesture, outside the capsule included; magnetising to a
                // section happens on release only.
                updateDrag(translationX: gesture.translation(in: lens).x, hovering: index)
            case .ended:
                guard isDragging else { return }
                drag = nil
                // The finger's speed at the moment it left: the lens keeps that momentum into
                // its settle instead of stopping dead and restarting from rest.
                commitSelection(to: index, velocity: gesture.velocity(in: lens).x)
            case .cancelled, .failed:
                // System-level interruption, not a user decision: keep the previous choice.
                // Settles on the un-lift spring like a release, so the return reads as the same
                // gesture ending rather than as a different animation taking over.
                abandonDrag(transition: .spring(activeTheme.motion.unlift))
            default:
                break
            }
        }

        /// Lets go of the drag without choosing anything: the lens goes back to the section that
        /// was selected.
        private func abandonDrag(transition: BNTransition) {
            guard isDragging else { return }
            drag = nil
            applySelection(transition: transition)
        }

        /// Releasing anywhere commits the nearest section — there is no cancel-by-leaving
        /// (decision 2026-07-23).
        ///
        /// `velocity` is the finger's horizontal speed at release, in the lens' points per second;
        /// it is carried into the settle so a flick lands like a throw.
        func commitSelection(to index: Int, velocity: CGFloat = 0) {
            if index == moreSlotIndex {
                // Letting go on More is not a choice yet: the lens settles back on the selection
                // and the menu offers the rest.
                applySelection(transition: .spring(activeTheme.motion.unlift))
                // Opening a menu without a touch arrives with iOS 17.4. Before it the lens settles
                // back and the menu waits for a tap on More itself.
                if #available(iOS 17.4, *) {
                    moreButton?.performPrimaryAction()
                }
                return
            }
            guard visibleItems.indices.contains(index) else { return }
            let item = visibleItems[index]
            let isReselection = item.id == selectedID
            selectedID = item.id
            // Release rides the un-lift spring, picked up from wherever the lift left the lens.
            // The selection spring is for host-driven changes, which have no lift in progress.
            applySelection(transition: .spring(activeTheme.motion.unlift), velocity: velocity)
            playSelectionAnimation(at: index)
            reportSelection(of: item.id, isReselection: isReselection)
            onMultiTap?(item.id, tapRunPosition(for: item.id))
        }

        /// A section picked in the More menu. The lens travels to More on the selection spring —
        /// no finger is on the bar, so there is no lift to settle from.
        func commitOverflowSelection(_ id: String) {
            let isReselection = id == selectedID
            selectedID = id
            applySelection(transition: .spring(activeTheme.motion.selection))
            if let moreSlotIndex {
                playSelectionAnimation(at: moreSlotIndex)
            }
            reportSelection(of: id, isReselection: isReselection)
        }

        private func reportSelection(of id: String, isReselection: Bool) {
            if isReselection {
                haptics.reselected()
                onReselect?(id)
            } else {
                haptics.selectionChanged()
                onSelect?(id)
            }
        }
    }
#endif
