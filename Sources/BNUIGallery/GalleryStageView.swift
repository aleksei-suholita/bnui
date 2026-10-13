#if canImport(UIKit)
    import BNUI
    import UIKit

    /// Where a demo lives: the backdrop, the demo on it, and the event feed over both.
    ///
    /// The backdrop runs the full height of the screen, under the navigation bar and under the
    /// inspector, so the drawer's rounded corners show stage rather than a gap and a translucent
    /// control has the same thing behind it wherever it sits. The demo is kept inside `demoArea`,
    /// whose bottom the page pins to the inspector's top — no height of the drawer hides it.
    ///
    /// The stage menu's tools act here: a phone's width in the middle of the demo area, Core
    /// Animation slowed down for the stage alone, a frame meter and outlines over the demo.
    final class GalleryStageView: UIView {
        /// The part of the stage the demo may use.
        let demoArea = UILayoutGuide()

        /// Where the demo is placed: the demo area, or a phone's width in its middle.
        private let demoBounds = UILayoutGuide()
        private lazy var widthCap = demoBounds.widthAnchor.constraint(lessThanOrEqualToConstant: 0)
        /// Hairlines at the edges of a narrowed stage, so its width is seen and not guessed.
        private let widthEdges = [UIView(), UIView()]
        private let backdropView = GalleryBackdropView()
        private let feed: GalleryEventFeedView
        private let frameMeter = GalleryFrameMeter()
        private let outlines: GalleryOutlineView
        private let demoView: UIView
        private let layout: BNGalleryLayout
        /// A background demo's sides: the stage's own, or a narrowed stage's.
        private var backgroundAcross: [NSLayoutConstraint] = []
        private var backgroundNarrowed: [NSLayoutConstraint] = []

        init(demoView: UIView, layout: BNGalleryLayout, feedEdge: BNGalleryEventFeedEdge) {
            self.demoView = demoView
            self.layout = layout
            feed = GalleryEventFeedView(edge: feedEdge)
            outlines = GalleryOutlineView(target: demoView)
            super.init(frame: .zero)
            addLayoutGuide(demoArea)
            addLayoutGuide(demoBounds)
            let fullWidth = demoBounds.widthAnchor.constraint(equalTo: demoArea.widthAnchor)
            fullWidth.priority = .defaultHigh
            NSLayoutConstraint.activate([
                demoBounds.topAnchor.constraint(equalTo: demoArea.topAnchor),
                demoBounds.bottomAnchor.constraint(equalTo: demoArea.bottomAnchor),
                demoBounds.centerXAnchor.constraint(equalTo: demoArea.centerXAnchor),
                demoBounds.widthAnchor.constraint(lessThanOrEqualTo: demoArea.widthAnchor),
                fullWidth,
            ])
            backdropView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(backdropView)
            NSLayoutConstraint.activate([
                backdropView.topAnchor.constraint(equalTo: topAnchor),
                backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),
                backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
                backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            demoView.translatesAutoresizingMaskIntoConstraints = false
            switch layout {
            case .centred: placeFitting(inset: nil)
            case let .width(at: .center, margin): placeFitting(inset: margin ?? BNGallerySpacing.m)
            case let .width(at: position, margin): placeAtEdge(position, margin: margin ?? 0)
            case .fill: placeFilling()
            case .background: placeAsBackground()
            }
            placeTools()
            placeFeed(at: feedEdge)
            placeFrameMeter()
            setBackdrop(.plain)
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func setBackdrop(_ backdrop: BNGalleryBackdrop) {
            // A background demo covers the whole stage; nothing of the stage's own should draw.
            backdropView.isHidden = layout == .background
            backdropView.backdrop = backdrop
        }

        func post(_ event: String) {
            feed.post(event)
        }

        /// Reset: the feed empties and the hitch count starts again.
        func clearEvents() {
            feed.clear()
            frameMeter.reset()
        }

        /// The stage menu's tools: the width, Core Animation's speed and the overlays.
        func apply(_ environment: GalleryEnvironment) {
            setWidth(environment.width.points)
            setAnimationSpeed(environment.speed.factor)
            frameMeter.isRunning = environment.showsFrameRate
            outlines.isRunning = environment.showsOutlines
        }

        private func setWidth(_ points: CGFloat?) {
            widthCap.constant = points ?? 0
            widthCap.isActive = points != nil
            for edge in widthEdges {
                edge.isHidden = points == nil
            }
            guard layout == .background else { return }
            NSLayoutConstraint.deactivate(points == nil ? backgroundNarrowed : backgroundAcross)
            NSLayoutConstraint.activate(points == nil ? backgroundAcross : backgroundNarrowed)
        }

        /// Re-based on the moment of the switch, so what is in flight carries on from where it is
        /// instead of jumping to where the new speed says it would be by now.
        private func setAnimationSpeed(_ speed: Float) {
            guard layer.speed != speed else { return }
            let now = CACurrentMediaTime()
            layer.timeOffset = layer.convertTime(now, from: nil)
            layer.beginTime = layer.superlayer?.convertTime(now, from: nil) ?? now
            layer.speed = speed
        }

        /// The width's hairlines and the outlines, over the demo and under the feed.
        private func placeTools() {
            for (index, edge) in widthEdges.enumerated() {
                edge.isHidden = true
                edge.backgroundColor = BNGalleryColor.separator
                edge.isUserInteractionEnabled = false
                edge.translatesAutoresizingMaskIntoConstraints = false
                addSubview(edge)
                NSLayoutConstraint.activate([
                    edge.topAnchor.constraint(equalTo: topAnchor),
                    edge.bottomAnchor.constraint(equalTo: bottomAnchor),
                    edge.widthAnchor.constraint(equalToConstant: 1),
                    index == 0
                        ? edge.trailingAnchor.constraint(equalTo: demoBounds.leadingAnchor)
                        : edge.leadingAnchor.constraint(equalTo: demoBounds.trailingAnchor),
                ])
            }
            outlines.translatesAutoresizingMaskIntoConstraints = false
            addSubview(outlines)
            NSLayoutConstraint.activate([
                outlines.topAnchor.constraint(equalTo: topAnchor),
                outlines.bottomAnchor.constraint(equalTo: bottomAnchor),
                outlines.leadingAnchor.constraint(equalTo: leadingAnchor),
                outlines.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        /// At the top corner the feed leaves free.
        private func placeFrameMeter() {
            frameMeter.translatesAutoresizingMaskIntoConstraints = false
            addSubview(frameMeter)
            NSLayoutConstraint.activate([
                frameMeter.topAnchor.constraint(equalTo: demoBounds.topAnchor, constant: BNGallerySpacing.s + 4),
                frameMeter.trailingAnchor.constraint(equalTo: demoBounds.trailingAnchor, constant: -BNGallerySpacing.m),
            ])
        }

        /// The height a self-sizing demo needs, margins included — what the inspector's middle
        /// height leaves the stage. `nil` for a full-bleed demo, which takes whatever it is given.
        var demoFittingHeight: CGFloat? {
            let margins = 2 * BNGallerySpacing.m
            switch layout {
            case .centred:
                return demoView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height + margins
            case let .width(at: position, margin):
                // Measured at the width it will be given: a field's or a bar's height can depend on it.
                let inset = margin ?? (position == .center ? BNGallerySpacing.m : 0)
                let width = demoBounds.layoutFrame.width - 2 * inset
                let size = demoView.systemLayoutSizeFitting(
                    CGSize(width: max(width, 0), height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel,
                )
                return size.height + margins + (position == .center ? 0 : margin ?? 0)
            case .fill, .background:
                return nil
            }
        }

        /// A bar at an edge of the demo area, the way it sits on a screen: edge to edge, or inset
        /// by `margin` from the sides and that edge.
        private func placeAtEdge(_ position: BNGalleryLayout.Position, margin: CGFloat) {
            addSubview(demoView)
            NSLayoutConstraint.activate([
                demoView.leadingAnchor.constraint(equalTo: demoBounds.leadingAnchor, constant: margin),
                demoView.trailingAnchor.constraint(equalTo: demoBounds.trailingAnchor, constant: -margin),
                position == .bottom
                    ? demoView.bottomAnchor.constraint(equalTo: demoBounds.bottomAnchor, constant: -margin)
                    : demoView.topAnchor.constraint(equalTo: demoBounds.topAnchor, constant: margin),
            ])
        }

        /// The whole stage, edge to edge. The demo lays its sample content out against its own
        /// safe area, which already clears the navigation bar.
        private func placeAsBackground() {
            addSubview(demoView)
            NSLayoutConstraint.activate([
                demoView.topAnchor.constraint(equalTo: topAnchor),
                demoView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            backgroundAcross = [
                demoView.leadingAnchor.constraint(equalTo: leadingAnchor),
                demoView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ]
            backgroundNarrowed = [
                demoView.leadingAnchor.constraint(equalTo: demoBounds.leadingAnchor),
                demoView.trailingAnchor.constraint(equalTo: demoBounds.trailingAnchor),
            ]
            NSLayoutConstraint.activate(backgroundAcross)
        }

        private func placeFeed(at edge: BNGalleryEventFeedEdge) {
            feed.translatesAutoresizingMaskIntoConstraints = false
            addSubview(feed)
            let margin = BNGallerySpacing.m
            NSLayoutConstraint.activate([
                feed.leadingAnchor.constraint(equalTo: demoBounds.leadingAnchor, constant: margin),
                feed.trailingAnchor.constraint(lessThanOrEqualTo: demoBounds.trailingAnchor, constant: -margin),
                edge == .top
                    ? feed.topAnchor.constraint(equalTo: demoBounds.topAnchor, constant: BNGallerySpacing.s + 4)
                    : feed.bottomAnchor.constraint(equalTo: demoBounds.bottomAnchor, constant: -(BNGallerySpacing.s + 4)),
            ])
        }

        private func placeFilling() {
            addSubview(demoView)
            NSLayoutConstraint.activate([
                demoView.topAnchor.constraint(equalTo: demoBounds.topAnchor),
                demoView.bottomAnchor.constraint(equalTo: demoBounds.bottomAnchor),
                demoView.leadingAnchor.constraint(equalTo: demoBounds.leadingAnchor),
                demoView.trailingAnchor.constraint(equalTo: demoBounds.trailingAnchor),
            ])
        }

        /// A control across the width keeps `inset` from the sides instead of its own width; without
        /// one, the control decides by itself (``GalleryWidthFitView``). When the stage gets shorter
        /// than the control — the drawer pulled up — it scrolls instead of being clipped, and only
        /// then: a scroll view that is always live would claim the vertical half of every drag
        /// made on the demo.
        private func placeFitting(inset: CGFloat?) {
            let scroll = GalleryFitScrollView()
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.delaysContentTouches = false
            scroll.showsHorizontalScrollIndicator = false
            scroll.contentInsetAdjustmentBehavior = .never
            scroll.backgroundColor = .clear
            addSubview(scroll)

            let content = UIView()
            content.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(content)
            let fitted = inset == nil ? GalleryWidthFitView(demo: demoView) : demoView
            fitted.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(fitted)

            // Exactly the visible height unless the demo needs more.
            let fitsFrame = content.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
            fitsFrame.priority = .defaultLow
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: demoBounds.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: demoBounds.bottomAnchor),
                scroll.leadingAnchor.constraint(equalTo: demoBounds.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: demoBounds.trailingAnchor),
                content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
                content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
                fitsFrame,
                fitted.centerYAnchor.constraint(equalTo: content.centerYAnchor),
                fitted.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: BNGallerySpacing.m),
                fitted.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -BNGallerySpacing.m),
                fitted.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: inset ?? BNGallerySpacing.m),
                fitted.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -(inset ?? BNGallerySpacing.m)),
            ])
        }
    }

    /// Holds a demo across its width or centred at its own, as the demo says: one with a width of
    /// its own — a button that hugs its title — is centred at it; one without — a button that
    /// fills — spans. Asked again on every layout pass, so a demo that switches between the two
    /// is laid out again.
    final class GalleryWidthFitView: UIView {
        private let demo: UIView
        private var across: [NSLayoutConstraint] = []
        private var centred: [NSLayoutConstraint] = []
        private var spans: Bool?

        init(demo: UIView) {
            self.demo = demo
            super.init(frame: .zero)
            demo.translatesAutoresizingMaskIntoConstraints = false
            addSubview(demo)
            NSLayoutConstraint.activate([
                demo.topAnchor.constraint(equalTo: topAnchor),
                demo.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            across = [
                demo.leadingAnchor.constraint(equalTo: leadingAnchor),
                demo.trailingAnchor.constraint(equalTo: trailingAnchor),
            ]
            centred = [
                demo.centerXAnchor.constraint(equalTo: centerXAnchor),
                demo.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
                demo.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            ]
            fit()
        }

        nonisolated deinit {}

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func layoutSubviews() {
            // Before the pass, so a demo that changed its mind is placed by the new rule in it.
            fit()
            super.layoutSubviews()
        }

        private func fit() {
            let spans = demo.intrinsicContentSize.width == UIView.noIntrinsicMetric
            guard spans != self.spans else { return }
            self.spans = spans
            NSLayoutConstraint.deactivate(spans ? centred : across)
            NSLayoutConstraint.activate(spans ? across : centred)
        }
    }

    /// Scrolls only when its content is taller than it is.
    private final class GalleryFitScrollView: UIScrollView {
        nonisolated deinit {}

        override func layoutSubviews() {
            super.layoutSubviews()
            let scrolls = contentSize.height > bounds.height + 0.5
            if isScrollEnabled != scrolls {
                isScrollEnabled = scrolls
                alwaysBounceVertical = scrolls
            }
        }
    }

#endif
