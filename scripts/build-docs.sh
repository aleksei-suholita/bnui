#!/bin/bash
# Builds the Swift-DocC documentation for the tab bar and opens or exports it.
#
# Run this yourself: it invokes `xcodebuild docbuild`, the heavy iOS build the agent leaves to
# you (see CLAUDE.md). The iOS build is required — on macOS the UIKit-gated control API is empty.
#
#   scripts/build-docs.sh           # build, then open the archive in Xcode's doc viewer
#   scripts/build-docs.sh --static  # build, then export a static site into docs-site/
#
# The three steps this wraps — docbuild → locate the .doccarchive → open/transform — are the
# ones that are easy to run out of order by hand.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED=.build/DerivedData
SCHEME=BNUI

echo "› Building documentation (iOS)…"
xcrun xcodebuild docbuild \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    -quiet

ARCHIVE=$(find "$DERIVED" -name "$SCHEME.doccarchive" -type d | head -1)
if [[ -z "$ARCHIVE" ]]; then
    echo "✗ No .doccarchive was produced. If the build failed on an unknown scheme, list the" >&2
    echo "  available ones with: xcodebuild -list" >&2
    exit 1
fi
echo "✓ Archive: $ARCHIVE"

if [[ "${1:-}" == "--static" ]]; then
    OUT=docs-site
    rm -rf "$OUT"
    xcrun docc process-archive transform-for-static-hosting "$ARCHIVE" \
        --output-path "$OUT" \
        --hosting-base-path bnui
    echo "✓ Static site in $OUT/ — serve it over HTTP (base path 'bnui')."
else
    open "$ARCHIVE"
fi
