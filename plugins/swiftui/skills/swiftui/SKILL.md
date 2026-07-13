---
name: swiftui
description: Look up how a SwiftUI API or interface intent is used in production macOS apps. Use only when explicitly requested with $swiftui.
---

# SwiftUI production lookup

## Bundled resource root

Let `<swiftui-plugin-root>` be the absolute plugin directory two levels above this `SKILL.md`. Resolve that path before running commands. Invoke the CLI as `<swiftui-plugin-root>/scripts/swiftui-ctx`; do not assume `swiftui-ctx` is on `PATH`.

Read the API name or design intent from the user's request, then run:

```bash
"<swiftui-plugin-root>/scripts/swiftui-ctx" lookup "<api-or-intent>" --json
```

If lookup returns exit code 3, retry with `search`. Follow the returned `consensus`, `recommended`, and literal `next_actions`. When a `file` action is available, fetch that enclosing production example before writing code. Use the modern replacement when the result marks an API deprecated.
