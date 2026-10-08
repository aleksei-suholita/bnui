import CoreGraphics

/// How the button behaves along its width. Height is not here — that belongs to the size.
public nonisolated enum BNButtonWidth: Equatable, Sendable {
    /// Sized by its content.
    case hug
    /// Stretches to the container — the full-width call to action.
    case fill
    case fixed(CGFloat)
}

/// Where the content sits when the button is wider than it needs to be.
public nonisolated enum BNButtonAlignment: Equatable, Sendable {
    case leading
    case center
    case trailing
}

/// Composition and behaviour — what is shown and how it copes. Appearance lives in the theme.
public nonisolated struct BNButtonConfiguration: Equatable, Sendable {
    /// What to do with a title that does not fit.
    public enum TitleBehavior: Equatable, Sendable {
        /// One line with an ellipsis.
        case truncate
        /// Grow in height; `lines` of 0 means no limit.
        case wrap(lines: Int)

        /// Line count to hand a label. 1 for truncation, `lines` otherwise.
        public var numberOfLines: Int {
            switch self {
            case .truncate: 1
            case let .wrap(lines): max(lines, 0)
            }
        }
    }

    public var width: BNButtonWidth
    public var alignment: BNButtonAlignment
    public var titleBehavior: TitleBehavior
    /// Keep room for the spinner even when the button is not loading. On by default: without it,
    /// entering `loading` would jolt the width, and the checklist forbids that.
    public var reservesSpaceForLoading: Bool
    /// At accessibility text sizes, stack icon over title instead of truncating.
    public var stacksVerticallyAtAccessibilitySizes: Bool
    public var accessibility: BNButtonAccessibilityStrings

    public init(
        width: BNButtonWidth = .hug,
        alignment: BNButtonAlignment = .center,
        titleBehavior: TitleBehavior = .truncate,
        reservesSpaceForLoading: Bool = true,
        stacksVerticallyAtAccessibilitySizes: Bool = true,
        accessibility: BNButtonAccessibilityStrings = .standard,
    ) {
        self.width = width
        self.alignment = alignment
        self.titleBehavior = titleBehavior
        self.reservesSpaceForLoading = reservesSpaceForLoading
        self.stacksVerticallyAtAccessibilitySizes = stacksVerticallyAtAccessibilitySizes
        self.accessibility = accessibility
    }
}
