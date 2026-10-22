# Changelog

Every release of BNUI. The kit follows semantic versioning; while it is at 0.x, a minor release
may break the API and a patch release does not. Each entry lists what is breaking, what is added
and what is fixed, by product.

## 0.8.0 — 2026-10-23

### Breaking

- `BNUITabBar`: the lens no longer grows under the finger by itself — the glass lifts it now — so
  `BNTabBarMetrics.liftedScale` and `BNTabBarMaterial.allowsLensSwell` are gone. A theme drops the
  `liftedScale:` argument; a material of the host's own drops `allowsLensSwell`.

### Added

- `BNUITabBar`: the sections and the lens lie inside the bar's material. On system glass they move
  with the glass itself, by its own response: it lifts them when a finger lands, and when the
  finger pulls it past the bar's end or up off the capsule, they stretch with it, in step. A lens
  renderer draws no glass of its own — inside glass it would be glass on glass.

### Fixed

- `BNUITabBar`: no more "Unable to simultaneously satisfy constraints" when the sections change or
  the bar narrows. A layout pass forced before the bar solves its widths met the sections at
  widths meant for another room — five preferred widths in a bar too narrow for them, a wider
  bar's widths after it narrowed — and UIKit broke a constraint to fit them. For that moment the
  capsule now reaches past the bar instead; the sections keep their lengths, so the lens stays on
  them.
- `BNUITabBar`: turning the accessory on with More in the bar no longer crashes. The accessory's
  entrance laid the bar out in the middle of a rebuild, and the slots were rebuilt into the lens
  just taken off the bar, with More's button pinned to it — which UIKit traps.

## 0.7.2 — 2026-10-14

### Fixed

- `BNUIButton`: a button with an SF Symbol is as tall as its size. A symbol's alignment rectangle
  reaches past its image — 1.7 pt above and below a 20 pt bold `plus` — and the button grew by that
  much: 48 pt laid out at 51.3, 40 at 43.3. The icon is now laid out by the image's own box, the one
  the button measures. A tab bar's action is such a button too.
- `BNUIGallery`: a page whose only knob is short opens its inspector. The stop that shows every
  knob was dropped as too close to the collapsed one, which left the header alone and the knob out
  of reach.
- `BNUIGallery`: a demo that switches between hugging and filling — a knob that sets a button's
  width — follows at once on a `.centred` page and in its states. The rule was read on the holder's
  own layout pass, which a demo held edge to edge never brought; Auto Layout now decides it.

## 0.7.1 — 2026-10-13

### Fixed

- `BNUICore`: a badge changed quickly no longer disappears. Going from a dot to a text and back,
  the part leaving finished after the one that had come back and hid it; a number changed while the
  badge was popping in stopped the pop and stayed half drawn. Each part of `BNBadgeView` now keeps
  its own pop — on a tab bar's section and on a button alike.

## 0.7.0 — 2026-10-13

### Breaking

- `BNUITabBar`: `BNTabBarTheme.IconSpec`'s initializer takes a `scale`, and
  `BNTabBarConfiguration`'s a `width` — a call without them reads as before.

### Added

- `BNUITabBar`: `BNTabBarConfiguration.width` — `.hug`, as before, or `.fill`: the sections share
  the whole width of the bar, with an action or without one, as the system's tab bar does on iOS 26,
  up to the theme's `maxBarWidth`. SwiftUI faces take it through `bnTabBarWidth(_:)`.
- `BNUITabBar`: `BNTabBarTheme.IconSpec.scale`, the symbols' `UIImage.SymbolScale` — `.medium`
  unless set; the system's tab bar on iOS 26 draws `.large`. Every section's symbol takes it, the
  app's own too, and so does the box an image is fitted into.

### Fixed

