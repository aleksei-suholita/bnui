#if canImport(UIKit)
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
            /// asset does not grow the bar. The action button draws the image its own way, as a
            /// button draws an icon.
            case image(UIImage, size: CGSize? = nil, rendering: ImageRendering = .template)
        }

        /// How an image takes the section's state.
        public enum ImageRendering: Equatable, Sendable {
            /// A glyph: its shape in the colour of the state, as a symbol is drawn.
            case template
            /// A picture in its own colours — a person's photo. The state does not touch
            /// it; the lens under it is what says the section is chosen.
            case original
        }

        public let id: String
        public let icon: Icon
        public let title: String
        /// A count, a short text or a dot. Changing only the badges of a bar's sections redraws the
        /// badges alone, and a finger on the bar keeps its gesture — one in place reads
        /// `bar.items[1].badge = .count(3)`.
        public var badge: BNTabBarBadge?
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
            badge: BNTabBarBadge? = nil,
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

    extension BNTabBarItem {
        /// Whether the two are the same section and only the badge tells them apart — the change a
        /// bar draws in place instead of rebuilding.
        func differsOnlyInBadge(from other: BNTabBarItem) -> Bool {
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
        func menuImage(pointSize: CGFloat) -> UIImage? {
            guard let image = drawnImage, let box = imageBox(pointSize: pointSize),
                  image.size.width > 0, image.size.height > 0 else { return drawnImage }
            let scale = min(box.width / image.size.width, box.height / image.size.height)
            let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            return UIGraphicsImageRenderer(size: fitted).image { _ in
                image.draw(in: CGRect(origin: .zero, size: fitted))
            }.withRenderingMode(image.renderingMode)
        }

        /// The box an image is fitted into: its own size, or the square of a round symbol drawn
        /// at `pointSize` — the size an avatar takes beside its neighbours. `nil` for a symbol,
        /// which the point size sizes itself.
        func imageBox(pointSize: CGFloat) -> CGSize? {
            guard case let .image(_, size, _) = self else { return nil }
            if let size {
                return size
            }
            let circle = UIImage(systemName: "circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))
            let side = circle.map { max($0.size.width, $0.size.height) } ?? pointSize
            return CGSize(width: side, height: side)
        }
    }
#endif
