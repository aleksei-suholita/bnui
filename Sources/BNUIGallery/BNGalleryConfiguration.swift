#if canImport(UIKit)
    import UIKit

    /// How the gallery looks as a whole in an app: the catalogue's title, the order and icons of
    /// its sections, and the app's own backdrops beside the gallery's.
    ///
    /// ```swift
    /// BNGallery.present(pages, from: self, configuration: BNGalleryConfiguration(
    ///     title: "App Design",
    ///     sections: [
    ///         .section("Buttons", symbol: "capsule"),
    ///         .section("Lists", symbol: "list.bullet"),
    ///     ],
    ///     backdrops: [
    ///         .image(feedScreenshot, title: "Feed"),
    ///         .view(title: "Chat") { ChatMock() },
    ///     ],
    /// ))
    /// ```
    public struct BNGalleryConfiguration {
        /// One heading of the catalogue.
        public struct Section {
            let name: String
            let symbol: String?

            /// The section the pages name in their `section`, with an SF Symbol beside its heading.
            public static func section(_ name: String, symbol: String? = nil) -> Self {
                Self(name: name, symbol: symbol)
            }
        }

        /// The catalogue's title.
        public var title: String
        /// Sections listed first, in this order and with these icons. The rest follow in the order
        /// of their first page; a section no page names is not shown.
        public var sections: [Section]
        /// The app's own backdrops, offered in every page's stage menu after the gallery's.
        public var backdrops: [BNGalleryBackdrop]

        /// A configuration; each part left out stays as the gallery has it.
        ///
        /// - Parameters:
        ///   - title: The catalogue's title.
        ///   - sections: Sections listed first, in this order and with these icons.
        ///   - backdrops: The app's own backdrops, after the gallery's in the stage menu.
        public init(title: String = "Design Gallery", sections: [Section] = [], backdrops: [BNGalleryBackdrop] = []) {
            self.title = title
            self.sections = sections
            self.backdrops = backdrops
        }
    }
#endif
