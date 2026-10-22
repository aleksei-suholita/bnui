#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Two-layer lens: the colour change happens exactly on the lens edge, not across the item.
    ///
    /// Both content layers hold the same items in the same places. Two masks decide what is seen:
    /// the selected layer is clipped **to** the lens capsule, the base layer is clipped to
    /// everything **except** it. Dragging then makes the selection flow through an icon rather
    /// than flipping it.
    ///
    /// The inversion uses `evenOdd` on a path with an outer rectangle — the reference
    /// implementation reaches for a private `CAFilter` for this, which we neither need nor allow.
    public struct BNMaskedLensRenderer: BNTabBarLensRenderer {
        public init() {}

        public func makeLens() -> any BNTabBarLens {
            BNMaskedLensView()
        }
    }

    final class BNMaskedLensView: UIView, BNTabBarLens {
        let contentView = UIView()
        let selectedContentView = UIView()
        var revealsSelectedContent: Bool {
            true
        }

        /// The marker: a tinted capsule that moves and resizes by frame.
        private let shape = UIView()
        private let baseMask = CAShapeLayer()
        private let selectedMask = CAShapeLayer()
        // Position and size animate independently: a section of a different width changes only
        // the size, so the travel already in flight is never interrupted mid-way — that is what
        // removed the velocity reset felt as a jerk on release.
        private var positionAnimation: BNAnimation?
        private var boundsAnimation: BNAnimation?
        private var lastCenter: CGPoint = .zero
        private var lastFrame: CGRect = .zero
        /// Runs only while a spring carries the marker, reading its presentation each frame.
        private var maskLink: CADisplayLink?
        /// Cap on the relative momentum a release may hand the spring. Momentum is speed over
        /// the remaining travel, so a flick released almost on target would otherwise divide
        /// by a few points and fling the marker across the bar and back.
        private static let maxMomentum: CGFloat = 12

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false

            shape.bnApplyCapsule()
            // Marker underneath, then the base items, then the revealed copy.
            // Putting the marker above the base layer would cover the very
            // icons it is supposed to sit behind.
            addSubview(shape)
            addSubview(contentView)
            addSubview(selectedContentView)
            // Both layers are held by constraints, so the bar's width keeps flowing from the items
            // up through the lens to the capsule. Only the marker moves by frame.
            pinToEdges(contentView)
            pinToEdges(selectedContentView)

            contentView.layer.mask = baseMask
            selectedContentView.layer.mask = selectedMask
            baseMask.fillRule = .evenOdd
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        private func pinToEdges(_ view: UIView) {
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        /// The punch-out is cut from `bounds`, so a resize invalidates it.
        ///
        /// Cut from where the marker *is*, never from where it is going: a layout pass lands
        /// mid-travel as well (releasing refreshes the item stacks, which invalidates the lens),
        /// and cutting from the model frame then reveals the destination a frame before the
        /// marker arrives — the flash of colour on the icon ahead of the lens.
        override func layoutSubviews() {
            super.layoutSubviews()
            guard !lastFrame.isEmpty else { return }
            syncMasksWithMarker()
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow == nil {
                stopFollowingMarker()
            }
        }

        func update(state: BNTabBarLensState, theme: BNTabBarTheme, transition: BNTransition) {
            shape.backgroundColor = theme.palette.lensTint

            // The marker sits a little inside its section. It does not grow under the finger by
            // itself: it lies in the bar's material, and glass that answers a touch lifts it along
            // with everything else on it.
            let inset = theme.geometry.lensInset
            let target = state.selection.insetBy(dx: inset, dy: inset)
            let targetCenter = CGPoint(x: target.midX, y: target.midY)
            let targetBounds = CGRect(origin: .zero, size: target.size)
            lastFrame = target

            guard transition.isAnimated else {
                positionAnimation?.interrupt()
                positionAnimation = nil
                boundsAnimation?.interrupt()
                boundsAnimation = nil
                stopFollowingMarker()
                shape.center = targetCenter
                shape.bounds = targetBounds
                lastCenter = targetCenter
                setMasks(to: target)
                return
            }

            // Only re-spring the position when the centre actually moves: a section of another
            // width changes the size only, so the travel in progress finishes rather than being
            // reset to zero velocity.
            if abs(targetCenter.x - lastCenter.x) > 0.5 || abs(targetCenter.y - lastCenter.y) > 0.5 {
                positionAnimation?.interrupt()
                // Stopping leaves the marker where it is on screen, so the distance still to go
                // is measured from there — an interrupted spring is exactly the case where "where
                // it was told to go last time" and "where it is" differ. Measured along the way the
                // marker travels: across a row, down a column.
                let dx = targetCenter.x - shape.center.x
                let dy = targetCenter.y - shape.center.y
                let travel = abs(dy) > abs(dx) ? dy : dx
                // UIKit wants momentum as a fraction of the remaining travel per second, which is
                // why the finger's speed arrives in points and is divided here, not at the source.
                let momentum = abs(travel) > 0.5
                    ? min(max(state.velocity / travel, -Self.maxMomentum), Self.maxMomentum)
                    : 0
                positionAnimation = transition.carrying(momentum).run { [shape] in shape.center = targetCenter }
                lastCenter = targetCenter
            }
            // Around a fixed centre the size changes symmetrically, no edge twitch.
            boundsAnimation?.interrupt()
            boundsAnimation = transition.run { [shape] in shape.bounds = targetBounds }

            // The masks are not animated alongside: they are driven from the marker's presentation
            // every frame while a spring carries it, so the reveal cannot drift from the marker's
            // edge whatever the spring does — momentum, interruption or retarget included.
            followMarker()
        }

        // MARK: - Masks

        private func setMasks(to lensFrame: CGRect) {
            // Half the shorter side: a row's marker is wider than high, a column's may be higher.
            let capsule = UIBezierPath(
                roundedRect: lensFrame,
                cornerRadius: min(lensFrame.width, lensFrame.height) / 2,
            )
            // Everything except the capsule: outer rect plus the capsule, wound with evenOdd.
            let inverted = UIBezierPath(rect: bounds)
            inverted.append(capsule)

            // Mask layers are standalone, so a path change would get Core Animation's implicit
            // quarter-second — a smear behind a marker that is set per frame. Disabled explicitly.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            selectedMask.path = capsule.cgPath
            baseMask.path = inverted.cgPath
            CATransaction.commit()
        }

        private func followMarker() {
            guard maskLink == nil else { return }
            let link = CADisplayLink(target: MarkerFollower(lens: self), selector: #selector(MarkerFollower.tick(_:)))
            // Every frame the display can give: the masks lag the marker by whatever is skipped.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            maskLink = link
        }

        private func stopFollowingMarker() {
            maskLink?.invalidate()
            maskLink = nil
        }

        /// One frame of the reveal: the masks are cut where the marker *is*, not where it is going.
        fileprivate func syncMasksWithMarker() {
            let stillMoving = positionAnimation?.isRunning == true || boundsAnimation?.isRunning == true
            guard stillMoving else {
                // Settled or interrupted — either way the model frame is the truth again.
                stopFollowingMarker()
                setMasks(to: lastFrame)
                return
            }
            // No presentation yet means the animation has not reached the render tree; the
            // next frame will have it. Skipping keeps the masks where they were instead of
            // jumping them to the destination ahead of the marker.
            guard let presented = shape.layer.presentation() else { return }
            let size = presented.bounds.size
            setMasks(to: CGRect(
                x: presented.position.x - size.width / 2,
                y: presented.position.y - size.height / 2,
                width: size.width,
                height: size.height,
            ))
        }
    }

    /// Display-link target that does not retain the lens. The lens normally invalidates the link
    /// itself; should it be deallocated mid-spring, the next tick finds it gone and stops the
    /// link, so no timer outlives the view it served.
    private final class MarkerFollower {
        private weak var lens: BNMaskedLensView?

        init(lens: BNMaskedLensView) {
            self.lens = lens
        }

        nonisolated deinit {}

        @objc func tick(_ link: CADisplayLink) {
            guard let lens else {
                link.invalidate()
                return
            }
            lens.syncMasksWithMarker()
        }
    }

    private extension BNTransition {
        /// The same transition with a spring pushed by `momentum`; curves and jumps are untouched.
        func carrying(_ momentum: CGFloat) -> BNTransition {
            guard case let .spring(spring) = self else { return self }
            return .spring(spring.withInitialVelocity(momentum))
        }
    }
#endif
