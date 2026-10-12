#if canImport(UIKit)
    import BNUI
    import UIKit

    /// Drives the inspector's height on a phone: works out its stops, follows a drag from the
    /// header or from the list, and settles.
    ///
    /// Up to three stops, each worked out from what it has to show rather than from fixed shares
    /// of the screen:
    ///
    /// - **collapsed** — the header alone, above the home indicator;
    /// - **medium** — whatever leaves the stage exactly a self-sizing demo's height, or the page's
    ///   share of the screen for a full-bleed demo;
    /// - **expanded** — every knob and no taller; past that the stage keeps a quarter of the screen.
    ///
    /// A stop too close to its neighbour is dropped, so a page with three knobs has two stops, not
    /// three nearly identical ones. A flick moves the drawer one stop, a slow release settles on
    /// the nearest, a tap on the header steps through them.
    final class GalleryDrawer: NSObject, UIScrollViewDelegate {
        typealias Detent = GalleryInspectorView.Detent

        struct Stop {
            let detent: Detent
            let height: CGFloat
        }

        private struct Measurement {
            let width: CGFloat
            let category: UIContentSizeCategory
            let height: CGFloat
        }

        /// Each page opens at the height it was last left at in this session.
        private static var remembered: [String: Detent] = [:]
        /// Two stops closer than this are one stop.
        private static let minimumStopGap: CGFloat = 80
        /// A release faster than this, in points per second, is a flick.
        private static let flickVelocity: CGFloat = 500

        let height: NSLayoutConstraint
        /// Off on a regular-width screen, where the inspector is a sidebar.
        var isEnabled = true {
            didSet {
                headerPan.isEnabled = isEnabled
                headerTap.isEnabled = isEnabled
            }
        }

        /// Hidden while the demo is typed into, the stage then running down to the keyboard —
        /// the page moves the stage's edge; the drawer only fades and stays on its stop, since its
        /// header has a height no constraint of the drawer's can take away.
        var isTucked = false {
            didSet {
                guard isTucked != oldValue else { return }
                animation?.interrupt()
                let tucked = isTucked
                animation = BNTransition.spring(BNSpring(duration: 0.42, bounce: 0)).run { [weak self] in
                    self?.inspector.alpha = tucked ? 0 : 1
                    self?.host?.layoutIfNeeded()
                }
            }
        }

        private(set) var detent: Detent
        private weak var host: UIView?
        private let inspector: GalleryInspectorView
        private let stage: GalleryStageView
        private let demoAreaFraction: CGFloat
        private let memoryKey: String
        private var animation: BNAnimation?
        private var measurement: Measurement?
        private(set) var isDragging = false
        private var dragStartHeight: CGFloat = 0
        /// The list drag currently drives the drawer rather than the list.
        private var listMovesDrawer = false
        /// The height the list drag asks for, before the rubber band.
        private var listDrawerHeight: CGFloat = 0
        private var listLastTranslation: CGFloat = 0
        /// The list's offset before the latest pan step — it has already scrolled by the time the
        /// drawer hears about the step, so its current offset cannot answer "was it at the top".
        private var listOffsetBeforeStep: CGFloat = 0
        /// Once the drawer took a drag, the list must not fling on release.
        private var listHeldStill = false
        private lazy var headerPan = UIPanGestureRecognizer(target: self, action: #selector(handleHeaderPan))
        private lazy var headerTap = UITapGestureRecognizer(target: self, action: #selector(handleHeaderTap))

        init(host: UIView, inspector: GalleryInspectorView, stage: GalleryStageView, page: any BNGalleryPage) {
            self.host = host
            self.inspector = inspector
            self.stage = stage
            // A demo that sizes itself is measured instead; a background takes the default half.
            demoAreaFraction = if case let .fill(share) = page.layout {
                share
            } else {
                0.5
            }
            memoryKey = page.title
            detent = Self.remembered[page.title] ?? .medium
            height = inspector.heightAnchor.constraint(equalToConstant: BNGalleryMetrics.inspectorHeaderHeight)
            // Below required, so a keyboard takes the drawer's height rather than the stage's.
            height.priority = .init(999)
            super.init()
            inspector.header.addGestureRecognizer(headerPan)
            inspector.header.addGestureRecognizer(headerTap)
            inspector.scrollView.delegate = self
            inspector.scrollView.panGestureRecognizer.addTarget(self, action: #selector(handleListPan))
            inspector.onGrow = { [weak self] in self?.step(by: 1, wrapping: false) }
            inspector.onShrink = { [weak self] in self?.step(by: -1, wrapping: false) }
            inspector.setDetent(detent)
        }

        /// Puts the drawer on its stop for the current screen. Stops move with a rotation, a new
        /// safe area or a text size, so this runs on every layout — and does nothing mid-drag or
        /// mid-settle, where the height is owned by the finger or the spring.
        func snapToCurrentStop() {
            guard isEnabled, !isTucked, !isDragging, animation?.isRunning != true else { return }
            let target = stop(nearest: detent).height
            if abs(height.constant - target) > 0.5 {
                height.constant = target
            }
        }

        // MARK: - Stops

        /// Lowest first; always at least the collapsed one.
        var stops: [Stop] {
            guard let host else { return [Stop(detent: .collapsed, height: BNGalleryMetrics.inspectorHeaderHeight)] }
            let insets = host.safeAreaInsets
            let available = max(host.bounds.height - insets.top, 0)
            let collapsed = BNGalleryMetrics.inspectorHeaderHeight + insets.bottom
            let ceiling = max(available - max(available * 0.25, 180), collapsed)
            let expanded = max(min(contentHeight(in: host) + insets.bottom, ceiling), collapsed)
            let stageShare = stage.demoFittingHeight ?? available * demoAreaFraction
            let medium = min(max(available - stageShare, collapsed), expanded)

            var result = [Stop(detent: .collapsed, height: collapsed)]
            if medium - collapsed >= Self.minimumStopGap {
                result.append(Stop(detent: .medium, height: medium))
            }
            if let last = result.last, expanded - last.height >= Self.minimumStopGap {
                result.append(Stop(detent: .expanded, height: expanded))
            }
            return result
        }

        /// The stop for a detent, or — on a page too small to have it — the stop nearest to where
        /// that detent would have been.
        func stop(nearest detent: Detent) -> Stop {
            let available = stops
            if let exact = available.first(where: { $0.detent == detent }) {
                return exact
            }
            let screen = host?.bounds.height ?? 0
            let wanted: CGFloat = switch detent {
            case .collapsed: 0
            case .medium: screen / 2
            case .expanded: screen
            }
            return available.min { abs($0.height - wanted) < abs($1.height - wanted) } ?? available[0]
        }

        /// The knob list's full height at the drawer's width, measured once per width and text
        /// size — the rows do not change otherwise, and a drag asks on every frame.
        private func contentHeight(in host: UIView) -> CGFloat {
            let width = inspector.bounds.width
            let category = host.traitCollection.preferredContentSizeCategory
            if let measurement, measurement.width == width, measurement.category == category {
                return measurement.height
            }
            inspector.layoutIfNeeded()
            let content = inspector.contentHeight
            if width > 0 {
                measurement = Measurement(width: width, category: category, height: content)
            }
            return content
        }

        // MARK: - Gestures

        @objc private func handleHeaderPan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                beginDrag()
                dragStartHeight = height.constant
            case .changed:
                move(to: dragStartHeight - gesture.translation(in: host).y)
            case .ended, .cancelled, .failed:
                endDrag(velocity: -gesture.velocity(in: host).y)
            default:
                break
            }
        }

        /// Rides along with the list's own pan. While the list is at its top, a drag down shrinks
        /// the drawer and a drag up grows it until the tallest stop, the list held still meanwhile.
        /// Once the drawer has a drag it keeps it to the end: handing it back to the list halfway
        /// would make the content jump by the distance already travelled.
        @objc private func handleListPan(_ gesture: UIPanGestureRecognizer) {
            guard isEnabled else { return }
            let list = inspector.scrollView
            let top = -list.adjustedContentInset.top
            switch gesture.state {
            case .began:
                listLastTranslation = 0
                listMovesDrawer = false
            case .changed:
                let translation = gesture.translation(in: host).y
                let delta = translation - listLastTranslation
                listLastTranslation = translation
                defer { listOffsetBeforeStep = list.contentOffset.y }
                if !listMovesDrawer {
                    guard listShouldTakeDrawer(delta: delta, top: top) else { return }
                    beginDrag()
                    listMovesDrawer = true
                    listHeldStill = true
                    listDrawerHeight = height.constant
                }
                listDrawerHeight -= delta
                move(to: listDrawerHeight)
                list.contentOffset.y = top
            case .ended, .cancelled, .failed:
                guard listMovesDrawer else { return }
                listMovesDrawer = false
                endDrag(velocity: -gesture.velocity(in: host).y)
            default:
                break
            }
        }

        private func listShouldTakeDrawer(delta: CGFloat, top: CGFloat) -> Bool {
            guard listOffsetBeforeStep <= top + 0.5 else { return false }
            let current = stops
            let canGrow = delta < 0 && height.constant < (current.last?.height ?? 0) - 0.5
            let canShrink = delta > 0 && height.constant > (current.first?.height ?? 0) + 0.5
            return canGrow || canShrink
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            listOffsetBeforeStep = scrollView.contentOffset.y
            listHeldStill = false
        }

        func scrollViewWillEndDragging(
            _ scrollView: UIScrollView,
            withVelocity _: CGPoint,
            targetContentOffset: UnsafeMutablePointer<CGPoint>,
        ) {
            guard listHeldStill else { return }
            targetContentOffset.pointee.y = -scrollView.adjustedContentInset.top
        }

        /// A tap on the header steps up through the stops and wraps back to collapsed — the system
        /// grabber's behaviour.
        @objc private func handleHeaderTap() {
            step(by: 1, wrapping: true)
        }

        // MARK: - Moving

        /// Caught mid-settle, the drawer continues from where it is on screen, not from where the
        /// spring was taking it.
        private func beginDrag() {
            let onScreen = inspector.layer.presentation()?.bounds.height ?? inspector.bounds.height
            animation?.interrupt()
            animation = nil
            isDragging = true
            height.constant = onScreen
            host?.layoutIfNeeded()
        }

        private func move(to proposed: CGFloat) {
            let current = stops
            let lowest = current.first?.height ?? proposed
            let highest = current.last?.height ?? proposed
            height.constant = Self.rubberBand(proposed, within: lowest ... highest)
            host?.layoutIfNeeded()
        }

        /// A flick moves one stop in its direction from wherever the drawer is; a slow release
        /// settles on the nearest stop. Projecting the flick instead would let a hard one skip the
        /// middle stop, which reads as the drawer running away.
        private func endDrag(velocity: CGFloat) {
            isDragging = false
            let current = stops
            let now = height.constant
            let top = current.last ?? current[0]
            let target: Stop = if velocity > Self.flickVelocity {
                current.first { $0.height > now + 1 } ?? top
            } else if velocity < -Self.flickVelocity {
                current.last { $0.height < now - 1 } ?? current[0]
            } else {
                current.min { abs($0.height - now) < abs($1.height - now) } ?? top
            }
            settle(at: target, velocity: velocity)
        }

        private func step(by offset: Int, wrapping: Bool) {
            let current = stops
            let here = stop(nearest: detent).detent
            let index = current.firstIndex { $0.detent == here } ?? 0
            let next = wrapping
                ? (index + offset + current.count) % current.count
                : min(max(index + offset, 0), current.count - 1)
            settle(at: current[next])
        }

        private func settle(at stop: Stop, velocity: CGFloat = 0) {
            detent = stop.detent
            Self.remembered[memoryKey] = stop.detent
            inspector.setDetent(stop.detent)
            let distance = stop.height - height.constant
            // The finger's speed as a share of the distance left, the unit the spring takes.
            let momentum = abs(distance) > 1 ? min(max(velocity / distance, -12), 12) : 0
            animation?.interrupt()
            height.constant = stop.height
            let spring = BNSpring(duration: 0.42, bounce: 0.1).withInitialVelocity(momentum)
            animation = BNTransition.spring(spring).run { [weak self] in
                self?.host?.layoutIfNeeded()
            }
        }

        /// Past either end the drawer still follows the finger, at a third of its travel.
        private static func rubberBand(_ value: CGFloat, within limits: ClosedRange<CGFloat>) -> CGFloat {
            if value < limits.lowerBound {
                return limits.lowerBound - (limits.lowerBound - value) / 3
            }
            if value > limits.upperBound {
                return limits.upperBound + (value - limits.upperBound) / 3
            }
            return value
        }
    }
#endif
