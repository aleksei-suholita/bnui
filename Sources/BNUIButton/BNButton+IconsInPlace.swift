#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        // MARK: - Icons in place

        /// Takes the new content in the view already shown when its title stays: only the icons
        /// change, in every style. An icon replaced where it stands morphs by the system's replace
        /// effect, one that comes grows in where it will stand, one that goes shrinks away where it
        /// stood, and the title, with any icon that stays, slides to its new place as the outline
        /// changes. Nothing blurs or fades through: what did not change is never drawn again.
        ///
        /// Not while a roll is under way: it carries the icon change itself. A blur still drawn
        /// gives way to the content at once.
        ///
        /// - Parameters:
        ///   - timing: Who animates the change.
        ///   - holdsSides: Whether the row stays held to the old outline's sides; let go, it is laid
        ///     out at its own width until the host gives the new frame.
        /// - Returns: `false` when more than the icons changed; the whole content is then replaced.
        func takesIconsInPlace(timing: BNButtonContentTiming, holdsSides: Bool) -> Bool {
            guard contentRenderer == nil, contentDrawing == nil,
                  let view = contentView as? BNButtonContentView, view.content.title == content.title,
                  let container = surface?.contentContainer
            else { return false }
            showContentUnderBlur()
            let kept = view.rowViews
            let before = kept.map { centre(of: $0, in: container) }
            guard let change = view.takeIconsInPlace(
                from: content,
                duration: contentSpring(for: timing).duration,
                symbolDuration: symbolDuration(for: timing),
            ) else { return false }
            solveForNewIcons()
            contentPins?.holdSides(holdsSides)

            var moved: [UIView] = []
            var arrivals: [(icon: UIView, alpha: CGFloat)] = []
            UIView.performWithoutAnimation {
                view.apply(state: contentState, transition: .immediate)
                for icon in change.left {
                    setLoose(icon, in: container)
                }
                // Everything in the row stands at its new place and size at once: an icon replaced
                // in place, its glyph fitted to its frame, would swell and shrink under the replace
                // effect if its frame sprang. What moved is then carried back to where it stood
                // and slides from there.
                place(view, in: container)
                view.layoutIfNeeded()
                for (row, old) in zip(kept, before) where !change.left.contains(where: { $0 === row }) {
                    let new = centre(of: row, in: container)
                    guard old != new else { continue }
                    row.transform = CGAffineTransform(translationX: old.x - new.x, y: old.y - new.y)
                    moved.append(row)
                }
                for icon in change.arrived {
                    arrivals.append((icon, icon.alpha))
                    icon.alpha = 0
                    icon.transform = reducesMotion ? .identity : Self.iconAway
                }
            }
            clipWhileTransitioning(for: settlingTime(of: timing))
            animate(moved: moved, arrivals: arrivals, leaving: change.left, timing: timing)
            return true
        }

        private func animate(
            moved: [UIView],
            arrivals: [(icon: UIView, alpha: CGFloat)],
            leaving: [UIView],
            timing: BNButtonContentTiming,
        ) {
            let tuning = activeContentTuning
            let spring = contentSpring(for: timing)
            let leavingAway = reducesMotion ? CGAffineTransform.identity : Self.iconAway
            let slides = { for view in moved {
                view.transform = .identity
            } }
            let arrives = {
                for (icon, alpha) in arrivals {
                    icon.alpha = alpha
                    icon.transform = .identity
                }
            }
            switch timing {
            case .immediate:
                break
            case .own:
                BNTransition.spring(sizeSpring).run(slides)
                BNTransition.spring(spring).run(afterDelay: spring.duration * tuning.incomingDelayShare, arrives)
                let leavingCurve = BNCurve(duration: spring.duration * tuning.outgoingShare, timing: Self.leavingTiming)
                for icon in leaving {
                    BNTransition.curve(leavingCurve).run {
                        icon.alpha = 0
                        icon.transform = leavingAway
                    } completion: { _ in
                        icon.removeFromSuperview()
                    }
                }
            case let .inherited(duration):
                // Straight into the host's block: the slide and the arrival take its curve.
                slides()
                arrives()
                for icon in leaving {
                    UIView.animate(
                        withDuration: duration * tuning.outgoingShare,
                        delay: 0,
                        options: [.overrideInheritedDuration, .overrideInheritedCurve, .curveEaseIn, .allowUserInteraction],
                    ) {
                        icon.alpha = 0
                        icon.transform = leavingAway
                    } completion: { _ in
                        icon.removeFromSuperview()
                    }
                }
            }
        }

        /// An icon taken out of the row, put loose in the container where it stood, kept there by
        /// its alignment while the outline changes under it. Behind the spinner it just goes.
        ///
        /// Centred content grows and shrinks from both ends, so an icon there goes with the end it
        /// stood at: kept in proportion, it would lag behind the edge closing in on it.
        private func setLoose(_ icon: UIView, in container: UIView) {
            guard status != .loading else {
                icon.removeFromSuperview()
                return
            }
            let frame = icon.convert(icon.bounds, to: container)
            container.addSubview(icon)
            icon.translatesAutoresizingMaskIntoConstraints = true
            icon.transform = .identity
            icon.frame = frame
            icon.autoresizingMask = if configuration.alignment == .center {
                [
                    frame.midX > container.bounds.midX ? .flexibleLeftMargin : .flexibleRightMargin,
                    .flexibleTopMargin,
                    .flexibleBottomMargin,
                ]
            } else {
                keepingPlaceMask
            }
        }

        /// Where a view of the row stands in the container, by its layout, not by a slide still
        /// under way: animations add up, so a slide started from there carries on from wherever
        /// the last one had got to.
        private func centre(of view: UIView, in container: UIView) -> CGPoint {
            view.superview?.convert(view.center, to: container) ?? view.center
        }

        /// How long a symbol's replace effect takes: the content's share of the duration the host
        /// set, or the host's own animation; `nil` — the system's speed, when the kit's own springs
        /// run at their own pace.
        private func symbolDuration(for timing: BNButtonContentTiming) -> TimeInterval? {
            switch timing {
            case let .inherited(duration): duration
            case .own: contentTransitionDuration == nil ? nil : activeContentTuning.content.duration
            case .immediate: nil
            }
        }

        /// Solves the layout again for the icons the row holds now, at the width the change takes.
        /// The scale and the insets solved for the old icons would lay a new symbol out at the old
        /// one's size — too wide for its frame, pushed off centre — and the slide below would start
        /// from there, until the next layout pass put it back: the symbol jerked sideways and back.
        private func solveForNewIcons() {
            let hugs = if case .hug = configuration.width {
                true
            } else {
                false
            }
            let output = solveLayout(availableWidth: hugs ? 0 : bounds.width)
            solvedOutput = output
            contentPins?.apply(output.contentInsets)
        }

        /// A blur still drawn gives way at once to the content under it, to be changed in place.
        private func showContentUnderBlur() {
            guard let overlay = blurOverlay else { return }
            blurOverlay = nil
            contentView?.alpha = status == .loading ? 0 : 1
            BNTransition.curve(Self.blurHandOver).run {
                overlay.alpha = 0
            } completion: { _ in
                overlay.removeFromSuperview()
            }
        }

        /// How small an icon is when it comes and when it goes, as a symbol appears.
        private static let iconAway = CGAffineTransform(scaleX: 0.5, y: 0.5)
        private static let blurHandOver = BNCurve(duration: 0.15)
    }
#endif
