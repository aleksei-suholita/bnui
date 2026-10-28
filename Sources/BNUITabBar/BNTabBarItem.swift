#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// One section of the bar.
    public struct BNTabBarItem: Identifiable, Equatable {
        /// Symbol or image.
        ///
        /// Deliberately only two cases. Anything richer — animated, shader-backed, a progress ring —
        /// is a `BNTabBarItemRenderer`, not another case here: a growing list of icon kinds is a dead
        /// end, because a view passed in this way never receives selection state.
        public enum Icon: Equatable {
            case symbol(String)
            /// A bundled asset or a photo, fitted into `size` with its proportions kept, or, without
            /// one, into a square as large as a round symbol at the theme's point size — an 80 pt
            /// asset does not grow the bar. A picture in its own colours (`.original`) is not
            /// touched by the state: the lens under it is what says the section is chosen. The
            /// action button leaves `size` aside and draws the image as a button draws an icon.
            ///
            /// A symbol image — the app's own symbol from its catalogue — is a symbol, not a
            /// picture: it is drawn and laid out as `.symbol` is, at the theme's point size, weight
            /// and scale, and `size` is left aside.
            case image(UIImage, size: CGSize? = nil, rendering: BNImageRendering = .template)
        }

        public let id: String
        public let icon: Icon
        /// The icon the section shows while it is selected — `house.fill` for `house` — or `nil` to
        /// keep ``icon``. Under the kit's lens it changes exactly on the lens edge, as the colour
        /// does. Changeable while the bar is on screen — a camera's section showing the filter in
        /// use — through `setSelectedIcon(_:for:)`, in place and animated: a symbol gives way by
        /// the system's replace effect, a picture cross-fades.
        public var selectedIcon: Icon?
        public let title: String
        /// A count, a short text or a dot. Changing only the badges of a bar's sections redraws the
        /// badges alone, and a finger on the bar keeps its gesture — one in place reads
        /// `bar.items[1].badge = .count(3)`.
        public var badge: BNBadge?
        /// The SF Symbol accent played when this section becomes selected — `.bounce.down.byLayer`,
        /// `.wiggle.left`, `.none`. Defaults to a bounce; set per item — a running-timer section can
        /// breathe while the rest bounce, or go silent. It plays on a symbol, the system's or the
        /// app's own passed as an image.
        public let selectionAnimation: BNTabBarSymbolAnimation
        /// Spoken name. Defaults to `title`, but stays required in every label mode —
        /// a hidden label must not silence VoiceOver.
        public let accessibilityLabel: String

        public init(
            id: String,
            icon: Icon,
            selectedIcon: Icon? = nil,
            title: String,
            badge: BNBadge? = nil,
            selectionAnimation: some BNTabBarSymbolEffect = .bounce,
            accessibilityLabel: String? = nil,
        ) {
            self.id = id
            self.icon = icon
            self.selectedIcon = selectedIcon
            self.title = title
            self.badge = badge
            self.selectionAnimation = selectionAnimation.symbolAnimation
            self.accessibilityLabel = accessibilityLabel ?? title
        }
    }

    extension BNTabBarItem {
        /// Whether the two are the same section and only the badge or the selected icon tells them
        /// apart — the changes a bar draws in place instead of rebuilding.
        func differsOnlyInPlace(from other: BNTabBarItem) -> Bool {
            id == other.id
                && icon == other.icon
                && title == other.title
                && selectionAnimation == other.selectionAnimation
                && accessibilityLabel == other.accessibilityLabel
        }
    }

    extension BNTabBarItem.Icon {
        /// The image a bar or a system menu draws: a template the drawer tints, or a picture kept
        /// in its own colours.
        var drawnImage: UIImage? {
            switch self {
            case let .symbol(name): UIImage(systemName: name)
            case let .image(image, _, .template): image.withRenderingMode(.alwaysTemplate)
            case let .image(image, _, .original): image.withRenderingMode(.alwaysOriginal)
            }
        }

        /// The image for a system menu, which draws a picture at whatever size it comes: an image
        /// is redrawn into its box first.
        func menuImage(for icon: BNTabBarTheme.IconSpec) -> UIImage? {
            guard let image = drawnImage, let box = imageBox(for: icon),
                  image.size.width > 0, image.size.height > 0 else { return drawnImage }
            let scale = min(box.width / image.size.width, box.height / image.size.height)
            let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            return UIGraphicsImageRenderer(size: fitted).image { _ in
                image.draw(in: CGRect(origin: .zero, size: fitted))
            }.withRenderingMode(image.renderingMode)
        }

        /// The box an image is fitted into: its own size, or the square of a round symbol drawn
        /// at the theme's point size and scale — the size an avatar takes beside its neighbours.
        /// `nil` for a symbol, the app's own passed as an image included, which the theme's
        /// configuration sizes itself: a box would fit the symbol's alignment rectangle, which its
        /// insets make smaller than the glyph, and draw it smaller than the system's beside it.
        func imageBox(for icon: BNTabBarTheme.IconSpec) -> CGSize? {
            guard case let .image(image, size, _) = self, !image.isSymbolImage else { return nil }
            if let size {
                return size
            }
            let configuration = UIImage.SymbolConfiguration(pointSize: icon.pointSize, weight: .regular, scale: icon.scale)
            let circle = UIImage(systemName: "circle", withConfiguration: configuration)
            let side = circle.map { max($0.size.width, $0.size.height) } ?? icon.pointSize
            return CGSize(width: side, height: side)
        }
    }
#endif
