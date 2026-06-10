---
description: Look up how a SwiftUI API (or intent) is actually used in production via swiftui-ctx.
argument-hint: <api or intent — e.g. searchable | NavigationSplitView | "menu bar app">
allowed-tools: Bash(swiftui-ctx:*), Bash(*/swiftui-ctx:*)
---
Ground this in real production SwiftUI before answering: **$ARGUMENTS**

!`Q="$ARGUMENTS"; CTX="$(command -v swiftui-ctx 2>/dev/null || echo "${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx")"; if [ -z "$Q" ]; then echo "Usage: /swiftui <api or intent — e.g. searchable | NavigationSplitView | \"menu bar app\">"; else "$CTX" lookup "$Q" 2>/dev/null || "$CTX" search "$Q" 2>/dev/null || echo "swiftui-ctx unavailable — run: \"$CTX\" doctor"; fi`

**If the block above shows a raw `` !`…` `` template or no real output** — this happens when this skill is invoked by the model via the Skill tool rather than typed as `/swiftui …`, in which case the `!` preprocessing and `$ARGUMENTS` don't run — then run the lookup yourself with the Bash tool (`swiftui-ctx` is on PATH as a bundled `bin/` command):
- `swiftui-ctx lookup "<the api or intent>"` (fall back to `swiftui-ctx search "<…>"`)
- if not found on PATH: `"$CLAUDE_PLUGIN_ROOT/scripts/swiftui-ctx" lookup "<…>"`

Using that output:
- Follow the `consensus` shape and the `recommended` example (highest production quality).
- If a `next_actions` line shows a `file …` command, run it to fetch the real, compilable enclosing view before writing code.
- If the API is flagged deprecated, use the replacement instead.
