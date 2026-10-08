import CoreGraphics
import Foundation

/// One tick of feedback, named by what it means.
///
/// `Hashable` because a signal travels inside values that are themselves hashed — a toast role, for
/// one — and a signal is a plain description with nothing to hash badly.
public nonisolated enum BNHapticSignal: Equatable, Hashable, Sendable {
    case impact(BNHapticWeight, intensity: CGFloat = 1)
    case notification(BNHapticNotification)
    case selection
}

public nonisolated enum BNHapticWeight: Equatable, Hashable, Sendable {
    case light
    case medium
    case heavy
    case soft
    case rigid
}

public nonisolated enum BNHapticNotification: Equatable, Hashable, Sendable {
    case success
    case warning
    case error
}

/// The merge rule, apart from the engine that plays through it.
///
/// Pure, because this is the only piece of the haptic layer with a decision in it — everything else
/// is a call into UIKit — and a rule about time that can only be checked by feeling a phone is a
/// rule nobody checks.
public nonisolated struct BNHapticGate: Equatable, Sendable {
    /// Two impulses closer together than this are one event to the finger.
    public var window: TimeInterval

    private var lastPlayed: TimeInterval?

    public init(window: TimeInterval = 0.15) {
        self.window = window
    }

    /// Whether a signal arriving at `time` should be felt.
    ///
    /// - Parameters:
    ///   - time: when the signal arrives, on the caller's monotonic clock — the player passes
    ///     `CACurrentMediaTime()`, a test passes whatever instant it needs.
    ///   - merging: `false` for continuous feedback — a drag crossing section boundaries, a
    ///     stack snapping card after card. There the stream *is* the report, and swallowing every
    ///     second tick would make the gesture lie about where the finger is. Such a tick still marks
    ///     the clock, so a single event landing right behind the stream does not double up on it.
    public mutating func shouldPlay(at time: TimeInterval, merging: Bool = true) -> Bool {
        guard merging, let last = lastPlayed, window > 0 else {
            lastPlayed = time
            return true
        }
        // A swallowed impulse deliberately does not mark the clock — otherwise a burst of suppressed
        // calls would keep pushing the silence forward and the next real event would never be felt.
        guard time - last >= window else { return false }
        lastPlayed = time
        return true
    }
}

#if canImport(UIKit)
    import UIKit

    /// The kit's haptic engine: every control's tick goes through one object, so the merge rule can
    /// be enforced across controls instead of inside each of them.
    ///
    /// The rule that made this necessary: a disabled button answers a touch with a refusal *and*
    /// tells its host, the host explains why with a toast, and the toast plays the haptic of its
    /// role. Two impulses land on one finger for one event — exactly what "one tap, one tick" in
    /// the button spec already forbade. Neither control can fix that alone, because neither knows
    /// the other played. So the window lives here, one layer below both.
    ///
    /// Merging is opt-out per call. Continuous gestures — dragging across the tab bar, scrubbing a
    /// chart — feed ticks faster than the window on purpose: there the stream *is* the feedback, and
    /// swallowing every second tick would take away the thing being reported.
    ///
    /// Muted by ``isEnabled``, the host's global switch, and by system-level limits (Low Power Mode,
    /// haptics turned off) which the generators observe themselves.
    public final class BNHaptics {
        /// The shared engine. A singleton because the rule it enforces is about the finger, and
        /// there is one of those however many controls are on screen.
        public static let shared = BNHaptics()

        /// The host's global switch.
        public var isEnabled: Bool = true

        /// Two impulses closer together than this are one event to the finger; the second is
        /// dropped. Same default as the button's own within-a-tap window.
        public var mergeWindow: TimeInterval {
            get { gate.window }
            set { gate.window = newValue }
        }

        private var gate = BNHapticGate()
        private var impacts: [BNHapticWeight: UIImpactFeedbackGenerator] = [:]
        private let notifications = UINotificationFeedbackGenerator()
        private let selection = UISelectionFeedbackGenerator()

        public init() {}

        /// Warms the generators so the tick lands with the frame that caused it.
        public func prepare(_ signal: BNHapticSignal) {
            guard isEnabled else { return }
            switch signal {
            case let .impact(weight, _): impactGenerator(weight).prepare()
            case .notification: notifications.prepare()
            case .selection: selection.prepare()
            }
        }

        /// Plays a signal, unless the previous one is still ringing.
        ///
        /// - Parameters:
        ///   - signal: the haptic to play.
        ///   - merging: `false` for continuous feedback, where a stream of close ticks is
        ///     the point rather than an accident.
        /// - Returns: whether it actually played. Callers that keep their own state — a control
        ///   deciding whether it has already answered a touch — need to know.
        @discardableResult
        public func play(_ signal: BNHapticSignal, merging: Bool = true) -> Bool {
            guard isEnabled else { return false }
            guard gate.shouldPlay(at: CACurrentMediaTime(), merging: merging) else { return false }

            switch signal {
            case let .impact(weight, intensity):
                impactGenerator(weight).impactOccurred(intensity: intensity)
            case let .notification(kind):
                notifications.notificationOccurred(kind.systemType)
            case .selection:
                selection.selectionChanged()
            }
            return true
        }

        private func impactGenerator(_ weight: BNHapticWeight) -> UIImpactFeedbackGenerator {
            if let existing = impacts[weight] {
                return existing
            }
            let generator = UIImpactFeedbackGenerator(style: weight.systemStyle)
            impacts[weight] = generator
            return generator
        }
    }

    extension BNHapticWeight {
        var systemStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: .light
            case .medium: .medium
            case .heavy: .heavy
            case .soft: .soft
            case .rigid: .rigid
            }
        }
    }

    extension BNHapticNotification {
        var systemType: UINotificationFeedbackGenerator.FeedbackType {
            switch self {
            case .success: .success
            case .warning: .warning
            case .error: .error
            }
        }
    }
#endif
