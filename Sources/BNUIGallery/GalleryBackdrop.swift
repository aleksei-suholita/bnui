#if (DEBUG || GalleryInRelease) && canImport(UIKit)
    import BNUI
    import UIKit

    /// What the stage puts behind a control.
    ///
    /// Each backdrop exists to answer one question about the control on it — the question is the
    /// subtitle in the stage menu. One setting for every page rather than a knob per demo: the
    /// questions are the same for every control, and a backdrop that is part of the stage fills
    /// the screen instead of a card in its middle.
    public enum BNGalleryBackdrop: CaseIterable, Sendable {
        /// The system background, light or dark with the stage.
        case plain
        /// An app's content — a featured card and grouped lists — light or dark with the stage.
        case interface
        /// A photo library: busy colour and hard edges, fixed in both appearances.
        case photos
        /// Pale, airy imagery with a white hotspot — where light glass loses light text.
        case bright
        /// Deep blue night with soft glows and stars.
        case night

        var title: String {
            switch self {
            case .plain: "Plain"
            case .interface: "Interface"
            case .photos: "Photos"
            case .bright: "Bright"
            case .night: "Night"
            }
        }

        /// The question the backdrop answers.
        var purpose: String {
            switch self {
            case .plain: "An ordinary screen"
            case .interface: "A list under the control"
            case .photos: "Busy, colourful media"
            case .bright: "Light imagery, the legibility trap"
            case .night: "Dark media"
            }
        }
    }

    /// Draws the chosen backdrop edge to edge.
    ///
    /// Drawn, not built from views or assets: one pass when the backdrop, the size or the
    /// appearance changes, and nothing at all while the inspector is dragged — the stage's size
    /// does not change then.
    final class GalleryBackdropView: UIView {
        var backdrop: BNGalleryBackdrop = .plain {
            didSet {
                guard backdrop != oldValue else { return }
                setNeedsDisplay()
            }
        }

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
            switch backdrop {
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
