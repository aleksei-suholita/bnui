# Changelog

Every release of BNUI. The kit follows semantic versioning; while it is at 0.x, a minor release
may break the API and a patch release does not. Each entry lists what is breaking, what is added
and what is fixed, by product.

## 0.3.0 — 2026-10-09

### Breaking

- `BNUIGallery`: every public type carries the `BN` prefix — `BNGalleryPage`, `BNGalleryKnob`,
  `BNGalleryViewController`, `BNGalleryPageViewController`, `BNGalleryBackdrop`,
  `BNGalleryEventReporting`, `BNGalleryEventFeedEdge`.
- `BNUIGallery`: a page's `fillsDemoArea`, `demoAreaFraction` and `isBackground` are one
  `layout: BNGalleryLayout` — `.centred`, `.width(at:)`, `.fill(share:)`, `.background`.

### Added

- `BNUIGallery`: `BNGallery.present(_:from:openingPageTitled:animated:)` opens the gallery from
  any app; `BNGallery.launchPageTitle` reads `-OpenGallery <Title>`; `BNGallery.post(_:)` writes
  to the event feed of the page on screen.
- `BNUIGallery`: `BNGalleryDemoPage` — a page from a demo and knobs bound to its properties by
  key path. A knob reads its starting value off the demo, and Reset writes it back.
- `BNUIGallery`: `.width(at:)` lays a demo across the stage at its own height — a field in the
  middle with the screen's margins, a bar at an edge from edge to edge.
- `BNUIGallery`: `BNGalleryDemoPage(_:presenting:controller:knobs:)` — a page for an alert, a
  sheet, a popover or a cover. The stage shows a Present button; each tap builds the controller
  from the props the knobs drive and presents it in the stage's appearance, text size and
  direction. The feed says when it is presented and when it is gone; Reset dismisses it.
- `BNUIGallery`: typing into a demo moves the inspector out of the way, so a field or a composer
  sits on the keyboard; a button in the navigation bar puts the keyboard down.
- `BNUIGallery`: `BNGalleryDemoPage(_:props:content:knobs:)` — a page for a SwiftUI view drawn
  from props the knobs drive, `ObservableObject` or, from iOS 17, `@Observable`. The view is
  hosted by a child controller, so a `.sheet` or an `.alert` inside it presents.
- `BNUIGallery`: `.states(_:)` on a demo page shows the demo in several named states at once; a
  knob moves them all, and brought back to its start puts each back in its state.
- `BNUIGallery`: the stage menu's tools — Width (320, 375 or 430 points, with a compact size
  class), Animation Speed (×0.5, ×0.25, ×0.1; Core Animation on the stage only), Frame Rate
  (frames per second and hitches since the page opened) and View Outlines.
- `BNUIGallery`: the package trait `GalleryInRelease` compiles the gallery in every
  configuration — for a TestFlight build, or a configuration Xcode does not take for debug by
  its name. Off by default: without it the gallery is Debug only, as before.
- `BNUIGallery`: its public API is listed in `api/BNUI.api` with the rest of the kit, so a change
  to it shows in the diff.

### Fixed

- `BNUIGallery`: on iOS 26 a horizontal swipe anywhere on a page no longer pops it; the content
  swipe back is switched off along with the edge one.

## 0.2.0 — 2026-10-09

### Breaking

- `BNUIButton`, `BNUITabBar`: the SwiftUI faces take what the control is in the initializer and
  how it looks from modifiers, which reach every control beneath them. Style, size, theme,
  material, haptics and every configuration field are `bnButton…`, `bnTabBar…` and
  `bnTabView…` modifiers, declared on any view and again on the face; the old initializer
  parameters are gone.
- `BNUIButton`: `BN.Button("Title")`, `BN.Button("Title", systemImage:)` and
  `BN.Button(content)`, each with `isLoading:`. `status:` is gone. `.bnButtonDisabled(_:)`
  disables the kit's way, with the refusal; SwiftUI's `.disabled()` disables silently, since it
  lets no touch through. A busy button stays busy under both. `.controlSize` picks the step of
  the size scale.
