/// How a control draws an image the host brings: as a glyph in the control's colours, or as a
/// picture in its own — a button's icon, a tab bar's section.
public nonisolated enum BNImageRendering: Equatable, Sendable {
    /// A glyph: its shape in the colour of the control's state, as a symbol is drawn.
    case template
    /// A picture in its own colours — a brand's logo, a person's photo. The control's colours do
    /// not touch it; each control says what carries its state instead.
    case original
}
