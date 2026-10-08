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
@State private var tab = "home"

var body: some View {
    BN.TabView(selection: $tab, tabs: [
        .init(item: BNTabBarItem(id: "home", icon: .symbol("house"), title: "Home")) { HomeView() },
        .init(item: BNTabBarItem(id: "stats", icon: .symbol("chart.bar"), title: "Stats")) { StatsView() },
    ])
}
```

## What crosses and how

**State stays with the host.** Whatever the UIKit control is told — a button's status, the
selected section, the bar's presentation — its SwiftUI face takes as a value or a binding.
Events arrive as modifiers on the view itself (`.onRejected`, `.onReselect`, `.onAction`), so
they read like SwiftUI and stay optional.

**SwiftUI's own switches count.** `.disabled(true)` above a button is its `.disabled` status;
a transaction that disables animations makes a status or selection change immediate. The
kit's own springs still carry an animated change — SwiftUI decides *whether*, never *how*.

**Sizes come from the controls.** A button answers with its layout solver: it hugs its
content in a stack, or takes the offered width for ``BNButtonWidth/fill``. The bar takes the
offered width and its own height.

**Unmatchable inputs are read once.** A material, a lens or an item renderer is a protocol
value with nothing to compare, and replacing one rebuilds the control — so the SwiftUI faces
take them when the control is made and leave them alone after.

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
