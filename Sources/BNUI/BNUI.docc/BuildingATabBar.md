# Building a Tab Bar

Compose a bottom navigation bar from sections, an optional action, and an optional accessory.

## Overview

The kit gives the bar two ways in. ``BNTabBarController`` replaces `UITabBarController`: it
holds a controller per tab and switches between them itself — what most apps want.
``BNTabBarView`` is the bar alone, for a host that switches its content by itself.

## The tab bar controller

Each tab is a bar item and the controller shown while it is selected:

```swift
let tabs = BNTabBarController(
    tabs: [
        .init(item: BNTabBarItem(id: "home", icon: .symbol("house"), selectedIcon: .symbol("house.fill"),
                                 title: "Home"),
              viewController: UINavigationController(rootViewController: HomeViewController())),
        .init(item: BNTabBarItem(id: "reports", icon: .symbol("chart.bar"), selectedIcon: .symbol("chart.bar.fill"),
                                 title: "Reports"),
              viewController: UINavigationController(rootViewController: ReportsViewController())),
    ],
    action: BNTabBarAction(icon: .symbol("plus"), accessibilityLabel: "New", style: .prominent)
)
tabs.onAction = { coordinator.create() }
window.rootViewController = tabs
```

The first tab is on screen at start. The bar floats over the content where the system's floating
bar stands on iOS 26 — ``BNTabBarController/Placement`` puts it elsewhere — and every screen's
safe area reaches up to the bar's top, so a scroll view keeps its last row clear of the bar
without being told. Every tab's controller is the tab bar controller's child for as long as it is
a tab: a tab left and come back to keeps its scroll position and its navigation stack, and a
screen in any tab finds the controller as `bnTabBarController`, the way it would find
`tabBarController`. A tab's stack is a plain `UINavigationController`.

### Selection

The controller owns which tab is on screen. ``BNTabBarController/onSelect`` reports a switch the
user made, after it is done; ``BNTabBarController/select(tabID:animated:)`` makes one from the
outside — after a modal flow saves, say — and is not reported back.
``BNTabBarController/shouldSelect`` is asked first and can turn a tab down: a locked one that
offers an invitation instead stays unselected, and the lens goes back. A second tap on the tab on
screen takes its stack back to the root, as under `UITabBarController`, and
``BNTabBarController/onReselect`` says so — the place to scroll the root back to its top.

### Hiding the bar

``BNTabBarController/setTabBarHidden(_:animated:)`` slides the bar away and back — for a
full-screen scene, or a screen that is to be without it — and every tab's content drops its inset
with it. Such a screen hides the bar as it appears and shows it as it goes:

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    bnTabBarController?.setTabBarHidden(true, animated: animated)
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    bnTabBarController?.setTabBarHidden(false, animated: animated)
}
```

Shown again in the middle of a swipe back, the bar comes back only once the swipe completes; a
cancelled one leaves the screen on top and the bar hidden. The bar does not follow
`hidesBottomBarWhenPushed`: a navigation controller says what it pushes to the system's tab bar
controller alone.

### Changing the tabs

A badge changes by the tab's id, so it holds whatever order the tabs stand in, and so does the
icon a tab shows while it is selected — a camera's tab showing the filter in use. Both change in
place: the badge pops, the icon gives way by the system's symbol replace effect — from iOS 18 the
one that morphs a symbol into its relative — or cross-fades when it is a picture:

```swift
tabs.setBadge(.count(3), for: "inbox")
tabs.setSelectedIcon(.symbol("camera.filters"), for: "camera")
```

A title changes through ``BNTabBarController/items``. Which tabs there are changes through
``BNTabBarController/tabs`` — a tab that appears with an invitation, a set an experiment decides.
The tab on screen stays on screen while it is among them; otherwise the first one takes its place,
and ``BNTabBarController/onSelect`` says so. The action can change with the app's state through
``BNTabBarController/action``.

## The bar on its own

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

The bar is sized by its content and detached from the screen edges; the host gives it the
width, and the sections' capsule aligns itself within that width with
``BNTabBarConfiguration/Alignment``. Set ``BNTabBarConfiguration/width`` to
``BNTabBarConfiguration/Width/fill`` and the sections share the whole width instead, as the
system's tab bar does on iOS 26, up to ``BNTabBarMetrics/maxBarWidth``.

## Sections and More

Sections stand in the capsule as long as the width gives each of them
``BNTabBarMetrics/minimumItemWidth``, and never more than six. Past that, the last slot is
``BNTabBarConfiguration/moreItem``, which opens the rest in a system menu; a section chosen
there is reported like any other, and the lens marks More while it is active. An action
takes its width before the sections do, so it brings More sooner. How many slots stand is
decided by the width alone, not by the labels, so a change of text size never moves a
section into the menu.

A bar short of room gives way in a fixed order: sections narrow below
``BNTabBarMetrics/preferredItemWidth``, then every label shrinks by one factor down to
``BNTabBarMetrics/minimumLabelScale``, then labels go and the bar shows icons alone. Sections
never narrow past the 44 pt touch target, whatever the theme asks. VoiceOver names every
section whatever is drawn.
The rules live in ``BNTabBarLayoutSolver``, where they are tested without a simulator.

## Selection effects

A section's symbol plays an effect once when the section is chosen — not when it is chosen again.
It is written the way the system's symbol effects are, with the options each effect has:

```swift
BNTabBarItem(id: "camera", icon: .image(cameraSymbol), title: "Camera",
             selectionAnimation: .bounce.down.byLayer)
