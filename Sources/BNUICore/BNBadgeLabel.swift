#if canImport(UIKit)
    import UIKit

    /// A label with horizontal breathing room, so a two-digit badge does not touch the capsule.
    ///
    /// UILabel has no text insets, so the intrinsic size is widened by hand; a `width >= height`
    /// constraint on the badge then keeps a single digit circular rather than an oval.
    final class BNBadgeLabel: UILabel {
        var horizontalInset: CGFloat = 5 {
            didSet { invalidateIntrinsicContentSize() }
        }

        override var intrinsicContentSize: CGSize {
            let base = super.intrinsicContentSize
            return CGSize(width: base.width + 2 * horizontalInset, height: base.height)
        }
    }
#endif
