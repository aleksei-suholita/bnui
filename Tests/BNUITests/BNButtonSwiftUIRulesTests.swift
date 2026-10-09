@testable import BNUIButton
import SwiftUI
import Testing

@Suite("BN.Button rules")
struct BNButtonSwiftUIRulesTests {
    @Test
    func `the two signals add up to one status`() {
        #expect(BNButtonStatus.resolving(isLoading: false, isEnabled: true) == .enabled)
        #expect(BNButtonStatus.resolving(isLoading: false, isEnabled: false) == .disabled)
        #expect(BNButtonStatus.resolving(isLoading: true, isEnabled: true) == .loading)
    }

    @Test
    func `busy wins over disabled`() {
        // A form disabled while it submits must not take the spinner from the button submitting it.
        #expect(BNButtonStatus.resolving(isLoading: true, isEnabled: false) == .loading)
    }

    @Test
    func `the enabled flag moves a button between enabled and disabled`() {
        #expect(BNButtonStatus.enabled.settingEnabledFlag(false) == .disabled)
        #expect(BNButtonStatus.disabled.settingEnabledFlag(true) == .enabled)
    }

    @Test
    func `the enabled flag never ends loading`() {
        // SwiftUI sets the flag on a wrapped control under `.disabled()`; busy must still win.
        #expect(BNButtonStatus.loading.settingEnabledFlag(false) == .loading)
        #expect(BNButtonStatus.loading.settingEnabledFlag(true) == .loading)
    }

    @Test
    func `control sizes fold onto the three steps`() {
        #expect(BNButtonSize(ControlSize.mini) == .small)
        #expect(BNButtonSize(ControlSize.small) == .small)
        #expect(BNButtonSize(ControlSize.regular) == .medium)
        #expect(BNButtonSize(ControlSize.large) == .large)
        #expect(BNButtonSize(ControlSize.extraLarge) == .large)
    }
}
