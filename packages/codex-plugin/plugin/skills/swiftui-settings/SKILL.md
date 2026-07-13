---
name: swiftui-settings
description: Create or update project settings for the SwiftUI plugin. Use only when explicitly requested with $swiftui-settings.
---

# SwiftUI plugin settings

Resolve the project root with `git rev-parse --show-toplevel`, falling back to the current directory. Use `<root>/.swiftui-plugin/settings.md` as the platform-neutral settings file. Read and preserve existing values when present. If only `<root>/.claude/swiftui.local.md` exists, migrate its values. Otherwise use `enabled: true` and `strict_audit: true`.

Write this shape:

```markdown
---
enabled: true
strict_audit: true
---

# SwiftUI plugin settings

- `enabled` controls the nonblocking deprecation hook.
- `strict_audit` controls whether hard audit findings produce a failing status.
```

Create the settings directory and file, then ensure the exact line `.swiftui-plugin/settings.md` exists in the project root `.gitignore`; append it without changing unrelated rules. The plugin reads legacy `.claude/swiftui.local.md` only while the neutral file is absent.
