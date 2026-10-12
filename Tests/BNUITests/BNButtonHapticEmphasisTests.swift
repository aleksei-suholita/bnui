@testable import BNUIButton
import Testing

@Suite("BNButtonHapticEmphasis")
struct BNButtonHapticEmphasisTests {
    @Test
    func `a silent style mutes the press and the confirmation`() {
        #expect(BNButtonHapticEmphasis.silent.heard(.press) == .silent)
        #expect(BNButtonHapticEmphasis.silent.heard(.trigger) == .silent)
    }

    @Test
    func `a silent style leaves the refusal to the theme`() {
        // The refusal answers "no" to a disabled button; whether it buzzes is the theme's switch,
        // the same for every style.
        #expect(BNButtonHapticEmphasis.silent.heard(.rejected) == .rejected)
    }

    @Test(arguments: [BNButtonHapticEmphasis.standard, .pronounced])
    func `an audible style passes every event through`(emphasis: BNButtonHapticEmphasis) {
        for event in [BNButtonHapticEvent.press, .trigger, .rejected, .silent] {
            #expect(emphasis.heard(event) == event)
        }
    }
}
