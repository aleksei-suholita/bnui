#!/bin/bash
# The agent's gate: every check that runs without a simulator, cheapest first. Run it before
# handing work over; exit 0 means every layer passed. The heavy half — the gallery on a simulator,
# haptics on a device — stays with the owner (CLAUDE.md, «Разделение труда»).
#
#   format    SwiftFormat would change nothing
#   lint      SwiftLint, warnings included, custom rules for the kit's boundaries
#   tests     `swift test` with warnings as errors, then the coverage floor below
#   ios       the package built for the iOS simulator SDK — scripts/typecheck-ios.sh
#   dead code Periphery over the index the iOS build left behind
#   api       public types carry the BN prefix; the public API is written to api/BNUI.api
#   docs      DocC over the same declarations: a broken link or an undocumented parameter fails
#
#   scripts/check.sh               run everything
#   scripts/check.sh --if-changed  skip when the tree is exactly as it was at the last green run
#                                  (the Stop hook and the git pre-commit hook call it this way)
set -euo pipefail

cd "$(dirname "$0")/.."

# Line coverage of what `swift test` can see — the UIKit-free solvers; the controls compile empty
# on macOS and are not counted. A floor, not a target: it sits just under today's number (90.6%),
# so a new solver without tests trips it. Raise it as the number rises; never lower it to pass.
COVERAGE_FLOOR=90

STAMP=.build/check.stamp
SYMBOL_GRAPHS=.build/ios/symbol-graphs

# Everything that decides the outcome: HEAD, the tracked changes and the untracked files' content.
fingerprint() {
    {
        git rev-parse HEAD 2>/dev/null || true
        git diff HEAD 2>/dev/null || git diff
        git ls-files --others --exclude-standard -z | xargs -0 shasum 2>/dev/null || true
    } | shasum | cut -d' ' -f1
}

if [[ "${1:-}" == "--if-changed" && -f "$STAMP" && "$(cat "$STAMP")" == "$(fingerprint)" ]]; then
    echo "✓ nothing changed since the last green run"
    exit 0
fi
rm -f "$STAMP"

step() {
    printf '\n━━ %s\n' "$1"
}

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

step "format"
swiftformat --lint . --quiet

step "lint"
swiftlint lint --strict --quiet

step "tests"
# Serial, so coverage is the same every run. Coverage counters are not atomic: two tests calling
# one function at once lose an increment, and a line LLVM counts as a difference of counters
# drops to 0 — the queue's last `wait` branch went uncovered now and then, more often under load.
# The whole run takes milliseconds either way.
if swift test --enable-code-coverage --no-parallel -Xswiftc -warnings-as-errors >"$LOG" 2>&1; then
    grep -E 'Test run with' "$LOG"
else
    # Swift Testing reports every test and every argument twice, started and passed; what is
    # left is the build errors, the failures and the totals.
    grep -vE '^\[([0-9][^]]*|Planning deferred tasks)\]| started\.$| passed after ' "$LOG" | cut -c1-400
    exit 1
fi

COVERAGE=$(jq '[.data[0].files[] | select(.filename | test("/Sources/BNUI[A-Za-z]*/") and (test("/Sources/BNUIGallery/") | not))
    | .summary.lines]
    | (map(.covered) | add) * 1000 / (map(.count) | add) | floor / 10' "$(swift test --show-codecov-path)")
echo "coverage: ${COVERAGE}% (floor ${COVERAGE_FLOOR}%)"
if ! awk -v c="$COVERAGE" -v f="$COVERAGE_FLOOR" 'BEGIN { exit !(c >= f) }'; then
    echo "✗ coverage ${COVERAGE}% is under the ${COVERAGE_FLOOR}% floor: the new logic needs tests" >&2
    exit 1
fi

step "ios"
./scripts/typecheck-ios.sh

step "dead code"
# --retain-public: Stint and Tapwake are not in the index, so public API only they call would
# read as unused. A false positive is silenced where it stands: `// periphery:ignore - <why>`.
periphery scan \
    --index-store-path .build/ios/out/Products/Debug-iphonesimulator/index/store \
    --retain-public \
    --relative-results \
    --disable-update-check \
    --quiet \
    --strict

