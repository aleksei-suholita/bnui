# Building a Button

Wire up ``BNButton``, choose a style, and let the control keep the promises the platform
does not.

## Overview

``BNButton`` is a binary action: one press, one result. It shows and reports — it never
performs the action, holds business state or navigates.

```swift
let finish = BNButton(content: .title("Finish"), style: .primary)
finish.onTap = { session.finish() }
```

It is built on `UIControl` rather than `UIButton` on purpose. From iOS 27 the appearance of
a `UIButton` stops belonging to the developer, and `UIButton.Configuration` will not let a
designer set so much as the disabled colour. Starting one layer lower also buys the
granularity the rest of this article depends on: the speed of a press, a haptic contract,
and a loading mode that does not move the button.

## Styles

A style is a value, not a case in an enum the control owns. The kit ships four —
``BNButtonStyle/primary``, ``BNButtonStyle/secondary``, ``BNButtonStyle/ghost`` and
``BNButtonStyle/destructive`` — and a host that needs a fifth declares it and passes it in,
without touching the control or the theme.

```swift
let brand = BNButtonStyle(
    id: "brand",
    fill: BNButtonColorSet(.systemIndigo),
    title: BNButtonColorSet(.white),
    material: BNGlassButtonMaterial(tinted: true)
)
button.style = brand
```

The material belongs to the style because degradation runs by style: when glass does not fit
the budget, the style goes flat and the control stays exactly as it was.

## Sizes and width

``BNButtonSize`` is a value too — `.small`, `.medium`, `.large`, or one of your own. Its
`height` is the *visual* height; the touch target is a separate guarantee (see below).

``BNButtonConfiguration/width`` decides the rest: `.hug` for content-sized, `.fill` for a
full-width call to action, `.fixed` for a set width. A long title truncates or wraps by
``BNButtonConfiguration/titleBehavior`` — the choice `UIButton.Configuration` does not
offer. A wrapped title keeps its first line where a single line sits, and each line after it adds
its own height. The corners round no further than ``BNButtonSize/maximumCornerRadius`` — the
radius the size has on one line — so a capsule grown tall turns into a rounded rectangle instead of
rounding into the text.

A `.hug` button whose content is one icon and nothing else comes out square, so a capsule
shape reads as a circle. The size decides that circle and the glyph never does: buttons of one
size stay one size whatever their symbols, and a row of them lines up. A glyph wider or taller
than the circle allows — ``BNButtonSize/iconOnlyInset`` from every edge — is shrunk to fit
rather than the button grown, and says so in the console. The size's `minWidth` is a floor for
buttons carrying words and does not apply here. Two icons without a title are content, not a
glyph, and size like a title does.

## Content

Title, title with a leading or trailing icon, an icon alone, or an arbitrary view:

```swift
BNButton(content: .title("Continue"))
BNButton(content: BNButtonContent(title: "Delete", leadingIcon: .symbol("trash")), style: .destructive)
BNButton(content: .icon(.symbol("gearshape"), accessibilityLabel: "Settings"))

let animated = BNButton(content: BNButtonContent(accessibilityLabel: "Recording"))
animated.contentRenderer = BNCustomViewContentRenderer { PulsingGlyphView() }
```

An icon on its own carries no words, so it owes VoiceOver a label — the control asserts on
that rather than shipping a silent button.

## State

`loading` and `disabled` belong to the host; the control never starts work of its own.

```swift
purchase.setStatus(.loading, animated: true)
let result = await purchases.buy(product)
purchase.setStatus(.enabled, animated: true)
```

Entering `loading` does not move the button. The content stays in the hierarchy at zero
alpha — so it keeps deciding the width — and the spinner is centred at a fixed size that
``BNButtonSize/effectiveMinWidth`` has already reserved room for.

`disabled` draws in the theme's own colours, refuses touches, and reports itself unavailable
to VoiceOver. `loading` stays available and reports itself busy.

### Refusing a touch

A disabled button that simply ignores a finger is indistinguishable from a broken one — the
user is left deciding whether the tap even landed. So it answers: a flash of
``BNButtonTheme/rejectionColor``, a short head shake, and a `.error` haptic. The host hears
it too, through ``BNButton/onRejected``, because the control can say "no" but only the host
knows why.

```swift
save.onRejected = { self.highlightMissingFields() }
```

Everything about it lives in ``BNButtonMotion/rejection``: distance, number of shakes,
flash, and whether the haptic fires at all. `.none` restores plain silence. `loading` never
refuses — busy is not the same as forbidden, and shaking there would tell the user their tap
was wrong when it was merely early.

Under Reduce Motion the shake goes and the flash stays: the refusal survives, the movement
does not.

## Motion

Press is a spring; release is a spring that knows how fast you were. A quick click returns
springier and with a shove, an unhurried press returns calmly — the reward for speed the
system button hints at and never quite gives you. Every animation is interruptible: a new
touch takes the movement over on whatever frame it finds it.

All of it comes from ``BNButtonMotion``, and Reduce Motion resolves it to a version with no
overshoot and no shove. The button still works; only the movement goes.

The numbers in the theme are placeholders until someone has sat with the gallery page and a
system button side by side on a device. That page has a slider for each of them.

## Materials

Three materials ship with the kit. ``BNGlassButtonMaterial`` is the real system
`UIGlassEffect`, on iOS 26 and later, used precisely because it answers Reduce Transparency,
Increase Contrast and Low Power itself, and because its `isInteractive` response — the light
tracking the touch point — is not reproducible by hand. When it is on, the control stands its
own compression down rather than doubling it. ``BNBlurButtonMaterial`` is a system material on
every version — any `UIBlurEffect.Style`, `.systemMaterial` unless you pick another; it does not
answer a finger, so the press is the control's. ``BNSolidButtonMaterial`` is flat paint. The
translucent standard styles wear glass on iOS 26 and `.systemMaterial` below it.

Under Reduce Transparency the control swaps the style's `opaqueFallback` in, whatever material
was asked for: the user turned translucency off everywhere, and a material can only speak for
itself.

## Accessibility

The guarantees the control keeps whatever the theme asks for:

- The touch area is never smaller than 44 × 44 pt, however small the button is drawn. Set
  ``BNButton/showsHitTargetOutline`` to see it.
- Dynamic Type grows the button rather than cropping the label, and at accessibility sizes
  an icon and a title restack vertically instead of truncating.
- Right-to-left mirrors the layout; the control never sets `semanticContentAttribute`.
- The trait is `.button`; `disabled` is unavailable and `loading` is busy.
- Reduce Transparency is answered by the control as a whole, not by each material.

## Topics

### Create a button

- ``BNButton/init(content:style:size:configuration:theme:material:haptics:accessibilityOverrides:)``
- ``BNButtonContent``
- ``BNButtonStyle``
- ``BNButtonSize``

### Respond to presses

- ``BNButton/onTap``
- ``BNButton/onTouchDown``
- ``BNButton/onTouchUp``
- ``BNButtonHaptics``

### Drive its state

- ``BNButton/status``
- ``BNButton/setStatus(_:animated:)``
- ``BNButtonStatus``

### Customise it

- ``BNButtonTheme``
- ``BNButtonMotion``
- ``BNButtonMaterial``
- ``BNButtonContentRenderer``
