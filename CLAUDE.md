# BNUI

A library of iOS controls — a button and a tab bar, with BNUICore under them —
published as a Swift package. UIKit, iOS 16+. Glass materials exist only on iOS 26 (the system's
Liquid Glass); every version has a blur material (`BNBlur…Material`, built on the system
`UIBlurEffect.Style`s), and the kit's presets wear it below iOS 26.

Public and at 0.x: the API may break between minor versions (see «Releases»). The users' side of
the package is `README.md`; this file is for working on it.

## Products and modules

| Product | Sources | Depends on |
|---|---|---|
| `BNUICore` | `Sources/BNUICore/` | — |
| `BNUIButton` | `Sources/BNUIButton/` | `BNUICore` |
| `BNUITabBar` | `Sources/BNUITabBar/` | `BNUICore`, `BNUIButton` |
| `BNUI` | `Sources/BNUI/` — re-exports only, and the DocC catalog | every control |
| `BNUIGallery` | `Sources/BNUIGallery/` | `BNUI` |

- A control module re-exports what its API is made of (`Exports.swift`), so an app writes one
  import per control.
- What the modules share without it being API is `package`, never `public`.
- A file imports every kit module it uses: with `MemberImportVisibility` on, an import in one file
  does not reach the next.
- A new control is a new module: a folder under `Sources/`, a target and a product in
  `Package.swift`, a line in `Sources/BNUI/Exports.swift`, its name in the module list of
  `scripts/check.sh` (step «api»), a gallery page.

## Where the truth lives

