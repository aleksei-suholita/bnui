# Changelog

Every release of BNUI. The kit follows semantic versioning; while it is at 0.x, a minor release
may break the API and a patch release does not. Each entry lists what is breaking, what is added
and what is fixed, by product.

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
