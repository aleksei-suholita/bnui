# Building a Tab Bar

Compose a bottom navigation bar from sections, an optional action, and an optional accessory.

## Overview

``BNTabBarView`` is a bar you drive and observe — it never navigates. You give it the
sections to show and which one is selected; it tells you when the selection changes. The
selection lives with the host, so the control stays a pure view: `selectedID` is what to
draw, `onSelect` is what happened.

```swift
let bar = BNTabBarView(items: [
    BNTabBarItem(id: "home", icon: .symbol("house.fill"), title: "Home"),
    BNTabBarItem(id: "reports", icon: .symbol("chart.bar.fill"), title: "Reports"),
])
bar.onSelect = { id in coordinator.show(id) }
bar.onEffectiveHeightChange = { height in scrollView.contentInset.bottom = height }
```

Sections stand in the capsule as long as the width gives each of them
``BNTabBarMetrics/minimumItemWidth``, and never more than six. Past that, the last slot is
``BNTabBarConfiguration/moreItem``, which opens the rest in a system menu; a section chosen
there is reported like any other, and the lens marks More while it is active. An action
takes its width before the sections do, so it brings More sooner. How many slots stand is
decided by the width alone, not by the labels, so a change of text size never moves a
section into the menu. The bar is
sized by its content and detached from the screen edges; the host gives it the width, and
the sections' capsule aligns itself within that width with
``BNTabBarConfiguration/Alignment``.

A bar short of room gives way in a fixed order: sections narrow below
``BNTabBarMetrics/preferredItemWidth``, then every label shrinks by one factor down to
``BNTabBarMetrics/minimumLabelScale``, then labels go and the bar shows icons alone. Sections
never narrow past the 44 pt touch target, whatever the theme asks. VoiceOver names every
section whatever is drawn.
The rules live in ``BNTabBarLayoutSolver``, where they are tested without a simulator.

## The selection lens

Selection is drawn by a *lens* — a marker that follows the finger and reveals the active
section, rather than a colour swapped onto an item. Pressing moves the lens onto the section
under the finger; dragging along the bar carries it with the finger, and releasing anywhere
commits the nearest section. There is no cancel-by-leaving: a gesture always resolves into a
choice.

The marker is a flat tinted capsule that only ever travels: it does not turn to glass and
does not grow under the finger. The lens is still a replaceable seam — ``BNMaskedLensRenderer``
is the default, and a renderer that reveals a second content layer colours the section
exactly along the marker's edge, so the change flows through an icon during a drag.

## Swappable materials

The bar's backdrop is a ``BNTabBarMaterial`` — the control never learns whether glass, metal
or flat paint is under it. The default, ``BNTabBarView/standardMaterial``, is
``BNGlassTabBarMaterial`` on iOS 26 and ``BNBlurTabBarMaterial`` below it; the blur plate is a
material of its own on iOS 26 too. ``BNSolidTabBarMaterial`` is the opaque fallback used,
together with a solid lens, under Reduce Transparency. Brand and seasonal skins plug in the
same way, without touching the control.

## The action button

An ``BNTabBarAction`` sits beside the sections — a real, primary action such as *create*,
not a sixth tab. It is a ``BNButton``, so the bar's most prominent tap answers with the same
physics as every other button in the app, and it is kept apart from the sections on every
channel: no selected state, the lens never touches it, a drag skips over it, it has its own
shape and haptic, and VoiceOver hears it outside the tab-bar container.

It is made of what the bar is made of: the bar's material hands over the button's through
``BNTabBarMaterial/makeActionMaterial(prominent:)``, so the action is glass beside a glass
capsule, a blurred plate beside a blurred one and paint beside paint. Its
``BNTabBarAction/Style`` says how loud it is and in what colour — `.standard`, or `.prominent`,
stained with the accent and carrying a light glyph. A host that wants another colour passes the
pair itself, `.prominent(fill:glyph:)`; the kit does not check their contrast.

Its haptic stays the bar's: the button's own generators are silenced, because an action must
not feel like changing a section, and two generators firing together would sound like both.

With an action present the composition is fixed: sections lead, action trails.

## The accessory

An ``BNTabBarAccessory`` is an arbitrary host view shown above the bar — a running session, a
mini player. The control owns its place, its appearance and the height it adds; the host
owns the content. The bar folds the accessory's height into ``BNTabBarView/effectiveHeight``
and reports it through ``BNTabBarView/onEffectiveHeightChange``, so scroll views stay clear.

## Theming and motion

Every value the bar draws comes from ``BNTabBarTheme`` — geometry, palette, typography, icon
weights and ``BNTabBarMotion`` springs. There are no literals in the control, so a second app
adopts the kit by swapping the theme. The touch target never drops below 44 pt whatever the
theme asks for.

## Accessibility

The bar adapts on its own: it steps aside for the keyboard, degrades springs under Reduce
Motion, turns opaque under Reduce Transparency, and keeps section labels legible as text
grows. VoiceOver announces each section
as "Tab N of M" with its selected state, and a long press is published as a custom action.

## Topics

### Set up the bar

- ``BNTabBarView``
- ``BNTabBarItem``
- ``BNTabBarConfiguration``

### Add slots

- ``BNTabBarAction``
- ``BNTabBarAccessory``

### Customize appearance

- ``BNTabBarTheme``
- ``BNTabBarMaterial``
- ``BNTabBarLensRenderer``
- ``BNTabBarItemRenderer``