- **The API is the code.** `///` comments and DocC (`Sources/BNUI/BNUI.docc`, built over the whole
  kit from the `BNUI` module's symbol graph). No document listing the methods.
- **The public surface is `api/BNUI.api`**: every public declaration with the product it belongs
  to, written by `check.sh`. Its diff is how a breaking change is seen.

## The rule the kit exists for

**The kit knows no app.** No name, no domain, no tokens. The SwiftLint rule `kit_knows_no_app`
holds the names: an app's name in any Swift file of the package, comments included, fails the lint.
Colour, font and spacing come from outside — through a theme, a style or an initializer parameter.
A control that wants a host's token is a defect of the boundary, not a convenience.

The reverse holds too: a component exactly one app needs does not live in the kit. The real test
of portability is naming a second app that needs it as it is.

## Division of labour (HARD RULE)

The heavy half is the OWNER's. The agent does NOT run `xcodebuild` or `xcrun simctl`.
`permissions.ask` in `.claude/settings.json` holds the rule: such a command never passes silently,
even in auto mode — the owner sees the request and decides.
Before handing work over the agent runs one command, and red means not done:

```bash
./scripts/check.sh   # ~10 s: format, lint, tests and coverage, iOS build, dead code, API, DocC
```

| Step | What it catches |
|---|---|
| `swiftformat --lint` | format |
| `swiftlint lint --strict` | correctness rules, the kit's boundaries (`custom_rules`), public API without a doc comment (the backlog of 2026-09-28 is in `.swiftlint.baseline`) |
| `swift test` | tests of the solvers and the shader; a warning is an error; coverage at least `COVERAGE_FLOOR` (90%) |
| `typecheck-ios.sh` | the package for the iOS simulator (debug and release) and the gallery app; a warning is an error |
| Periphery | unused code; a false positive gets `// periphery:ignore - <why>` above the declaration |
| api | a public type without the `BN` prefix, a declaration no product claims; rewrites `api/BNUI.api` |
| DocC | a broken ``` ``Symbol`` ``` link, an undocumented parameter |

The gate also runs by itself. The Stop hook (`scripts/stop-check.sh`) keeps the agent from ending
its turn while the gate is red — up to three attempts in a row. The git `pre-commit` hook
(`scripts/git-hooks/`, enabled once with `git config core.hooksPath scripts/git-hooks`) refuses a
red commit and requires the regenerated `api/BNUI.api` to be committed with an API change. Both
call `check.sh --if-changed`: when the tree has not changed since the last green run, it takes a
fraction of a second.

IMPORTANT: `swift build` and `swift test` without a triple build the package for macOS, where
`canImport(UIKit)` is false — **all UIKit code compiles empty**, and a green build proves nothing
about it. The one fast check of the controls is `typecheck-ios.sh`: `swift build --triple
arm64-apple-ios16.0-simulator`, not `xcodebuild`.

## Architecture rules (binary)

- Every public type carries the `BN` prefix. An app's name is not in the kit and cannot be.
- MainActor by default, Swift 6 strict concurrency.
- Pure solvers (geometry, motion, metrics, the haptic merge rule) are kept apart from the
  views and covered by tests: they are what `swift test` checks.
- No force unwraps outside tests; errors are never swallowed silently.
- **A control is not done without a gallery page** — `Sources/BNUIGallery`, registered in
  `BNUIGalleryPages.all()`. The gallery draws itself with its own `BNGallery*` constants, not an
  app's tokens.
- Haptics go through one engine (`BNHaptics`); continuous gestures play with `merging: false`.
  A tick goes where the finger cannot predict the result.

## File map

- `Sources/BNUICore/` — `BNHaptics`, `BNBlur` (the blur plate: system material, rim, shadow),
  `BNShapes` (`BNShape` — a control's outline from its theme, capsule or radius — and applying it
  to a view on any iOS), `BNMotion` (`BNSpring`/`BNCurve`/`BNTransition`/`BNAnimation`). There are
  no contrast checks (WCAG, a veil) and no Increase Contrast handling in the kit: removed until
  after the alpha
- `Sources/BNUIButton/` — `BNButton`: theme, roles, materials, motion
- `Sources/BNUITabBar/` — `BNTabBarView` (lens, materials, section renderers) and
  `BNTabBarContainerViewController`, a replacement for `UITabBarController` that hosts the content
  and owns the selected section; "+" lives in the bar as an action, not as a tab
- `Sources/BNUI/` — `Exports.swift` (the whole kit behind one import) and `BNUI.docc`
- `Sources/BNUIGallery/` — the showcase: the engine (`GalleryPage`, `GalleryKnob`, the catalog
  `GalleryViewController`, a page `GalleryPageViewController` = the stage `GalleryStageView`
  (backdrop `GalleryBackdrop`, feed `GalleryEventFeedView`) + the panel `GalleryInspectorView`,
  whose heights `GalleryDrawer` drives; knob rows `GalleryKnobRow`, the stage's environment
  `GalleryEnvironment`) and the pages of the kit's controls
- `GalleryApp/BNUIGalleryApp.xcodeproj` — the showcase as an app of its own: its root is
  `BNUIGalleryPages.all()`, the package is linked by the path `..`. Debug only; `-OpenGallery
  <Title>` opens a page straight away. The folder `GalleryApp/BNUIGalleryApp` is synchronized —
  files are not registered in the pbxproj
- SwiftUI faces — the `BN` namespace (`BNUICore/BN.swift`): `BNButton` is UIKit, `BN.Button` is
  SwiftUI; after the dot comes the name of the SwiftUI counterpart where there is one
  (`BN.TabView`), the control's name otherwise (`BN.TabBar`). The file is
  `<UIKit type>+SwiftUI.swift` next to the control and holds only the wrapper: no `#Preview`, no
  gallery pages. `BNUICore/BNHostingView` puts SwiftUI in any `UIView` slot;
  `BNUICore/BNSwiftUISupport` gives Core's types an `Animation` and a `Color`
- `Tests/BNUITests/` — Swift Testing, pure logic only; one target over every module, each file
  `@testable import`s the modules it exercises
- `api/BNUI.api` — the public API line by line, generated by `check.sh`; never edited by hand,
  its diff read before a commit
- `scripts/` — `check.sh` (the gate), `typecheck-ios.sh`, `stop-check.sh` (the agent's Stop hook),
  `git-hooks/pre-commit`, `format-lint.sh` (a hook on every edit), `build-docs.sh` (DocC to read —
  through `xcodebuild`, run by the owner)
- `README.md` — for the package's users; `CHANGELOG.md` — every release

## Releases

- A release is an annotated tag `X.Y.Z`, no `v` prefix, with its entry in `CHANGELOG.md`
  (Breaking / Added / Fixed, by product).
- At 0.x the number comes from `git diff <last tag> -- api/BNUI.api`: a removed or changed line
  means a breaking change and a new MINOR; added lines only, or none, a new PATCH.
- 1.0.0 is the owner's call.
