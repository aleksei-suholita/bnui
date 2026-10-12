#if canImport(UIKit)
    import UIKit

    /// How a demo sits on the stage.
    public enum BNGalleryLayout: Equatable, Sendable {
        /// Where a demo spanning the width sits.
        public enum Position: Sendable {
            case top, center, bottom
        }

        /// Sizes itself and is centred — a button, a chip, an avatar. A demo with no width of its
        /// own, such as a button that fills, spans the stage within the screen's margins instead;
        /// one that switches between the two is laid out again. When the stage gets shorter than
        /// the demo, the demo scrolls rather than being clipped.
        case centred

        /// Spans the stage's width at its own height — a text field, a progress bar, a toolbar.
        ///
        /// In the middle it keeps the screen's margins, the way a field sits in a form; at an edge
        /// it runs edge to edge, the way a bar sits on a screen. `margin` insets it from the sides
        /// instead — and at an edge from that edge too, for a bar that floats the way a tab bar
        /// does in its container.
        ///
        /// A demo with a width of its own is stretched too, alone and on a page of states alike.
        /// For one that decides for itself — a button that hugs beside one that fills — the
        /// layout is ``centred``.
        case width(at: Position = .center, margin: CGFloat? = nil)

        /// Takes the whole demo area — a control sized by its container, such as a carousel or a
        /// stack of cards, which centred at its own size would collapse to nothing. `share` is the
        /// part of the screen the demo gets while the inspector is at its middle height.
        case fill(share: CGFloat = 0.5)

        /// Is itself a background — a texture, a surface a screen is built on.
        ///
        /// It takes the whole stage, under the navigation bar and under the inspector, the way it
        /// would take a whole screen, and replaces the stage's backdrop: the stage menu offers no
        /// backdrop for it. A background over another background answers no question, and one
        /// framed inside a strip is judged on the wrong room.
        case background
    }
#endif
