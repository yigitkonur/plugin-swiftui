#!/usr/bin/env bash
# PostToolUse guard — NON-BLOCKING. When an edited *.swift file introduces a deprecated SwiftUI API,
# nudge the agent (never deny the edit). Static grep only: no CLI call, no build, no latency.
#
# Configuration (checked in order):
#   1. .swiftui-plugin/settings.md in the project root — set `enabled: false` to disable.
#   2. .claude/swiftui.local.md — temporary backward-compatible fallback.
#   3. SWIFTUI_GUARD=off environment variable — environment opt-out.
set -euo pipefail
[ "${SWIFTUI_GUARD:-on}" = "off" ] && exit 0

input="$(cat)"
event_cwd="$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    value=json.load(sys.stdin).get("cwd", "")
    print(value if isinstance(value, str) else "")
except Exception:
    print("")' 2>/dev/null || true)"
[[ -d "$event_cwd" ]] || event_cwd="$PWD"
project_root="$(git -C "$event_cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$event_cwd")"

# Read neutral settings first, then the legacy Claude file only when neutral settings are absent.
settings=""
if [[ -f "$project_root/.swiftui-plugin/settings.md" ]]; then
  settings="$project_root/.swiftui-plugin/settings.md"
elif [[ -f "$project_root/.claude/swiftui.local.md" ]]; then
  settings="$project_root/.claude/swiftui.local.md"
fi
if [[ -n "$settings" ]]; then
  _fm=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$settings")
  _en=$(echo "$_fm" | grep '^enabled:' | sed 's/enabled: *//' | sed 's/^"\(.*\)"$/\1/' || true)
  [[ "$_en" == "false" ]] && exit 0
fi

root="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
names="$root/hooks/deprecated-names.txt"
[ -f "$names" ] || exit 0
printf '%s' "$input" | python3 "$root/hooks/deprecation-guard.py" "$names"
exit 0
