---
description: Create or update .swiftui-plugin/settings.md to configure the swiftui plugin for this project
---

# /swiftui-settings — Configure the swiftui plugin for this project

Creates or updates `.swiftui-plugin/settings.md` with per-project plugin settings shared by Claude and Codex.

## Steps

1. Check if `.swiftui-plugin/settings.md` already exists with the Read tool. If it does, show the current values to the user. If only `.claude/swiftui.local.md` exists, use its values as migration defaults.

2. Ask the user which settings to configure (or accept defaults):
   - `enabled` (true/false) — master on/off for the deprecation hook (default: true)
   - `strict_audit` (true/false) — whether `/swiftui-audit` should exit non-zero on `hard` findings (default: true)

3. Resolve the project root with `git rev-parse --show-toplevel` (fall back to the current directory), then ensure `<root>/.swiftui-plugin/` exists.

4. Write the settings file with YAML frontmatter:

```markdown
---
enabled: true
strict_audit: true
---

# swiftui plugin settings

- `enabled` — set to `false` to silence the deprecation guard hook.
- `strict_audit` — set to `false` to make `/swiftui-audit` advisory only (no non-zero exit on hard findings).

After editing this file, restart Claude Code for hook changes to take effect.
```

5. Ensure the exact line `.swiftui-plugin/settings.md` is present in the project root `.gitignore`; append it when absent without changing unrelated rules.

6. Confirm to the user: "Settings saved to `.swiftui-plugin/settings.md`. Restart your agent host for hook changes to take effect."
