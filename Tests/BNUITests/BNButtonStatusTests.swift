@testable import BNUIButton
import Testing

@Suite("BNButtonStatus")
struct BNButtonStatusTests {
    @Test
    func `only an enabled button reacts to a finger`() {
        #expect(BNButtonStatus.enabled.allowsInteraction)
        #expect(!BNButtonStatus.disabled.allowsInteraction)
        #expect(!BNButtonStatus.loading.allowsInteraction)
    }

    @Test
    func `a loading button stays reachable to VoiceOver, a disabled one does not`() {
        // Loading reports itself busy; hiding it would make the action vanish mid-way.
        #expect(BNButtonStatus.enabled.isAccessibilityEnabled)
        #expect(BNButtonStatus.loading.isAccessibilityEnabled)
        #expect(!BNButtonStatus.disabled.isAccessibilityEnabled)
    }
}

@Suite("BNButtonAccessibility")
struct BNButtonAccessibilityTests {
    @Test
    func `an override left empty reads the system`() {
        let overrides = BNButtonAccessibilityOverrides.none
        #expect(overrides.resolvedReduceMotion(system: true))
        #expect(!overrides.resolvedReduceMotion(system: false))
        #expect(overrides.resolvedReduceTransparency(system: true))
        #expect(!overrides.resolvedReduceTransparency(system: false))
    }

    @Test
    func `a forced override wins over the system`() {
        let overrides = BNButtonAccessibilityOverrides(reduceMotion: false, reduceTransparency: true)
        #expect(!overrides.resolvedReduceMotion(system: true))
        #expect(overrides.resolvedReduceTransparency(system: false))
    }

    @Test
    func `the standard words leave the disabled hint to the system`() {
        let strings = BNButtonAccessibilityStrings.standard
        #expect(!strings.busyValue.isEmpty)
        #expect(strings.disabledHint == nil)
    }
}

@Suite("BNButtonConfiguration")
struct BNButtonConfigurationTests {
    @Test
    func `the default keeps room for the spinner`() {
        // Without the reserved room, entering `loading` would jolt the width.
        let configuration = BNButtonConfiguration()
        #expect(configuration.reservesSpaceForLoading)
        #expect(configuration.stacksVerticallyAtAccessibilitySizes)
        #expect(configuration.width == .hug)
        #expect(configuration.alignment == .center)
        #expect(configuration.titleBehavior == .truncate)
        #expect(configuration.accessibility == .standard)
    }

    @Test(arguments: [
        (BNButtonConfiguration.TitleBehavior.truncate, 1),
        (.wrap(lines: 3), 3),
        (.wrap(lines: 0), 0),
        (.wrap(lines: -2), 0),
    ])
    func `a title behaviour hands the label its line count`(
        behavior: BNButtonConfiguration.TitleBehavior,
        lines: Int,
    ) {
        #expect(behavior.numberOfLines == lines)
    }
}
