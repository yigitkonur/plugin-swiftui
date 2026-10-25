# Agent guide — plugin-swiftui

Maintenance rules for AI agents working on this plugin.

<!-- kit:agents:start -->
## Releases, versions and installs (shared by every plugin repo)

- **Never bump a version by hand.** `.github/workflows/release.yml` runs after `ci` is green on `main`. `scripts/kit/release.py` reads the conventional-commit subjects since the last release tag (`feat` is a minor, `fix`/`perf`/unprefixed a patch, `type!:` or a BREAKING CHANGE line a major, a minor while the version is 0.x; docs, ci, chore, test, style, build and refactor release nothing) and counts only commits that touch shipped files. It writes every manifest, the marketplace entries and CHANGELOG.md, commits `chore(release): vX [skip ci]`, tags `vX` and `<plugin>--vX` (several plugins: `<plugin>--vX` only) and publishes the GitHub release. `python3 scripts/kit/release.py` with no flags prints what it would do; Actions > release > Run workflow forces a level or a dry run.
- **One version source: the manifests** (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, the marketplace entry). Never a constant in code; read the manifest at runtime.
- Installed copies update only when the version string changes, so a change users should get must reach `main` as a releasing commit type (`feat`, `fix`, `perf`, or `!`).
- **Install policy:** installed globally and off (`"defaultEnabled": false`), switched on per project with `plugin on <name>`. Never document a project-scope install as the way in.
- `scripts/kit/*`, `scripts/kit.sha256`, `.github/workflows/release.yml`, the `kit:manifests` job in `ci.yml` and the blocks between `kit:` markers in README.md and AGENTS.md are copies from [yigitkonur/plugin-kit](https://github.com/yigitkonur/plugin-kit). Change them there and run its `sync.sh`; `scripts/kit/check-manifests.py` fails CI on a local edit.
- Before pushing: `python3 scripts/kit/check-manifests.py --validate`, `python3 scripts/kit/secret-scan.py --tree`, `python3 scripts/kit/check-links.py`, then this repo's own checks.
<!-- kit:agents:end -->

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
