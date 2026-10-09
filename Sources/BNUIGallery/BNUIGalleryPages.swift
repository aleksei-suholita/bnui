#if (DEBUG || GalleryInRelease) && canImport(UIKit)
    /// The kit's own pages, in the order they are shown.
    ///
    /// A host app appends its pages to these: the kit ships the showcase for its controls, and an
    /// app that adds a component of its own adds a page next to them rather than inside them.
    public enum BNUIGalleryPages {
        /// A page per control of the kit, freshly made.
        public static func all() -> [any BNGalleryPage] {
            [
                BNTabBarGalleryPage(),
                BNButtonGalleryPage(),
            ]
        }
    }
#endif
