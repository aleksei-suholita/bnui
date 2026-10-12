import CoreGraphics

/// Which way the content runs inside the button.
public nonisolated enum BNButtonContentAxis: Equatable, Sendable {
    case horizontal
    case vertical
}

/// What a content view reports about the pieces it holds, measured unbounded.
///
/// Measured by the view, decided by the solver: the view knows fonts and symbols, the solver knows
/// the rules, and keeping the two apart is what makes the rules testable.
public nonisolated struct BNButtonContentMeasurement: Equatable, Sendable {
    /// `.zero` when there is no title.
    public var titleSize: CGSize
    /// One line of the title: `titleSize.height` until the title wraps, 0 when there is no title.
    public var titleLineHeight: CGFloat
    /// Leading and trailing icons, in layout order — 0, 1 or 2 entries.
    public var iconSizes: [CGSize]

    /// A `titleLineHeight` of `nil` means the title is one line, `titleSize.height` tall.
    public init(titleSize: CGSize = .zero, titleLineHeight: CGFloat? = nil, iconSizes: [CGSize] = []) {
        self.titleSize = titleSize
        self.titleLineHeight = titleLineHeight ?? titleSize.height
        self.iconSizes = iconSizes
    }

    /// Tallest icon, or 0 when there are none.
    public var iconHeight: CGFloat {
        iconSizes.map(\.height).max() ?? 0
    }
}

