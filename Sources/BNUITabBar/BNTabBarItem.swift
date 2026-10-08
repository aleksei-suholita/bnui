#if canImport(UIKit)
    import UIKit

    /// One section of the bar.
    public struct BNTabBarItem: Identifiable, Equatable {
        /// Symbol or bundled asset.
        ///
        /// Deliberately only two cases. Anything richer — animated, shader-backed, a progress ring —
        /// is a `BNTabBarItemRenderer`, not another case here: a growing list of icon kinds is a dead
        /// end, because a view passed in this way never receives selection state.
        public enum Icon: Equatable {
            case symbol(String)
            case image(UIImage)
        }

        public let id: String
        public let icon: Icon
        public let title: String
        public let badge: String?
        /// The SF Symbol accent played when this section becomes selected. Defaults to a bounce;
        /// set per item — a running-timer section can breathe while the rest bounce, or go silent.
        public let selectionAnimation: BNTabBarSymbolAnimation
        /// Spoken name. Defaults to `title`, but stays required in every label mode —
        /// a hidden label must not silence VoiceOver.
        public let accessibilityLabel: String

        public init(
            id: String,
            icon: Icon,
            title: String,
            badge: String? = nil,
            selectionAnimation: BNTabBarSymbolAnimation = .bounce,
            accessibilityLabel: String? = nil,
        ) {
            self.id = id
            self.icon = icon
            self.title = title
            self.badge = badge
            self.selectionAnimation = selectionAnimation
            self.accessibilityLabel = accessibilityLabel ?? title
        }
    }

    extension BNTabBarItem.Icon {
        /// The glyph as a template, tinted by whoever draws it — the bar or a system menu.
        var templateImage: UIImage? {
            switch self {
            case let .symbol(name): UIImage(systemName: name)
            case let .image(image): image.withRenderingMode(.alwaysTemplate)
            }
        }
    }
#endif
