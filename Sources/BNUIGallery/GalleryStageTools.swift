#if (DEBUG || GalleryInRelease) && canImport(UIKit)
    import BNUI
    import UIKit

    /// The frame rate and the hitches since the page opened, in a capsule at the stage's corner —
    /// for glass, blur and long lists, whose cost shows as dropped frames before anything else.
    ///
    /// It times the main thread's frames — the whole app's, not the demo's alone. A hitch is a frame
    /// that took more than one and a half of the display's frame times.
    final class GalleryFrameMeter: UIView {
        private let label = UILabel()
        private var link: CADisplayLink?
        private var lastFrame: CFTimeInterval = 0
        private var sampleStart: CFTimeInterval = 0
        private var framesInSample = 0
        private var framesPerSecond = 0
        private var hitches = 0

        var isRunning = false {
            didSet {
                isHidden = !isRunning
                updateLink()
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isHidden = true
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
            backgroundColor = UIColor(white: 0, alpha: 0.58)
            bnApplyCapsule()
            label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            label.textColor = BNGalleryColor.onMedia
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
                label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            ])
            refresh()
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updateLink()
        }

        /// Hitches counted from now — Reset starts the count again.
        func reset() {
            hitches = 0
            refresh()
        }

        private func updateLink() {
            let wanted = isRunning && window != nil
            if wanted, link == nil {
                let link = CADisplayLink(
                    target: GalleryDisplayLinkTarget { [weak self] in self?.frameDrawn($0) },
                    selector: #selector(GalleryDisplayLinkTarget.fire(_:)),
                )
                link.add(to: .main, forMode: .common)
                self.link = link
                lastFrame = 0
            } else if !wanted {
                link?.invalidate()
                link = nil
            }
        }

        private func frameDrawn(_ link: CADisplayLink) {
            let frameTime = link.targetTimestamp - link.timestamp
            if lastFrame > 0 {
                if frameTime > 0, link.timestamp - lastFrame > frameTime * 1.5 {
                    hitches += 1
                }
            } else {
                sampleStart = link.timestamp
                framesInSample = 0
            }
            lastFrame = link.timestamp
            framesInSample += 1
            // Counted over half a second, so the number can be read rather than flickering.
            let elapsed = link.timestamp - sampleStart
            if elapsed >= 0.5 {
                framesPerSecond = Int((Double(framesInSample) / elapsed).rounded())
                framesInSample = 0
                sampleStart = link.timestamp
                refresh()
            }
        }

        private func refresh() {
            label.text = "\(framesPerSecond) fps · \(hitches) \(hitches == 1 ? "hitch" : "hitches")"
        }
    }

    /// A frame around every view of the demo, coloured by its depth below the demo's root and
    /// drawn over it on every frame from where the views are on screen — mid-animation included —
    /// so spacing, hit areas and stray containers show without touching the demo's own layers.
    final class GalleryOutlineView: UIView {
        private weak var target: UIView?
        /// One per depth, the deeper over the shallower.
        private let shapes: [CAShapeLayer]
        private var link: CADisplayLink?

        var isRunning = false {
            didSet {
                isHidden = !isRunning
                for shape in shapes {
                    shape.path = nil
                }
                updateLink()
            }
        }

        init(target: UIView) {
            self.target = target
            shapes = BNGalleryColor.outlineDepths.map { color in
                let shape = CAShapeLayer()
                shape.fillColor = nil
                shape.strokeColor = color.cgColor
                shape.lineWidth = 1
                // Redrawn every frame from where the views are; an implicit animation would trail.
                shape.actions = ["path": NSNull()]
                return shape
            }
            super.init(frame: .zero)
            isHidden = true
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
            for shape in shapes {
                layer.addSublayer(shape)
            }
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            for shape in shapes {
                shape.frame = bounds
            }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updateLink()
        }

        private func updateLink() {
            let wanted = isRunning && window != nil
            if wanted, link == nil {
                let link = CADisplayLink(
                    target: GalleryDisplayLinkTarget { [weak self] _ in self?.redraw() },
                    selector: #selector(GalleryDisplayLinkTarget.fire(_:)),
                )
                link.add(to: .main, forMode: .common)
                self.link = link
            } else if !wanted {
                link?.invalidate()
                link = nil
            }
        }

        private func redraw() {
            guard let target else { return }
            // Measured in the render tree, both ends alike, so a view in flight is outlined where
            // it is drawn rather than where it is headed.
            let space = layer.presentation() ?? layer
            let paths = shapes.map { _ in CGMutablePath() }
            outline(target, depth: 0, into: paths, in: space, rendered: layer.presentation() != nil)
            for (shape, path) in zip(shapes, paths) {
                shape.path = path
            }
        }

        private func outline(_ view: UIView, depth: Int, into paths: [CGMutablePath], in space: CALayer, rendered: Bool) {
            guard !view.isHidden, view.alpha > 0.01 else { return }
            let viewLayer = rendered ? view.layer.presentation() ?? view.layer : view.layer
            let frame = viewLayer.convert(viewLayer.bounds, to: space)
            // A view of no size has no outline, and inset it would be the null rectangle, whose
            // infinite corners leave the whole path undrawable; a view scaled to nothing converts
            // to the same.
            let drawable = frame.width >= 1 && frame.height >= 1
                && [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
            if drawable, !paths.isEmpty {
                paths[min(depth, paths.count - 1)].addRect(frame.insetBy(dx: 0.5, dy: 0.5))
            }
            for subview in view.subviews {
                outline(subview, depth: depth + 1, into: paths, in: space, rendered: rendered)
            }
        }
    }

    /// A display link's target that does not keep its owner alive: the link holds its target
    /// strongly, and the owner holds the link.
    private final class GalleryDisplayLinkTarget: NSObject {
        private let onFrame: (CADisplayLink) -> Void

        init(_ onFrame: @escaping (CADisplayLink) -> Void) {
            self.onFrame = onFrame
        }

        @objc func fire(_ link: CADisplayLink) {
            onFrame(link)
        }
    }
#endif
