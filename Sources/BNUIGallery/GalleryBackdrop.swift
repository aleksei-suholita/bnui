#if canImport(UIKit)
    import BNUI
    import UIKit

    /// What the stage puts behind a control.
    ///
    /// Each backdrop exists to answer one question about the control on it — the question is the
    /// subtitle in the stage menu. One setting for every page rather than a knob per demo: the
    /// questions are the same for every control, and a backdrop that is part of the stage fills
    /// the screen instead of a card in its middle.
    ///
    /// Five come with the gallery, drawn rather than loaded. An app adds its own — a screenshot of
    /// its feed, a mock of its chat — with ``image(_:title:purpose:)`` or
    /// ``view(title:purpose:make:)`` in ``BNGalleryConfiguration/backdrops``.
    public struct BNGalleryBackdrop: Equatable {
        /// What draws a backdrop.
        enum Source {
            case painted(GalleryPaintedBackdrop)
            case image(UIImage)
            case view(() -> UIView)
        }

        /// The name in the stage menu. Two backdrops of one name are one backdrop.
        public let title: String
        /// The question the backdrop answers, under its name in the stage menu.
        public let purpose: String?
        let source: Source

        /// The system background, light or dark with the stage.
        public static let plain = Self(title: "Plain", purpose: "An ordinary screen", source: .painted(.plain))
        /// An app's content — a featured card and grouped lists — light or dark with the stage.
        public static let interface = Self(title: "Interface", purpose: "A list under the control", source: .painted(.interface))
        /// A photo library: busy colour and hard edges, fixed in both appearances.
        public static let photos = Self(title: "Photos", purpose: "Busy, colourful media", source: .painted(.photos))
        /// Pale, airy imagery with a white hotspot — where light glass loses light text.
        public static let bright = Self(title: "Bright", purpose: "Light imagery, the legibility trap", source: .painted(.bright))
        /// Deep blue night with soft glows and stars.
        public static let night = Self(title: "Night", purpose: "Dark media", source: .painted(.night))

        /// The gallery's own, in the order the stage menu lists them.
        static let painted: [Self] = [.plain, .interface, .photos, .bright, .night]

        /// An image of the app's own over the whole stage, filling it — a screenshot of the screen
        /// the control lives on.
        public static func image(_ image: UIImage, title: String, purpose: String? = nil) -> Self {
            Self(title: title, purpose: purpose, source: .image(image))
        }

        /// A view of the app's own over the whole stage, made afresh each time it is picked — a
        /// screen's mock, alive.
        public static func view(title: String, purpose: String? = nil, make: @escaping () -> UIView) -> Self {
            Self(title: title, purpose: purpose, source: .view(make))
        }

        /// One backdrop if they have one name.
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.title == rhs.title
        }
    }

    /// The backdrops the gallery draws itself.
    enum GalleryPaintedBackdrop {
        case plain, interface, photos, bright, night
    }

    /// Draws the chosen backdrop edge to edge.
    ///
    /// The gallery's own are drawn, not built from views or assets: one pass when the backdrop,
    /// the size or the appearance changes, and nothing at all while the inspector is dragged — the
    /// stage's size does not change then. An app's image or view is laid over the plain one.
    final class GalleryBackdropView: UIView {
        var backdrop: BNGalleryBackdrop = .plain {
            didSet {
                guard backdrop != oldValue else { return }
                showAppContent()
                setNeedsDisplay()
            }
        }

        /// An app's image or view, when the backdrop is one of the app's.
        private var appContent: UIView?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = true
            contentMode = .redraw
            isUserInteractionEnabled = false
            if #available(iOS 17.0, *) {
                registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: GalleryBackdropView, _) in
                    view.setNeedsDisplay()
                }
            }
        }

        override func traitCollectionDidChange(_ previous: UITraitCollection?) {
            super.traitCollectionDidChange(previous)
            // iOS 16 has no trait registration; the same change arrives here instead.
            guard #unavailable(iOS 17.0) else { return }
            if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
                setNeedsDisplay()
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func draw(_: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            guard case let .painted(painted) = backdrop.source else {
                UIColor.systemBackground.setFill()
                context.fill(bounds)
                return
            }
            switch painted {
            case .plain:
                UIColor.systemBackground.setFill()
                context.fill(bounds)
            case .interface:
                GalleryInterfacePainter.draw(in: bounds, context: context)
            case .photos:
                GalleryImageryPainter.drawLibrary(in: bounds, context: context)
            case .bright:
                GalleryImageryPainter.drawBright(in: bounds, context: context)
            case .night:
                GalleryImageryPainter.drawNight(in: bounds, context: context)
            }
        }

        private func showAppContent() {
            appContent?.removeFromSuperview()
            appContent = nil
            let content: UIView
            switch backdrop.source {
            case .painted:
                return
            case let .image(image):
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                content = imageView
            case let .view(make):
                content = make()
            }
            content.translatesAutoresizingMaskIntoConstraints = false
            addSubview(content)
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: topAnchor),
                content.bottomAnchor.constraint(equalTo: bottomAnchor),
                content.leadingAnchor.constraint(equalTo: leadingAnchor),
                content.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            appContent = content
        }
    }

    // MARK: - Drawing helpers

    /// A repeatable sequence of numbers, so a backdrop looks the same on every launch.
    struct GallerySeededRandom {
        private var state: UInt64

        init(seed: Int) {
            state = UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15 &+ 1
        }

        /// SplitMix64: tiny, and good enough to scatter stars and suns.
        mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            value ^= value >> 31
            let unit = CGFloat(value >> 11) / CGFloat(UInt64(1) << 53)
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }
    }

    enum GalleryPaint {
        static func color(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha,
            )
        }

        /// A straight blend between colours, from `start` to `end`.
        static func linear(_ context: CGContext, colors: [UIColor], from start: CGPoint, to end: CGPoint) {
            let cgColors = colors.map(\.cgColor) as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) else { return }
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        /// A soft round glow fading to nothing — suns, bokeh, the colour blooms of a wallpaper.
        static func glow(_ context: CGContext, at center: CGPoint, radius: CGFloat, color: UIColor, alpha: CGFloat = 1) {
            let cgColors = [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: [0, 1]) else { return }
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
    }
#endif
