#if canImport(UIKit)
    import UIKit

    /// The system materials a blur material can be made of: the thickness scale, thinnest first,
    /// then chrome — the material of system bars. One list, so every page names them the same way.
    enum GalleryBlurThickness {
        static let all: [(name: String, style: UIBlurEffect.Style)] = [
            ("ultra thin", .systemUltraThinMaterial),
            ("thin", .systemThinMaterial),
            ("regular", .systemMaterial),
            ("thick", .systemThickMaterial),
            ("chrome", .systemChromeMaterial),
        ]

        /// Where `.systemMaterial` — what the kit's defaults wear below iOS 26 — sits in ``all``.
        static let standardIndex = 2

        /// The knob position a page starts at: glass, first in its list, on iOS 26; below it the
        /// blur the kit falls to by default, after the `leading` choices that come before the blurs.
        static func defaultIndex(leading: Int) -> Int {
            if #available(iOS 26.0, *) {
                return 0
            }
            return leading + standardIndex
        }
    }
#endif
