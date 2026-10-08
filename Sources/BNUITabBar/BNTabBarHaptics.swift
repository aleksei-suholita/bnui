#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// The bar's haptic contract, written down rather than picked in code.
    ///
    /// | Event | Response |
    /// |---|---|
    /// | touch-down on an inactive section | light, short |
    /// | crossing a section boundary while dragging | selection tick |
    /// | section changed | selection, heavier than a crossing |
    /// | active section re-selected | different pattern — the finger must tell it apart |
    /// | action button | its own pattern, never the section-change one |
    /// | More opens its menu | light, like a touch-down — the menu is not a choice yet |
    /// | system interruption | silence |
    ///
    /// The system bar is silent throughout, so this is a cheap and noticeable win.
    ///
    /// Every tick goes through ``BNHaptics``, the kit's one engine — so a host switching haptics off
    /// has one switch to reach rather than one per control, and so the merge window can see across
    /// controls. Crossings are played *unmerged*: during a drag they arrive faster than the window
    /// on purpose, and there the stream is the report of where the finger is. The single events
    /// around them — the commit, the re-selection, the action — merge normally, which is what keeps
    /// a crossing and the commit landing right behind it from reading as a rattle.
    ///
    /// Muted by ``isEnabled`` (this bar alone), by `BNHaptics.isEnabled` (everything), and by
    /// system-level limits.
    public final class BNTabBarHaptics {
        public var isEnabled: Bool

        private let engine: BNHaptics

        public init(isEnabled: Bool = true, engine: BNHaptics = .shared) {
            self.isEnabled = isEnabled
            self.engine = engine
        }

        /// Called on touch-down so the generators are warm by the time the finger moves.
        public func prepare() {
            guard isEnabled else { return }
            engine.prepare(.selection)
            engine.prepare(.impact(.medium))
        }

        public func pressedDown() {
            guard isEnabled else { return }
            // The first impulse of a gesture: never swallowed, or the touch goes unanswered.
            engine.play(.impact(.light, intensity: 0.6), merging: false)
        }

        public func crossedBoundary() {
            guard isEnabled else { return }
            engine.play(.selection, merging: false)
        }

        public func selectionChanged() {
            guard isEnabled else { return }
            engine.play(.impact(.medium))
        }

        /// The action is not navigation, so it must not feel like changing a section.
        public func actionTriggered() {
            guard isEnabled else { return }
            engine.play(.impact(.soft))
        }

        /// Answers the finger without announcing a change: nothing is chosen until a section is
        /// picked in the menu, and that pick plays `selectionChanged` as any other.
        public func overflowOpened() {
            guard isEnabled else { return }
            engine.play(.impact(.light, intensity: 0.6), merging: false)
        }

        /// Deliberately a different shape from `selectionChanged` — re-selecting the active
        /// section means something else, and the finger should notice without looking.
        public func reselected() {
            guard isEnabled else { return }
            engine.play(.impact(.rigid, intensity: 0.9))
        }
    }
#endif
