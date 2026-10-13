/// An SF Symbol effect a tab bar's section plays the moment it becomes selected, with its options —
/// written the way the system's symbol effects are:
///
/// ```swift
/// BNTabBarItem(id: "camera", icon: .image(cameraSymbol), title: "Camera",
///              selectionAnimation: .bounce.down.byLayer)
/// ```
///
/// Each effect offers only the options it has: `.rotate.down` does not compile. A parameter of the
/// host's own that passes an effect on is written `some BNTabBarSymbolEffect` and reads the same.
public nonisolated protocol BNTabBarSymbolEffect: Sendable {
    /// The effect with its options, as an item keeps it.
    var symbolAnimation: BNTabBarSymbolAnimation { get }
}

/// The one-shot SF Symbol effect an item plays the moment it becomes selected, as the item keeps it.
///
/// Written as a ``BNTabBarSymbolEffect`` — `.bounce`, `.wiggle.left.byLayer`, `.none` — and kept as
/// this value, equal for equal options. Carried per item rather than per bar: a running-timer
/// section can breathe while the rest bounce. Pure and UIKit-free — it only names the effect; the
/// item view plays the system's `SymbolEffect` at the point of use.
///
/// The effect is a one-shot accent and fires only when a *different* section is chosen — never on
/// reselect. It plays on a symbol, a system one or the app's own passed as an image; a picture has
/// no layers to move. Reduce Motion suppresses it.
///
/// Symbol effects arrive with iOS 17: below it the icon changes weight and colour without moving.
/// An effect the system does not have yet — wiggle, rotate and breathe before iOS 18, draw on
/// before iOS 26 — plays as a plain bounce.
public nonisolated struct BNTabBarSymbolAnimation: BNTabBarSymbolEffect, Equatable {
    nonisolated enum Kind: Equatable, Sendable {
        case none
        case bounce(Bounce)
        case pulse(Pulse)
        case wiggle(Wiggle)
        case rotate(Rotate)
        case breathe(Breathe)
        case drawOn(DrawOn)
    }

    /// What moves: each layer in turn, all of them at once, or — drawing on — each path apart.
    /// Unset, the system's choice for the effect.
    nonisolated enum Layering: Equatable, Sendable {
        case byLayer
        case wholeSymbol
        case individually
    }

    nonisolated enum BounceDirection: Equatable, Sendable {
        case up
        case down
    }

    nonisolated enum WiggleDirection: Equatable, Sendable {
        case left
        case right
        case up
        case down
        case forward
        case backward
        case clockwise
        case counterClockwise
        case custom(angle: Double)
    }

    nonisolated enum RotateDirection: Equatable, Sendable {
        case clockwise
        case counterClockwise
    }

    /// Whether a breath is a swell alone or pulses its opacity with it.
    nonisolated enum BreatheStyle: Equatable, Sendable {
        case plain
        case pulse
    }

    let kind: Kind

    /// What an item plays when nothing is chosen: a plain bounce.
    static let standard = BNTabBarSymbolAnimation(kind: .bounce(Bounce()))

    /// Itself: a kept effect is passed on as it is.
    public var symbolAnimation: BNTabBarSymbolAnimation {
        self
    }
}

/// Copy-and-change, shared by every effect's options.
nonisolated protocol BNTabBarSymbolEffectOptions: Equatable, Sendable {}

nonisolated extension BNTabBarSymbolEffectOptions {
    func with<Value>(_ option: WritableKeyPath<Self, Value>, _ value: Value) -> Self {
        var copy = self
        copy[keyPath: option] = value
        return copy
    }
}

// MARK: - Effects

public extension BNTabBarSymbolAnimation {
    /// A bounce — the default: the symbol jumps once and lands.
    nonisolated struct Bounce: BNTabBarSymbolEffect, BNTabBarSymbolEffectOptions {
        var direction: BounceDirection?
        var layering: Layering?

        /// Bounces upwards.
        public var up: Self {
            with(\.direction, .up)
        }

        /// Bounces downwards, as if pressed.
        public var down: Self {
            with(\.direction, .down)
        }

        /// Each layer of the symbol bounces in turn.
        public var byLayer: Self {
            with(\.layering, .byLayer)
        }

        /// The whole symbol bounces at once.
        public var wholeSymbol: Self {
            with(\.layering, .wholeSymbol)
        }

        /// The bounce, as an item keeps it.
        public var symbolAnimation: BNTabBarSymbolAnimation {
            BNTabBarSymbolAnimation(kind: .bounce(self))
        }
    }

    /// One pulse of the symbol's opacity.
    nonisolated struct Pulse: BNTabBarSymbolEffect, BNTabBarSymbolEffectOptions {
        var layering: Layering?

        /// Each layer of the symbol pulses in turn.
        public var byLayer: Self {
            with(\.layering, .byLayer)
        }

        /// The whole symbol pulses at once.
        public var wholeSymbol: Self {
            with(\.layering, .wholeSymbol)
        }

        /// The pulse, as an item keeps it.
        public var symbolAnimation: BNTabBarSymbolAnimation {
            BNTabBarSymbolAnimation(kind: .pulse(self))
        }
    }

