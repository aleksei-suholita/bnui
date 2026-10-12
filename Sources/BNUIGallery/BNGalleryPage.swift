#if canImport(UIKit)
    import BNUI
    import UIKit

    /// A gallery page: the control's demo view plus knobs for its properties.
    /// Kit rule: a control is not done until it has a page of its own.
    ///
    /// Everything past `title`, `makeDemoView()` and `makeKnobs(for:)` has a default, so a page
    /// written for an older engine keeps compiling and simply looks plainer in the catalogue.
    ///
    /// A page that is a demo and knobs bound to its properties needs no type of its own: see
    /// ``BNGalleryDemoPage``. Conforming here is for a page that needs more — a demo controller,
    /// a reset for state no knob owns, knobs worked out from the demo's own tables.
    public protocol BNGalleryPage {
        /// The page's name in the catalogue and in its navigation bar, and what
        /// `-OpenGallery <Title>` asks for.
        var title: String { get }

        /// SF Symbol drawn in the catalogue next to the title.
        var symbol: String { get }

        /// One line under the title in the catalogue: what the page is for, not what it contains.
        var summary: String? { get }

        /// The catalogue heading the page is listed under. Sections appear in the order of their
        /// first page, so the order pages are handed to the gallery still decides the layout.
        var section: String { get }

        /// A fresh demo, made each time the page opens.
        func makeDemoView() -> UIView

        /// A demo that has to be a view controller — one hosting children of its own, such as a
        /// system tab bar controller to stand next to — provides it here. When it does, its
        /// `view` is the demo view and `makeDemoView()` is never called.
        func makeDemoViewController() -> UIViewController?

        /// How the demo sits on the stage: centred at its own size, across the width, over the
        /// whole demo area or as the stage's background.
        var layout: BNGalleryLayout { get }

        /// What the stage puts behind the demo when the page opens; the stage menu changes it.
        var backdrop: BNGalleryBackdrop { get }

        /// The edge of the stage the event feed sits on — the one the control does not use.
        var eventFeedEdge: BNGalleryEventFeedEdge { get }

        /// The inspector's rows for the demo just made, in order. Each knob captures the demo it
        /// drives.
        func makeKnobs(for demoView: UIView) -> [BNGalleryKnob]

        /// Commands of the page's own — a replay, a sample error, anything that is an action rather
        /// than a value — in a ⋯ menu in the page's navigation bar, which shows only when there are
        /// some. Menus and toggles nest as in any `UIMenu`.
        func makeActions(for demoView: UIView) -> [UIMenuElement]

        /// Called by the inspector's Reset before every knob is put back to its initial value.
        ///
        /// Knobs restore what they own; this is for the state no knob owns — a log, messages still
        /// in flight, a selection the demo made on its own.
        func resetDemo(_ demoView: UIView)
    }

    public extension BNGalleryPage {
        /// Two stacked squares — a generic control.
        var symbol: String {
            "square.on.square"
        }

        /// No line under the title.
        var summary: String? {
            nil
        }

        /// Listed under "Controls".
        var section: String {
            "Controls"
        }

        /// No controller: the demo is `makeDemoView()`.
        func makeDemoViewController() -> UIViewController? {
            nil
        }

        /// Centred at the demo's own size.
        var layout: BNGalleryLayout {
            .centred
        }

        /// The system background.
        var backdrop: BNGalleryBackdrop {
            .plain
        }

        /// Along the top of the stage.
        var eventFeedEdge: BNGalleryEventFeedEdge {
            .top
        }

        /// No commands of its own: no ⋯ menu.
        func makeActions(for _: UIView) -> [UIMenuElement] {
            []
        }

        /// Nothing to reset beyond the knobs.
        func resetDemo(_: UIView) {}
    }
#endif
