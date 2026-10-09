# BNUI

iOS controls built on UIKit, with a SwiftUI face for each. Alpha.

## Requirements

- iOS 16 or later. The Liquid Glass materials need iOS 26; below it the controls wear a blur
  material built on the system `UIBlurEffect` styles.
- Swift 6.2 (Xcode 26) or later.

## Installation

Add the package with Swift Package Manager:

```swift
.package(url: "https://github.com/aleksei-suholita/bnui.git", exact: "0.2.0")
```

Then depend on the whole kit or only on the controls you use:

| Product | What it holds | Brings along |
|---|---|---|
| `BNUI` | everything below | — |
| `BNUIButton` | `BNButton` and its SwiftUI face `BN.Button` | `BNUICore` |
| `BNUITabBar` | `BNTabBarView`, `BNTabBarContainerViewController` and their SwiftUI faces | `BNUIButton` |
| `BNUICore` | motion, haptics, shapes and materials every control is made of | — |
| `BNUIGallery` | a debug-only showcase with a page per control | `BNUI` |

```swift
.target(
    name: "App",
    dependencies: [.product(name: "BNUIButton", package: "bnui")]
)
```

One import per control is enough: a product re-exports what its API is made of.

## Usage

### Button

```swift
import BNUIButton

let finish = BNButton(content: .title("Finish"), style: .primary)
finish.onTap = { session.finish() }
```

The control reports, the host acts: a button never performs the action, holds business state or
navigates.

### Tab bar

```swift
import BNUITabBar

let bar = BNTabBarView(items: [
    BNTabBarItem(id: "home", icon: .symbol("house.fill"), title: "Home"),
    BNTabBarItem(id: "reports", icon: .symbol("chart.bar.fill"), title: "Reports"),
])
bar.onSelect = { id in coordinator.show(id) }
```

`BNTabBarContainerViewController` replaces `UITabBarController`: it hosts the content under the
floating bar and owns the selected section.

### SwiftUI

Every control has a SwiftUI face in the `BN` namespace — the same UIKit control underneath, not a
second implementation.

```swift
BN.Button("Finish") { session.finish() }
    .bnButtonStyle(.primary)
```

The initializer takes what the control is; looks come from `bn…` modifiers, which reach every
control beneath them — set a theme once at the root.

## Theming

Everything a control draws comes from a theme, a style or an initializer parameter — never from a
literal inside the control. An app adopts the kit by passing its own theme, not by editing the
controls.

## Documentation

The API is documented in DocC. In Xcode, choose Product › Build Documentation; the articles
*Building a Button*, *Building a Tab Bar* and *Using the Kit from SwiftUI* walk through each control.

## Versioning

The kit follows semantic versioning and is at 0.x: a minor release (0.1 → 0.2) may break the API,
a patch release (0.1.0 → 0.1.1) does not. Pin an exact version or use `.upToNextMinor(from:)` —
`from:` alone would accept a breaking 0.x release. Changes are listed in
[CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).
