#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// A gallery page: the control's demo view plus knobs for its properties.
    /// Kit rule: a control is not done until it has a page of its own.
    ///
    /// Everything past `title`, `makeDemoView()` and `makeKnobs(for:)` has a default, so a page
    /// written for an older engine keeps compiling and simply looks plainer in the catalogue.
    public protocol GalleryPage {
        var title: String { get }

        /// SF Symbol drawn in the catalogue next to the title.
        var symbol: String { get }

        /// One line under the title in the catalogue: what the page is for, not what it contains.
        var summary: String? { get }

        /// The catalogue heading the page is listed under. Sections appear in the order of their
        /// first page, so the order pages are handed to the gallery still decides the layout.
        var section: String { get }

        func makeDemoView() -> UIView

        /// A demo that has to be a view controller — one hosting children of its own, such as a
        /// system tab bar controller to stand next to — provides it here. When it does, its
        /// `view` is the demo view and `makeDemoView()` is never called.
        func makeDemoViewController() -> UIViewController?

        /// Pin the demo view to the whole stage instead of centring it at its own size.
        ///
        /// Centring is right for a control that knows how big it is — a button, a tab bar. A
        /// control sized by its container has no size to be centred at and collapses to nothing,
        /// which is exactly what a full-bleed control is supposed to do.
        var fillsDemoArea: Bool { get }

        /// Share of the screen a full-bleed demo gets at the middle height of the inspector. A demo
        /// that sizes itself is measured instead, and this is ignored.
        var demoAreaFraction: CGFloat { get }

        /// What the stage puts behind the demo when the page opens; the stage menu changes it.
        var backdrop: GalleryBackdrop { get }

        /// The demo is itself a background — a texture, a surface a screen is built on.
        ///
        /// It then takes the whole stage, under the navigation bar and under the inspector, the way
        /// it would take a whole screen, and replaces the stage backdrop: the stage menu offers no
        /// backdrop for it. A background laid over another background answers no question, and a
        /// background framed inside a strip is judged on the wrong room.
        var isBackground: Bool { get }

        /// The edge of the stage the event feed sits on — the one the control does not use.
        var eventFeedEdge: GalleryEventFeedEdge { get }

        func makeKnobs(for demoView: UIView) -> [GalleryKnob]

        /// Called by the inspector's Reset before every knob is put back to its initial value.
        ///
        /// Knobs restore what they own; this is for the state no knob owns — a log, messages still
        /// in flight, a selection the demo made on its own.
        func resetDemo(_ demoView: UIView)
    }

    public extension GalleryPage {
        var symbol: String {
            "square.on.square"
        }

        var summary: String? {
            nil
        }

        var section: String {
            "Controls"
        }

        func makeDemoViewController() -> UIViewController? {
            nil
        }

        var fillsDemoArea: Bool {
            false
        }

        var demoAreaFraction: CGFloat {
            0.5
        }

        var backdrop: GalleryBackdrop {
            .plain
        }

        var isBackground: Bool {
            false
        }

        var eventFeedEdge: GalleryEventFeedEdge {
            .top
        }

        func resetDemo(_: UIView) {}
    }
#endif
