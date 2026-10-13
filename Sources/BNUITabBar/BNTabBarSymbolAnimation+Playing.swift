#if canImport(UIKit)
    import UIKit

    // MARK: - Playing an effect

    extension BNTabBarSymbolAnimation {
        /// Plays the effect once on `imageView`'s symbol. An effect the system does not have yet
        /// plays as a plain bounce.
        @available(iOS 17.0, *)
        @MainActor func play(on imageView: UIImageView) {
            switch kind {
            case .none:
                break
            case let .bounce(bounce):
                imageView.addSymbolEffect(bounce.effect, options: .nonRepeating)
            case let .pulse(pulse):
                imageView.addSymbolEffect(pulse.effect, options: .nonRepeating)
            case .wiggle, .rotate, .breathe:
                guard #available(iOS 18.0, *) else {
                    Self.standard.play(on: imageView)
                    return
                }
                playIOS18Effect(on: imageView)
            case let .drawOn(drawOn):
                guard #available(iOS 26.0, *) else {
                    Self.standard.play(on: imageView)
                    return
                }
                drawOn.play(on: imageView)
            }
        }

        @available(iOS 18.0, *)
        @MainActor private func playIOS18Effect(on imageView: UIImageView) {
            switch kind {
            case let .wiggle(wiggle):
                imageView.addSymbolEffect(wiggle.effect, options: .nonRepeating)
            case let .rotate(rotate):
                imageView.addSymbolEffect(rotate.effect, options: .nonRepeating)
            case let .breathe(breathe):
                imageView.addSymbolEffect(breathe.effect, options: .nonRepeating)
            case .none, .bounce, .pulse, .drawOn:
                break
            }
        }
    }

    // MARK: - The system's effects

    /// The system's effects that move by layer or as a whole, so the choice is applied once for
    /// all of them.
    nonisolated protocol BNLayeredSymbolEffect {
        var byLayer: Self { get }
        var wholeSymbol: Self { get }
    }

    nonisolated extension BNLayeredSymbolEffect {
        func layered(_ layering: BNTabBarSymbolAnimation.Layering?) -> Self {
            switch layering {
            case .byLayer?: byLayer
            case .wholeSymbol?: wholeSymbol
            case .individually?, nil: self
            }
        }
    }

    @available(iOS 17.0, *)
    extension BounceSymbolEffect: BNLayeredSymbolEffect {}

    @available(iOS 17.0, *)
    extension PulseSymbolEffect: BNLayeredSymbolEffect {}

    @available(iOS 18.0, *)
    extension WiggleSymbolEffect: BNLayeredSymbolEffect {}

    @available(iOS 18.0, *)
    extension RotateSymbolEffect: BNLayeredSymbolEffect {}

    @available(iOS 18.0, *)
    extension BreatheSymbolEffect: BNLayeredSymbolEffect {}

    @available(iOS 26.0, *)
    extension DrawOnSymbolEffect: BNLayeredSymbolEffect {}

    @available(iOS 17.0, *)
    extension BNTabBarSymbolAnimation.Bounce {
        var effect: BounceSymbolEffect {
            let effect: BounceSymbolEffect = switch direction {
            case .up?: .bounce.up
            case .down?: .bounce.down
            case nil: .bounce
            }
            return effect.layered(layering)
        }
    }

    @available(iOS 17.0, *)
    extension BNTabBarSymbolAnimation.Pulse {
        var effect: PulseSymbolEffect {
            PulseSymbolEffect.pulse.layered(layering)
        }
    }

    @available(iOS 18.0, *)
    extension BNTabBarSymbolAnimation.Wiggle {
        var effect: WiggleSymbolEffect {
            let effect: WiggleSymbolEffect = switch direction {
            case .left?: .wiggle.left
            case .right?: .wiggle.right
            case .up?: .wiggle.up
            case .down?: .wiggle.down
            case .forward?: .wiggle.forward
            case .backward?: .wiggle.backward
            case .clockwise?: .wiggle.clockwise
            case .counterClockwise?: .wiggle.counterClockwise
            case let .custom(angle)?: .wiggle.custom(angle: angle)
            case nil: .wiggle
            }
            return effect.layered(layering)
        }
    }

    @available(iOS 18.0, *)
    extension BNTabBarSymbolAnimation.Rotate {
        var effect: RotateSymbolEffect {
            let effect: RotateSymbolEffect = switch direction {
            case .clockwise?: .rotate.clockwise
            case .counterClockwise?: .rotate.counterClockwise
            case nil: .rotate
            }
            return effect.layered(layering)
        }
    }

    @available(iOS 18.0, *)
    extension BNTabBarSymbolAnimation.Breathe {
        var effect: BreatheSymbolEffect {
            let effect: BreatheSymbolEffect = switch style {
            case .plain?: .breathe.plain
            case .pulse?: .breathe.pulse
            case nil: .breathe
            }
            return effect.layered(layering)
        }
    }

    @available(iOS 26.0, *)
    extension BNTabBarSymbolAnimation.DrawOn {
        var effect: DrawOnSymbolEffect {
            layering == .individually ? .drawOn.individually : DrawOnSymbolEffect.drawOn.layered(layering)
        }

        /// Drawing on is a state rather than a moment: while the effect is on, the symbol waits
        /// undrawn, and taking it off draws the symbol in. So it goes on at once and comes off,
        /// animated, on the next turn of the main queue — taken off in the same turn, nothing is
        /// drawn.
        @MainActor func play(on imageView: UIImageView) {
            let effect = effect
            imageView.addSymbolEffect(effect, options: .nonRepeating, animated: false)
            Task { @MainActor [weak imageView] in
                imageView?.removeSymbolEffect(ofType: effect, options: .nonRepeating, animated: true)
            }
        }
    }
#endif
