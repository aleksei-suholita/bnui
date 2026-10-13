import CoreGraphics

/// The outline a theme gives a control — the button's size step, the toast's plate. A case rather
/// than a raw radius so `capsule` keeps meaning "half the height" whatever height the control is
/// drawn at — up to the limit the control sets, see ``cornerRadius(forHeight:maximumRadius:)``.
public nonisolated enum BNShape: Equatable, Sendable {
    case capsule
    case rounded(radius: CGFloat)

    /// The radius to draw for a given height, never more than `maximumRadius`.
    ///
    /// The limit is how a control that has grown taller than it was drawn for stops being a
    /// capsule. A wrapped title makes the button taller; a capsule that kept rounding its ends
    /// with the height would cut into the first and last lines, and widening the padding to
    /// clear them only makes the text wrap again. Past the limit the ends stop growing and the
    /// shape becomes a rounded rectangle — the rule of `UICornerConfiguration.capsule(maximumRadius:)`.
    /// A control passes the radius it has on one line, so on one line a capsule is a capsule.
    public func cornerRadius(forHeight height: CGFloat, maximumRadius: CGFloat = .infinity) -> CGFloat {
        let radius = switch self {
        case .capsule: max(height, 0) / 2
        case let .rounded(radius): max(radius, 0)
        }
        return min(radius, max(maximumRadius, 0))
    }

    /// How far inside the corner of its bounds the outline passes on the corner's diagonal — the
    /// same distance from the top and from the side. Where a badge hangs on a control: on the rim
    /// of a circle at 45°, at the very corner of a square.
    package func cornerInset(forHeight height: CGFloat, maximumRadius: CGFloat = .infinity) -> CGFloat {
        cornerRadius(forHeight: height, maximumRadius: maximumRadius) * (1 - 1 / CGFloat(2).squareRoot())
    }
}

#if canImport(UIKit)
    import UIKit

    // Rounded corners that keep up with the view, on every iOS the kit supports.
    //
    // iOS 26 has corner configuration, which the system keeps in sync as a view grows: a capsule
    // stays a capsule after Dynamic Type has made the button taller. Below it a radius is a number,
    // so a capsule has to be rounded again every time the height changes — on views the kit does
    // not subclass too: a badge label, a blur, the disc behind an icon.

    package extension UIView {
        /// The shape a theme chose, kept up with the view as it grows, never rounder than
        /// `maximumRadius` — see ``BNShape/cornerRadius(forHeight:maximumRadius:)``.
        func bnApplyShape(_ shape: BNShape, maximumRadius: CGFloat = .infinity) {
            if let plate = self as? BNBlurPlateView {
                // The plate rounds its own layers — the clip, the rim, the shadow path — so it
                // takes the shape itself; a corner configuration on its outside would reach none.
                plate.shape = shape
                plate.maximumRadius = maximumRadius
                return
            }
            switch shape {
            case .capsule:
                bnApplyCapsule(maximumRadius: maximumRadius)
            case let .rounded(radius):
                bnApplyCorners(radius: min(radius, max(maximumRadius, 0)))
            }
        }

        /// A capsule at whatever height the view ends up, its ends rounding no further than
        /// `maximumRadius`.
        func bnApplyCapsule(maximumRadius: CGFloat = .infinity) {
            if #available(iOS 26.0, *) {
                cornerConfiguration = maximumRadius.isFinite
                    ? .capsule(maximumRadius: Double(max(maximumRadius, 0)))
                    : .capsule()
            } else {
                layer.cornerCurve = .continuous
                BNCapsuleTracker.attach(to: self, maximumRadius: maximumRadius)
            }
        }

        /// A fixed radius on the continuous curve.
        func bnApplyCorners(radius: CGFloat) {
            if #available(iOS 26.0, *) {
                cornerConfiguration = .corners(radius: .fixed(radius))
            } else {
                BNCapsuleTracker.detach(from: self)
                layer.cornerCurve = .continuous
                layer.cornerRadius = radius
            }
        }
    }

    /// Rounds a capsule again below iOS 26.
    ///
    /// Resized with the view it rounds by autoresizing, so its own layout pass is exactly that view
    /// changing size — the one hook that fires for a view without subclassing it. It draws nothing,
    /// takes no touches and is invisible to VoiceOver.
    private final class BNCapsuleTracker: UIView {
        private weak var target: UIView?
        private var maximumRadius: CGFloat = .infinity

        static func attach(to view: UIView, maximumRadius: CGFloat) {
            let host = trackerHost(of: view)
            // A second attach updates the limit rather than adding a tracker: the shape is
            // re-applied whenever the control's metrics move.
            let tracker = host.subviews.lazy.compactMap { $0 as? BNCapsuleTracker }.first ?? {
                let tracker = BNCapsuleTracker(frame: host.bounds)
                tracker.target = view
                tracker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                host.insertSubview(tracker, at: 0)
                return tracker
            }()
            tracker.maximumRadius = maximumRadius
            view.layer.cornerRadius = BNShape.capsule.cornerRadius(forHeight: view.bounds.bnShorterSide, maximumRadius: maximumRadius)
        }

        static func detach(from view: UIView) {
            for tracker in trackerHost(of: view).subviews where tracker is BNCapsuleTracker {
                tracker.removeFromSuperview()
            }
        }

        /// An effect view takes subviews only in its content view, which always fills it.
        private static func trackerHost(of view: UIView) -> UIView {
            (view as? UIVisualEffectView)?.contentView ?? view
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            accessibilityElementsHidden = true
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            target?.layer.cornerRadius = BNShape.capsule.cornerRadius(forHeight: bounds.bnShorterSide, maximumRadius: maximumRadius)
        }
    }

    private extension CGRect {
        /// What a capsule rounds by, as `UICornerConfiguration.capsule()` does on iOS 26: the
        /// shorter side, so a capsule standing upright rounds by its width.
        var bnShorterSide: CGFloat {
            min(width, height)
        }
    }
#endif
