#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// The knob panel: a header that says what changed and puts it back, over a scroll of cards.
    ///
    /// On a phone it is a drawer docked to the bottom that the page resizes between three heights;
    /// on a regular-width screen it is a sidebar. The view draws both and knows neither's geometry —
    /// the page owns the constraints, the view only changes its chrome.
    final class GalleryInspectorView: UIView {
        enum Detent: CaseIterable {
            /// Just the header: the stage gets nearly the whole screen.
            case collapsed
            /// The split the page asked for.
            case medium
            /// The knobs get most of the screen, the demo a strip above them.
            case expanded
        }

        enum Layout {
            case drawer, sidebar
        }

        /// The drag and tap target; the page attaches its gestures here.
        let header = UIView()
        /// The knob list. The page listens to its pan, so a drag that starts on the list moves the
        /// drawer first while the list is at its top — the way a system sheet behaves.
        let scrollView: UIScrollView = GalleryInspectorScrollView()
        private(set) var rows: [GalleryKnobRow] = []
        var onReset: (() -> Void)?
        /// VoiceOver's swipe up and down on the grabber: one height larger or smaller.
        var onGrow: (() -> Void)?
        var onShrink: (() -> Void)?

        private let grabber = GalleryGrabberView()
        private let titleLabel = UILabel()
        private let changesLabel = UILabel()
        private let resetButton = UIButton(configuration: .plain())
        private let sections = UIStackView()
        /// A hairline along the edge that faces the stage. The shadow alone vanishes whenever the
        /// stage is the same grey as the drawer — the Interface backdrop, or anything in dark mode.
        private let outline = CAShapeLayer()
        private var layout = Layout.drawer

        init(knobs: [GalleryKnob]) {
            super.init(frame: .zero)
            backgroundColor = BNGalleryColor.groupedBackground
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.16
            layer.shadowRadius = 20
            layer.shadowOffset = CGSize(width: 0, height: -3)
            buildHeader()
            buildSections(from: knobs)
            outline.fillColor = nil
            outline.zPosition = 1
            layer.addSublayer(outline)
            refreshOutlineColor()
            if #available(iOS 17.0, *) {
                registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitDisplayScale.self]) { (view: GalleryInspectorView, _) in
                    view.refreshOutlineColor()
                    view.setNeedsLayout()
                }
            }
            refreshChanges()
            setLayout(.drawer)
        }

        override func traitCollectionDidChange(_ previous: UITraitCollection?) {
            super.traitCollectionDidChange(previous)
            // iOS 16 has no trait registration; the same change arrives here instead.
            guard #unavailable(iOS 17.0) else { return }
            refreshOutlineColor()
            setNeedsLayout()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // The shadow follows the rounded outline instead of being worked out from pixels on
            // every frame of a drag.
            let radius = layout == .drawer ? BNGalleryMetrics.inspectorRadius : 0
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius),
            ).cgPath
            let lineWidth = 1 / max(traitCollection.displayScale, 1)
            outline.lineWidth = lineWidth
            outline.frame = bounds
            outline.path = outlinePath(lineWidth: lineWidth).cgPath
        }

        /// The drawer's top edge with its rounded corners, open at the bottom; a sidebar's leading
        /// edge. Drawn half a line inside the bounds, so none of it is clipped.
        private func outlinePath(lineWidth: CGFloat) -> UIBezierPath {
            let inset = lineWidth / 2
            let path = UIBezierPath()
            switch layout {
            case .sidebar:
                path.move(to: CGPoint(x: inset, y: 0))
                path.addLine(to: CGPoint(x: inset, y: bounds.maxY))
            case .drawer:
                let radius = min(BNGalleryMetrics.inspectorRadius, bounds.width / 2, bounds.height)
                path.move(to: CGPoint(x: inset, y: bounds.maxY))
                path.addLine(to: CGPoint(x: inset, y: radius))
                path.addArc(
                    withCenter: CGPoint(x: radius, y: radius),
                    radius: radius - inset,
                    startAngle: .pi,
                    endAngle: .pi * 1.5,
                    clockwise: true,
                )
                path.addLine(to: CGPoint(x: bounds.maxX - radius, y: inset))
                path.addArc(
                    withCenter: CGPoint(x: bounds.maxX - radius, y: radius),
                    radius: radius - inset,
                    startAngle: .pi * 1.5,
                    endAngle: 0,
                    clockwise: true,
                )
                path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
            }
            return path
        }

        private func refreshOutlineColor() {
            outline.strokeColor = BNGalleryColor.separator.resolvedColor(with: traitCollection).cgColor
        }

        // MARK: - State

        func setLayout(_ layout: Layout) {
            self.layout = layout
            let radius = layout == .drawer ? BNGalleryMetrics.inspectorRadius : 0
            roundTopCorners(radius: radius)
            grabber.isHidden = layout == .sidebar
            layer.shadowOpacity = layout == .drawer ? 0.16 : 0
            setNeedsLayout()
        }

        func setDetent(_ detent: Detent) {
            grabber.accessibilityValue = switch detent {
            case .collapsed: "Collapsed"
            case .medium: "Half"
            case .expanded: "Expanded"
            }
            // Collapsed, the cards are behind the home indicator; VoiceOver should not find them.
            scrollView.accessibilityElementsHidden = detent == .collapsed
        }

        /// Everything the drawer would need to show all its knobs: header plus the whole list.
        /// Valid after a layout pass at the drawer's current width.
        var contentHeight: CGFloat {
            BNGalleryMetrics.inspectorHeaderHeight + scrollView.contentSize.height
        }

        func refreshChanges() {
            let count = rows.count { $0.isModified }
            changesLabel.text = switch count {
            case 0: rows.isEmpty ? "No controls on this page" : "All at defaults"
            case 1: "1 changed"
            default: "\(count) changed"
            }
            changesLabel.textColor = count == 0 ? BNGalleryColor.secondaryLabel : BNGalleryColor.accent
            resetButton.isEnabled = count > 0
        }

        // MARK: - Building

        private func buildHeader() {
            grabber.onIncrement = { [weak self] in self?.onGrow?() }
            grabber.onDecrement = { [weak self] in self?.onShrink?() }

            titleLabel.text = "Controls"
            titleLabel.font = BNGalleryFont.headline
            titleLabel.adjustsFontForContentSizeCategory = true
            changesLabel.font = BNGalleryFont.footnote
            changesLabel.adjustsFontForContentSizeCategory = true
            let titles = UIStackView(arrangedSubviews: [titleLabel, changesLabel])
            titles.axis = .vertical
            titles.spacing = 1

            resetButton.configuration?.title = "Reset"
            resetButton.configuration?.image = UIImage(systemName: "arrow.counterclockwise")
            resetButton.configuration?.imagePadding = BNGallerySpacing.xs
            resetButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .small)
            resetButton.addAction(UIAction { [weak self] _ in self?.onReset?() }, for: .primaryActionTriggered)

            let row = UIStackView(arrangedSubviews: [titles, UIView(), resetButton])
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = BNGallerySpacing.xs

            for view in [grabber, row] {
                view.translatesAutoresizingMaskIntoConstraints = false
                header.addSubview(view)
            }
            header.translatesAutoresizingMaskIntoConstraints = false
            addSubview(header)
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: topAnchor),
                header.leadingAnchor.constraint(equalTo: leadingAnchor),
                header.trailingAnchor.constraint(equalTo: trailingAnchor),
                header.heightAnchor.constraint(equalToConstant: BNGalleryMetrics.inspectorHeaderHeight),
                grabber.topAnchor.constraint(equalTo: header.topAnchor, constant: 6),
                grabber.centerXAnchor.constraint(equalTo: header.centerXAnchor),
                grabber.widthAnchor.constraint(equalToConstant: BNGalleryMetrics.grabberSize.width),
                grabber.heightAnchor.constraint(equalToConstant: BNGalleryMetrics.grabberSize.height),
                row.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: BNGallerySpacing.l),
                row.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -BNGallerySpacing.m),
                row.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: 4),
            ])
        }

        private func buildSections(from knobs: [GalleryKnob]) {
            sections.axis = .vertical
            sections.spacing = BNGallerySpacing.l
            sections.translatesAutoresizingMaskIntoConstraints = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.alwaysBounceVertical = true
            scrollView.keyboardDismissMode = .interactive
            // A slider answers the moment it is touched rather than after the list has decided the
            // touch is not a scroll; `GalleryInspectorScrollView` gives the scroll back everywhere else.
            scrollView.delaysContentTouches = false
            scrollView.addSubview(sections)
            addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                sections.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: BNGallerySpacing.xs),
                sections.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -BNGallerySpacing.l),
                sections.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: BNGallerySpacing.m),
                sections.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -BNGallerySpacing.m),
            ])

            // Knobs before the first header form an untitled section of their own.
            var title: String?
            var pending: [GalleryKnobRow] = []
            for knob in knobs {
                if case .header = knob.control {
                    addSection(title: title, rows: pending)
                    title = knob.label
                    pending = []
                } else if let row = GalleryKnobRow.make(for: knob) {
                    row.onModifiedChange = { [weak self] in self?.refreshChanges() }
                    pending.append(row)
                }
            }
            addSection(title: title, rows: pending)
        }

        private func addSection(title: String?, rows: [GalleryKnobRow]) {
            guard !rows.isEmpty else { return }
            self.rows += rows
            let section = UIStackView()
            section.axis = .vertical
            section.spacing = BNGallerySpacing.s
            if let title {
                let heading = UILabel()
                heading.text = title
                heading.font = BNGalleryFont.sectionHeader
                heading.textColor = BNGalleryColor.secondaryLabel
                heading.adjustsFontForContentSizeCategory = true
                heading.accessibilityTraits = .header
                let inset = UIView()
                heading.translatesAutoresizingMaskIntoConstraints = false
                inset.addSubview(heading)
                NSLayoutConstraint.activate([
                    heading.topAnchor.constraint(equalTo: inset.topAnchor),
                    heading.bottomAnchor.constraint(equalTo: inset.bottomAnchor),
                    heading.leadingAnchor.constraint(equalTo: inset.leadingAnchor, constant: BNGallerySpacing.m),
                    heading.trailingAnchor.constraint(equalTo: inset.trailingAnchor, constant: -BNGallerySpacing.m),
                ])
                section.addArrangedSubview(inset)
            }
            section.addArrangedSubview(Self.makeCard(rows: rows))
            sections.addArrangedSubview(section)
        }

        private static func makeCard(rows: [GalleryKnobRow]) -> UIView {
            let card = UIStackView()
            card.axis = .vertical
            card.backgroundColor = BNGalleryColor.card
            card.bnApplyCorners(radius: BNGalleryMetrics.cardRadius)
            card.clipsToBounds = true
            for (index, row) in rows.enumerated() {
                if index > 0 {
                    card.addArrangedSubview(GalleryHairline())
                }
                card.addArrangedSubview(row)
            }
            return card
        }
    }

    /// Lets a vertical drag that starts on a button, a switch or segments scroll the list — the
    /// default keeps it on any control — while a slider keeps its drag.
    private final class GalleryInspectorScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            !(view is UISlider)
        }
    }

    /// The capsule at the top of the drawer. For VoiceOver it is an adjustable element: swipe up
    /// for a taller drawer, down for a shorter one — the drag, for a user who cannot drag.
    private final class GalleryGrabberView: UIView {
        var onIncrement: (() -> Void)?
        var onDecrement: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = BNGalleryColor.tertiaryLabel
            bnApplyCapsule()
            isAccessibilityElement = true
            accessibilityLabel = "Controls panel"
            accessibilityTraits = .adjustable
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func accessibilityIncrement() {
            onIncrement?()
        }

        override func accessibilityDecrement() {
            onDecrement?()
        }
    }

    /// A one-pixel separator between rows, inset like a Settings list.
    private final class GalleryHairline: UIView {
        private let line = UIView()
        private lazy var thickness = line.heightAnchor.constraint(equalToConstant: 1)

        override init(frame: CGRect) {
            super.init(frame: frame)
            line.backgroundColor = BNGalleryColor.separator
            line.translatesAutoresizingMaskIntoConstraints = false
            addSubview(line)
            NSLayoutConstraint.activate([
                line.topAnchor.constraint(equalTo: topAnchor),
                line.bottomAnchor.constraint(equalTo: bottomAnchor),
                line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: BNGallerySpacing.m),
                line.trailingAnchor.constraint(equalTo: trailingAnchor),
                thickness,
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window else { return }
            thickness.constant = 1 / max(window.traitCollection.displayScale, 1)
        }
    }

    private extension UIView {
        /// The drawer's shape: rounded on top, square where it meets the screen's bottom edge.
        func roundTopCorners(radius: CGFloat) {
            if #available(iOS 26.0, *) {
                cornerConfiguration = .corners(
                    topLeftRadius: .fixed(radius),
                    topRightRadius: .fixed(radius),
                    bottomLeftRadius: .fixed(0),
                    bottomRightRadius: .fixed(0),
                )
            } else {
                layer.cornerRadius = radius
                layer.cornerCurve = .continuous
                layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            }
        }
    }
#endif
