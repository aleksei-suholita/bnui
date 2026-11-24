#if canImport(UIKit)
    import BNUICore
    import SwiftUI
    import UIKit

    public extension BN {
        /// ``BNButton`` in a SwiftUI hierarchy.
        ///
        /// The same control, not a lookalike: the press physics, the haptic contract and the refusal
        /// of a disabled tap all come from the UIKit button underneath, which is the reason the kit is
        /// UIKit-first in the first place.
        ///
        /// ```swift
        /// BN.Button("Pay", isLoading: isPaying) { pay() }
        ///     .bnButtonStyle(.primary)
        ///     .onRejected { showWhyNot() }
        /// ```
        ///
        /// The initializer takes what the button is — its label and action — and whether it is
        /// busy. How it looks comes from modifiers, which reach every button beneath them:
        ///
        /// ```swift
        /// Form { … }
        ///     .bnButtonStyle(.secondary)
        ///     .bnButtonWidth(.fill)
        ///     .controlSize(.large)
        /// ```
        ///
        /// Disabled two ways. ``SwiftUICore/View/bnButtonDisabled(_:)`` is the kit's: a tap is
        /// refused — a flash, a shake, ``BNButton/onRejected``. SwiftUI's `.disabled()` lets no touch
        /// through, so the button stays silent under it, as a system one would. `isLoading` wins
        /// over both: a form disabled while it submits keeps the spinner on the button submitting
        /// it. `.controlSize` picks the button's step of the size scale.
        ///
        /// Sized by the button's own layout solver: it hugs its content, or takes the offered width
        /// for ``BNButtonWidth/fill``, and its height grows with Dynamic Type and wrapped titles.
        ///
        /// New content changed inside an animation — `withAnimation`, `.animation(_:value:)` —
        /// goes on the kit's springs in the ``SwiftUICore/View/bnButtonContentTransition(_:)``
        /// style, a blur unless one is set; changed outside one, it is shown at once, as a `Text`
        /// would be. The frame follows the new size the way SwiftUI lays it out, and the outline
        /// moves to it on the kit's spring. A new style changes the colours on the theme's
        /// state-change curve; a press under way carries on.
        struct Button: UIViewRepresentable {
            let content: BNButtonContent
            let isLoading: Bool
            let action: () -> Void
            var adjustments: [(inout BNButtonEnvironment) -> Void] = []
            var badge: BNBadge?

            var onTouchDown: (() -> Void)?
            var onTouchUp: ((Bool) -> Void)?
            var onTouchCancel: (() -> Void)?
            var onRejected: (() -> Void)?

            /// A button with a title.
            ///
            /// - Parameters:
            ///   - title: what the button says.
            ///   - isLoading: busy — the title gives way to a spinner and taps are swallowed.
            ///   - action: what a tap does.
            public init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
                self.init(.title(title), isLoading: isLoading, action: action)
            }

            /// A button with a title and an SF Symbol before it.
            ///
            /// - Parameters:
            ///   - title: what the button says.
            ///   - systemImage: the symbol's name.
            ///   - isLoading: busy — the content gives way to a spinner and taps are swallowed.
            ///   - action: what a tap does.
            public init(_ title: String, systemImage: String, isLoading: Bool = false, action: @escaping () -> Void) {
                self.init(
                    BNButtonContent(title: title, leadingIcon: .symbol(systemImage)),
                    isLoading: isLoading,
                    action: action,
                )
            }

            /// A button with any content the kit draws: an icon alone, icons on both sides.
            ///
            /// - Parameters:
            ///   - content: what the button shows.
            ///   - isLoading: busy — the content gives way to a spinner and taps are swallowed.
            ///   - action: what a tap does.
            public init(_ content: BNButtonContent, isLoading: Bool = false, action: @escaping () -> Void) {
                self.content = content
                self.isLoading = isLoading
                self.action = action
            }

            // MARK: - Badge

            /// A badge with a count: zero or less shows none, and past the theme's limit it reads
            /// "99+". See ``BNButton/badge``.
            public func badge(_ count: Int) -> Self {
                badge(.count(count))
            }

            /// A badge with a short word or sign — "New", "!".
            public func badge(_ text: String) -> Self {
                badge(.text(text))
            }

            /// Any badge — a dot, or a count or text with its own words for VoiceOver. `nil` shows
            /// none.
            public func badge(_ badge: BNBadge?) -> Self {
                var copy = self
                copy.badge = badge
                return copy
            }

            // MARK: - Events

            /// A touch landed while the button was disabled and was refused — the moment to tell the
            /// user why. See ``BNButton/onRejected``.
            public func onRejected(_ handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.onRejected = handler
                return copy
            }

            /// The button accepted a touch; exactly one `onTouchUp` or `onTouchCancel` follows. See
            /// ``BNButton/onTouchDown``.
            public func onTouchDown(_ handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.onTouchDown = handler
                return copy
            }

            /// The finger lifted: `true` inside, together with the action, `false` outside. See
            /// ``BNButton/onTouchUp``.
            public func onTouchUp(_ handler: @escaping (Bool) -> Void) -> Self {
                var copy = self
                copy.onTouchUp = handler
                return copy
            }

            /// The touch ended without a lift that counts. See ``BNButton/onTouchCancel``.
            public func onTouchCancel(_ handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.onTouchCancel = handler
                return copy
            }

            /// Records a modifier set on this button itself: it is applied over the environment.
            func adjusting(_ adjustment: @escaping (inout BNButtonEnvironment) -> Void) -> Self {
                var copy = self
                copy.adjustments.append(adjustment)
                return copy
            }

            // MARK: - UIViewRepresentable

            public func makeUIView(context: Context) -> BNButton {
                let settings = settings(in: context.environment)
                let button = BNButton(
                    content: content,
                    style: settings.style ?? .primary,
                    size: size(settings, in: context.environment),
                    configuration: settings.configuration,
                    theme: settings.theme ?? .standard,
                    material: settings.material,
                    haptics: settings.haptics ?? BNButtonHaptics(),
                )
                button.contentTransition = settings.contentTransition ?? .blur
                button.contentTransitionDuration = settings.contentTransitionDuration
                // The frame is SwiftUI's: it lays the button out from `sizeThatFits`, and a button
                // laying out the hosting controller's view itself would fight it.
                button.animatesSizeChanges = false
                // SwiftUI writes `isEnabled` on a wrapped control from its own `.disabled()` alone —
                // on the gallery stand that write took a busy button's spinner away. The face counts
                // SwiftUI's flag in already, so the write is kept off the status: it must undo
                // neither a disabled set by `bnButtonDisabled` nor a spinner.
                button.statusFollowsEnabledFlag = false
                // A button that appears already loading appears that way; it does not animate into it.
                button.setStatus(status(settings, in: context.environment), animated: false)
                button.badge = badge
                wire(button)
                return button
            }

            public func updateUIView(_ button: BNButton, context: Context) {
                let settings = settings(in: context.environment)
                // Each of these setters compares before it rebuilds, so re-assigning an unchanged value
                // on every SwiftUI update costs nothing.
                button.style = settings.style ?? .primary
                button.size = size(settings, in: context.environment)
                button.configuration = settings.configuration
                button.theme = settings.theme ?? .standard
                // The material setter rebuilds unconditionally, and a protocol value cannot be
                // compared — hence the identity.
                if button.material?.identity != settings.material?.identity {
                    button.material = settings.material
                }
                // After the looks, whose rebuilds would cut a content change short. SwiftUI decides
                // whether the change is animated, as it does for a `Text`: inside an animation it is,
                // on the kit's own springs and in the button's transition; outside one it is at once.
                button.contentTransition = settings.contentTransition ?? .blur
                button.contentTransitionDuration = settings.contentTransitionDuration
                button.setContent(
                    content,
                    animated: context.transaction.animation != nil && !context.transaction.disablesAnimations,
                )
                // The kit's own state-change curve carries the change; SwiftUI only decides whether
                // there is one at all.
                button.setStatus(
                    status(settings, in: context.environment),
                    animated: !context.transaction.disablesAnimations,
                )
                button.badge = badge
                wire(button)
            }

            public func sizeThatFits(_ proposal: ProposedViewSize, uiView button: BNButton, context _: Context) -> CGSize? {
                let offered = proposal.width.flatMap { $0.isFinite ? $0 : nil }
                if button.configuration.width == .fill, offered == nil {
                    // A full-width button asked for its ideal width has no answer of its own; SwiftUI's
                    // default, which reads the intrinsic size, is as good as any.
                    return nil
                }
                // Zero is the solver's "unbounded": a title measured against nothing stays on one line.
                let output = button.solveLayout(availableWidth: offered ?? 0)
                return CGSize(width: output.buttonWidth, height: output.buttonHeight)
            }

            // MARK: - Internals

            /// The environment's settings with this button's own laid over them.
            private func settings(in environment: EnvironmentValues) -> BNButtonEnvironment {
                var settings = environment.bnButton
                for adjustment in adjustments {
                    adjustment(&settings)
                }
                return settings
            }

            private func size(_ settings: BNButtonEnvironment, in environment: EnvironmentValues) -> BNButtonSize {
                settings.size ?? BNButtonSize(environment.controlSize)
            }

            /// Disabled by SwiftUI's `.disabled()` or by the kit's `bnButtonDisabled`; busy wins over
            /// both.
            private func status(_ settings: BNButtonEnvironment, in environment: EnvironmentValues) -> BNButtonStatus {
                .resolving(isLoading: isLoading, isEnabled: environment.isEnabled && !settings.isDisabled)
            }

            /// Re-wired on every update: the closures capture the view's current values, and yesterday's
            /// closure would call yesterday's action.
            private func wire(_ button: BNButton) {
                button.onTap = action
                button.onTouchDown = onTouchDown
                button.onTouchUp = onTouchUp
                button.onTouchCancel = onTouchCancel
                button.onRejected = onRejected
            }
        }
    }
#endif
