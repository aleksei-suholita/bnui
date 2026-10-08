#!/bin/bash
# PostToolUse hook: форматирует и линтит тронутый Swift-файл.
# exit 2 → вывод возвращается Claude, он исправляет нарушения сам.
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ "$file_path" == *.swift ]] || exit 0
[[ -f "$file_path" ]] || exit 0

swiftformat "$file_path" --quiet 2>/dev/null
lint_output=$(swiftlint lint --quiet "$file_path" 2>&1)
if [[ -n "$lint_output" ]]; then
    echo "$lint_output" >&2
    exit 2
fi
exit 0
