import CoreGraphics
import Foundation

/// The rules of a touch, lifted out of the view: what counts as pressed, when the action fires,
/// how instant the press was, and when the button stays silent.
public nonisolated struct BNButtonInteraction: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        case down(at: TimeInterval)
        /// The finger moved; `inside` is whether it is still within the touch area.
        case moved(inside: Bool)
        case up(inside: Bool, at: TimeInterval)
        /// The system took the touch away — a call, a system gesture, a parent scroll view.
        case cancelled
    }

    /// The `UIControl` touch events a step of the touch sends, under the same names.
    ///
    /// The button declines `UIControl` tracking, so nothing in UIKit sends these for it; the rule
    /// lives here, beside the decision to fire, so that it can be tested without UIKit. A touch
    /// the button accepted ends with exactly one of `touchUpInside`, `touchUpOutside` and
    /// `touchCancel`; a touch it never accepted sends nothing.
    public struct ControlEvents: OptionSet, Equatable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let touchDown = ControlEvents(rawValue: 1 << 0)
        public static let touchDragInside = ControlEvents(rawValue: 1 << 1)
        public static let touchDragOutside = ControlEvents(rawValue: 1 << 2)
        public static let touchDragEnter = ControlEvents(rawValue: 1 << 3)
        public static let touchDragExit = ControlEvents(rawValue: 1 << 4)
        /// Sent only with the action: a target bound to it must not slip past what stops the
        /// action, so a lift inside that does not fire ends as ``touchCancel``.
        public static let touchUpInside = ControlEvents(rawValue: 1 << 5)
        public static let touchUpOutside = ControlEvents(rawValue: 1 << 6)
        public static let touchCancel = ControlEvents(rawValue: 1 << 7)
    }

    public struct Outcome: Equatable, Sendable {
        /// Whether the button should draw itself pressed after this event.
        public var isPressed: Bool
        /// Whether the host's handler should run.
        public var didFire: Bool
        /// How instant the press was, 0...1. Meaningful on a release; drives the return spring.
        public var snap: CGFloat
        public var haptic: BNButtonHapticEvent
        /// The touch landed on a disabled button and should be refused — a flash, a shake, a buzz.
        public var didReject: Bool
        /// The touch events the host's targets should hear for this step.
        public var controlEvents: ControlEvents = []

        public init(
            isPressed: Bool,
            didFire: Bool,
            snap: CGFloat,
            haptic: BNButtonHapticEvent,
            didReject: Bool = false,
        ) {
            self.isPressed = isPressed
            self.didFire = didFire
            self.snap = snap
            self.haptic = haptic
            self.didReject = didReject
        }

        init(
            isPressed: Bool,
            didFire: Bool,
            snap: CGFloat,
            haptic: BNButtonHapticEvent,
            didReject: Bool = false,
            controlEvents: ControlEvents,
        ) {
            self.init(isPressed: isPressed, didFire: didFire, snap: snap, haptic: haptic, didReject: didReject)
            self.controlEvents = controlEvents
        }

        static let idle = Outcome(isPressed: false, didFire: false, snap: 0, haptic: .silent)
    }

    public var snapWindow: TimeInterval
    /// How short a press has to be for its two haptics to become one. See the `.up` branch.
    public var hapticMergeWindow: TimeInterval
    public var cooldown: TimeInterval

    public private(set) var isPressed = false
    public private(set) var downTime: TimeInterval?
    public private(set) var lastFireTime: TimeInterval?

    public init(
        snapWindow: TimeInterval = 0.25,
        hapticMergeWindow: TimeInterval = 0.15,
        cooldown: TimeInterval = 0,
    ) {
        self.snapWindow = snapWindow
        self.hapticMergeWindow = hapticMergeWindow
        self.cooldown = cooldown
    }

    /// The single place where "fired / did not fire / stayed silent" is decided.
    public mutating func handle(_ event: Event, status: BNButtonStatus) -> Outcome {
        guard status.allowsInteraction else {
            return refuse(event, status: status)
        }
        switch event {
        case let .down(time):
            return press(at: time)
        case let .moved(inside):
            return drag(inside: inside)
        case let .up(inside, time):
            return release(inside: inside, at: time)
        case .cancelled:
            return Outcome(isPressed: false, didFire: false, snap: 0, haptic: .silent, controlEvents: dropTouch())
        }
    }

    private mutating func refuse(_ event: Event, status: BNButtonStatus) -> Outcome {
        let ending = dropTouch()
        // A refusal answers the one question an ignored tap leaves open — did the touch even
        // land? It belongs to the moment the finger arrives, not to the lift: the gesture was
        // turned down already, and there is nothing left to wait for. `loading` says nothing,
        // because busy is not the same as forbidden.
        guard status == .disabled, case .down = event else {
            return Outcome(isPressed: false, didFire: false, snap: 0, haptic: .silent, controlEvents: ending)
        }
        return Outcome(isPressed: false, didFire: false, snap: 0, haptic: .rejected, didReject: true, controlEvents: ending)
    }

    private mutating func press(at time: TimeInterval) -> Outcome {
        let ending = dropTouch()
        isPressed = true
        downTime = time
        return Outcome(isPressed: true, didFire: false, snap: 0, haptic: .press, controlEvents: ending.union(.touchDown))
    }

    private mutating func drag(inside: Bool) -> Outcome {
        guard downTime != nil else { return .idle }
        // Where the finger is, on every move; the crossing, once, when it happens.
        var events: ControlEvents = inside ? .touchDragInside : .touchDragOutside
        if inside != isPressed {
            events.insert(inside ? .touchDragEnter : .touchDragExit)
        }
        // No haptic in either direction. The finger never left the glass, and a tick on every
        // re-entry would rattle continuously while a finger rests on the edge.
        isPressed = inside
        return Outcome(isPressed: inside, didFire: false, snap: 0, haptic: .silent, controlEvents: events)
    }

    private mutating func release(inside: Bool, at time: TimeInterval) -> Outcome {
        guard let downTime else {
            // A release with no press behind it — not this button's to act on.
            return .idle
        }
        self.downTime = nil
        isPressed = false
        let snap = BNButtonMotion.snap(heldFor: time - downTime, window: snapWindow)
        guard inside else {
            // Released outside: the cancel gesture. The return still carries the snap, so the
            // button springs back the way it was pressed, but nothing fires and nothing buzzes.
            return Outcome(isPressed: false, didFire: false, snap: snap, haptic: .silent, controlEvents: .touchUpOutside)
        }
        if let lastFireTime, cooldown > 0, time - lastFireTime < cooldown {
            // Swallowed by the theme's barrier. Silent on purpose: the finger must not be told
            // an action happened when it did not — and neither must a target bound to
            // `touchUpInside`, so the touch ends cancelled.
            return Outcome(isPressed: false, didFire: false, snap: snap, haptic: .silent, controlEvents: .touchCancel)
        }
        lastFireTime = time
        // A quick tap is one event to the finger, not two. The press tick fired some forty
        // milliseconds ago, and a confirmation that close does not read as a second beat — it
        // smears the first one, which is why a fast tap felt mushier than a slow one. So the
        // confirmation is dropped and the press tick stands for the whole tap. Past the window
        // the two are far enough apart to be felt separately, and the confirmation earns its
        // place: the finger has been holding, and "it fired" is news.
        let heldFor = time - downTime
        return Outcome(
            isPressed: false,
            didFire: true,
            snap: snap,
            haptic: heldFor < hapticMergeWindow ? .silent : .trigger,
            controlEvents: .touchUpInside,
        )
    }

    /// Lets go of the touch being followed. One that was followed ends cancelled, so a host that
    /// paired its touch-down with an ending is never left waiting: the button turned disabled or
    /// loading under the finger, the system took the touch, or a new press replaced it.
    private mutating func dropTouch() -> ControlEvents {
        defer {
            isPressed = false
            downTime = nil
        }
        return downTime == nil ? [] : .touchCancel
    }
}
