---
description: Audit a SwiftUI file (or the current diff) for deprecated APIs and non-idiomatic usage, grounded in real macOS apps.
argument-hint: "[path/to/File.swift]  (defaults to changed Swift files)"
---
Audit SwiftUI in: **$ARGUMENTS** _(empty = the current git diff)_

Deprecated APIs still seen in production (scan the target against these):
!`"${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx" deprecated 2>/dev/null | head -20 || echo "swiftui-ctx unavailable"`

Now:
1. Read the target file(s) (or `git diff` if no path given).
2. For each SwiftUI symbol used, check `"${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx" deprecated <api>` (flag + replacement)
   and compare its call to `swiftui-ctx lookup <api>` `consensus`.
3. Report findings as `file:line — issue → fix` with the swiftui-ctx permalink as evidence, ranked deprecated (high)
   > non-consensus shape (medium) > nit. Do not rewrite unless asked.
