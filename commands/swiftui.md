---
description: Look up how a SwiftUI API (or intent) is actually used in production via swiftui-ctx.
argument-hint: <api or intent — e.g. searchable | NavigationSplitView | "menu bar app">
---
Ground this in real production SwiftUI before answering: **$ARGUMENTS**

!`Q="$ARGUMENTS"; CTX="${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx"; if [ -z "$Q" ]; then echo "Usage: /swiftui <api or intent — e.g. searchable | NavigationSplitView | \"menu bar app\">"; else "$CTX" lookup "$Q" 2>/dev/null || "$CTX" search "$Q" 2>/dev/null || echo "swiftui-ctx unavailable — run: \"$CTX\" doctor"; fi`

Using the output above:
- Follow the `consensus` shape and the `recommended` example (highest production quality).
- If a `next_actions` line shows a `file …` command, run it to fetch the real, compilable enclosing view before writing code.
- If the API is flagged deprecated, use the replacement instead.