step "api"
# CLAUDE.md: every public type carries the BN prefix. Read off the compiler's own list of public
# declarations rather than grepped: a nested `BNButton.Style` is fine, a top-level `Style` is not.
# The umbrella's graph covers the controls; the gallery is a product of its own, outside it.
UNPREFIXED=$(jq -r '.symbols[]
    | select(.kind.identifier | test("^swift\\.(struct|class|enum|protocol|typealias|actor)$"))
    | select(.pathComponents | length == 1)
    | .pathComponents[0] | select(startswith("BN") | not)' \
    "$SYMBOL_GRAPHS/BNUI.symbols.json" "$SYMBOL_GRAPHS/BNUIGallery.symbols.json")
if [[ -n "$UNPREFIXED" ]]; then
    echo "✗ public types without the BN prefix:" >&2
    echo "$UNPREFIXED" >&2
    exit 1
fi

# Which product declares what. The umbrella's graph lists the whole kit, and a control's graph lists
# its own declarations and those of the modules it re-exports — BNUIButton's carries BNUICore's
# too. A declaration belongs to the first module, in dependency order, whose graph lists it: the
# product an app depends on to get it.
OWNERS=.build/ios/api-owners.tsv
shopt -s nullglob
for module in BNUICore BNUIButton BNUITabBar BNUIGallery; do
    jq -r --arg module "$module" '.symbols[] | "\(.identifier.precise)\t\($module)"' \
        "$SYMBOL_GRAPHS/$module".symbols.json "$SYMBOL_GRAPHS/$module"@*.symbols.json
done | awk -F'\t' '!seen[$1]++' >"$OWNERS"

# The public surface, one declaration per line with its product, sorted. Committed, so a change to
# the API — even one line inside a long file — shows up in the diff, and a breaking one is seen as
# such; so is a declaration that moves to another product.
mkdir -p api
{
    echo "# The public API of BNUI: product | declaration path | declaration. Generated by scripts/check.sh — do not edit."
    jq -r '.symbols[]
        | "\(.identifier.precise)\t\(.pathComponents | join(".")) | \([.declarationFragments[]?.spelling] | join("") | gsub("\\s+"; " "))"' \
        "$SYMBOL_GRAPHS"/BNUI.symbols.json "$SYMBOL_GRAPHS"/BNUI@*.symbols.json \
        "$SYMBOL_GRAPHS"/BNUIGallery.symbols.json "$SYMBOL_GRAPHS"/BNUIGallery@*.symbols.json |
        awk -F'\t' 'NR == FNR { owner[$1] = $2; next } { print ($1 in owner ? owner[$1] : "?") " | " $2 }' "$OWNERS" - |
        LC_ALL=C sort
} >api/BNUI.api
if grep -q '^? ' api/BNUI.api; then
    echo "✗ public declarations no product claims — a module missing from the list above:" >&2
    grep '^? ' api/BNUI.api >&2
    exit 1
fi
echo "$(grep -vc '^#' api/BNUI.api) public declarations, no type without the BN prefix"
if [[ -n "$(git status --porcelain -- api/BNUI.api)" ]]; then
    echo "  the public API differs from the last commit: git diff api/BNUI.api"
fi

step "docs"
# DocC reads the symbol graphs the iOS build wrote — only the kit's, not the gallery's.
DOCC_GRAPHS=.build/ios/docc-graphs
rm -rf "$DOCC_GRAPHS" && mkdir -p "$DOCC_GRAPHS"
cp "$SYMBOL_GRAPHS"/BNUI.symbols.json "$SYMBOL_GRAPHS"/BNUI@*.symbols.json "$DOCC_GRAPHS"/
if xcrun docc convert Sources/BNUI/BNUI.docc \
    --additional-symbol-graph-dir "$DOCC_GRAPHS" \
    --fallback-display-name BNUI \
    --fallback-bundle-identifier bnui.BNUI \
    --output-path .build/ios/BNUI.doccarchive \
    --warnings-as-errors >"$LOG" 2>&1; then
    echo "documentation builds clean"
else
    grep -E 'error|warning|-->' "$LOG" | sed -E 's|\.\./|Sources/BNUI/|' | cut -c1-300
    exit 1
fi

fingerprint >"$STAMP"
printf '\n✓ all checks passed\n'
