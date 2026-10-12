#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// What the button shows. Every slot is optional.
    ///
    /// A button without a title has no words of its own: ``accessibilityLabel`` gives it some, as
    /// does the button's own `accessibilityLabel`, which wins over it. Without either, VoiceOver
    /// reads it only as a button.
    public struct BNButtonContent: Equatable {
        public var title: String?
        public var leadingIcon: BNButtonIcon?
        public var trailingIcon: BNButtonIcon?
        /// What VoiceOver reads; without it, the title speaks for the button.
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

        public static func icon(_ icon: BNButtonIcon, accessibilityLabel: String? = nil) -> BNButtonContent {
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
    /// An image is a glyph in the style's colours, as a symbol is, unless its `rendering` is
    /// `.original`: a logo keeps its own colours, and the button carries its state on it by dimming
    /// it when disabled.
    ///
    /// Whether an icon mirrors in a right-to-left layout belongs to the image. SF Symbols that point
    /// along the reading direction (`chevron.forward`) mirror themselves, and so does an asset whose
    /// Direction is set to mirror in the asset catalog. `flipsForRTL` mirrors an image that would not:
    /// one drawn in code, or an asset without that setting. It only adds mirroring — `false` leaves
    /// an image that mirrors itself as it is.
    public enum BNButtonIcon: Equatable {
        case symbol(String)
        case image(UIImage, flipsForRTL: Bool = false, rendering: BNImageRendering = .template)
    }

    extension BNButtonIcon {
        var rendering: BNImageRendering {
            switch self {
            case .symbol: .template
            case let .image(_, _, rendering): rendering
            }
        }
    }
#endif