BNTabBarItem(id: "timer", icon: .symbol("timer"), title: "Timer",
             selectionAnimation: .breathe.pulse)
```

The default is a plain bounce; `.none` keeps the symbol still. An app's own symbol, passed as an
image, plays like a system one; a picture does not. Symbol effects arrive with iOS 17, and an
effect the system does not have yet — wiggle, rotate and breathe before iOS 18, drawing on before
iOS 26 — plays as a plain bounce. Reduce Motion stills them all. A parameter of the app's own that
passes an effect on is written `some BNTabBarSymbolEffect`.

## The selection lens

Selection is drawn by a *lens* — a marker that follows the finger and reveals the active
section, rather than a colour swapped onto an item. Pressing moves the lens onto the section
under the finger; dragging along the bar carries it with the finger, and releasing anywhere
commits the nearest section. There is no cancel-by-leaving: a gesture always resolves into a
choice.

The marker is a flat tinted capsule and never turns to glass itself, nor grows by itself. The
sections and the marker lie inside the material, so on glass that answers a touch they move with
the glass: it lifts them when a finger lands, and stretches them with it when the finger pulls it
past the bar's end or off the capsule — the system's own response. Over blur or paint, and under
Reduce Motion, the marker only travels. The lens is still a replaceable seam — ``BNMaskedLensRenderer``
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

## Badges

A section's ``BNBadge`` is a count, a short text or a dot — the same badge a ``BNButton`` wears:

```swift
BNTabBarItem(id: "inbox", icon: .symbol("tray"), title: "Inbox",
             badge: .count(unread, accessibilityLabel: "\(unread) unread"))
BNTabBarItem(id: "news", icon: .symbol("newspaper"), title: "News",
             badge: .dot(accessibilityLabel: "New posts"))
```

The bar formats a count: zero or less shows no badge, the user's digits are used, and past
``BNBadgeTheme/countLimit`` it reads "99+". A badge is pinned just inside a trailing corner of
the icon — the top, or the bottom by ``BNBadgeTheme/position``, where it lies over a shown
title — and grows away from the icon, but never past its own section: where the section is too
narrow, it slides back over the icon rather than onto the next one. It follows Dynamic Type only
up to ``BNBadgeTheme/maximumContentSizeCategory`` — the icon keeps one size. Its look is the
theme's ``BNTabBarTheme/badge``.

One badge changes by its section's id — ``BNTabBarView/setBadge(_:for:)``, and the same on the
tab bar controller — and an id the bar does not have is passed over. Changing nothing but badges
redraws the badges alone: they pop in and out and a number cross-fades, while a finger on the bar
keeps its gesture.

The bar draws the badges above its material rather than in it: system glass blends what lies
inside it into itself, and a badge's red comes out washed. A badge therefore does not rise with
the glass under a finger. A custom renderer gives the bar the view to hang a badge from —
``BNTabBarItemRendering/badgeAnchor`` — or draws its own with a ``BNBadgeView``, inside the
material, and joins in through ``BNTabBarItemRendering/updateBadge(_:transition:)``; one that
does neither is rebuilt as before.

VoiceOver reads a badge in the host's words, or as shown when there are none; a dot always
brings its own. A section behind More shows its badge as the menu item's subtitle, and More
wears a dot while any of them has one, naming them in its spoken value.

## The vertical bar on iPhone Duo

iPhone Duo moves an app's bars into a strip beside the content — the status bar, the navigation
bar's buttons, the tab bar — when the app is built against the iOS 27.1 SDK.
``BNTabBarController`` follows it: where the system keeps that strip, the bar stands
in it as a column at its bottom, where the system puts its own tab bar. A column shows icons
only, puts the action under the sections and keeps clear of what the system reserves in the
strip, such as the camera. The bar turns into a column only when every section fits there;
otherwise it stays a row along the bottom, as it does on every other iPhone.

A tab opts out as it does under `UITabBarController`: its controller's
`preferredVerticalBarBehavior` is `.disabled`, and the bar goes back to the bottom with the
system's bars. A ``BNTabBarView`` you place yourself stays a row.

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

- ``BNTabBarController``
- ``BNTabBarView``
- ``BNTabBarItem``
- ``BNTabBarSymbolEffect``
- ``BNBadge``
- ``BNTabBarConfiguration``

### Add slots

- ``BNTabBarAction``
- ``BNTabBarAccessory``

### Customize appearance

- ``BNTabBarTheme``
- ``BNTabBarMaterial``
- ``BNTabBarLensRenderer``
- ``BNTabBarItemRenderer``
