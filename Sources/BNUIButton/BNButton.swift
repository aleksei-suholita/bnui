#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// The kit's button: a binary action over a swappable material.
    ///
    /// The control shows and reports. It does not perform the action, hold business state, navigate,
    /// or know a word of any app's domain; the host moves it in and out of `loading`. Built on
    /// `UIControl` rather than `UIButton` because the granularity of the touch is the point — the
    /// speed of the press is carried into the return spring, the haptic contract is its own, and the
    /// disabled colour belongs to the theme rather than to the system.
    ///
    /// ```swift
    /// let button = BNButton(content: .title("Finish"), style: .primary)
    /// button.onTap = { session.finish() }
    /// ```
    ///
    /// Targets hear it as they would any `UIControl`. The action is `.primaryActionTriggered`,
    /// sent with ``onTap`` — bind to it rather than to `.touchUpInside`, because the keyboard,
    /// VoiceOver and Switch Control press the button without a touch and send the action alone.
    /// A finger's touch also sends the standard touch events, ending in exactly one of
    /// `.touchUpInside`, `.touchUpOutside` and `.touchCancel`. `.touchUpInside` comes only with
    /// the action: a lift the cooldown swallows, or one on a button that turned disabled or
    /// loading under the finger, ends as `.touchCancel`. A touch the button never accepted sends
    /// no touch events; ``onRejected`` reports the refusal.
    public final class BNButton: UIControl {
        // MARK: - Content and composition

        public var content: BNButtonContent {
            didSet {
                guard content != oldValue else { return }
                rebuild()
            }
        }

        public var style: BNButtonStyle {
            didSet {
                guard style != oldValue else { return }
                rebuild()
            }
        }

        public var size: BNButtonSize {
            didSet {
                guard size != oldValue else { return }
                rebuild()
            }
        }

        public var configuration: BNButtonConfiguration {
            didSet {
                guard configuration != oldValue else { return }
                rebuild()
            }
        }

        // MARK: - Appearance

        public var theme: BNButtonTheme {
            didSet {
                guard theme != oldValue else { return }
                if theme.requiresRebuild(comparedTo: oldValue) {
                    rebuild()
                } else {
                    // Metrics and motion are read at the moment they are used, so a changed spring
                    // must not throw away the view tree — the gallery's sliders depend on that.
                    activeTheme = resolvedTheme
                    interaction.snapWindow = activeTheme.motion.snapWindow
                    interaction.hapticMergeWindow = activeTheme.motion.hapticMergeWindow
                    interaction.cooldown = activeTheme.motion.cooldown
                    invalidateSolvedLayout()
                }
            }
        }

        /// Overrides the style's material. `nil` — the style decides, which is the usual case.
        public var material: (any BNButtonMaterial)? {
            didSet { rebuild() }
        }

        public var contentRenderer: (any BNButtonContentRenderer)? {
            didSet { rebuild() }
        }

        public var loadingIndicator: any BNButtonLoadingIndicatorFactory = BNActivityLoadingIndicator() {
            didSet {
                guard loadingIndicator.identity != oldValue.identity else { return }
                rebuild()
            }
        }

        /// Forces accessibility settings instead of reading the system. For the gallery; production
        /// leaves it alone.
        public var accessibilityOverrides: BNButtonAccessibilityOverrides {
            didSet {
                guard accessibilityOverrides != oldValue else { return }
                rebuild()
            }
        }

        public let haptics: BNButtonHaptics

        // MARK: - State (the host owns the truth)

        public var status: BNButtonStatus {
            didSet {
                guard status != oldValue else { return }
                syncEnabledFlag()
                applyState(transition: .curve(activeTheme.motion.stateChange))
                updateAccessibilityState()
            }
        }

        /// A bridge for hosts that reach for the UIKit flag.
        ///
        /// Kept as a real stored flag rather than computed from ``status``: UIKit reads this very
        /// property, and a getter that answered from `status` would look like a bridge while
        /// quietly being a switch. It no longer gates the touches either way — those arrive through
        /// `pressRecognizer`, which is what lets a disabled button still refuse a tap.
        override public var isEnabled: Bool {
            get { super.isEnabled }
            set {
                super.isEnabled = newValue
                guard statusFollowsEnabledFlag else { return }
                let target = status.settingEnabledFlag(newValue)
                if status != target {
                    status = target
                }
            }
        }

        /// Whether setting ``isEnabled`` moves ``status``. The SwiftUI face turns it off: it works
        /// the status out itself, and SwiftUI writes the flag on its own.
        var statusFollowsEnabledFlag = true

        public var isLoading: Bool {
            status == .loading
        }

        public func setStatus(_ status: BNButtonStatus, animated: Bool) {
            guard status != self.status else { return }
            pendingStatusTransition = animated ? nil : .immediate
            self.status = status
            pendingStatusTransition = nil
        }

        // MARK: - Events

        /// The finger lifted inside. Every such lift is reported; guarding against double taps is
        /// the host's job, as the contract says.
        public var onTap: (() -> Void)?
        /// The button accepted a touch. Exactly one ``onTouchUp`` or ``onTouchCancel`` follows; a
        /// touch the button does not accept — disabled, loading — reports none of the three.
        public var onTouchDown: (() -> Void)?
        /// The finger lifted: `true` inside, together with the action, `false` outside. A lift
        /// inside that does not fire ends in ``onTouchCancel`` instead, as `.touchUpInside` does.
        public var onTouchUp: ((Bool) -> Void)?
        /// The touch ended without a lift that counts: the system took it, the button turned
        /// disabled or loading under the finger, or the cooldown swallowed the lift.
        public var onTouchCancel: (() -> Void)?
        /// A touch landed on the button while it was disabled and was refused.
        ///
        /// Worth reporting rather than swallowing: the control can say "no", but only the host
        /// knows *why* — and that is usually the more useful half of the answer.
        public var onRejected: (() -> Void)?

        // MARK: - Internals shared with the extensions

        /// The theme after accessibility overrides — resolved once per rebuild so every part reads
        /// the same values.
        var activeTheme: BNButtonTheme = .standard
        var activeStyle: BNButtonStyle = .primary
        var interaction = BNButtonInteraction()
        var surface: BNButtonSurface?
        var contentView: (any BNButtonContentRendering)?
        var contentPins: BNButtonContentPins?
        var scaleAnimation: BNAnimation?
        var solvedOutput: BNButtonLayoutSolver.Output?
        var isPressedByTouch = false
        var pendingStatusTransition: BNTransition?
        var pendingEnvironmentRebuild = false
        var borderView: UIView?
        var indicatorView: (any BNButtonLoadingIndicating)?
        var rejectionOverlay: UIView?
        var rejectionAnimation: BNAnimation?
        /// The button's one source of touches. Sits on the button itself, so it hears a touch wherever
        /// in the hit area it lands — inside the material or in the margin around it. See
        /// ``BNButtonPressRecognizer``.
        let pressRecognizer = BNButtonPressRecognizer(target: nil, action: nil)
        static let rejectionAnimationKey = "bn.button.rejection"
        /// One touch is one refusal, however many phases report it.
        var lastRejectionTime: CFTimeInterval = 0
        static let rejectionDebounce: CFTimeInterval = 0.2

        /// Draws the outline of the touch area.
        ///
        /// Not gated behind `DEBUG`: the checklist item "44 × 44 confirmed on a visually smaller
        /// icon button" has to be verifiable in whatever build is on the device, and a debug-only
        /// switch inside a library depends on how the *library* was compiled rather than the app.
        public var showsHitTargetOutline = false {
            didSet {
                guard showsHitTargetOutline != oldValue else { return }
                setNeedsLayout()
            }
        }

        var hitOverlay: CAShapeLayer?
        var focusRing: CAShapeLayer?

        // MARK: - Init

        public init(
            content: BNButtonContent,
            style: BNButtonStyle = .primary,
            size: BNButtonSize = .medium,
            configuration: BNButtonConfiguration = BNButtonConfiguration(),
            theme: BNButtonTheme = .standard,
            material: (any BNButtonMaterial)? = nil,
            haptics: BNButtonHaptics = BNButtonHaptics(),
            accessibilityOverrides: BNButtonAccessibilityOverrides = .none,
        ) {
            self.content = content
            self.style = style
            self.size = size
            self.configuration = configuration
            self.theme = theme
            self.material = material
            self.haptics = haptics
            self.accessibilityOverrides = accessibilityOverrides
            status = .enabled
            super.init(frame: .zero)
            observeEnvironment()
            installPressRecognizer()
            rebuild()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func syncEnabledFlag() {
            let shouldBeEnabled = status != .disabled
            if isEnabled != shouldBeEnabled {
                isEnabled = shouldBeEnabled
            }
        }

        // MARK: - UIKit overrides

        //
        // Overrides live in the class rather than in the extensions because Swift does not allow
        // them in one. Each is a thin call into the file that owns the behaviour.

        override public var intrinsicContentSize: CGSize {
            solvedIntrinsicSize
        }

        override public func traitCollectionDidChange(_ previous: UITraitCollection?) {
            super.traitCollectionDidChange(previous)
            guard #unavailable(iOS 17.0) else { return }
            legacyTraitsDidChange(from: previous)
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            refreshSolvedLayout()
            updateFocusEffect()
            updateHitOverlay()
        }

        override public var canBecomeFocused: Bool {
            status.allowsInteraction
        }

        override public func didUpdateFocus(
            in context: UIFocusUpdateContext,
            with coordinator: UIFocusAnimationCoordinator,
        ) {
            super.didUpdateFocus(in: context, with: coordinator)
            // Riding the system coordinator rather than a timer of our own: focus moves together
            // with the rest of the screen, and a ring on its own schedule lags behind it.
            coordinator.addCoordinatedAnimations { [weak self] in
                guard let self else { return }
                applyState(transition: .curve(activeTheme.motion.focus))
                updateFocusEffect()
            }
        }

        override public func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if handlesActivation(presses) {
                applyKeyPress(true)
            }
            super.pressesBegan(presses, with: event)
        }

        override public func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if handlesActivation(presses) {
                applyKeyPress(false)
            }
            super.pressesEnded(presses, with: event)
        }

        override public func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if handlesActivation(presses) {
                applyKeyPress(false)
            }
            super.pressesCancelled(presses, with: event)
        }

        override public func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
            hitRect.contains(point)
        }

        /// Keeps the button in the hit-test even when it is disabled.
        ///
        /// `UIControl` drops itself out of hit-testing once `isEnabled` is false, which takes its
        /// gesture recognizers down with it — so a disabled button cannot hear the touch it is
        /// supposed to refuse. Interactive subviews still get first refusal, because that is how
        /// system glass lights up under the finger; everything else lands on the control.
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
            guard self.point(inside: point, with: event) else { return nil }

            for subview in subviews.reversed() {
                let converted = convert(point, to: subview)
                if let hit = subview.hitTest(converted, with: event) {
                    return hit
                }
            }
            return self
        }

        /// Tracking is declined on purpose: every touch arrives through `pressRecognizer` instead.
        /// Tracking starts only for a touch that lands on the button itself — the margin the hit area
        /// adds — and accepting it there would run the whole state machine twice for one finger.
        /// The touch events tracking would have sent come from the recognizer's phases instead.
        override public func beginTracking(_: UITouch, with _: UIEvent?) -> Bool {
            false
        }

        /// Fires the action without a finger. `UIControl` declares this for the keyboard and
        /// Switch Control; the button routes it through the same state machine a touch uses, so a
        /// keyboard press cannot take a different path than a tap.
        override public func performPrimaryAction() {
            firePrimaryAction()
        }

        override public func accessibilityActivate() -> Bool {
            firePrimaryAction()
            return true
        }
    }
#endif
