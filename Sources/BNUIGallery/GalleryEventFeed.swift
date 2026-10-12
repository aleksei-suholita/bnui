#if canImport(UIKit)
    import BNUI
    import UIKit

    /// A demo that reports what its control said — a selection, a tap that fired, why a toast left.
    ///
    /// The page wires it to the stage's event feed, so every page shows events the same way and
    /// in the same place instead of each demo squeezing a log label of its own into its corner.
    public protocol BNGalleryEventReporting: AnyObject {
        var onGalleryEvent: ((String) -> Void)? { get set }
    }

    /// The edge of the stage the event feed sits on — away from wherever the control itself lives.
    public enum BNGalleryEventFeedEdge: Sendable {
        case top, bottom
    }

    /// The last few events as small dark capsules over the stage, newest nearest the edge and the
    /// older ones fading. Readable on any backdrop, never in the way of a touch, and kept until
    /// Reset: a toast's dismissal reason is only useful if it is still there when you look.
    final class GalleryEventFeedView: UIView {
        private static let capacity = 5
        /// Opacity by age, newest first.
        private static let fade: [CGFloat] = [1, 0.8, 0.62, 0.46, 0.32]

        private let edge: BNGalleryEventFeedEdge
        private let stack = UIStackView()

        init(edge: BNGalleryEventFeedEdge) {
            self.edge = edge
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
            stack.axis = .vertical
            stack.alignment = .leading
            stack.spacing = BNGallerySpacing.xs
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func post(_ text: String) {
            let entry = Self.makeEntry(text)
            entry.alpha = 0
            entry.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            stack.insertArrangedSubview(entry, at: edge == .top ? 0 : stack.arrangedSubviews.count)
            while stack.arrangedSubviews.count > Self.capacity {
                let oldest = edge == .top ? stack.arrangedSubviews.last : stack.arrangedSubviews.first
                oldest?.removeFromSuperview()
            }
            layoutIfNeeded()
            let entries = newestFirst
            BNTransition.spring(BNSpring(duration: 0.35, bounce: 0.2)).run { [weak self] in
                for (age, view) in entries.enumerated() {
                    view.alpha = Self.fade[min(age, Self.fade.count - 1)]
                }
                entry.transform = .identity
                self?.layoutIfNeeded()
            }
            UIAccessibility.post(notification: .announcement, argument: text)
        }

        func clear() {
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }

        private var newestFirst: [UIView] {
            edge == .top ? stack.arrangedSubviews : stack.arrangedSubviews.reversed()
        }

        private static func makeEntry(_ text: String) -> UIView {
            let label = UILabel()
            label.text = text
            label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            label.textColor = BNGalleryColor.onMedia
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            let capsule = UIView()
            capsule.backgroundColor = UIColor(white: 0, alpha: 0.58)
            capsule.bnApplyCapsule()
            label.translatesAutoresizingMaskIntoConstraints = false
            capsule.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: capsule.topAnchor, constant: 5),
                label.bottomAnchor.constraint(equalTo: capsule.bottomAnchor, constant: -5),
                label.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -10),
            ])
            return capsule
        }
    }
#endif
