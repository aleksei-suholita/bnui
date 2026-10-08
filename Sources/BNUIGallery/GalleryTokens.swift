#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// Constants the showcase draws itself with.
    ///
    /// Not part of the kit's contract and not public: a control's own look comes from its theme,
    /// and the gallery around it needs a ruler of its own. These used to be an app's placeholder
    /// tokens, which is exactly the kind of tie that stops a kit from leaving.
    enum BNGallerySpacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }

    enum BNGalleryMetrics {
        /// Corner of a knob card — the inset-grouped cards of iOS 26 Settings.
        static let cardRadius: CGFloat = 22
        /// Top corners of the inspector drawer.
        static let inspectorRadius: CGFloat = 32
        /// A row is never shorter than a comfortable touch, whatever its control.
        static let rowMinHeight: CGFloat = 48
        /// Catalogue icon: a rounded square with a glyph, the way Settings draws its rows.
        static let iconSize: CGFloat = 30
        static let iconRadius: CGFloat = 8
        static let grabberSize = CGSize(width: 36, height: 5)
        /// The drawer's header: grabber, title and the two buttons. Collapsed, this is all that
        /// stays on screen.
        static let inspectorHeaderHeight: CGFloat = 64
        /// Width of the inspector when it becomes a sidebar on a regular-width screen.
        static let sidebarWidth: CGFloat = 380
    }

    enum BNGalleryColor {
        /// The inspector drawer and the catalogue behind the cards.
        static var groupedBackground: UIColor {
            .systemGroupedBackground
        }

        /// A knob card on the grouped background.
        static var card: UIColor {
            .secondarySystemGroupedBackground
        }

        static var label: UIColor {
            .label
        }

        static var secondaryLabel: UIColor {
            .secondaryLabel
        }

        static var tertiaryLabel: UIColor {
            .tertiaryLabel
        }

        static var separator: UIColor {
            .separator
        }

        /// A row of an action card while the finger is on it.
        static var highlight: UIColor {
            .systemFill
        }

        static var accent: UIColor {
            .tintColor
        }

        /// A label drawn on top of a filled surface, where the fill stays the same in both themes.
        static var onMedia: UIColor {
            .white
        }
    }

    enum BNGalleryFont {
        static var body: UIFont {
            .preferredFont(forTextStyle: .body)
        }

        static var headline: UIFont {
            .preferredFont(forTextStyle: .headline)
        }

        static var footnote: UIFont {
            .preferredFont(forTextStyle: .footnote)
        }

        /// Section heading above a card.
        static var sectionHeader: UIFont {
            UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .semibold))
        }

        /// A slider's value: tabular digits, so the number does not jitter sideways while it changes.
        static var value: UIFont {
            UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedDigitSystemFont(ofSize: 17, weight: .regular))
        }
    }
#endif
