#!/usr/bin/env bash
# PostToolUse guard — NON-BLOCKING. When an edited *.swift file introduces a deprecated SwiftUI API,
# nudge the agent (never deny the edit). Static grep only: no CLI call, no build, no latency.
#
# Configuration (checked in order):
#   1. .claude/swiftui.local.md in the project root — set `enabled: false` to disable.
#   2. SWIFTUI_GUARD=off environment variable — legacy opt-out.
set -euo pipefail
[ "${SWIFTUI_GUARD:-on}" = "off" ] && exit 0

# Read plugin settings if present (.claude/swiftui.local.md per plugin-settings pattern)
if [[ -f ".claude/swiftui.local.md" ]]; then
  _fm=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' ".claude/swiftui.local.md")
  _en=$(echo "$_fm" | grep '^enabled:' | sed 's/enabled: *//' | sed 's/^"\(.*\)"$/\1/')
  [[ "$_en" == "false" ]] && exit 0
fi

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
names="$root/hooks/deprecated-names.txt"
[ -f "$names" ] || exit 0

input="$(cat)"
fp="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[[ "$fp" == *.swift ]] || exit 0

hits=""
while IFS='|' read -r api repl; do
  [ -z "$api" ] && continue
  # match the api as a SwiftUI call/usage token within the edit payload
  if printf '%s' "$input" | grep -qE "[.(]${api}\b|\b${api}\("; then
    hits="${hits}  - .${api} -> ${repl}\\n"
  fi
done < "$names"
[ -z "$hits" ] && exit 0

msg="swiftui: this .swift edit may use deprecated SwiftUI APIs:\\n${hits}Verify with \`swiftui-ctx deprecated <api>\` and migrate (skill: swiftui-modernize)."
# emit non-blocking context for the agent
esc="$(printf '%b' "$msg" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}\n' "$esc"
exit 0
