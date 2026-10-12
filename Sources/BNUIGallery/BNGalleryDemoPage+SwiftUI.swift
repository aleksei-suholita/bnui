#if canImport(UIKit)
    import SwiftUI
    import UIKit

    public extension BNGalleryDemoPage {
        /// A page for a SwiftUI view, drawn from props the knobs drive.
        ///
        /// ```swift
        /// final class PillProps: ObservableObject {
        ///     @Published var count = 3
        ///     @Published var isSelected = false
        /// }
        ///
        /// BNGalleryDemoPage("Reaction Pill", props: PillProps()) { props in
        ///     ReactionPill(count: props.count, isSelected: props.isSelected)
        /// } knobs: { _ in [
        ///     .slider("Count", \.count, in: 0 ... 999),
        ///     .toggle("Selected", \.isSelected),
        /// ] }
        /// ```
        ///
        /// A SwiftUI view is a value: a knob cannot reach into one already on screen. So the values
        /// live in the props, the knobs write them by key path, and the view is drawn again from
        /// them. It is hosted by a child controller, so a `.sheet` or an `.alert` inside it can
        /// present, and the stage's appearance, text size and direction reach it as its environment.
        ///
        /// - Parameters:
        ///   - title: The page's name in the catalogue, and what `-OpenGallery` asks for.
        ///   - symbol: SF Symbol drawn in the catalogue next to the title.
        ///   - summary: One line under the title: what the page is for.
        ///   - section: The catalogue heading the page is listed under.
        ///   - layout: How the view sits on the stage.
        ///   - backdrop: What the stage puts behind the view when the page opens.
        ///   - eventFeedEdge: The edge of the stage the event feed sits on.
        ///   - props: What the view is drawn from, and what the knobs drive; made each time the
        ///     page opens.
        ///   - content: The view, drawn from the props.
        ///   - knobs: The inspector's rows for the props, in order.
        init(
            _ title: String,
            symbol: String = "square.on.square",
            summary: String? = nil,
            section: String = "Controls",
            layout: BNGalleryLayout = .centred,
            backdrop: BNGalleryBackdrop = .plain,
            eventFeedEdge: BNGalleryEventFeedEdge = .top,
            props: @escaping @autoclosure () -> Subject,
            @ViewBuilder content: @escaping (Subject) -> some View,
            knobs: @escaping (Subject) -> [Knob] = { _ in [] },
        ) where Subject: ObservableObject {
            self.init(
                title: title, symbol: symbol, summary: summary, section: section, layout: layout,
                backdrop: backdrop, eventFeedEdge: eventFeedEdge, subject: props,
                stage: .controller { props in
                    GallerySwiftUIController(subject: props, root: GalleryObservedContent(props: props, content: content))
                },
                knobs: knobs,
            )
        }

        /// A page for a SwiftUI view drawn from `@Observable` props — the same as the page for
        /// `ObservableObject` props, the view following whatever of the props it reads.
        ///
        /// - Parameters:
        ///   - title: The page's name in the catalogue, and what `-OpenGallery` asks for.
        ///   - symbol: SF Symbol drawn in the catalogue next to the title.
        ///   - summary: One line under the title: what the page is for.
        ///   - section: The catalogue heading the page is listed under.
        ///   - layout: How the view sits on the stage.
        ///   - backdrop: What the stage puts behind the view when the page opens.
        ///   - eventFeedEdge: The edge of the stage the event feed sits on.
        ///   - props: What the view is drawn from, and what the knobs drive; made each time the
        ///     page opens.
        ///   - content: The view, drawn from the props.
        ///   - knobs: The inspector's rows for the props, in order.
        @available(iOS 17.0, *)
        init(
            _ title: String,
            symbol: String = "square.on.square",
            summary: String? = nil,
            section: String = "Controls",
            layout: BNGalleryLayout = .centred,
            backdrop: BNGalleryBackdrop = .plain,
            eventFeedEdge: BNGalleryEventFeedEdge = .top,
            props: @escaping @autoclosure () -> Subject,
            @ViewBuilder content: @escaping (Subject) -> some View,
            knobs: @escaping (Subject) -> [Knob] = { _ in [] },
        ) where Subject: Observable {
            self.init(
                title: title, symbol: symbol, summary: summary, section: section, layout: layout,
                backdrop: backdrop, eventFeedEdge: eventFeedEdge, subject: props,
                stage: .controller { props in
                    GallerySwiftUIController(subject: props, root: GalleryTrackedContent(props: props, content: content))
                },
                knobs: knobs,
            )
        }
    }

    public extension BNGalleryDemoPage.Knob {
        /// A colour well bound to a SwiftUI `Color` property of the props.
        static func color(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Color>,
            note: String? = nil,
        ) -> Self {
            Self { subject in
                BNGalleryKnob(
                    label: label,
                    control: .color(
                        initial: UIColor(subject[keyPath: property]),
                        onChange: { subject[keyPath: property] = Color(uiColor: $0) },
                    ),
                    note: note,
                )
            }
        }
    }

    /// Hosts a page's SwiftUI view as a child controller — so a `.sheet` or an `.alert` inside it
    /// has a controller to present from — sized by what the view asks for, and carries its props
    /// for the knobs.
    final class GallerySwiftUIController<Root: View>: UIViewController {
        private let hosting: UIHostingController<Root>
        private let carrier: GalleryCarrierView

        init(subject: AnyObject, root: Root) {
            hosting = UIHostingController(rootView: root)
            hosting.sizingOptions = [.intrinsicContentSize]
            carrier = GalleryCarrierView(subjects: [subject])
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func loadView() {
            view = carrier
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            // The stage's backdrop shows through, as it does behind a UIKit demo.
            hosting.view.backgroundColor = .clear
            addChild(hosting)
            carrier.embed(hosting.view)
            hosting.didMove(toParent: self)
        }
    }

    /// The page's view, drawn again whenever its `ObservableObject` props announce a change.
    struct GalleryObservedContent<Props: ObservableObject, Content: View>: View {
        @ObservedObject var props: Props
        let content: (Props) -> Content

        var body: some View {
            content(props)
        }
    }

    /// The page's view over `@Observable` props, which SwiftUI follows by what the body reads.
    struct GalleryTrackedContent<Props: AnyObject, Content: View>: View {
        let props: Props
        let content: (Props) -> Content

        var body: some View {
            content(props)
        }
    }
#endif
