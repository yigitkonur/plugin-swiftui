---
description: Create or update .claude/swiftui.local.md to configure the swiftui plugin for this project
---

# /swiftui-settings — Configure the swiftui plugin for this project

Creates or updates `.claude/swiftui.local.md` with per-project plugin settings.

## Steps

1. Check if `.claude/swiftui.local.md` already exists with the Read tool. If it does, show the current values to the user.

2. Ask the user which settings to configure (or accept defaults):
   - `enabled` (true/false) — master on/off for the deprecation hook (default: true)
   - `strict_audit` (true/false) — whether `/swiftui-audit` should exit non-zero on `hard` findings (default: true)

3. Ensure `.claude/` directory exists: `mkdir -p .claude`

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

5. Verify `.claude/*.local.md` is in `.gitignore`. If not, remind the user to add it.

6. Confirm to the user: "Settings saved to `.claude/swiftui.local.md`. Restart Claude Code for hook changes to take effect."
