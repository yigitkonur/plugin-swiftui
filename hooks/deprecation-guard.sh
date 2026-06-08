#!/usr/bin/env bash
# PostToolUse guard — NON-BLOCKING. When an edited *.swift file introduces a deprecated SwiftUI API,
# nudge the agent (never deny the edit). Static grep only: no CLI call, no build, no latency.
# Disable by removing the hooks entry, or set SWIFTUI_GUARD=off.
set -euo pipefail
[ "${SWIFTUI_GUARD:-on}" = "off" ] && exit 0

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
