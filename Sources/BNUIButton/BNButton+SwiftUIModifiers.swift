#if canImport(UIKit)
    import BNUICore
    import SwiftUI
    import UIKit

    /// What the `bnButton…` modifiers have set for the buttons beneath them.
    ///
    /// Every field is optional: unset means the button's own default. A modifier nearer the
    /// button writes over a farther one, the way SwiftUI's own environment does, and one applied
    /// to ``BN/Button`` itself writes over both.
    nonisolated struct BNButtonEnvironment {
        var style: BNButtonStyle?
        var size: BNButtonSize?
        var theme: BNButtonTheme?
        var material: (any BNButtonMaterial)?
        var haptics: BNButtonHaptics?
        var width: BNButtonWidth?
        var alignment: BNButtonAlignment?
        var titleBehavior: BNButtonConfiguration.TitleBehavior?
        var reservesSpaceForLoading: Bool?
        var stacksVerticallyAtAccessibilitySizes: Bool?
        var accessibilityStrings: BNButtonAccessibilityStrings?
        /// Set by `bnButtonDisabled` anywhere above. Once true it stays true below, as SwiftUI's
        /// own `.disabled()` does: a form disabled as a whole cannot be re-enabled from inside.
        var isDisabled = false

        /// The configuration the fields add up to, field by field over the kit's defaults.
        var configuration: BNButtonConfiguration {
            let defaults = BNButtonConfiguration()
            return BNButtonConfiguration(
                width: width ?? defaults.width,
                alignment: alignment ?? defaults.alignment,
                titleBehavior: titleBehavior ?? defaults.titleBehavior,
                reservesSpaceForLoading: reservesSpaceForLoading ?? defaults.reservesSpaceForLoading,
                stacksVerticallyAtAccessibilitySizes: stacksVerticallyAtAccessibilitySizes
                    ?? defaults.stacksVerticallyAtAccessibilitySizes,
                accessibility: accessibilityStrings ?? defaults.accessibility,
            )
        }
    }

    private nonisolated struct BNButtonEnvironmentKey: EnvironmentKey {
        static var defaultValue: BNButtonEnvironment {
            BNButtonEnvironment()
        }
    }

    extension EnvironmentValues {
        nonisolated var bnButton: BNButtonEnvironment {
            get { self[BNButtonEnvironmentKey.self] }
            set { self[BNButtonEnvironmentKey.self] = newValue }
        }
    }

    // MARK: - On any view: every button beneath

    public extension View {
        /// The style of every ``BN/Button`` beneath: `primary`, `secondary`, `ghost`,
        /// `destructive`, or one of the host's own.
        func bnButtonStyle(_ style: BNButtonStyle) -> some View {
            transformEnvironment(\.bnButton) { $0.style = style }
        }

        /// A step of the size scale for every ``BN/Button`` beneath. Without one, a button takes
        /// its step from SwiftUI's `.controlSize`.
        func bnButtonSize(_ size: BNButtonSize) -> some View {
            transformEnvironment(\.bnButton) { $0.size = size }
        }

        /// The theme of every ``BN/Button`` beneath — once, at the root, is the usual place.
        func bnButtonTheme(_ theme: BNButtonTheme) -> some View {
            transformEnvironment(\.bnButton) { $0.theme = theme }
        }

        /// A material over the style's own for every ``BN/Button`` beneath.
        func bnButtonMaterial(_ material: any BNButtonMaterial) -> some View {
            transformEnvironment(\.bnButton) { $0.material = material }
        }

        /// The haptics of every ``BN/Button`` beneath. Read once, when a button is made: the UIKit
        /// button holds its haptics for life.
        func bnButtonHaptics(_ haptics: BNButtonHaptics) -> some View {
            transformEnvironment(\.bnButton) { $0.haptics = haptics }
        }

        /// How wide every ``BN/Button`` beneath is: hugging its content, filling the offered
        /// width, or fixed.
        func bnButtonWidth(_ width: BNButtonWidth) -> some View {
            transformEnvironment(\.bnButton) { $0.width = width }
        }

        /// Where the content of every ``BN/Button`` beneath sits once the button is wider than it.
        func bnButtonAlignment(_ alignment: BNButtonAlignment) -> some View {
            transformEnvironment(\.bnButton) { $0.alignment = alignment }
        }

        /// What a title too long for one line does in every ``BN/Button`` beneath: truncate, or
        /// wrap onto more lines.
        func bnButtonTitleBehavior(_ behavior: BNButtonConfiguration.TitleBehavior) -> some View {
            transformEnvironment(\.bnButton) { $0.titleBehavior = behavior }
        }

        /// Whether every ``BN/Button`` beneath keeps room for its spinner, so that `isLoading`
        /// does not change its width.
        func bnButtonReservesSpaceForLoading(_ reserves: Bool) -> some View {
            transformEnvironment(\.bnButton) { $0.reservesSpaceForLoading = reserves }
        }

        /// Whether an icon and a title restack vertically at accessibility sizes in every
        /// ``BN/Button`` beneath.
        func bnButtonStacksVerticallyAtAccessibilitySizes(_ stacks: Bool) -> some View {
            transformEnvironment(\.bnButton) { $0.stacksVerticallyAtAccessibilitySizes = stacks }
        }

        /// The words VoiceOver says for every ``BN/Button`` beneath — "busy", in the app's
        /// language.
        func bnButtonAccessibilityStrings(_ strings: BNButtonAccessibilityStrings) -> some View {
            transformEnvironment(\.bnButton) { $0.accessibilityStrings = strings }
        }

        /// Disables every ``BN/Button`` beneath, the kit's way: a tap is refused — a flash, a
        /// shake, ``BNButton/onRejected`` — instead of falling silent.
        ///
        /// SwiftUI's `.disabled()` disables a button too, but lets no touch reach it, so the
        /// button cannot answer one; it also disables every other control beneath. This reaches
        /// the kit's buttons alone, and a text field beside them stays editable. Once disabled
        /// above, a button is not enabled again from below. `isLoading` wins over both.
        func bnButtonDisabled(_ disabled: Bool) -> some View {
            transformEnvironment(\.bnButton) { $0.isDisabled = $0.isDisabled || disabled }
        }
    }

    // MARK: - On the button: this one alone

    /// The same modifiers again, returning the button itself, so that they and the events can
    /// come in any order — `Text.font` beside `View.font` is SwiftUI's own example. Set here, a
    /// value wins over the environment.
    public extension BN.Button {
        /// This button's style, over any `bnButtonStyle` above it.
        func bnButtonStyle(_ style: BNButtonStyle) -> Self {
            adjusting { $0.style = style }
        }

        /// This button's step of the size scale, over any `bnButtonSize` or `.controlSize` above it.
        func bnButtonSize(_ size: BNButtonSize) -> Self {
            adjusting { $0.size = size }
        }

        /// This button's theme, over any `bnButtonTheme` above it.
        func bnButtonTheme(_ theme: BNButtonTheme) -> Self {
            adjusting { $0.theme = theme }
        }

        /// This button's material, over the style's own and any `bnButtonMaterial` above it.
        func bnButtonMaterial(_ material: any BNButtonMaterial) -> Self {
            adjusting { $0.material = material }
        }

        /// This button's haptics, over any `bnButtonHaptics` above it. Read once, when the button
        /// is made.
        func bnButtonHaptics(_ haptics: BNButtonHaptics) -> Self {
            adjusting { $0.haptics = haptics }
        }

        /// This button's width, over any `bnButtonWidth` above it.
        func bnButtonWidth(_ width: BNButtonWidth) -> Self {
            adjusting { $0.width = width }
        }

        /// Where this button's content sits, over any `bnButtonAlignment` above it.
        func bnButtonAlignment(_ alignment: BNButtonAlignment) -> Self {
            adjusting { $0.alignment = alignment }
        }

        /// What this button's long title does, over any `bnButtonTitleBehavior` above it.
        func bnButtonTitleBehavior(_ behavior: BNButtonConfiguration.TitleBehavior) -> Self {
            adjusting { $0.titleBehavior = behavior }
        }

        /// Whether this button keeps room for its spinner, over any modifier of the same name above.
        func bnButtonReservesSpaceForLoading(_ reserves: Bool) -> Self {
            adjusting { $0.reservesSpaceForLoading = reserves }
        }

        /// Whether this button restacks at accessibility sizes, over any modifier of the same name
        /// above.
        func bnButtonStacksVerticallyAtAccessibilitySizes(_ stacks: Bool) -> Self {
            adjusting { $0.stacksVerticallyAtAccessibilitySizes = stacks }
        }

        /// The words VoiceOver says for this button, over any `bnButtonAccessibilityStrings` above.
        func bnButtonAccessibilityStrings(_ strings: BNButtonAccessibilityStrings) -> Self {
            adjusting { $0.accessibilityStrings = strings }
        }

        /// Disables this button the kit's way, refusing a tap rather than ignoring it. A
        /// `bnButtonDisabled(true)` above still wins.
        func bnButtonDisabled(_ disabled: Bool) -> Self {
            adjusting { $0.isDisabled = $0.isDisabled || disabled }
        }
    }
#endif
