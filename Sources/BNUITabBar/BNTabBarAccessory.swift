#if canImport(UIKit)
    import UIKit

    /// A host view shown above the bar — a mini player, a running session, an active ride.
    ///
    /// The control owns where it sits, how it appears and the height it adds; the host owns what
    /// is inside. Content-free by design: the bar must not learn what the accessory means.
    public struct BNTabBarAccessory {
        /// Whether the accessory spans the bar's width or hugs its own content.
        public enum Width {
            case matchBar
            case hug
        }

        public let view: UIView
        public let width: Width
        /// Gap between the accessory and the capsule below it.
        public let spacing: CGFloat

        public init(view: UIView, width: Width = .matchBar, spacing: CGFloat = 8) {
            self.view = view
            self.width = width
            self.spacing = spacing
        }
    }
#endif
