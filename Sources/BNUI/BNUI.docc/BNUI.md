# ``BNUI``

Controls that feel a step beyond what UIKit ships: a button and a glass-backed tab bar.

## Overview

BNUI gives a UIKit or SwiftUI app two controls:

- ``BNButton`` — one press, one result. The press answers the speed of the finger, a disabled
  button refuses a tap visibly instead of ignoring it, haptics follow a contract of their own,
  and the loading mode does not move the button. See <doc:BuildingAButton>.
- ``BNTabBarContainerViewController`` — a replacement for `UITabBarController` with a floating
  bar: a selection lens that follows the finger, a More menu when the sections outgrow the
  width, an action button and an accessory above the bar. ``BNTabBarView`` is the bar alone.
  See <doc:BuildingATabBar>.

Both follow Dynamic Type, VoiceOver, right-to-left, Reduce Motion and Reduce Transparency, and
both have a SwiftUI face — the same UIKit control underneath, not a second implementation. See
<doc:UsingTheKitFromSwiftUI>.

### Quick start

```swift
import BNUI

let tabs = BNTabBarContainerViewController(tabs: [
    .init(item: BNTabBarItem(id: "home", icon: .symbol("house.fill"), title: "Home"),
          viewController: HomeViewController()),
    .init(item: BNTabBarItem(id: "settings", icon: .symbol("gearshape.fill"), title: "Settings"),
          viewController: SettingsViewController()),
])
window.rootViewController = tabs

let save = BNButton(content: .title("Save"), style: .primary)
save.onTap = { model.save() }
```

The controls report and the host acts: a button never performs its action itself, and the
container switches tabs but leaves every other flow to the host.

### Looks come from outside

Everything a control draws comes from a theme, a style or an initializer parameter, never from
a literal inside the control, so an app adopts the kit by passing its own values rather than
editing the controls. A button takes its colours and material from a ``BNButtonStyle`` and the
rest from a ``BNButtonTheme``; the bar takes all of it from a ``BNTabBarTheme`` and a
``BNTabBarMaterial``.

### iOS versions

The kit runs on iOS 16 and later. Glass exists from iOS 26, and so do the glass materials.
Every control also has a blur material — a system `UIBlurEffect` material, from
`.systemUltraThinMaterial` to `.systemThickMaterial`, on a plate with a rim and a shadow — that
exists on every version: the kit's defaults wear glass on iOS 26 and the blur plate below
it. The few other effects that need a newer system step back: symbol animations, announcement
priority, opening a menu without a touch.

### Choosing what to import

`import BNUI` brings the whole kit. An app that wants only some of the controls depends on
their products instead; each product brings along what its API is made of, so one import per
control is enough.

| Product | What it holds | Brings along |
|---|---|---|
| `BNUICore` | Motion, haptics, shapes, the blur plate and the ``BN`` namespace | — |
| `BNUIButton` | ``BNButton`` and ``BN/Button`` | `BNUICore` |
| `BNUITabBar` | ``BNTabBarView``, ``BNTabBarContainerViewController`` and their SwiftUI faces | `BNUIButton` |
| `BNUIGallery` | A bench with a page per control, open to an app's own pages; documented on its own | `BNUI` |

## Topics

### Essentials

- <doc:BuildingAButton>
- ``BNButton``
- <doc:BuildingATabBar>
- ``BNTabBarContainerViewController``
- ``BNTabBarView``

### SwiftUI

- <doc:UsingTheKitFromSwiftUI>
- ``BN``
- ``BN/Button``
- ``BN/TabBar``
- ``BN/TabView``
- ``BN/Tab``
- ``BNHostingView``

### Foundation

The layer under every control: the outline a theme gives a control, the badge and the images
the controls share, and the springs and curves each control's motion vocabulary is built from.

- ``BNShape``
- ``BNBadge``
- ``BNBadgeTheme``
- ``BNBadgeView``
- ``BNImageRendering``
- ``BNSpring``
- ``BNCurve``
- ``BNTransition``
- ``BNAnimation``

### Feedback

Every control plays through one engine, so a host has a single switch and the merge rule can see
across controls. Each control keeps a thin wrapper of its own, which is where its haptic *contract*
is written down.

- ``BNHaptics``
- ``BNHapticGate``
- ``BNHapticSignal``
- ``BNHapticWeight``
- ``BNHapticNotification``
- ``BNButtonHaptics``
- ``BNTabBarHaptics``

### Button Composition

- ``BNButtonContent``
- ``BNButtonIcon``
- ``BNButtonConfiguration``
- ``BNButtonStyle``
- ``BNButtonSize``
- ``BNButtonWidth``
- ``BNButtonAlignment``

### Button State

- ``BNButtonStatus``
- ``BNButtonInteraction``
- ``BNButtonPressRecognizer``
- ``BNButtonRejection``
- ``BNButtonHapticEvent``
- ``BNButtonHapticEmphasis``

### Button Theming

- ``BNButtonTheme``
- ``BNButtonMetrics``
- ``BNButtonInsets``
- ``BNButtonColorSet``
- ``BNButtonBorder``

### Button Motion

- ``BNButtonMotion``

### Button Materials

- ``BNButtonMaterial``
- ``BNButtonSurface``
- ``BNButtonSurfaceState``
- ``BNButtonPressResponse``
- ``BNGlassButtonMaterial``
- ``BNBlurButtonMaterial``
- ``BNSolidButtonMaterial``

### Custom Button Content

- ``BNButtonContentRenderer``
- ``BNButtonContentRendering``
- ``BNButtonContentState``
- ``BNStandardButtonContentRenderer``
- ``BNCustomViewContentRenderer``
- ``BNButtonLoadingIndicatorFactory``
- ``BNButtonLoadingIndicating``
- ``BNActivityLoadingIndicator``
- ``BNButtonLayoutSolver``
- ``BNButtonContentMeasurement``
- ``BNButtonContentAxis``
- ``BNButtonAccessibilityStrings``
- ``BNButtonAccessibilityOverrides``

### Sections and Slots

- ``BNTabBarItem``
- ``BNTabBarSymbolEffect``
- ``BNTabBarSymbolAnimation``
- ``BNTabBarAction``
- ``BNTabBarAccessory``
- ``BNTabBarConfiguration``
- ``BNTabBarPresentation``

### Theming

- ``BNTabBarTheme``
- ``BNTabBarMetrics``

### Motion

- ``BNTabBarMotion``

### Materials

- ``BNTabBarMaterial``
- ``BNTabBarSurface``
- ``BNGlassTabBarMaterial``
- ``BNBlurTabBarMaterial``
- ``BNSolidTabBarMaterial``

### The Selection Lens

- ``BNTabBarLensRenderer``
- ``BNTabBarLens``
- ``BNTabBarLensState``
- ``BNMaskedLensRenderer``

### Custom Section Content

- ``BNTabBarItemRenderer``
- ``BNTabBarItemRendering``
- ``BNTabBarItemState``
- ``BNTabBarItemLayer``
- ``BNStandardTabBarItemRenderer``

### Layout and Gestures

- ``BNTabBarLayoutSolver``
- ``BNTabBarGeometry``
- ``BNTabBarDragRecognizer``
