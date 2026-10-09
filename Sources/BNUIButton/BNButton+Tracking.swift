#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        // MARK: - Touch area

        /// The visual bounds grown to the platform minimum.
        ///
        /// The frame is left alone on purpose: growing it would push the neighbours around, while a
        /// wider `point(inside:)` only widens what a finger can reach. `UIControl` computes
        /// `isTouchInside` through this same method, so drag-to-cancel respects the grown area for
        /// free.
        var hitRect: CGRect {
            let outsets = activeTheme.geometry.hitOutsets(forVisualSize: bounds.size)
            return bounds.inset(by: UIEdgeInsets(
                top: -outsets.top,
                left: -outsets.leading,
                bottom: -outsets.bottom,
                right: -outsets.trailing,
            ))
        }

        /// The area used while a finger is already down — slightly more forgiving than the hit area,
        /// so a tremor at the edge does not read as the button refusing the tap.
        private var trackingRect: CGRect {
            hitRect.insetBy(dx: -activeTheme.geometry.dragHysteresis, dy: -activeTheme.geometry.dragHysteresis)
        }

        func containsTouch(_ point: CGPoint) -> Bool {
            trackingRect.contains(point)
        }

        // MARK: - Touch phases

        func handleTouchDown(tapCount: Int) {
            haptics.prepare()
            let outcome = interaction.handle(.down(at: CACurrentMediaTime()), status: status)
            // The press has to be on screen in the first frame, so it rides the press spring
            // immediately rather than waiting for anything else to settle.
            apply(outcome, transition: .spring(activeTheme.motion.press))
            reportTouch(outcome.controlEvents, tapCount: tapCount)
        }

        func handleTouchMoved(inside: Bool) {
            let wasPressed = isPressedByTouch
            let outcome = interaction.handle(.moved(inside: inside), status: status)
            if outcome.isPressed != wasPressed {
                // Leaving is not a click, so the return here is the calm one; coming back
                // re-presses.
                let transition: BNTransition = outcome.isPressed
                    ? .spring(activeTheme.motion.press)
                    : .spring(activeTheme.motion.releaseSlow)
                apply(outcome, transition: transition)
            }
            reportTouch(outcome.controlEvents)
        }

        func handleTouchUp(inside: Bool) {
            let outcome = interaction.handle(.up(inside: inside, at: CACurrentMediaTime()), status: status)
            // The reward for speed: a quick click returns springier and with a shove, an unhurried
            // press returns calmly. Both come from the same snap the pure state machine measured.
            apply(outcome, transition: .spring(activeTheme.motion.releaseSpring(snap: outcome.snap)))

            reportTouch(outcome.controlEvents)
            if outcome.didFire {
                onTap?()
                sendActions(for: .primaryActionTriggered)
            }
            applyPendingEnvironmentRebuild()
        }

        func handleTouchCancelled() {
            let outcome = interaction.handle(.cancelled, status: status)
            apply(outcome, transition: .spring(activeTheme.motion.releaseSlow))
            reportTouch(outcome.controlEvents)
            applyPendingEnvironmentRebuild()
        }

        /// Tells the host what the touch did, twice over and in the same words: the closures, then
        /// the `UIControl` touch events for its targets. Both come from the one rule the interaction
        /// decided, so they cannot disagree. The button declines `UIControl` tracking, so nothing
        /// else sends these events.
        private func reportTouch(_ events: BNButtonInteraction.ControlEvents, tapCount: Int = 1) {
            // A cancel first: a press that replaced another ends the old touch before it starts.
            if events.contains(.touchCancel) {
                onTouchCancel?()
            }
            if events.contains(.touchDown) {
                onTouchDown?()
            }
            if events.contains(.touchUpInside) {
                onTouchUp?(true)
            }
            if events.contains(.touchUpOutside) {
                onTouchUp?(false)
            }

            var controlEvents = UIControl.Event(events)
            if controlEvents.contains(.touchDown), tapCount > 1 {
                controlEvents.insert(.touchDownRepeat)
            }
            guard !controlEvents.isEmpty else { return }
            sendActions(for: controlEvents)
        }

        /// Programmatic activation: the keyboard, Switch Control and VoiceOver all arrive here, so
        /// they fire exactly what a finger fires.
        ///
        /// The confirmation is played here rather than read off the outcome: there was no finger and
        /// therefore no press tick, so there is nothing for the merge window to merge with, and an
        /// activation that answered with silence would feel like nothing happened.
        func firePrimaryAction() {
            guard status.allowsInteraction else { return }
            let now = CACurrentMediaTime()
            let press = interaction.handle(.down(at: now), status: status)
            // There is no finger here, so no touch events of its own — but a finger already on the
            // button has just lost its touch to this activation, and the host hears it end.
            reportTouch(press.controlEvents.intersection(.touchCancel))
            let outcome = interaction.handle(.up(inside: true, at: now), status: status)
            guard outcome.didFire else { return }
            haptics.triggered(emphasis: activeStyle.hapticEmphasis)
            onTap?()
            sendActions(for: .primaryActionTriggered)
        }

        // MARK: - Keyboard and Switch Control

        /// Whether this press is an activation rather than an ordinary key.
        func handlesActivation(_ presses: Set<UIPress>) -> Bool {
            presses.contains { press in
                guard let key = press.key else { return press.type == .select }
                return key.charactersIgnoringModifiers == " " || key.keyCode == .keyboardReturnOrEnter
            }
        }

        /// Draws the press for a key held down — and deliberately does not fire.
        ///
        /// `UIControl` already sends `performPrimaryAction()` for a focused control on space and
        /// return; firing here as well would run the host's handler twice for one keystroke. The
        /// key press owns the look, the system owns the action.
        func applyKeyPress(_ pressed: Bool) {
            guard status.allowsInteraction, isPressedByTouch != pressed else { return }
            isPressedByTouch = pressed
            let motion = activeTheme.motion
            applyState(transition: .spring(pressed ? motion.press : motion.releaseFast))
        }

        // MARK: - The touch driver

        /// Puts the button's touch driver on the button itself, once.
        ///
        /// This is the one place the choice of driver is made. `UIControl` tracking starts only for
        /// a touch that lands on the control itself, and interactive glass answers a finger only when
        /// the touch lands inside it — so a glass button cannot track without losing the system's
        /// response. A recognizer hears every touch that lands on its view or anywhere beneath it, so
        /// on the button it hears both: a touch inside the material, and one in the margin `hitRect`
        /// adds, where nothing but the button is under the finger. In the material's content view it
        /// would miss the margin.
        func installPressRecognizer() {
            pressRecognizer.delegate = self
            pressRecognizer.addTarget(self, action: #selector(bnHandlePress))
            addGestureRecognizer(pressRecognizer)
        }

        @objc private func bnHandlePress(_ recognizer: BNButtonPressRecognizer) {
            let point = recognizer.location(in: self)
            switch recognizer.state {
            case .began: handleTouchDown(tapCount: recognizer.tapCount)
            case .changed: handleTouchMoved(inside: containsTouch(point))
            case .ended: handleTouchUp(inside: containsTouch(point))
            case .cancelled, .failed: handleTouchCancelled()
            default: break
            }
        }

        // MARK: - Refusal

        /// Answers a touch the button cannot accept: a flash, a head shake, a buzz.
        ///
        /// A disabled button that ignores a finger is indistinguishable from a broken one — the
        /// user is left wondering whether the tap even landed. This says: it landed, and the answer
        /// is no.
        func playRejection() {
            let rejection = activeTheme.motion.rejection
            guard rejection.isEnabled else { return }

            if rejection.isHapticEnabled {
                haptics.rejected()
            }
            flashRejection(rejection)
            shakeRejection(rejection)
        }

        private func flashRejection(_ rejection: BNButtonRejection) {
            guard let overlay = rejectionOverlay, rejection.flashAlpha > 0 else { return }
            // Restarted rather than queued: a second impatient tap should re-light the button, not
            // wait its turn behind the first.
            rejectionAnimation?.interrupt()
            overlay.alpha = rejection.flashAlpha

            // `easeInOut` rather than `easeOut`, and only after the hold: an ease-out fade loses
            // most of its opacity in the first few frames, which is what made the colour read as a
            // flicker instead of an answer.
            let fade = BNTransition.curve(BNCurve(duration: rejection.flashFade, timing: .easeInOut))
            rejectionAnimation = fade.run(afterDelay: rejection.flashHold) {
                overlay.alpha = 0
            }
        }

        private func shakeRejection(_ rejection: BNButtonRejection) {
            let offsets = rejection.offsets
            guard offsets.count > 2 else { return }

            // A layer animation, not a transform: it never touches the model value, so Auto Layout
            // and the press compression carry on as if nothing had moved.
            let shake = CAKeyframeAnimation(keyPath: "position.x")
            shake.values = offsets.map { NSNumber(value: Double($0)) }
            shake.duration = rejection.duration
            shake.isAdditive = true
            shake.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.removeAnimation(forKey: Self.rejectionAnimationKey)
            layer.add(shake, forKey: Self.rejectionAnimationKey)
        }

        // MARK: - Applying an outcome

        private func apply(_ outcome: BNButtonInteraction.Outcome, transition: BNTransition) {
            isPressedByTouch = outcome.isPressed
            applyState(transition: transition)

            // The refusal owns its own haptic, because it also owns the flash and the shake — one
            // decision, played in one place. Debounced, so one touch is one answer however many
            // phases report it.
            if outcome.didReject {
                let now = CACurrentMediaTime()
                guard now - lastRejectionTime > Self.rejectionDebounce else { return }
                lastRejectionTime = now
                playRejection()
                onRejected?()
                return
            }

            switch outcome.haptic {
            case .press: haptics.pressed()
            case .trigger: haptics.triggered(emphasis: activeStyle.hapticEmphasis)
            case .rejected, .silent: break
            }
        }
    }

    extension BNButton: UIGestureRecognizerDelegate {
        /// Never blocks anything else — the system's glass response and the host's own gestures
        /// (a scroll view above this button) all keep working alongside.
        public func gestureRecognizer(
            _: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer,
        ) -> Bool {
            true
        }
    }

    private extension UIControl.Event {
        init(_ events: BNButtonInteraction.ControlEvents) {
            let pairs: [(BNButtonInteraction.ControlEvents, UIControl.Event)] = [
                (.touchDown, .touchDown),
                (.touchDragInside, .touchDragInside),
                (.touchDragOutside, .touchDragOutside),
                (.touchDragEnter, .touchDragEnter),
                (.touchDragExit, .touchDragExit),
                (.touchUpInside, .touchUpInside),
                (.touchUpOutside, .touchUpOutside),
                (.touchCancel, .touchCancel),
            ]
            self = pairs.reduce(into: []) { result, pair in
                if events.contains(pair.0) {
                    result.insert(pair.1)
                }
            }
        }
    }
#endif
