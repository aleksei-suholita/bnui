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
        /// BN.Button(.title("Finish"), style: .primary, status: isSaving ? .loading : .enabled) {
        ///     session.finish()
        /// }
        /// .onRejected { showWhyNot() }
        /// ```
        ///
        /// The host still owns the status. `.disabled(true)` above the button counts as `.disabled`,
        /// so a SwiftUI form that disables its controls wholesale disables this one too.
        ///
        /// Sized by the button's own layout solver: it hugs its content, or takes the offered width
        /// for ``BNButtonWidth/fill``, and its height grows with Dynamic Type and wrapped titles.
        struct Button: UIViewRepresentable {
            public var content: BNButtonContent
            public var style: BNButtonStyle
            public var size: BNButtonSize
            public var configuration: BNButtonConfiguration
            public var theme: BNButtonTheme
            /// Overrides the style's material. Compared by identity, so a new instance of the same
            /// material does not rebuild the button.
            public var material: (any BNButtonMaterial)?
            public var status: BNButtonStatus
            /// Read once, when the button is made — the UIKit button holds its haptics for life.
            public var haptics: BNButtonHaptics
            public var action: () -> Void

            var onTouchDown: (() -> Void)?
            var onTouchUp: ((Bool) -> Void)?
            var onRejected: (() -> Void)?

            public init(
                _ content: BNButtonContent,
                style: BNButtonStyle = .primary,
                size: BNButtonSize = .medium,
                configuration: BNButtonConfiguration = BNButtonConfiguration(),
                theme: BNButtonTheme = .standard,
                material: (any BNButtonMaterial)? = nil,
                status: BNButtonStatus = .enabled,
                haptics: BNButtonHaptics = BNButtonHaptics(),
                action: @escaping () -> Void,
            ) {
                self.content = content
                self.style = style
                self.size = size
                self.configuration = configuration
                self.theme = theme
                self.material = material
                self.status = status
                self.haptics = haptics
                self.action = action
            }

            // MARK: - Events

            /// A touch landed while the button was disabled and was refused — the moment to tell the
            /// user why. See ``BNButton/onRejected``.
            public func onRejected(_ handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.onRejected = handler
                return copy
            }

            public func onTouchDown(_ handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.onTouchDown = handler
                return copy
            }

            /// `true` when the finger lifted inside the touch area.
            public func onTouchUp(_ handler: @escaping (Bool) -> Void) -> Self {
                var copy = self
                copy.onTouchUp = handler
                return copy
            }

            // MARK: - UIViewRepresentable

            public func makeUIView(context: Context) -> BNButton {
                let button = BNButton(
                    content: content,
                    style: style,
                    size: size,
                    configuration: configuration,
                    theme: theme,
                    material: material,
                    haptics: haptics,
                )
                // A button that appears already loading appears that way; it does not animate into it.
                button.setStatus(resolvedStatus(in: context.environment), animated: false)
                wire(button)
                return button
            }

            public func updateUIView(_ button: BNButton, context: Context) {
                // Each of these setters compares before it rebuilds, so re-assigning an unchanged value
                // on every SwiftUI update costs nothing.
                button.content = content
                button.style = style
                button.size = size
                button.configuration = configuration
                button.theme = theme
                // The material setter rebuilds unconditionally, and a protocol value cannot be
                // compared — hence the identity.
                if button.material?.identity != material?.identity {
                    button.material = material
                }
                // The kit's own state-change curve carries the change; SwiftUI only decides whether
                // there is one at all.
                button.setStatus(
                    resolvedStatus(in: context.environment),
                    animated: !context.transaction.disablesAnimations,
                )
                wire(button)
            }

            public func sizeThatFits(_ proposal: ProposedViewSize, uiView button: BNButton, context _: Context) -> CGSize? {
                let offered = proposal.width.flatMap { $0.isFinite ? $0 : nil }
                if configuration.width == .fill, offered == nil {
                    // A full-width button asked for its ideal width has no answer of its own; SwiftUI's
                    // default, which reads the intrinsic size, is as good as any.
                    return nil
                }
                // Zero is the solver's "unbounded": a title measured against nothing stays on one line.
                let output = button.solveLayout(availableWidth: offered ?? 0)
                return CGSize(width: output.buttonWidth, height: output.buttonHeight)
            }

            // MARK: - Internals

            private func resolvedStatus(in environment: EnvironmentValues) -> BNButtonStatus {
                environment.isEnabled ? status : .disabled
            }

            /// Re-wired on every update: the closures capture the view's current values, and yesterday's
            /// closure would call yesterday's action.
            private func wire(_ button: BNButton) {
                button.onTap = action
                button.onTouchDown = onTouchDown
                button.onTouchUp = onTouchUp
                button.onRejected = onRejected
            }
        }
    }
#endif