- All products: on iOS 18 an app crashed — "pointer being freed was not allocated" — when a kit
  object went away inside `TaskLocal.withValue`, such as a button changing state there. Under the
  kit's default main-actor isolation every class's deinit hopped to the main actor, and that
  runtime frees a task-local value it does not own. Every class now declares a nonisolated deinit,
  and the gate fails on one that does not.
- `BNUITabBar`: the lens could stay where the sections used to be after the bar's width changed —
  44 pt wide, or across two sections, when the sections were given before the bar had a width,
  and where the portrait put it after a rotation. It read the sections' frames before their stack
  had laid them out at their solved widths, and waited for a second layout pass a rotation does not
  bring; the widths are now solved and the lens placed in one pass. A width that changed while a
  selection spring was running is looked at again once it lands, too.
- `BNUITabBar`: sections a rotation moves into More or out of it no longer grow out of nothing at
  the bar's leading edge; they appear in place and move with the rotation.
- `BNUITabBar`: an app's own symbol passed as an image is laid out as a system symbol is — at the
  theme's point size, weight and scale. It was fitted into a box by its alignment rectangle and
  drew about a fifth smaller than the system's beside it; `size` is left aside for a symbol image.

## 0.6.0 — 2026-10-13

### Breaking

- `BNUITabBar`: `BNTabBarSymbolAnimation` is a struct, written through `BNTabBarSymbolEffect` the
  way the system's symbol effects are. `.bounce`, `.pulse`, `.wiggle`, `.rotate`, `.breathe` and
  `.none` read as before; a `switch` over them no longer compiles. `BNTabBarItem`'s initializer and
  `BN.Tab.selectionAnimation(_:)` take `some BNTabBarSymbolEffect`, and so does a parameter of the
  app's own that passes one on.

### Added

- `BNUICore`: `BNBadgeView` is public — the badge the kit's controls draw, for a custom tab bar
  item renderer to draw the same one. `pin(toCornerOf:)` hangs it from a view's trailing corner
  at the theme's position, `keepInside(_:)` keeps a long text inside the section, and
  `spokenText` is what the section says for it.
- `BNUITabBar`: a selection effect takes the options the system's has — `.bounce.down.byLayer`,
  `.wiggle.forward`, `.wiggle.custom(angle:)`, `.rotate.counterClockwise`, `.breathe.pulse`,
  `.pulse.wholeSymbol` — and `.drawOn`, with `.individually`, on iOS 26. Where the system has no
  such effect yet, a plain bounce plays, as before.
- `BNUITabBar`: an app's own symbol passed as an image — `.image(UIImage(named: "camera.symbol"))`
  — plays the selection effect as a system symbol does. A picture still does not.

### Fixed

- `BNUITabBar`: when the bar's width moved a section into More or out of it, the lens could stay
  on a slot whose width was not yet solved — narrow and off its section — until something else
  laid the bar out.
- `BNUITabBar`: a row takes a touch only where it draws — the capsule, the action with its touch
  target's margin, the accessory — as a column already did. The empty rest of its view passes the
  touch to the content under it. A column now counts the action's margin too.

## 0.5.0 — 2026-10-12

### Breaking

- `BNUICore`: `BNTabBarBadge` is `BNBadge`, moved from `BNUITabBar` — the badge a button wears
  too. Its cases and rules are as before.
- `BNUITabBar`: a badge's look is `BNTabBarTheme.badge`, a `BNBadgeTheme`. `Palette.badgeBackground`
  and `.badgeText` are `badge.background` and `.text`; `Typography.badge` and
  `.badgeMaximumContentSizeCategory` are `badge.font` and `.maximumContentSizeCategory`;
  `BNTabBarMetrics.badgeCountLimit`, `.badgeOverlap`, `.badgeDotSide` and `.badgeAppearScale` are
  `badge.countLimit`, `.overlap`, `.dotSide` and `.appearScale`. A badge's text is semibold
  `caption2` by default, rather than regular; a theme with a font of its own keeps it.
