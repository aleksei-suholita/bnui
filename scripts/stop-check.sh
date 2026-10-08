#!/bin/bash
# Claude Code Stop hook: the agent does not hand work over while scripts/check.sh is red.
#
# A turn that changed nothing costs a fingerprint (`check.sh --if-changed`, well under a second).
# A red gate blocks the stop and hands the failure back to the agent — at most three times in a
# row, so a failure the agent cannot fix (the toolchain, the owner's unfinished edit) ends in a
# report to the owner rather than a loop.
set -uo pipefail

cd "$(dirname "$0")/.."
input=$(cat)
ATTEMPTS=.build/stop-check.attempts
MAX_ATTEMPTS=3

# `stop_hook_active` is true when the agent is already continuing because this hook blocked it.
if [[ "$(echo "$input" | jq -r '.stop_hook_active // false')" != "true" ]]; then
    rm -f "$ATTEMPTS"
fi

if output=$(./scripts/check.sh --if-changed 2>&1); then
    rm -f "$ATTEMPTS"
    exit 0
fi

attempt=$(($(cat "$ATTEMPTS" 2>/dev/null || echo 0) + 1))
if ((attempt > MAX_ATTEMPTS)); then
    rm -f "$ATTEMPTS"
    jq -n '{systemMessage: "scripts/check.sh is still red after three attempts — the work is not ready to hand over."}'
    exit 0
fi
mkdir -p .build && echo "$attempt" >"$ATTEMPTS"

reason="scripts/check.sh is red (attempt $attempt of $MAX_ATTEMPTS). Fix what your changes broke, then stop again.
If the failure is outside your changes — the owner's edit in progress, the toolchain — do not touch
it: say so in your reply to the owner.

$(echo "$output" | grep -vE '^\[|Building for|Build complete' | tail -40)"
jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
