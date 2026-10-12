# ``BNUIGallery``

A bench for controls — the kit's and an app's own — with knobs, backdrops, light and dark, text
sizes and right-to-left.

## Overview

The gallery is a catalogue of pages. A page puts one control on a stage and its properties in an
inspector under it. The stage's menu changes the backdrop, the appearance, the text size, the
layout direction and the width, slows animations down, counts frames and outlines views; an event
feed on the stage shows what the control reports.

The kit's controls come as pages ready to list, ``BNUIGalleryPages/all()``, and an app adds its
own beside them:

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

### Pages

``BNGalleryDemoPage`` makes most pages without a type of their own:

- A view and knobs bound to its properties by key path. A knob reads where the demo starts, and
  Reset puts it back.
- With `presenting:`, an alert, a sheet, a popover or a cover, built from props the knobs drive
  and presented from a button on the stage.
- With `props:`, a SwiftUI view drawn from props the knobs drive — `ObservableObject` or, from
  iOS 17, `@Observable`.
- ``BNGalleryDemoPage/states(_:)`` shows the demo in several named states at once, and a knob
  moves them all.
- ``BNGalleryDemoPage/action(_:image:perform:)`` puts a command of the page's own in a ⋯ menu.

Knobs come for numbers, switches, choices, text, colours, steps, dates and views of the page's
own. ``BNGalleryLayout`` says how the demo sits on the stage: centred at its own size, across the
width, over the whole stage, or as its background.

A page that needs more — a demo controller, a reset for state no knob owns — conforms to
``BNGalleryPage`` and builds its demo, knobs and commands in code.

### The catalogue

``BNGalleryConfiguration`` names the catalogue, orders its sections and adds the app's own
backdrops — a screenshot of a real screen, a mock view — beside the gallery's.
``BNGallery/present(_:from:configuration:openingPageTitled:animated:)`` shows the catalogue full
screen; an app that has a navigation stack of its own pushes ``BNGalleryViewController`` instead.
`-OpenGallery <Title>` at launch opens a page straight away, through ``BNGallery/launchPageTitle``.

### The way in

The gallery is compiled in every configuration, TestFlight's Release included, with nothing to
set. The app decides where the way in is: behind `#if DEBUG` for Debug only, or, for TestFlight,
closed at run time — TestFlight and the App Store get the same binary. An app that links
`BNUIGallery` carries its code into the App Store build either way.

## Topics

### Opening the Gallery

- ``BNGallery``
- ``BNGalleryConfiguration``
- ``BNUIGalleryPages``

### Writing a Page

- ``BNGalleryDemoPage``
- ``BNGalleryPage``
- ``BNGalleryKnob``
- ``BNGalleryLayout``
- ``BNGalleryBackdrop``

### The Event Feed

- ``BNGalleryEventReporting``
- ``BNGalleryEventFeedEdge``

### Controllers

- ``BNGalleryViewController``
- ``BNGalleryPageViewController``
