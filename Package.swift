// swift-tools-version: 6.2
import PackageDescription

/// Swift 7 behaviour, adopted ahead of the language mode. Each one cost the kit at most a couple of
/// edits when it was switched on; `scripts/check.sh` builds with them and with warnings as errors.
let upcomingFeatures: [SwiftSetting] = [
    // `any P` spelled out — an existential's cost is visible where it is paid.
    .enableUpcomingFeature("ExistentialAny"),
    // A member is visible only in files that import its module. Without it, a file compiles off
    // another file's `import UIKit`, and the macOS build of `swift test` cannot tell.
    .enableUpcomingFeature("MemberImportVisibility"),
    // A nonisolated `async` function runs on its caller's actor instead of hopping off it.
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    // A conformance of a main-actor type is main-actor isolated.
    .enableUpcomingFeature("InferIsolatedConformances"),
    // A `weak` capture is a `let`: a closure cannot reassign it.
    .enableUpcomingFeature("ImmutableWeakCaptures"),
]

/// Every module of the kit, the gallery included, is built the same way.
let kitSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(MainActor.self),
] + upcomingFeatures

let package = Package(
    name: "BNUI",
    // macOS is here only so `swift test` can run the pure solvers without a simulator; every
    // UIKit file in the package is gated behind `#if canImport(UIKit)`.
    platforms: [.iOS(.v16), .macOS(.v15)],
    products: [
        // The whole kit behind one import.
        .library(name: "BNUI", targets: ["BNUI"]),
        // One product per control, for an app that wants only some of them. Each one re-exports
        // what its API is made of, so a single import is enough: BNUIButton brings BNUICore along.
        .library(name: "BNUICore", targets: ["BNUICore"]),
        .library(name: "BNUIButton", targets: ["BNUIButton"]),
        .library(name: "BNUITabBar", targets: ["BNUITabBar"]),
        // The showcase. Compiled in every configuration, TestFlight's Release included: the app
        // decides where it is linked and keeps the way in behind a condition of its own.
        .library(name: "BNUIGallery", targets: ["BNUIGallery"]),
    ],
    dependencies: [
        // Apple-style API documentation. `swift package generate-documentation` builds for macOS,
        // where the UIKit-gated control API is empty — build docs for iOS with `xcodebuild docbuild`.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
    ],
    targets: [
        // Motion, haptics, materials and shapes: what every control is made of. What the controls
        // share without it being API is `package`, seen across the kit's modules and nowhere else.
        .target(name: "BNUICore", swiftSettings: kitSettings),
        .target(name: "BNUIButton", dependencies: ["BNUICore"], swiftSettings: kitSettings),
        // The bar's action is a button, and so is its material.
        .target(name: "BNUITabBar", dependencies: ["BNUICore", "BNUIButton"], swiftSettings: kitSettings),
        .target(name: "BNUI", dependencies: ["BNUICore", "BNUIButton", "BNUITabBar"], swiftSettings: kitSettings),
        .target(name: "BNUIGallery", dependencies: ["BNUI"], swiftSettings: kitSettings),
        // The UIKit-free parts — layout solvers, motion resolution, the haptic merge
        // rule — verified on macOS without a simulator.
        .testTarget(
            name: "BNUITests",
            dependencies: ["BNUICore", "BNUIButton", "BNUITabBar"],
            swiftSettings: upcomingFeatures,
        ),
    ],
)
