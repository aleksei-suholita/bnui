@testable import BNUICore
import Testing

/// Results are taken into locals before `#expect` sees them: the macro rewrites the expression it
/// is given into a closure, and a closure cannot call a mutating method on the gate.
@Suite("BNHapticGate")
struct BNHapticGateTests {
    @Test
    func `the first impulse always lands`() {
        var gate = BNHapticGate(window: 0.15)
        let played = gate.shouldPlay(at: 0)
        #expect(played)
    }

    @Test
    func `a second impulse inside the window is swallowed`() {
        // The rule the engine exists for: a button refusing a touch and the toast that explains why
        // are one event to the finger, however many controls produced them.
        var gate = BNHapticGate(window: 0.15)
        let first = gate.shouldPlay(at: 0)
        let second = gate.shouldPlay(at: 0.1)
        #expect(first)
        #expect(!second)
    }

    @Test
    func `past the window it lands again`() {
        var gate = BNHapticGate(window: 0.15)
        let first = gate.shouldPlay(at: 0)
        let later = gate.shouldPlay(at: 0.15)
        #expect(first)
        #expect(later)
    }

    @Test
    func `a swallowed impulse does not push the silence forward`() {
        // Otherwise a burst of suppressed calls would keep extending the window and the next real
        // event would never be felt at all.
        var gate = BNHapticGate(window: 0.15)
        let first = gate.shouldPlay(at: 0)
        let swallowed = [gate.shouldPlay(at: 0.05), gate.shouldPlay(at: 0.10)]
        let next = gate.shouldPlay(at: 0.15)
        #expect(first)
        #expect(swallowed == [false, false])
        #expect(next)
    }

    @Test
    func `continuous feedback is never swallowed`() {
        // Crossing tab bar sections, snapping card after card: there the stream is the report of
        // where the finger is, and dropping every second tick makes the gesture lie.
        var gate = BNHapticGate(window: 0.15)
        let stream = [
            gate.shouldPlay(at: 0, merging: false),
            gate.shouldPlay(at: 0.01, merging: false),
            gate.shouldPlay(at: 0.02, merging: false),
        ]
        #expect(stream == [true, true, true])
    }

    @Test
    func `a continuous tick still marks the clock`() {
        // A single event landing right behind the stream — a boundary crossed, then the commit on
        // release — must not double up on it.
        var gate = BNHapticGate(window: 0.15)
        let crossing = gate.shouldPlay(at: 0, merging: false)
        let commit = gate.shouldPlay(at: 0.02)
        #expect(crossing)
        #expect(!commit)
    }

    @Test
    func `a window of zero merges nothing`() {
        var gate = BNHapticGate(window: 0)
        let first = gate.shouldPlay(at: 0)
        let second = gate.shouldPlay(at: 0)
        #expect(first)
        #expect(second)
    }
}
