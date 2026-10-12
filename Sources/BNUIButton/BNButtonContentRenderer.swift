#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Everything a content view needs to draw itself for the current moment.
    public struct BNButtonContentState {
        public var isPressed: Bool
        public var status: BNButtonStatus
        public var isFocused: Bool
        public var axis: BNButtonContentAxis
        public var numberOfLines: Int
        /// How far the icons are shrunk to fit the size — see
        /// ``BNButtonLayoutSolver/Output/iconScale``. A custom view is not scaled; it is its host's.
        public var iconScale: CGFloat
        public var alignment: BNButtonAlignment
        public var style: BNButtonStyle
        public var size: BNButtonSize
        public var theme: BNButtonTheme

        public init(
            isPressed: Bool,
            status: BNButtonStatus,
            isFocused: Bool,
            axis: BNButtonContentAxis,
            numberOfLines: Int,
            iconScale: CGFloat = 1,
            alignment: BNButtonAlignment,
            style: BNButtonStyle,
            size: BNButtonSize,
            theme: BNButtonTheme,
        ) {
            self.isPressed = isPressed
            self.status = status
            self.isFocused = isFocused
            self.axis = axis
            self.numberOfLines = numberOfLines
            self.iconScale = iconScale
            self.alignment = alignment
            self.style = style
            self.size = size
            self.theme = theme
        }
    }

    /// The contract a content view owes the button.
    ///
    /// This is where the spec's "arbitrary view" lands — but unlike a plain slot, such a view is
    /// handed the button's state and is asked to measure itself, so alignment and the touch target
    /// keep working whatever is inside.
    public protocol BNButtonContentRendering: UIView {
        func apply(state: BNButtonContentState, transition: BNTransition)
        /// Sizes of the pieces, for ``BNButtonLayoutSolver``.
        ///
        /// `fittingWidth` is the room left for content after padding — `.greatestFiniteMagnitude`
        /// when there is none to speak of yet. A wrapping title needs it: measured unbounded it
        /// would report one long line, and the button would be sized for a line it never draws.
        func measure(fittingWidth: CGFloat) -> BNButtonContentMeasurement
    }

    public protocol BNButtonContentRenderer {
        /// Distinguishes one renderer from another for the control's equality check.
        var identity: String { get }
        func makeContentView(
            for content: BNButtonContent,
            theme: BNButtonTheme,
            size: BNButtonSize,
        ) -> any BNButtonContentRendering
    }

    /// Title, icons, or both — the renderer nearly every button uses.
    public struct BNStandardButtonContentRenderer: BNButtonContentRenderer {
        public init() {}

        public var identity: String {
            "standard"
        }

        public func makeContentView(
            for content: BNButtonContent,
            theme: BNButtonTheme,
            size: BNButtonSize,
        ) -> any BNButtonContentRendering {
            BNButtonContentView(content: content, theme: theme, size: size)
        }
    }

    /// Wraps an arbitrary view — an animated or shader-drawn glyph, a badge, anything.
    ///
    /// The control gives that view a frame, an alignment and a touch target; it does not colour it,
    /// because a view the host brought along owns its own appearance. Disabled is the exception:
    /// the state has to read somehow, so the wrapper dims it.
    public struct BNCustomViewContentRenderer: BNButtonContentRenderer {
        public let identity: String
        private let makeView: () -> UIView

        /// - Parameters:
        ///   - identity: distinguishes this renderer from another for the control's equality check.
        ///   - makeView: builds the view. Called on every rebuild, so it should be cheap.
        public init(identity: String = "custom", makeView: @escaping () -> UIView) {
            self.identity = identity
            self.makeView = makeView
        }

        public func makeContentView(
            for _: BNButtonContent,
            theme _: BNButtonTheme,
            size _: BNButtonSize,
        ) -> any BNButtonContentRendering {
            BNCustomContentView(wrapping: makeView())
        }
    }
#endif
