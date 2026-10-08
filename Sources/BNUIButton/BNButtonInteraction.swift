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
            isPressed = false
            downTime = nil
            // A refusal answers the one question an ignored tap leaves open — did the touch even
            // land? It belongs to the moment the finger arrives, not to the lift: the gesture was
            // turned down already, and there is nothing left to wait for. `loading` says nothing,
            // because busy is not the same as forbidden.
            guard status == .disabled, case .down = event else { return .idle }
            return Outcome(isPressed: false, didFire: false, snap: 0, haptic: .rejected, didReject: true)
        }

        switch event {
        case let .down(time):
            isPressed = true
            downTime = time
            return Outcome(isPressed: true, didFire: false, snap: 0, haptic: .press)

        case let .moved(inside):
            guard downTime != nil else { return .idle }
            // No haptic in either direction. The finger never left the glass, and a tick on every
            // re-entry would rattle continuously while a finger rests on the edge.
            isPressed = inside
            return Outcome(isPressed: inside, didFire: false, snap: 0, haptic: .silent)

        case let .up(inside, time):
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
                return Outcome(isPressed: false, didFire: false, snap: snap, haptic: .silent)
            }
            if let lastFireTime, cooldown > 0, time - lastFireTime < cooldown {
                // Swallowed by the theme's barrier. Silent on purpose: the finger must not be told
                // an action happened when it did not.
                return Outcome(isPressed: false, didFire: false, snap: snap, haptic: .silent)
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
            )

        case .cancelled:
            isPressed = false
            downTime = nil
            return .idle
        }
    }
}
