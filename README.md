# BNUI

iOS controls built on UIKit, with a SwiftUI face for each. Alpha.

## Requirements

- iOS 16 or later. The Liquid Glass materials need iOS 26; below it the controls wear a blur
  material built on the system `UIBlurEffect` styles.
- Swift 6.2 (Xcode 26) or later.

## Installation

Add the package with Swift Package Manager:

```swift
.package(url: "https://github.com/aleksei-suholita/bnui.git", exact: "0.7.2")
```

Then depend on the whole kit or only on the controls you use:

| Product | What it holds | Brings along |
|---|---|---|
| `BNUI` | everything below | — |
| `BNUIButton` | `BNButton` and its SwiftUI face `BN.Button` | `BNUICore` |
| `BNUITabBar` | `BNTabBarView`, `BNTabBarContainerViewController` and their SwiftUI faces | `BNUIButton` |
| `BNUICore` | motion, haptics, shapes and materials every control is made of | — |
| `BNUIGallery` | a bench with a page per control, open to an app's own pages; compiled in every configuration | `BNUI` |

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

`BNTabBarContainerViewController` replaces `UITabBarController`: it holds a controller per tab,
floats the bar over the content and switches tabs itself.

```swift
import BNUITabBar

let tabs = BNTabBarContainerViewController(
    tabs: [
        .init(item: BNTabBarItem(id: "home", icon: .symbol("house.fill"), title: "Home"),
              viewController: UINavigationController(rootViewController: HomeViewController())),
        .init(item: BNTabBarItem(id: "reports", icon: .symbol("chart.bar.fill"), title: "Reports"),
              viewController: UINavigationController(rootViewController: ReportsViewController())),
    ],
    action: BNTabBarAction(icon: .symbol("plus"), accessibilityLabel: "New", style: .prominent)
)
tabs.onAction = { coordinator.create() }
tabs.setBadge(.count(3), for: "home")
window.rootViewController = tabs
```

Every tab's safe area grows by the bar's height, so scroll views keep clear of it on their own.
On iPhone Duo, built against the iOS 27.1 SDK, the container stands the bar in the strip beside
the content where the system moves its own bars.

`BNTabBarView` is the bar alone, for a host that switches its content itself: it draws
`selectedID` and reports `onSelect`.

### SwiftUI

Every control has a SwiftUI face in the `BN` namespace — the same UIKit control underneath, not a
second implementation.

```swift
BN.Button("Finish") { session.finish() }
    .bnButtonStyle(.primary)
```

The initializer takes what the control is; looks come from `bn…` modifiers, which reach every
control beneath them — set a theme once at the root.

### Gallery

`BNUIGallery` is a bench for controls — the kit's and an app's own — with knobs, backdrops, light
and dark, text sizes and right-to-left. A page is a demo and knobs bound to its properties; the
kit's own pages come with it:

```swift
#if DEBUG
import BNUIGallery

let pill = BNGalleryDemoPage("Reaction Pill", symbol: "face.smiling") {
    ReactionPillView()
} knobs: { pill in [
    .slider("Count", \.count, in: 0 ... 999),
    .toggle("Selected", \.isSelected),
    .button("Bump") { pill.bump(animated: true) },
] }

BNGallery.present([pill] + BNUIGalleryPages.all(), from: self)
#endif
```

The gallery is compiled in every configuration, so the app decides where the way in is — behind
`#if DEBUG`, or closed at run time for TestFlight. An app that links `BNUIGallery` carries its
code into the App Store build either way. Pages for alerts and sheets, SwiftUI views, every state
at once, and the app's own backdrops are in the gallery's documentation.

## Theming

Everything a control draws comes from a theme, a style or an initializer parameter — never from a
literal inside the control. An app adopts the kit by writing its values once and passing them in,
not by editing the controls:

```swift
extension BNButtonStyle {
    static let brand = BNButtonStyle(
        id: "brand",
        fill: BNButtonColorSet(.systemIndigo),
        title: BNButtonColorSet(.white)
    )
}

extension BNTabBarTheme {
    static let app = BNTabBarTheme(palette: .init(selected: .systemIndigo))
}

let save = BNButton(content: .title("Save"), style: .brand)
let tabs = BNTabBarContainerViewController(tabs: tabList, theme: .app)
```

A button takes its colours and material from its style and type, geometry and motion from a
`BNButtonTheme`; the bar takes all of it from a `BNTabBarTheme`. UIKit has no environment to carry
a theme, so a UIKit screen passes it to each control. In SwiftUI a modifier at the root reaches
every control beneath it: `.bnTabBarTheme(.app)`.

## Documentation

The API reference and the articles — *Building a Button*, *Building a Tab Bar*, *Using the Kit
from SwiftUI* — are on the
[Swift Package Index](https://swiftpackageindex.com/aleksei-suholita/bnui/documentation/bnui),
with the gallery's documentation beside them. In Xcode, Product › Build Documentation builds the
same pages.

## Versioning

The kit follows semantic versioning and is at 0.x: a minor release (0.1 → 0.2) may break the API,
a patch release (0.1.0 → 0.1.1) does not. Pin an exact version or use `.upToNextMinor(from:)` —
`from:` alone would accept a breaking 0.x release. Changes are listed in
[CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).
