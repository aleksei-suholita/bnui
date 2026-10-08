#if canImport(UIKit)
    import UIKit

    /// What the button shows. Every slot is optional.
    ///
    /// An icon-only button needs ``accessibilityLabel``: a symbol is not a word, and VoiceOver has
    /// nothing to read without one. The control checks in debug builds rather than trusting it.
    public struct BNButtonContent: Equatable {
        public var title: String?
        public var leadingIcon: BNButtonIcon?
        public var trailingIcon: BNButtonIcon?
        /// Required when there is no title; otherwise the title speaks for the button.
        public var accessibilityLabel: String?

        public init(
            title: String? = nil,
            leadingIcon: BNButtonIcon? = nil,
            trailingIcon: BNButtonIcon? = nil,
            accessibilityLabel: String? = nil,
        ) {
            self.title = title
            self.leadingIcon = leadingIcon
            self.trailingIcon = trailingIcon
            self.accessibilityLabel = accessibilityLabel
        }

        public static func title(_ text: String) -> BNButtonContent {
            BNButtonContent(title: text)
        }

        public static func icon(_ icon: BNButtonIcon, accessibilityLabel: String) -> BNButtonContent {
            BNButtonContent(leadingIcon: icon, accessibilityLabel: accessibilityLabel)
        }

        public var resolvedAccessibilityLabel: String? {
            accessibilityLabel ?? title
        }

        public var hasTitle: Bool {
            !(title ?? "").isEmpty
        }
    }

    /// A system symbol, or an image the host brings.
    ///
    /// Whether an icon mirrors in a right-to-left layout belongs to the image. SF Symbols that point
    /// along the reading direction (`chevron.forward`) mirror themselves, and so does an asset whose
    /// Direction is set to mirror in the asset catalog. `flipsForRTL` mirrors an image that would not:
    /// one drawn in code, or an asset without that setting. It only adds mirroring — `false` leaves
    /// an image that mirrors itself as it is.
    public enum BNButtonIcon: Equatable {
        case symbol(String)
        case image(UIImage, flipsForRTL: Bool = false)
    }
#endif