- `BNUITabBar`: `BNTabBarItem.ImageRendering` is `BNImageRendering` in `BNUICore`.
  `.image(_:size:rendering:)` reads as before.
- `BNUIButton`: `BNButtonIcon.image` carries a rendering — `.image(_:flipsForRTL:rendering:)`.
  `.image(picture)` reads as before; a pattern that matches it binds three values.

### Added

- `BNUIButton`: an image icon in its own colours — `.image(logo, rendering: .original)`. A disabled
  button dims it rather than recolouring it.
- `BNUIButton`: `BNButton.badge` — a count, a text or a dot on the button's outline, moving with
  its press and read by VoiceOver with the button; its look is `BNButtonTheme.badge`. `BN.Button`
  takes it through `.badge(_:)`.
- `BNUIButton`: `BNButton.menu`, with `showsMenuAsPrimaryAction` as on `UIButton`: a tap opens the
  menu and sends `.menuActionTriggered` instead of the action, or a long press opens it and a tap
  still fires.
- `BNUICore`: `BNBadgeTheme.position` — a badge at the top or the bottom trailing corner, on a
  button's outline and on a section's icon alike.
- `BNUITabBar`: a long badge — "99+" — stays inside its section, sliding back over the icon where
  there is no room, instead of lying on the next section.
- `BNUITabBar`: `setBadge(_:for:)` on `BNTabBarView` and `BNTabBarContainerViewController` — one
  badge by its section's id, drawn in place; an unknown id is passed over.
- `BNUITabBar`: the action button draws an `.original` image in its own colours.
- `BNUIGallery`: the Button page has knobs for a badge, a menu and a picture icon.
- `BNUIButton`: a button without a title no longer needs a label — `.icon(_:accessibilityLabel:)`
  takes none, and a debug build no longer stops on one without it. VoiceOver then reads it only as
  a button.

### Fixed

- `BNUIButton`: a label set through the button's own `accessibilityLabel` is no longer wiped when
  the button rebuilds — on a new theme, a text size, light or dark. It wins over the content's
  label, as on `UIButton`.
- `BNUIButton`: an image taller than the size holds — an 80 pt asset beside a title, or one of two
  icons — no longer grows the button to its height. It is shrunk to one line of the size, both
  icons together, as a lone icon is shrunk into its circle.

## 0.4.1 — 2026-10-12

No change to the API.

### Added

- The documentation is hosted on the
  [Swift Package Index](https://swiftpackageindex.com/aleksei-suholita/bnui/documentation/bnui):
  the kit's reference and articles, and the gallery's beside them.
- `BNUIGallery`: documentation of its own — pages, knobs, layouts, the catalogue and the way in.
- `BNUITabBar`: *Building a Tab Bar* opens with `BNTabBarContainerViewController` — its tabs, the
  safe area it gives each of them, selection from the outside, badges — and the container has a
  page of its own in the reference.

### Fixed

- `BNUITabBar`: *Building a Tab Bar* said the lens never grows under the finger. Over glass that
  answers a touch it swells, as `BNTabBarMetrics.liftedScale` says; over blur or paint, and under
  Reduce Motion, it keeps its size.

## 0.4.0 — 2026-10-12

### Breaking

- `BNUIGallery`: `BNGalleryBackdrop` is a struct rather than an enum, so an app can add its own:
  `.plain`, `.interface`, `.photos`, `.bright` and `.night` read as before, but it is no longer
  `CaseIterable` or `Sendable`, and a `switch` over it no longer compiles.
- `BNUIGallery`: `BNGalleryKnob.Control` has four more cases; a `switch` over it needs them.
- `BNUIGallery`: the `GalleryInRelease` trait is gone, and the gallery is compiled in every
  configuration — a TestFlight build has it with no setting and on any `swift-tools-version`. An
  app keeps the way in behind a condition of its own; one that links `BNUIGallery` carries its code
  into the App Store build too. A manifest that names the trait drops it.
- `BNUIGallery`: `BNGalleryLayout.width(at:)` is `width(at:margin:)`; a pattern that matches it
  names the margin.
- `BNUITabBar`: `BNTabBarItem.Icon.image` carries a size and a rendering —
  `.image(_:size:rendering:)`. `.image(picture)` reads as before; a pattern that matches it binds
  three values.

### Added

- `BNUIGallery`: knobs for a colour (`UIColor`, `UIColor?` or SwiftUI `Color`), a stepper, a date
  and a view of the page's own — `.color`, `.stepper`, `.date`, `.custom` on a demo page, and
  `.color`, `.stepper`, `.date`, `.custom` cases of `BNGalleryKnob.Control`.
- `BNUIGallery`: commands of a page's own in a ⋯ menu of its navigation bar —
  `.action(_:image:perform:)` on a demo page, `makeActions(for:)` on `BNGalleryPage`.
- `BNUIGallery`: `BNGalleryConfiguration` — the catalogue's title, the order and icons of its
  sections, and an app's own backdrops (`BNGalleryBackdrop.image(_:title:purpose:)`,
  `.view(title:purpose:make:)`). `BNGallery.present`, `BNGalleryViewController` and
  `BNGalleryPageViewController` take it.
