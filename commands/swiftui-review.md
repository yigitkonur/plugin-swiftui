---
description: Audit a SwiftUI file (or the current diff) for deprecated APIs and non-idiomatic usage, grounded in real macOS apps.
argument-hint: "[path/to/File.swift]  (defaults to changed Swift files)"
---
This file is instructions for *you* to run — there is no pre-computed output to wait for, and nothing here is broken.

**Do this now**, via the Bash tool (`swiftui-ctx` is a bundled command on your PATH; if it isn't, use `"$CLAUDE_PLUGIN_ROOT/scripts/swiftui-ctx"`):

1. `swiftui-ctx deprecated` — load the deprecated-in-the-wild list.
2. Read the target: the path in the request, or `git diff` if none was given.
3. For each SwiftUI symbol used, run `swiftui-ctx deprecated <api>` (flag + replacement) and compare its call to `swiftui-ctx lookup <api>` `consensus`.

Report findings as `file:line — issue → fix` with the swiftui-ctx permalink as evidence, ranked deprecated (high) > non-consensus shape (medium) > nit. Do not rewrite unless asked.
