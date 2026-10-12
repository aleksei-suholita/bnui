#if canImport(UIKit)
    import UIKit

    /// A page that is a demo and knobs bound to its properties — no type of its own, no cast, no
    /// table of starting values.
    ///
    /// ```swift
    /// BNGalleryDemoPage("Reaction Pill", symbol: "face.smiling") {
    ///     ReactionPillView()
    /// } knobs: { pill in [
    ///     .header("Content"),
    ///     .text("Emoji", \.emoji),
    ///     .slider("Count", \.count, in: 0 ... 999),
    ///     .toggle("Selected", \.isSelected),
    ///     .choice("Size", \.size),
    ///     .header("Host"),
    ///     .button("Bump, as the host") { pill.bump(animated: true) },
    /// ] }
    /// ```
    ///
    /// A demo made in more than one statement names its type, which Swift does not infer from a
    /// closure of several statements:
    ///
    /// ```swift
    /// BNGalleryDemoPage<ReactionPillView>("Reaction Pill") {
    ///     let pill = ReactionPillView()
    ///     pill.onTap = { BNGallery.post("tap") }
    ///     return pill
    /// } knobs: { pill in [
    ///     .slider("Count", \.count, in: 0 ... 999),
    /// ] }
    /// ```
    ///
    /// The demo is made afresh each time the page opens. A knob bound to a key path reads its
    /// starting value off that demo, so the page starts where the control does, and Reset puts
    /// that value back. What a property cannot say — a call with an animation, something a host
    /// would do — is a `.button`, or any ``BNGalleryKnob`` wrapped in `.knob(_:)`. A demo whose
    /// control reports through callbacks writes to the event feed with ``BNGallery/post(_:)``.
    ///
    /// An alert, a sheet or anything else the gallery should present rather than show is a page
    /// made with `presenting:` — its knobs drive the props the controller is built from.
    ///
    /// A page that needs more — a demo controller, a reset for state no knob owns — conforms to
    /// ``BNGalleryPage`` instead.
    public struct BNGalleryDemoPage<Subject: AnyObject>: BNGalleryPage {
        /// The page's name in the catalogue and in its navigation bar.
        public let title: String
        /// SF Symbol drawn in the catalogue next to the title.
        public let symbol: String
        /// One line under the title in the catalogue.
        public let summary: String?
        /// The catalogue heading the page is listed under.
        public let section: String
        /// What the stage puts behind the demo when the page opens.
        public let backdrop: BNGalleryBackdrop
        /// The edge of the stage the event feed sits on.
        public let eventFeedEdge: BNGalleryEventFeedEdge
        /// How one demo sits on the stage, or in its row on a page of states.
        private let subjectLayout: BNGalleryLayout
        private let makeSubject: () -> Subject
        private let stage: Stage
        private let makeKnobList: (Subject) -> [Knob]
        private var stateList: [State] = []
        private var actionList: [Action] = []

        /// How the page puts what the knobs drive on the stage.
        enum Stage {
            /// It is the demo view.
            case view
            /// A controller is built around it — a Present button, a SwiftUI host.
            case controller((Subject) -> UIViewController)
        }

        /// How the demo sits on the stage. A page of states fills the stage with a column of them.
        public var layout: BNGalleryLayout {
            stateList.isEmpty ? subjectLayout : .fill()
        }

        /// What every public initializer comes down to.
        init(
            title: String,
            symbol: String,
            summary: String?,
            section: String,
            layout: BNGalleryLayout,
            backdrop: BNGalleryBackdrop,
            eventFeedEdge: BNGalleryEventFeedEdge,
            subject: @escaping () -> Subject,
            stage: Stage,
            knobs: @escaping (Subject) -> [Knob],
        ) {
            self.title = title
            self.symbol = symbol
            self.summary = summary
            self.section = section
            subjectLayout = layout
            self.backdrop = backdrop
            self.eventFeedEdge = eventFeedEdge
            makeSubject = subject
            self.stage = stage
            makeKnobList = knobs
        }

        /// A page for a demo view and the knobs bound to it.
        ///
        /// - Parameters:
        ///   - title: The page's name in the catalogue, and what `-OpenGallery` asks for.
        ///   - symbol: SF Symbol drawn in the catalogue next to the title.
        ///   - summary: One line under the title: what the page is for.
        ///   - section: The catalogue heading the page is listed under.
        ///   - layout: How the demo sits on the stage.
        ///   - backdrop: What the stage puts behind the demo when the page opens.
        ///   - eventFeedEdge: The edge of the stage the event feed sits on — the one the control
        ///     does not use.
        ///   - demo: Makes the demo; called each time the page opens.
        ///   - knobs: The inspector's rows for the demo just made, in order.
        public init(
            _ title: String,
            symbol: String = "square.on.square",
            summary: String? = nil,
            section: String = "Controls",
            layout: BNGalleryLayout = .centred,
            backdrop: BNGalleryBackdrop = .plain,
            eventFeedEdge: BNGalleryEventFeedEdge = .top,
            demo: @escaping () -> Subject,
            knobs: @escaping (Subject) -> [Knob] = { _ in [] },
        ) where Subject: UIView {
            self.init(
                title: title, symbol: symbol, summary: summary, section: section, layout: layout,
                backdrop: backdrop, eventFeedEdge: eventFeedEdge, subject: demo, stage: .view, knobs: knobs,
            )
        }

        /// A page for a controller the gallery presents — an alert, an action sheet, a sheet, a
        /// popover, a full-screen cover.
        ///
        /// ```swift
        /// final class DeleteProps {
        ///     var item = "Summer trip"
        ///     var isDestructive = true
        /// }
        ///
        /// BNGalleryDemoPage("Delete Alert", presenting: DeleteProps()) { props in
        ///     let alert = UIAlertController(title: "Delete \(props.item)?", message: nil, preferredStyle: .alert)
        ///     alert.addAction(UIAlertAction(title: "Delete", style: props.isDestructive ? .destructive : .default))
        ///     alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ///     return alert
        /// } knobs: { _ in [
        ///     .text("Item", \.item),
        ///     .toggle("Destructive", \.isDestructive),
        /// ] }
        /// ```
        ///
        /// The stage shows a Present button. Each tap builds the controller afresh from the props,
        /// as the knobs left them, and presents it with the stage's appearance, text size and
        /// layout direction; a popover points at the button. The feed says when it is presented
        /// and when it is gone, and Reset dismisses it. A sheet covers the inspector: dismiss it,
        /// move a knob, present again.
        ///
        /// - Parameters:
        ///   - title: The page's name in the catalogue, and what `-OpenGallery` asks for.
        ///   - symbol: SF Symbol drawn in the catalogue next to the title.
        ///   - summary: One line under the title: what the page is for.
        ///   - section: The catalogue heading the page is listed under.
        ///   - backdrop: What the stage puts behind the controller when it is presented over it.
        ///   - eventFeedEdge: The edge of the stage the event feed sits on.
        ///   - props: What the controller is made from, and what the knobs drive; made once each
        ///     time the page opens.
        ///   - controller: Builds the controller from the props; called on every Present.
        ///   - knobs: The inspector's rows for the props, in order.
        public init(
            _ title: String,
            symbol: String = "square.on.square",
            summary: String? = nil,
            section: String = "Controls",
            backdrop: BNGalleryBackdrop = .plain,
            eventFeedEdge: BNGalleryEventFeedEdge = .top,
            presenting props: @escaping @autoclosure () -> Subject,
            controller: @escaping (Subject) -> UIViewController,
            knobs: @escaping (Subject) -> [Knob] = { _ in [] },
        ) {
            self.init(
                title: title, symbol: symbol, summary: summary, section: section, layout: .centred,
                backdrop: backdrop, eventFeedEdge: eventFeedEdge, subject: props,
                stage: .controller { subject in
                    GalleryPresenterController(subject: subject) { controller(subject) }
                },
                knobs: knobs,
            )
        }

        /// The same demo in several states at once, one under another with its name above it.
        ///
        /// ```swift
        /// BNGalleryDemoPage("Primary Button") {
        ///     PrimaryButton(title: "Continue")
        /// } knobs: { _ in [
        ///     .text("Title", \.title),
        /// ] }
        /// .states([
        ///     .state("Enabled"),
        ///     .state("Disabled") { $0.isEnabled = false },
        ///     .state("Loading") { $0.isLoading = true },
        /// ])
        /// ```
        ///
        /// Each state gets a demo of its own, made fresh and then set into the state. A knob moves
        /// every demo at once; brought back to where it started — by hand or by Reset — it puts
        /// each demo back where its state had it, so the states survive the knobs. A demo that
        /// sizes itself sits centred in its row; any other spans the width at its own height.
        public func states(_ states: [State]) -> Self {
            var page = self
            page.stateList = states
            return page
        }

        /// A command of the page's own in the ⋯ menu of its navigation bar — a replay, a sample
        /// error: `.action("Replay", image: "play") { $0.replay() }`. On a page of states it acts
        /// on every demo.
        ///
        /// - Parameters:
        ///   - title: The command's name in the menu.
        ///   - image: An SF Symbol beside the name.
        ///   - perform: What it does to the demo — or to the props, on a page drawn from props.
        public func action(_ title: String, image: String? = nil, perform: @escaping (Subject) -> Void) -> Self {
            var page = self
            page.actionList.append(Action(title: title, image: image, perform: perform))
            return page
        }

        /// The page's commands, each acting on every demo the page made.
        public func makeActions(for demoView: UIView) -> [UIMenuElement] {
            let subjects = Self.subjects(of: demoView)
            return actionList.map { action in
                UIAction(title: action.title, image: action.image.flatMap { UIImage(systemName: $0) }) { _ in
                    for subject in subjects {
                        action.perform(subject)
                    }
                }
            }
        }

        /// The demo, for a page whose demo is one view.
        public func makeDemoView() -> UIView {
            makeSubject() as? UIView ?? UIView()
        }

        /// The stage's controller: a column of states, or a controller built around the demo.
        public func makeDemoViewController() -> UIViewController? {
            if !stateList.isEmpty {
                let rows = stateList.map { state in
                    let subject = makeSubject()
                    state.configure(subject)
                    return GalleryStatesController.Row(name: state.name, subject: subject, content: content(for: subject))
                }
                return GalleryStatesController(rows: rows, acrossWidth: subjectLayout != .centred)
            }
            guard case let .controller(build) = stage else { return nil }
            return build(makeSubject())
        }

        /// The knobs, each bound to what the page just made. On a page of states one row drives the
        /// same knob of every demo.
        public func makeKnobs(for demoView: UIView) -> [BNGalleryKnob] {
            let lists = Self.subjects(of: demoView).map { subject in
                makeKnobList(subject).map { $0.make(subject) }
            }
            guard let first = lists.first else { return [] }
            return first.indices.map { index in
                BNGalleryKnob.fanOut(lists.compactMap { $0.indices.contains(index) ? $0[index] : nil })
            }
        }

        /// Dismisses what the page presented; the knobs put back the rest.
        public func resetDemo(_ demoView: UIView) {
            (demoView as? any GalleryDemoResetting)?.resetForGallery()
        }

        private func content(for subject: Subject) -> GalleryStatesController.Content {
            switch stage {
            case .view: .view(subject as? UIView ?? UIView())
            case let .controller(build): .controller(build(subject))
            }
        }

        /// The demo view itself, or what the view the gallery built around the demo carries.
        private static func subjects(of demoView: UIView) -> [Subject] {
            if let subject = demoView as? Subject {
                return [subject]
            }
            return (demoView as? any GallerySubjectCarrying)?.gallerySubjects.compactMap { $0 as? Subject } ?? []
        }
    }

    public extension BNGalleryDemoPage {
        /// A knob of a demo page. It becomes a ``BNGalleryKnob`` once the demo exists, so a knob
        /// bound to a key path can read where the demo starts.
        struct Knob {
            let make: (Subject) -> BNGalleryKnob
        }

        /// A command of the page's own, as `action(_:image:perform:)` keeps it.
        struct Action {
            let title: String
            let image: String?
            let perform: (Subject) -> Void
        }

        /// One state of the demo on a page that shows them all at once.
        struct State {
            let name: String
            let configure: (Subject) -> Void

            /// A state: its name, written above its demo, and what puts a fresh demo into it —
            /// nothing, for the state the demo starts in.
            public static func state(_ name: String, _ configure: @escaping (Subject) -> Void = { _ in }) -> Self {
                Self(name: name, configure: configure)
            }
        }
    }
#endif
