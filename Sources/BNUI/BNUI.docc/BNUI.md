# ``BNUI``

Controls that feel a step beyond what UIKit ships: a button and a glass-backed tab bar.

## Overview

`BNUI` is a package of interactive components that know nothing about any one app's domain.
A control takes abstract data and reports events; the host owns meaning and navigation.
Every type carries the `BN` prefix, because the kit outlives the app it was first written for.

The boundary is enforced by the module graph rather than by discipline: an app's design layer
depends on `BNUI`, never the other way round, so an app component cannot leak into the
library. Anything that needs a word from a product's vocabulary — "activity", "alarm",
"session" — lives on the other side of that line, in the app that owns the word.

``BNButton`` is a binary action over a swappable material: one press, one result, a haptic
contract of its own and a loading mode that does not move the button. See
<doc:BuildingAButton>.

``BNTabBarView`` is a bottom navigation bar built on Liquid Glass, with a lens that
follows the finger, a swappable material, and optional action and accessory slots. See
<doc:BuildingATabBar>.

The kit runs on iOS 16 and later. Glass exists from iOS 26, and so do the glass materials.
Every control also has a blur material — a system `UIBlurEffect` material, from
`.systemUltraThinMaterial` to `.systemThickMaterial`, on a plate with a rim and a shadow — that
exists on every version: the kit's defaults wear glass on iOS 26 and the blur plate below
it. The few other effects that need a newer system step back: symbol animations, announcement
priority, opening a menu without a touch.

Everything a control draws comes from a theme, never a literal, so a second app adopts the
kit by swapping the theme rather than editing the controls.

Every control also has a SwiftUI face — the same UIKit control underneath, not a
second implementation. See <doc:UsingTheKitFromSwiftUI>.

### Choosing what to import

`import BNUI` brings the whole kit. An app that wants only some of the controls depends on
their products instead; each product brings along what its API is made of, so one import per
control is enough.

| Product | What it holds | Brings along |
|---|---|---|
| `BNUICore` | Motion, haptics, shapes, the blur plate and the ``BN`` namespace | — |
| `BNUIButton` | ``BNButton`` and ``BN/Button`` | `BNUICore` |
| `BNUITabBar` | ``BNTabBarView``, ``BNTabBarContainerViewController`` and their SwiftUI faces | `BNUIButton` |

## Topics

### Essentials

- <doc:BuildingAButton>
- ``BNButton``
- <doc:BuildingATabBar>
- ``BNTabBarView``

### SwiftUI

- <doc:UsingTheKitFromSwiftUI>
- ``BN``
- ``BN/Button``
- ``BN/TabBar``
- ``BN/TabView``
- ``BNHostingView``

### Foundation

The layer under every control: one haptic engine with the merge rule, the blur plate the
translucent materials draw, the outline a theme gives a control, and the springs and curves each
control's motion vocabulary is built from.

- ``BNShape``
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