- `BNUITabBar`: `BN.TabView` and `BN.TabBar` are built from `BN.Tab` values — SwiftUI's `Tab`
  from iOS 16 — and select by any `Hashable` value instead of a string id; events hand back the
  value. `BN.TabView.Tab` is gone. The action button and its handler are one modifier,
  `.action(_:perform:)`, in place of the `action:` parameter and `.onAction`.
- `BNUITabBar`: a section's badge is a `BNTabBarBadge` — `.count`, `.text` or `.dot` — in place
  of a string. `BN.Tab.badge(_:)` takes an `Int`, a `String` or a `BNTabBarBadge?`.

### Added

- `BNUITabBar`: `BNTabBarContainerViewController` takes the bar's `material`, `lensRenderer`,
  `itemRenderer` and `haptics`, as `BNTabBarView` does.
- `BNUITabBar`: badges. A count is capped at `BNTabBarMetrics.badgeCountLimit` ("99+") and
  written in the user's digits; a dot badge; VoiceOver reads the host's words for a badge. A
  badge grows away from the icon and stops following Dynamic Type at
  `badgeMaximumContentSizeCategory`. More wears a dot while a section behind it has a badge.
- `BNUITabBar`: `BNTabBarItemRendering.updateBadge(_:transition:)`, so a renderer can draw a
  new badge in place. Its default answers `false`, and such a renderer is rebuilt as before.
- `BNUIButton`: `BNButton` sends the standard `UIControl` touch events — `.touchDown`,
  `.touchDownRepeat`, the drags, `.touchUpInside`, `.touchUpOutside`, `.touchCancel` — so a
  target bound to `.touchUpInside` hears a tap instead of nothing. `.touchUpInside` comes only
  with the action; `BNButtonInteraction.Outcome.controlEvents` carries the rule.
- `BNUIButton`: `BNButton.onTouchCancel` and `BN.Button.onTouchCancel(_:)` — a touch that ended
  without a lift that counts: the system took it, the button turned disabled or loading under
  the finger, or the cooldown swallowed the lift.

### Fixed

- `BNUIButton`: setting `isEnabled` no longer ends `loading` — busy wins over disabled. SwiftUI
  sets the flag on a wrapped control under `.disabled()`, which took the spinner away from a
  busy `BN.Button`.
- `BNUITabBar`: changing nothing but badges no longer rebuilds the bar. A finger on the bar
  keeps its gesture while a count changes, and a badge pops in, out and cross-fades instead of
  appearing at once.
- `BNUIButton`: `onTouchDown` is always followed by exactly one `onTouchUp` or `onTouchCancel`,
  and a touch the button does not accept reports none of them. `onTouchUp` used to come for a
  refused touch as well, and not at all for a cancelled one. `onTouchUp(true)` now comes only
  with the action, as `.touchUpInside` does.
- `BNUIButton`: a change of Dynamic Type, appearance, Reduce Motion or Reduce Transparency while
  a finger is on `BNButton` waits for the finger to lift instead of rebuilding the button under
  it and losing the tap.

## 0.1.0 — 2026-10-08

The first public release.

### Added

- `BNUIButton`: `BNButton` and its SwiftUI face `BN.Button`. Styles and sizes as values, Liquid
  Glass, blur and solid materials, a haptic contract, a loading mode that keeps the button's size,
  title wrapping, VoiceOver and Dynamic Type support.
- `BNUITabBar`: `BNTabBarView`, `BNTabBarContainerViewController` and their SwiftUI faces
  `BN.TabBar` and `BN.TabView`. A selection lens that follows the finger, an action and an
  accessory slot, a "More" section when the sections outgrow the width.
- `BNUICore`: springs, curves and transitions, one haptic engine with a merge rule, shapes and the
  blur plate the translucent materials draw.
- `BNUIGallery`: a debug-only showcase with a page per control.
