#!/bin/bash
# Builds the kit for iOS — BNUI, the gallery and the app that hosts it — without a simulator.
#
# Why this exists: `swift build` and `swift test` build the package for macOS, where
# `canImport(UIKit)` is false and every control compiles as an empty shell. A green macOS build
# therefore proves nothing about the controls — it will not even notice a missing `import BNUI`.
# This builds the same package for the iOS simulator SDK, with the same Package.swift settings and
# warnings as errors, in seconds. It is `swift build` with a triple, not `xcodebuild`.
#
# The debug build leaves an index store and the symbol graphs in .build/ios for the later steps of
# scripts/check.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
TRIPLE=arm64-apple-ios16.0-simulator
BUILD=.build/ios
PRODUCTS="$BUILD/out/Products/Debug-iphonesimulator"
SYMBOL_GRAPHS="$BUILD/symbol-graphs"

# Swift Build prints a progress line per task and, on failure, the whole compiler command line;
# neither says what broke.
quiet() {
    grep -vE '^\[([0-9][^]]*|Planning deferred tasks)\]' | cut -c1-400
}

ios_build() {
    swift build --scratch-path "$BUILD" --triple "$TRIPLE" --sdk "$SDK" -Xswiftc -warnings-as-errors "$@" 2>&1 | quiet
    return "${PIPESTATUS[0]}"
}

# `--enable-index-store` on every run: an incremental build without it leaves a partial index
# behind, and Periphery reads that one.
# The symbol graphs — the compiler's list of public declarations — feed the API dump, the BN
# prefix check and DocC in scripts/check.sh. Synthesized members are left out: without that every
# SwiftUI face would list the thousands of `View` modifiers it inherits.
echo "› BNUI + BNUIGallery (debug)"
# A module's graphs are written when the module is rebuilt, and only those whose content changed: a
# graph for something the module no longer declares or extends — a module gone after a branch
# switch, a type it stopped extending — stays behind and passes for current API. So when the
# package changes shape (the manifest or the set of source files), the graphs start over from a
# rebuild of the kit's modules; the module caches survive it, and it takes seconds.
SHAPE=$({ cat Package.swift; find Sources -name '*.swift' | LC_ALL=C sort; } | shasum | cut -d' ' -f1)
if [[ "$(cat "$SYMBOL_GRAPHS/.shape" 2>/dev/null)" != "$SHAPE" ]]; then
    rm -rf "$SYMBOL_GRAPHS" "$BUILD/out/Products" "$BUILD/out/Intermediates.noindex"
fi
mkdir -p "$SYMBOL_GRAPHS"
ios_build --target BNUIGallery --enable-index-store \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir -Xswiftc "$PWD/$SYMBOL_GRAPHS" \
    -Xswiftc -symbol-graph-minimum-access-level -Xswiftc public \
    -Xswiftc -symbol-graph-skip-synthesized-members
echo "$SHAPE" >"$SYMBOL_GRAPHS/.shape"

echo "› BNUI + BNUIGallery (release)"
# Release is how a TestFlight build is made, and the gallery is compiled there too.
ios_build --target BNUIGallery -c release

# The standalone app that hosts the gallery is an Xcode project, not a package target, so it is
# type-checked directly against the modules built above.
echo "› BNUIGalleryApp"
swiftc -typecheck -sdk "$SDK" -target "$TRIPLE" -swift-version 6 -default-isolation MainActor \
    -warnings-as-errors -parse-as-library -I "$PRODUCTS" \
    -module-name BNUIGalleryApp \
    $(find GalleryApp -name "*.swift")

echo "✓ iOS build passed"
