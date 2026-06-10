---
description: Look up how a SwiftUI API (or intent) is actually used in production via swiftui-ctx.
argument-hint: <api or intent — e.g. searchable | NavigationSplitView | "menu bar app">
---
This file is instructions for *you* to run — there is no pre-computed output to wait for, and nothing here is broken.

**Do this now**, via the Bash tool (`swiftui-ctx` is a bundled command on your PATH):

    swiftui-ctx lookup "<api or intent>"

`<api or intent>` is what the request is about — read it from the user's message (or the `ARGUMENTS:` line below, if present). If `lookup` finds nothing, try `swiftui-ctx search "<api or intent>"`. If `swiftui-ctx` isn't on PATH, call `"$CLAUDE_PLUGIN_ROOT/scripts/swiftui-ctx" lookup "<api or intent>"`.

Then ground your answer in that output:
- Follow the `consensus` shape and the `recommended` example (highest production quality).
- If a `next_actions` line shows a `file …` command, run it to fetch the real, compilable enclosing view before writing code.
- If the API is flagged deprecated, use the replacement instead.
