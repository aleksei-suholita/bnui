# Using the Kit from SwiftUI

Put every control on a SwiftUI screen without a second implementation of any of them.

## Overview

The kit is UIKit-first: the granularity of a touch, interruptible animation and the renderer
are why it exists, and UIKit is where those are reachable. SwiftUI gets the same controls
through thin wrappers — not lookalikes — so a press feels the same on a SwiftUI screen as on
a UIKit one, and there is one control to fix, not two.

One rule tells the two apart: `BNButton` is UIKit, `BN.Button` is SwiftUI. The faces live
in the ``BN`` namespace, and after the dot comes the name of the SwiftUI counterpart where
there is one — `BN.Button` for `Button`, `BN.TabView` for `TabView` — so a SwiftUI screen
reaches for the name it already knows, and typing `BN.` lists everything the kit offers it.
Each face lives beside its control, in `<UIKit type>+SwiftUI.swift`:

| UIKit | SwiftUI |
|---|---|
| ``BNButton`` | ``BN/Button`` |
| ``BNTabBarView`` | ``BN/TabBar`` |
| ``BNTabBarContainerViewController`` | ``BN/TabView`` |

The models — content, styles, themes, items — are shared, so a theme written for a
UIKit screen dresses a SwiftUI one unchanged.

```swift
enum Section { case home, stats }
@State private var section = Section.home

var body: some View {
    BN.TabView(selection: $section) {
        BN.Tab("Home", systemImage: "house", value: .home) { HomeView() }
        BN.Tab("Stats", systemImage: "chart.bar", value: .stats) { StatsView() }
    }
    .bnTabBarTheme(appTabBarTheme)
    .bnButtonTheme(appButtonTheme)
}
```

## What crosses and how

**The initializer says what the control is.** A button's label and action, a tab view's
tabs — and the state the host owns, as a value or a binding: whether a button is busy, the
selected tab, the bar's presentation. A tab's value is any `Hashable`, usually a case of the
host's own enum, so a selection that names a tab that is not there does not compile.

**Modifiers say how it looks, for everything beneath.** Each is named `bn`, the control and
the property — `bnButtonStyle`, `bnTabBarMaterial`, `bnTabViewMargin` — and reaches every
control of its kind beneath it, so a theme is set once at the root and a form styles its
buttons together. The nearest one wins. Each is declared on the face as well, where it
returns the face, so the kit's modifiers and the events can come in any order:

```swift
Form {
    BN.Button("Save") { save() }
    BN.Button("Delete", systemImage: "trash") { delete() }
        .bnButtonStyle(.destructive)
        .onRejected { explainWhy() }
}
.bnButtonStyle(.secondary)
.bnButtonWidth(.fill)
```

Events arrive as methods on the face (`.onRejected`, `.onReselect`) and stay optional. A bar's
action button comes with its handler in one call, `.action(_:perform:)`, so neither half can be
forgotten.

**SwiftUI's own switches count where they mean the same.** `.controlSize` picks a button's
step of the size scale, and `.disabled(true)` above a button disables it — silently, because
SwiftUI lets no touch through to a disabled view, so the button cannot refuse one. The kit's
own `.bnButtonDisabled(_:)` disables the kit's buttons alone and keeps the refusal: a flash,
a shake and ``BNButton/onRejected``, while a text field beside them stays editable.

```swift
Form {
    TextField("Email", text: $email)
    BN.Button("Save") { save() }
        .onRejected { showWhyNot() }
}
.bnButtonDisabled(!isValid)
```

A busy button stays busy under either: a form disabled while it submits keeps the spinner on
the button submitting it. A transaction that disables animations makes a status or selection change immediate; the
kit's own springs still carry an animated change — SwiftUI decides *whether*, never *how*.
`.buttonStyle`, `.tint` and `.buttonBorderShape` dress SwiftUI's own buttons and leave the
kit's alone.

**Sizes come from the controls.** A button answers with its layout solver: it hugs its
content in a stack, or takes the offered width for ``BNButtonWidth/fill``. The bar takes the
offered width and its own height.

**Unmatchable inputs are read once.** A material, a lens, an item renderer or haptics is a
value with nothing to compare, and replacing one rebuilds the control — so the SwiftUI faces
take them when the control is made and leave them alone after. ``BN/TabView`` reads all of its
bar's settings once, when its container is made.

**The environment reaches hosted content.** A tab's content and the bar's accessory live in
hosting controllers, which do not pass the SwiftUI environment on by themselves; ``BN/TabView``
and ``BN/TabBar`` hand it across, so an observable model injected above the container is
visible inside every tab.

## Slots that take a UIView

A button's custom content is a UIKit slot, and ``BNHostingView`` puts a SwiftUI view into it
or into any other `UIView` slot:

```swift
button.contentRenderer = BNCustomViewContentRenderer { BNHostingView(SyncBadge()) }
```

It sizes itself by what the content asks for and ignores safe areas. Content in a slot is for
showing: presenting a sheet from inside one is not supported.

## Motion and colour

``BNSpring``, ``BNCurve`` and ``BNTransition`` convert to SwiftUI's `Animation`, so a SwiftUI
view beside a kit control lands on the same spring:

```swift
.animation(BNTabBarTheme.standard.motion.selection.animation, value: selection)
```
