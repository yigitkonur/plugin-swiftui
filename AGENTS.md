# Agent guide — claude-swiftui-plugin

Maintenance rules for AI agents working on this plugin.

## ALWAYS bump the version on any user-facing change

When you change anything that ships to users — `commands/`, `agents/`, `skills/`, `hooks/`,
`scripts/`, `bin/`, the catalog, or `plugin.json` itself — **bump `version` in
`.claude-plugin/plugin.json` in the same change, before pushing to `main`.**

Installers gate updates on the manifest version. If the version doesn't change, nobody pulls the
fix no matter how correct it is — the update is invisible. A bug fix that users never receive is
not a fix.

- Semantic versioning: bug fix → patch (`1.0.0` → `1.0.1`); new command/skill or
  backward-compatible feature → minor (`1.0.1` → `1.1.0`); breaking change → major.
- Bump in the **same commit** as the change (or an adjacent commit in the same push) — never push
  shipped changes with a stale version.
- Docs-only changes that don't ship (e.g. this file, internal `eval/`) don't need a bump.

## Plugin manifest gotchas (learned the hard way)

- `.claude-plugin/plugin.json` is schema-validated strictly. Do **not** add string path fields
  like `"commands": "./commands"` — rely on auto-discovery. Extra/mis-typed path fields fail
  installation with `Validation errors: <field>: Invalid input`.

## Commands & skills are model-first

Commands (`commands/*.md`) are merged into skills, so the model invokes them via the Skill tool —
where `$ARGUMENTS` substitution and `` !`…` `` bash preprocessing **do not run** (the model sees
raw template text). Write command/skill bodies as direct instructions for the model to run tools
itself via Bash (mirror the `skills/*/SKILL.md` files). Do not rely on `!` preprocessing or
`$ARGUMENTS`, and don't add `allowed-tools` gating.

The bundled CLI is reachable three ways: bare `swiftui-ctx` (the `bin/swiftui-ctx` PATH shim) →
`"$CLAUDE_PLUGIN_ROOT/scripts/swiftui-ctx"` → the script's own self-location.