    /// A single wiggle, in the direction the symbol suggests unless one is chosen.
    nonisolated struct Wiggle: BNTabBarSymbolEffect, BNTabBarSymbolEffectOptions {
        var direction: WiggleDirection?
        var layering: Layering?

        /// Wiggles to the left.
        public var left: Self {
            with(\.direction, .left)
        }

        /// Wiggles to the right.
        public var right: Self {
            with(\.direction, .right)
        }

        /// Wiggles upwards.
        public var up: Self {
            with(\.direction, .up)
        }

        /// Wiggles downwards.
        public var down: Self {
            with(\.direction, .down)
        }

        /// Wiggles the way the text reads — to the right, or to the left in a right-to-left
        /// layout.
        public var forward: Self {
            with(\.direction, .forward)
        }

        /// Wiggles against the way the text reads.
        public var backward: Self {
            with(\.direction, .backward)
        }

        /// Wiggles by turning clockwise.
        public var clockwise: Self {
            with(\.direction, .clockwise)
        }

        /// Wiggles by turning counterclockwise.
        public var counterClockwise: Self {
            with(\.direction, .counterClockwise)
        }

        /// Each layer of the symbol wiggles in turn.
        public var byLayer: Self {
            with(\.layering, .byLayer)
        }

        /// The whole symbol wiggles at once.
        public var wholeSymbol: Self {
            with(\.layering, .wholeSymbol)
        }

        /// Wiggles along a direction of its own.
        ///
        /// - Parameter angle: the direction, as the system's `WiggleSymbolEffect.custom(angle:)`
        ///   takes it.
        public func custom(angle: Double) -> Self {
            with(\.direction, .custom(angle: angle))
        }

        /// The wiggle, as an item keeps it.
        public var symbolAnimation: BNTabBarSymbolAnimation {
            BNTabBarSymbolAnimation(kind: .wiggle(self))
        }
    }

    /// One full turn of the symbol's rotatable layers.
    nonisolated struct Rotate: BNTabBarSymbolEffect, BNTabBarSymbolEffectOptions {
        var direction: RotateDirection?
        var layering: Layering?

        /// Turns clockwise.
        public var clockwise: Self {
            with(\.direction, .clockwise)
        }

        /// Turns counterclockwise.
        public var counterClockwise: Self {
            with(\.direction, .counterClockwise)
        }

        /// Only the layers the symbol marks as rotating turn.
        public var byLayer: Self {
            with(\.layering, .byLayer)
        }

        /// The whole symbol turns.
        public var wholeSymbol: Self {
            with(\.layering, .wholeSymbol)
        }

        /// The turn, as an item keeps it.
        public var symbolAnimation: BNTabBarSymbolAnimation {
            BNTabBarSymbolAnimation(kind: .rotate(self))
        }
    }

    /// A single breath: the symbol swells and settles once.
    nonisolated struct Breathe: BNTabBarSymbolEffect, BNTabBarSymbolEffectOptions {
        var style: BreatheStyle?
        var layering: Layering?

        /// Swells in size alone.
        public var plain: Self {
            with(\.style, .plain)
        }

        /// Swells and pulses its opacity with it.
        public var pulse: Self {
            with(\.style, .pulse)
        }

        /// Each layer of the symbol breathes in turn.
        public var byLayer: Self {
            with(\.layering, .byLayer)
        }

        /// The whole symbol breathes at once.
        public var wholeSymbol: Self {
            with(\.layering, .wholeSymbol)
        }

        /// The breath, as an item keeps it.
        public var symbolAnimation: BNTabBarSymbolAnimation {
            BNTabBarSymbolAnimation(kind: .breathe(self))
        }
    }

    /// The symbol drawn anew along its paths, as by a pen. iOS 26; a plain bounce before it.
    nonisolated struct DrawOn: BNTabBarSymbolEffect, BNTabBarSymbolEffectOptions {
        var layering: Layering?

        /// Each layer of the symbol is drawn in turn.
        public var byLayer: Self {
            with(\.layering, .byLayer)
        }

        /// The whole symbol is drawn at once.
        public var wholeSymbol: Self {
            with(\.layering, .wholeSymbol)
        }

        /// Each path of the symbol is drawn on its own, one after another.
        public var individually: Self {
            with(\.layering, .individually)
        }

        /// The drawing, as an item keeps it.
        public var symbolAnimation: BNTabBarSymbolAnimation {
            BNTabBarSymbolAnimation(kind: .drawOn(self))
        }
    }
}

// MARK: - Choosing one

public nonisolated extension BNTabBarSymbolEffect where Self == BNTabBarSymbolAnimation {
    /// No effect: the icon still changes weight and colour, it just does not move.
    static var none: Self {
        BNTabBarSymbolAnimation(kind: .none)
    }
}

public nonisolated extension BNTabBarSymbolEffect where Self == BNTabBarSymbolAnimation.Bounce {
    /// A single bounce — the default.
    static var bounce: Self {
        Self()
    }
}

public nonisolated extension BNTabBarSymbolEffect where Self == BNTabBarSymbolAnimation.Pulse {
    /// One pulse of the symbol's opacity.
    static var pulse: Self {
        Self()
    }
}

public nonisolated extension BNTabBarSymbolEffect where Self == BNTabBarSymbolAnimation.Wiggle {
    /// A single wiggle. iOS 18; a plain bounce before it.
    static var wiggle: Self {
        Self()
    }
}

public nonisolated extension BNTabBarSymbolEffect where Self == BNTabBarSymbolAnimation.Rotate {
    /// One full turn of the symbol's rotatable layers. iOS 18; a plain bounce before it.
    static var rotate: Self {
        Self()
    }
}

public nonisolated extension BNTabBarSymbolEffect where Self == BNTabBarSymbolAnimation.Breathe {
    /// A single breath. iOS 18; a plain bounce before it.
    static var breathe: Self {
        Self()
    }
}

public nonisolated extension BNTabBarSymbolEffect where Self == BNTabBarSymbolAnimation.DrawOn {
    /// The symbol drawn anew along its paths. iOS 26; a plain bounce before it.
    static var drawOn: Self {
        Self()
    }
}
