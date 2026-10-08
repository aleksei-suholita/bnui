#if canImport(UIKit)
    import UIKit

    /// The spinner shown while the host is busy.
    ///
    /// Behind a protocol because `UIActivityIndicatorView` comes in a couple of fixed sizes, and a
    /// large button that scaled one up would show a blurred spinner. A host with its own artwork
    /// plugs it in here rather than fighting the transform.
    public protocol BNButtonLoadingIndicating: UIView {
        func setAnimating(_ animating: Bool)
        func apply(color: UIColor, side: CGFloat)
    }

    public protocol BNButtonLoadingIndicatorFactory {
        /// Distinguishes one factory from another for the control's equality checks.
        var identity: String { get }
        func makeIndicator() -> any BNButtonLoadingIndicating
    }

    /// The system spinner.
    public struct BNActivityLoadingIndicator: BNButtonLoadingIndicatorFactory {
        public init() {}

        public var identity: String {
            "activity"
        }

        public func makeIndicator() -> any BNButtonLoadingIndicating {
            BNActivityIndicatorView()
        }
    }

    final class BNActivityIndicatorView: UIView, BNButtonLoadingIndicating {
        /// `UIActivityIndicatorView.Style.medium` draws at this size; everything else is a scale
        /// away from it, and a scale is exactly what blurs a spinner.
        private static let nativeSide: CGFloat = 20

        private let indicator = UIActivityIndicatorView(style: .medium)

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            indicator.hidesWhenStopped = false
            indicator.translatesAutoresizingMaskIntoConstraints = false
            addSubview(indicator)
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func setAnimating(_ animating: Bool) {
            if animating {
                indicator.startAnimating()
            } else {
                indicator.stopAnimating()
            }
        }

        func apply(color: UIColor, side: CGFloat) {
            indicator.color = color
            // Left alone unless the difference would actually show: a 10% scale is invisible, and
            // not applying it keeps the spinner crisp.
            let scale = side / Self.nativeSide
            indicator.transform = abs(scale - 1) < 0.1 ? .identity : CGAffineTransform(scaleX: scale, y: scale)
        }
    }
#endif
