#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        /// Changes the content, animated unless `animated` is `false` — the animated counterpart of
        /// setting ``content``, as `setOn(_:animated:)` is of `isOn`.
        ///
        /// Who animates the change is decided in this order:
        ///
        /// - Nobody, at once: `animated` is `false`, the button is not in a window, or animations
        ///   are off for the moment (`UIView.performWithoutAnimation`).
        /// - The host: a call made inside an animation block the host is running joins it and
        ///   takes its duration and curve.
        /// - The button: its own springs, at ``contentTransitionDuration`` when that is set.
        ///
        /// An animation run by `UIViewPropertyAnimator` is not seen as the host's: the change then
        /// runs on the button's springs beside it.
        ///
        /// The old content gives way in the ``contentTransition`` style, clipped to the outline
        /// while the change is under way; when the title stays, only the icons change, in place.
        /// The outline moves to the new size, and so do the views around the button unless
        /// ``animatesSizeChanges`` is off.
        ///
        /// - Parameters:
        ///   - newContent: What the button shows next.
        ///   - animated: Whether the change is animated.
        public func setContent(_ newContent: BNButtonContent, animated: Bool) {
            guard newContent != content else { return }
            let timing = BNButtonContentTiming.resolve(
                animated: animated,
                isInWindow: window != nil,
                animationsEnabled: UIView.areAnimationsEnabled,
                inheritedDuration: UIView.inheritedAnimationDuration,
            )
            guard timing != .immediate else {
                content = newContent
                return
            }
            let root = animatesSizeChanges ? sizeChangeLayoutRoot : nil
            if timing == .own {
                // Whatever the host left pending lands now, unanimated, as it would have without
                // the button: the spring below then carries only what the new content moves.
                root?.layoutIfNeeded()
            }

            isSwappingContent = true
            content = newContent
            isSwappingContent = false
            solvesNaturalWidth = true

            var arrival: (outgoing: UIView?, incoming: UIView)?
            if !takesIconsInPlace(timing: timing) {
                UIView.performWithoutAnimation { arrival = prepareArrival() }
            }
            let startCentre = contentCentre
            invalidateSolvedLayout()
            updateAccessibility()
            // The new size goes under its spring before the content starts to change: a picture
            // the blur takes lays out whatever is pending at once, and the width would jump.
            layOutNewSize(root: root, timing: timing)
            if let arrival {
                transition(from: arrival.outgoing, to: arrival.incoming, timing: timing, startCentre: startCentre)
            }
        }

        /// The tuning a change runs on: the kit's, at the duration the host asked for.
        var activeContentTuning: BNButtonContentTransitionTuning {
            contentTransitionTuning.scaled(toDuration: contentTransitionDuration)
        }

        /// The spring the content changes on: the kit's own, or one as long as the host's animation.
        func contentSpring(for timing: BNButtonContentTiming) -> BNSpring {
            switch timing {
            case let .inherited(duration): BNSpring(duration: duration, bounce: 0)
            case .own, .immediate: reducesMotion ? BNSpring(duration: 0.1, bounce: 0) : activeContentTuning.content
            }
        }

        /// The middle of the content's container, in its own coordinates.
        var contentCentre: CGPoint {
            guard let container = surface?.contentContainer else { return .zero }
            return CGPoint(x: container.bounds.midX, y: container.bounds.midY)
        }

        // MARK: - Content

        /// Sets the old content loose and puts the new one in its place, invisible: the fade that
        /// follows is what shows it. Called with animations off, so nothing here is animated by a
        /// block the host may be running.
        private func prepareArrival() -> (outgoing: UIView?, incoming: UIView)? {
            guard let container = surface?.contentContainer else { return nil }
            let outgoing = detachContentView(in: container)
            let renderer = contentRenderer ?? BNStandardButtonContentRenderer()
            let incoming = renderer.makeContentView(for: content, theme: activeTheme, size: size)
            incoming.isUserInteractionEnabled = false
            incoming.translatesAutoresizingMaskIntoConstraints = false
            if let outgoing {
                container.insertSubview(incoming, aboveSubview: outgoing)
            } else if let indicatorView {
                container.insertSubview(incoming, belowSubview: indicatorView)
            } else {
                container.addSubview(incoming)
            }
            contentView = incoming
            invalidateSolvedLayout()
            activateContentConstraints(for: incoming, in: container)
            incoming.apply(state: contentState, transition: .immediate)
            place(incoming, in: container)
            // Its own views are laid out now, at the size they keep. Left to the layout under the
            // spring, they would grow there from nothing — the title out of the top-left corner.
            incoming.layoutIfNeeded()
            return (outgoing, incoming)
        }

        /// Takes the current content off its constraints and leaves it where it stands, kept in
        /// place by its alignment while the outline changes size under it.
        ///
        /// One leaving view at a time: a change that lands mid-transition sends the previous one
        /// off at once, and the one that was arriving leaves from wherever its fade had got to.
        private func detachContentView(in container: UIView) -> UIView? {
            if blurOverlay != nil {
                // The content under a blur still running is shown as it is, sharp, and leaves from there.
                contentView?.alpha = 1
                removeBlurOverlay()
            }
            outgoingContentView?.removeFromSuperview()
            outgoingContentView = nil
            contentFadeAnimation?.interrupt()
            contentFadeAnimation = nil
            guard let old = contentView else { return nil }
            let bounds = old.bounds
            let center = old.center
            NSLayoutConstraint.deactivate(container.constraints.filter { $0.firstItem === old || $0.secondItem === old })
            old.translatesAutoresizingMaskIntoConstraints = true
            old.bounds = bounds
            old.center = center
            old.autoresizingMask = keepingPlaceMask
            outgoingContentView = old
            return old
        }

        var keepingPlaceMask: UIView.AutoresizingMask {
            let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
            let horizontal: UIView.AutoresizingMask = switch configuration.alignment {
            case .center: [.flexibleLeftMargin, .flexibleRightMargin]
            case .leading: rightToLeft ? .flexibleLeftMargin : .flexibleRightMargin
            case .trailing: rightToLeft ? .flexibleRightMargin : .flexibleLeftMargin
            }
            return horizontal.union([.flexibleTopMargin, .flexibleBottomMargin])
        }

        /// Puts the arriving content where it stands in the outline as it is now, centred or at
        /// its edge, at the size it is going to have, so the layout that follows only moves it.
        /// Left to the layout, it would grow out of the container's corner, where a new view
        /// starts, and squeezed into the old width its title would show an ellipsis first.
        func place(_ incoming: UIView, in container: UIView) {
            let hugs = if case .hug = configuration.width {
                true
            } else {
                false
            }
            let output = solveLayout(availableWidth: hugs ? 0 : bounds.width)
            let width = output.contentWidth
            let height = incoming.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel,
            ).height
            let room = container.bounds
            let insets = output.contentInsets
            let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
            let x: CGFloat = switch configuration.alignment {
            case .center: (room.width - width) / 2
            case .leading: rightToLeft ? room.width - insets.leading - width : insets.leading
            case .trailing: rightToLeft ? insets.trailing : room.width - insets.trailing - width
            }
            incoming.frame = CGRect(x: x, y: (room.height - height) / 2, width: width, height: height)
        }

        private func transition(
            from outgoing: UIView?,
            to incoming: UIView,
            timing: BNButtonContentTiming,
            startCentre: CGPoint,
        ) {
            guard status != .loading else {
                // Behind the spinner nothing is seen to change: the old content goes at once, and
                // the new one waits, hidden, for the spinner to give way.
                if let outgoing {
                    finishLeaving(outgoing)
                }
                removeContentDrawing()
                incoming.alpha = 0
                return
            }
            clipWhileTransitioning(for: settlingTime(of: timing))
            if drawsChange(from: outgoing, to: incoming, timing: timing, startCentre: startCentre) {
                return
            }
            let moves = contentMoves(height: incoming.bounds.height)
            UIView.performWithoutAnimation {
                incoming.alpha = 0
                incoming.transform = moves.arrivesFrom
            }

            switch timing {
            case .immediate:
                break
            case .own:
                let spring = contentSpring(for: timing)
                if let outgoing {
                    let leaving = BNCurve(duration: spring.duration * moves.leavingShare, timing: Self.leavingTiming)
                    BNTransition.curve(leaving).run {
                        outgoing.alpha = 0
                        outgoing.transform = moves.leavesTo
                    } completion: { [weak self] _ in
                        self?.finishLeaving(outgoing)
                    }
                }
                contentFadeAnimation = BNTransition.spring(spring).run(afterDelay: spring.duration * moves.arrivalDelayShare) {
                    incoming.alpha = 1
                    incoming.transform = .identity
                }
            case let .inherited(duration):
                if let outgoing {
                    leaveInHostsAnimation(outgoing, moves: moves, duration: duration)
                }
                // Straight into the host's block: the arrival takes the host's own curve.
                incoming.alpha = 1
                incoming.transform = .identity
            }
        }

        /// Nested in the host's block, but shorter and on a curve of its own: the old content must
        /// be gone before the new one is fully there.
        private func leaveInHostsAnimation(_ outgoing: UIView, moves: BNButtonContentMoves, duration: TimeInterval) {
            UIView.animate(
                withDuration: duration * moves.leavingShare,
                delay: 0,
                options: [
                    .overrideInheritedDuration,
                    .overrideInheritedCurve,
                    .curveEaseIn,
                    .allowUserInteraction,
                ],
            ) {
                outgoing.alpha = 0
                outgoing.transform = moves.leavesTo
            } completion: { [weak self] _ in
                self?.finishLeaving(outgoing)
            }
        }

        /// Where the old content goes and the new one comes from, in the ``contentTransition``
        /// style. Under Reduce Motion nothing moves or scales: every style becomes a fade.
        private func contentMoves(height: CGFloat) -> BNButtonContentMoves {
            let tuning = contentTransitionTuning
            var moves = switch contentTransition {
            // The drawn styles land here only when they cannot be drawn: then they fade through.
            case .fadeThrough, .blur, .roll:
                BNButtonContentMoves(
                    arrivesFrom: CGAffineTransform(scaleX: tuning.incomingScale, y: tuning.incomingScale),
                    leavingShare: tuning.outgoingShare,
                    arrivalDelayShare: tuning.incomingDelayShare,
                )
            case let .slide(direction):
                BNButtonContentMoves(
                    sliding: direction,
                    travel: height * Self.slideShare,
                    leavingShare: tuning.outgoingShare,
                    arrivalDelayShare: tuning.incomingDelayShare,
                )
            }
            if reducesMotion {
                moves.leavesTo = .identity
                moves.arrivesFrom = .identity
            }
            return moves
        }

        /// The leaving content accelerates away: it is on its way out, not arriving anywhere.
        static let leavingTiming = BNCurve.Timing.controlPoints(x1: 0.4, y1: 0, x2: 1, y2: 1)

        /// How far a sliding title travels, in its own heights.
        private static let slideShare: CGFloat = 0.6
        func finishLeaving(_ view: UIView) {
            view.removeFromSuperview()
            if outgoingContentView === view {
                outgoingContentView = nil
            }
        }

        // MARK: - Size

        /// Lays out the surroundings for the new size: under the button's own spring, or straight
        /// into the host's animation, whose curve it then takes. Nothing at all when the frame is
        /// left to the host: it moves on the host's next layout pass.
        ///
        /// A layout still under way from the previous change is not stopped: the new one is laid
        /// on top of it, the way UIKit's animations add up, so a quick run of changes moves on
        /// without a jolt.
        private func layOutNewSize(root: UIView?, timing: BNButtonContentTiming) {
            guard let root else { return }
            switch timing {
            case .immediate:
                break
            case .own:
                BNTransition.spring(sizeSpring).run { root.layoutIfNeeded() }
            case .inherited:
                root.layoutIfNeeded()
            }
        }

        /// The spring the outline and its surroundings move on, when the kit animates them.
        var sizeSpring: BNSpring {
            reducesMotion ? BNSpring(duration: 0.1, bounce: 0) : activeContentTuning.size
        }

        /// The view laid out once new content has changed the button's size: the root view of the
        /// nearest view controller, what a host usually lays out itself. `layoutIfNeeded()` lays
        /// out only the subtree under the view it is sent to, so a container hugging the button,
        /// laid out from the button's superview alone, would keep its old frame while the button
        /// inside it grows.
        private var sizeChangeLayoutRoot: UIView? {
            nearestViewController?.view ?? window
        }

        private var nearestViewController: UIViewController? {
            var responder = next
            while let current = responder {
                if let controller = current as? UIViewController {
                    return controller
                }
                responder = current.next
            }
            return nil
        }
    }
#endif
