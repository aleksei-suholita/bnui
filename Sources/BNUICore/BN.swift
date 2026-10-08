#if canImport(UIKit)
    /// The kit in SwiftUI.
    ///
    /// Every control has two faces and one rule between them: `BNButton` is UIKit, `BN.Button` is
    /// SwiftUI. After the dot comes the name of the SwiftUI counterpart where there is one —
    /// `BN.Button` for `Button`, `BN.TabView` for `TabView` — so a SwiftUI screen reaches for the
    /// name it already knows.
    ///
    /// A face is the same UIKit control underneath, not a second implementation: the press, the
    /// haptics and the refusal of a disabled tap are the UIKit control's own. Scene-level services
    /// are modifiers instead, the way SwiftUI's own are — `bnToastLayer(_:)`.
    public enum BN {} // swiftlint:disable:this type_name
#endif
