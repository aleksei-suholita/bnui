#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// Where a demo lives: the backdrop, the demo on it, and the event feed over both.
    ///
    /// The backdrop runs the full height of the screen, under the navigation bar and under the
    /// inspector, so the drawer's rounded corners show stage rather than a gap and a translucent
    /// control has the same thing behind it wherever it sits. The demo is kept inside `demoArea`,
    /// whose bottom the page pins to the inspector's top — no height of the drawer hides it.
    final class GalleryStageView: UIView {
        /// The part of the stage the demo may use.
        let demoArea = UILayoutGuide()

        private let backdropView = GalleryBackdropView()
        private let feed: GalleryEventFeedView
        private let demoView: UIView
        private let placement: Placement

        /// How the demo sits on the stage.
        enum Placement {
            /// Sizes itself: centred in the demo area, scrolling if the area gets shorter.
            case centred
            /// Sized by its container: pinned to the demo area.
            case filling
            /// Is a background: pinned to the whole stage, in place of the backdrop.
            case background
        }

        init(demoView: UIView, placement: Placement, feedEdge: GalleryEventFeedEdge) {
            self.demoView = demoView
            self.placement = placement
            feed = GalleryEventFeedView(edge: feedEdge)
            super.init(frame: .zero)
            addLayoutGuide(demoArea)
            backdropView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(backdropView)
            NSLayoutConstraint.activate([
                backdropView.topAnchor.constraint(equalTo: topAnchor),
                backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),
                backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
                backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            demoView.translatesAutoresizingMaskIntoConstraints = false
            switch placement {
            case .centred: placeCentred()
            case .filling: placeFilling()
            case .background: placeAsBackground()
            }
            placeFeed(at: feedEdge)
            setBackdrop(.plain)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func setBackdrop(_ backdrop: GalleryBackdrop) {
            // A background demo covers the whole stage; nothing of the stage's own should draw.
            backdropView.isHidden = placement == .background
            backdropView.backdrop = backdrop
        }

        func post(_ event: String) {
            feed.post(event)
        }

        func clearEvents() {
            feed.clear()
        }

        /// The height a self-sizing demo needs, margins included — what the inspector's middle
        /// height leaves the stage. `nil` for a full-bleed demo, which takes whatever it is given.
        var demoFittingHeight: CGFloat? {
            guard placement == .centred else { return nil }
            return demoView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height + 2 * BNGallerySpacing.m
        }

        /// The whole stage, edge to edge. The demo lays its sample content out against its own
        /// safe area, which already clears the navigation bar.
        private func placeAsBackground() {
            addSubview(demoView)
            NSLayoutConstraint.activate([
                demoView.topAnchor.constraint(equalTo: topAnchor),
                demoView.bottomAnchor.constraint(equalTo: bottomAnchor),
                demoView.leadingAnchor.constraint(equalTo: leadingAnchor),
                demoView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        private func placeFeed(at edge: GalleryEventFeedEdge) {
            feed.translatesAutoresizingMaskIntoConstraints = false
            addSubview(feed)
            let margin = BNGallerySpacing.m
            NSLayoutConstraint.activate([
                feed.leadingAnchor.constraint(equalTo: demoArea.leadingAnchor, constant: margin),
                feed.trailingAnchor.constraint(lessThanOrEqualTo: demoArea.trailingAnchor, constant: -margin),
                edge == .top
                    ? feed.topAnchor.constraint(equalTo: demoArea.topAnchor, constant: BNGallerySpacing.s + 4)
                    : feed.bottomAnchor.constraint(equalTo: demoArea.bottomAnchor, constant: -(BNGallerySpacing.s + 4)),
            ])
        }

        private func placeFilling() {
            addSubview(demoView)
            NSLayoutConstraint.activate([
                demoView.topAnchor.constraint(equalTo: demoArea.topAnchor),
                demoView.bottomAnchor.constraint(equalTo: demoArea.bottomAnchor),
                demoView.leadingAnchor.constraint(equalTo: demoArea.leadingAnchor),
                demoView.trailingAnchor.constraint(equalTo: demoArea.trailingAnchor),
            ])
        }

        /// A control that sizes itself is centred. When the stage gets shorter than the control —
        /// the drawer pulled up — it scrolls instead of being clipped, and only then: a scroll view
        /// that is always live would claim the vertical half of every drag made on the demo.
        private func placeCentred() {
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
            content.addSubview(demoView)

            // Exactly the visible height unless the demo needs more.
            let fitsFrame = content.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
            fitsFrame.priority = .defaultLow
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: demoArea.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: demoArea.bottomAnchor),
                scroll.leadingAnchor.constraint(equalTo: demoArea.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: demoArea.trailingAnchor),
                content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
                content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
                fitsFrame,
                demoView.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                demoView.centerYAnchor.constraint(equalTo: content.centerYAnchor),
                demoView.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: BNGallerySpacing.m),
                demoView.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -BNGallerySpacing.m),
            ])
        }
    }

    /// Scrolls only when its content is taller than it is.
    private final class GalleryFitScrollView: UIScrollView {
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