/// Pure layout of the button — numbers in, numbers out, no UIKit, so the rules are tested on macOS.
///
/// The view measures its own content and asks this for the answer, rather than deciding for itself.
/// That keeps the two awkward requirements — grow instead of clipping at accessibility sizes, and
/// never let the touch area drop below 44 pt — in one place that a test can reach.
public nonisolated enum BNButtonLayoutSolver {
    public struct Input: Equatable, Sendable {
        /// Width the host offers. A ceiling for `hug`, the target for `fill`.
        public var availableWidth: CGFloat
        /// Title measured on a single unbounded line. 0 when there is no title.
        public var titleWidth: CGFloat
        public var titleHeight: CGFloat
        /// One line of the title — what a wrapped title holds in place, see
        /// ``BNButtonLayoutSolver``'s vertical inset. 0 when there is no title.
        public var titleLineHeight: CGFloat
        /// Widths of the leading and trailing icons — 0, 1 or 2 entries.
        public var iconWidths: [CGFloat]
        public var iconHeight: CGFloat
        public var size: BNButtonSize
        public var metrics: BNButtonMetrics
        public var width: BNButtonWidth
        public var titleBehavior: BNButtonConfiguration.TitleBehavior
        public var isAccessibilitySize: Bool
        public var allowsVerticalStack: Bool

        public init(
            availableWidth: CGFloat,
            titleWidth: CGFloat,
            titleHeight: CGFloat,
            titleLineHeight: CGFloat? = nil,
            iconWidths: [CGFloat],
            iconHeight: CGFloat,
            size: BNButtonSize = .medium,
            metrics: BNButtonMetrics = .standard,
            width: BNButtonWidth = .hug,
            titleBehavior: BNButtonConfiguration.TitleBehavior = .truncate,
            isAccessibilitySize: Bool = false,
            allowsVerticalStack: Bool = true,
        ) {
            self.availableWidth = availableWidth
            self.titleWidth = titleWidth
            self.titleHeight = titleHeight
            self.titleLineHeight = titleLineHeight ?? titleHeight
            self.iconWidths = iconWidths
            self.iconHeight = iconHeight
            self.size = size
            self.metrics = metrics
            self.width = width
            self.titleBehavior = titleBehavior
            self.isAccessibilitySize = isAccessibilitySize
            self.allowsVerticalStack = allowsVerticalStack
        }
    }

    public struct Output: Equatable, Sendable {
        public var axis: BNButtonContentAxis
        /// Width the content occupies, padding excluded.
        public var contentWidth: CGFloat
        public var buttonWidth: CGFloat
        public var buttonHeight: CGFloat
        public var numberOfLines: Int
        /// How far the touch area reaches past the drawn button.
        public var hitOutsets: BNButtonInsets
        /// The room the content keeps from the button's edges — the text paddings, or
        /// ``BNButtonSize/iconOnlyInset`` on every side of a lone icon.
        public var contentInsets: BNButtonInsets
        /// How far the icons are shrunk: a lone one to fit its circle, icons beside a title or each
        /// other to fit the size's height. 1 unless an icon would cross the inset or the padding.
        public var iconScale: CGFloat

        /// The area a finger actually hits. Never smaller than the platform minimum.
        public var touchSize: CGSize {
            CGSize(
                width: buttonWidth + hitOutsets.leading + hitOutsets.trailing,
                height: buttonHeight + hitOutsets.top + hitOutsets.bottom,
            )
        }
    }

    public static func solve(_ input: Input) -> Output {
        let size = input.size
        let hasTitle = input.titleWidth > 0
        let icons = input.iconWidths.filter { $0 > 0 }

        if !hasTitle, icons.count == 1, let icon = icons.first {
            return solveLoneIcon(input: input, iconWidth: icon)
        }

        let iconScale = iconScaleBesideContent(input: input)
        let scaledIcons = icons.map { $0 * iconScale }
        let iconHeight = icons.isEmpty ? 0 : input.iconHeight * iconScale
        let horizontalContent = horizontalContentWidth(icons: scaledIcons, titleWidth: input.titleWidth, spacing: size.iconSpacing)
        let ceiling = max(input.availableWidth, 0)
        let roomForContent = max(ceiling - 2 * size.horizontalPadding, 0)

        // Stacking is for the case it was invented for: an icon and a title that no longer fit
        // side by side at accessibility sizes. A lone title gains nothing from a vertical axis —
        // it wraps or truncates — and stacking one at standard sizes would just look broken.
        let stacks = input.allowsVerticalStack
            && input.isAccessibilitySize
            && hasTitle
            && !icons.isEmpty
            && horizontalContent > roomForContent

        let axis: BNButtonContentAxis = stacks ? .vertical : .horizontal
        let contentWidth = stacks
            ? max(input.titleWidth, scaledIcons.max() ?? 0)
            : horizontalContent

        let numberOfLines = input.titleBehavior.numberOfLines
        let contentHeight = stacks
            ? verticalContentHeight(input: input, iconHeight: iconHeight, spacing: size.iconSpacing)
            : max(input.titleHeight, iconHeight)

        // The size's height holds until the content genuinely needs more: Dynamic Type grows the
        // button rather than cropping the label. Icon over title has no single line to hold in
        // place, so a stack keeps the plain padding.
        let verticalInset = stacks ? size.verticalPadding : restingVerticalInset(input: input, iconHeight: iconHeight)
        let buttonHeight = max(size.height, contentHeight + 2 * verticalInset)
        let buttonWidth = resolveWidth(input: input, contentWidth: contentWidth, ceiling: ceiling)

        return Output(
            axis: axis,
            contentWidth: min(contentWidth, max(buttonWidth - 2 * size.horizontalPadding, 0)),
            buttonWidth: buttonWidth,
            buttonHeight: buttonHeight,
            numberOfLines: numberOfLines,
            hitOutsets: input.metrics.hitOutsets(forVisualSize: CGSize(width: buttonWidth, height: buttonHeight)),
            contentInsets: BNButtonInsets(vertical: verticalInset, horizontal: size.horizontalPadding),
            iconScale: iconScale,
        )
    }

    /// Icons beside a title, or beside each other, are no taller than one line the size holds —
    /// its height less the vertical padding. A taller one is shrunk rather than the button grown,
    /// as a lone icon is shrunk into its circle: the height belongs to the size, and only text,
    /// wrapped or grown by Dynamic Type, is allowed past it. Two icons shrink together, by the
    /// taller one, so the pair keeps its proportions.
    private static func iconScaleBesideContent(input: Input) -> CGFloat {
        let room = max(input.size.height - 2 * input.size.verticalPadding, 0)
        return min(1, fit(input.iconHeight, into: room))
    }

    /// One icon and nothing else: the size decides the button, and the icon fits into it.
    ///
    /// Sized by the glyph instead, two buttons of one step would differ whenever their symbols
    /// do — at 17 pt `person.2` is 28 pt wide and `gearshape` 22 — and a row of them would stop
    /// lining up. A glyph that will not fit is shrunk rather than the button grown: a thinner
    /// stroke shows only side by side, a wider button shows at once. Hugging, the button is
    /// square, so a capsule draws a circle; `minWidth` is a floor for words and is not applied.
    private static func solveLoneIcon(input: Input, iconWidth: CGFloat) -> Output {
        let size = input.size
        let inset = max(size.iconOnlyInset, 0)
        let height = size.height
        let width: CGFloat = switch input.width {
        case .hug: height
        case .fill, .fixed: resolveWidth(input: input, contentWidth: iconWidth, ceiling: max(input.availableWidth, 0))
        }

        let room = CGSize(width: max(width - 2 * inset, 0), height: max(height - 2 * inset, 0))
        let scale = min(1, fit(iconWidth, into: room.width), fit(input.iconHeight, into: room.height))

        return Output(
            axis: .horizontal,
            contentWidth: iconWidth * scale,
            buttonWidth: width,
            buttonHeight: height,
            numberOfLines: input.titleBehavior.numberOfLines,
            hitOutsets: input.metrics.hitOutsets(forVisualSize: CGSize(width: width, height: height)),
            contentInsets: BNButtonInsets(vertical: inset, horizontal: inset),
            iconScale: scale,
        )
    }

    /// The room above and below content that has outgrown the size's height.
    ///
    /// One line sits centred in the height, `(height − line) / 2` from the top. A wrapped title
    /// keeps that room rather than dropping to `verticalPadding`: the first line stays where it
    /// was, and every line after it adds exactly its own height. `verticalPadding` is the floor,
    /// for type so large that one line no longer fits the size. An icon taller than a line of text
    /// is what one line holds, or a single line beside it would grow the button.
    private static func restingVerticalInset(input: Input, iconHeight: CGFloat) -> CGFloat {
        let size = input.size
        let line = max(input.titleLineHeight, iconHeight)
        return max(size.verticalPadding, (size.height - line) / 2)
    }

    /// The scale that brings `extent` within `room`. An extent of 0 has nothing to shrink.
    private static func fit(_ extent: CGFloat, into room: CGFloat) -> CGFloat {
        extent > 0 ? room / extent : 1
    }

    private static func horizontalContentWidth(icons: [CGFloat], titleWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let pieces = icons + (titleWidth > 0 ? [titleWidth] : [])
        guard !pieces.isEmpty else { return 0 }
        return pieces.reduce(0, +) + spacing * CGFloat(pieces.count - 1)
    }

    private static func verticalContentHeight(input: Input, iconHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        // Wrapping is allowed to add lines here; truncation keeps one. Either way the icon sits
        // above the title with a single gap.
        let lines = max(input.titleBehavior.numberOfLines, 1)
        return iconHeight + spacing + input.titleHeight * CGFloat(lines)
    }

    private static func resolveWidth(input: Input, contentWidth: CGFloat, ceiling: CGFloat) -> CGFloat {
        let size = input.size
        let hugged = contentWidth + 2 * size.horizontalPadding
        let desired: CGFloat = switch input.width {
        case .hug: min(hugged, ceiling > 0 ? ceiling : hugged)
        case .fill: ceiling
        case let .fixed(width): width
        }
        // The floor is applied last so it survives every mode, including a fixed width that forgot
        // the spinner has to fit.
        return max(desired, size.effectiveMinWidth)
    }
}