- `BNUITabBar`: the vertical bar of iPhone Duo. Built against the iOS 27.1 SDK,
  `BNTabBarContainerViewController` stands the bar in the strip beside the content where the
  system moves its own bars — a column of icons at the strip's bottom, the action under it — when
  every section fits there, and keeps it a row otherwise. It defers `preferredVerticalBarBehavior`
  to the tab on screen, as `UITabBarController` does, so a tab opts out with `.disabled`. Built
  with an older SDK, nothing changes. `BNTabBarLensState.axis` tells a lens which way the bar
  runs; the kit's lens swells along a column only.
- `BNUIGallery`: `then:` on a demo page's `.toggle`, `.slider`, `.text` and `.choice` — run after
  the property is written, Reset included, for a second property the value implies.
- `BNUIGallery`: `.width(at:margin:)` insets a demo from the sides — and at an edge from that
  edge — so a bar floats as a tab bar does in its container.
- `BNUITabBar`: an image section fits a box — its own `size`, or the square of a round symbol at
  the theme's point size — so an 80 pt asset no longer grows the bar; the More menu draws it at
  that size too. `rendering: .original` keeps a photo's colours, and only the lens says the
  section is chosen. `BN.Tab(_:image:size:rendering:value:)` takes both.
- `BNUITabBar`: `BNTabBarItem.badge` is a `var`, and `BNTabBarContainerViewController.items` can
  be set: `bar.items[1].badge = .count(3)` redraws that badge alone, in place.
- `BNUIGallery`: a *TabBar container* page — the container full screen, with navigation buttons
  in every tab — and an *Axis* knob on the *TabBar* page that shows the bar as a column anywhere.

### Fixed

- `BNUIButton`: a style of `BNButtonHapticEmphasis.silent` no longer ticks on touch-down — it
  mutes the press as well as the confirmation, as its documentation says. The refusal stays the
  theme's to silence (`BNButtonRejection.isHapticEnabled`).
- `BNUIGallery`: a demo that sizes itself is centred at its own width and one with no width of
  its own spans the stage, decided per demo and again whenever the demo changes its mind. On a
  page of states a button that hugs is no longer stretched, and on a `.centred` page a button
  that fills no longer collapses.
- `BNUITabBar`: a tap no longer drops the lens on the section at once. A touch shifts by a point
  as it lands, which the bar took for a drag; the lens now follows the finger from 10 pt of
  travel along the bar, the distance at which a long press already gives way to a drag.
- `BNUICore`: a capsule standing taller than wide rounds by its width, as
  `UICornerConfiguration.capsule()` does: the blur plate on every iOS, any capsule below iOS 26.

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
