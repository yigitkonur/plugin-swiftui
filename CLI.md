# swiftui-ctx — CLI contract

Real-world SwiftUI usage from **1,857 production macOS apps**, queryable for AI agents.
The *practice* layer; pair with [sosumi.ai](https://sosumi.ai) (official docs), which every result links to.

## Build & run
```bash
( cd swiftui-scan && swift build -c release --product swiftui-ctx )
swiftui-scan/.build/release/swiftui-ctx <command> [--json] [--catalog <dir>] [--limit N] [--platform macos|any] [--offline]
```
The catalog dir is found via `--catalog`, `$SWIFTUI_CTX_CATALOG`, `./catalog`, or the package-relative `../catalog`.

## Commands (16)
Core:
- `lookup <api>` — consensus arg-shapes (%), recommended + diverse real examples, co-occurring APIs, deprecation note, doc link. **Start here.**
- `examples <api> [--shape S] [--repo R] [--page N]` — ranked, paginated call sites.
- `file <id|permalink> [--smart|--decl|--chain|--full]` — fetch real source live. `--smart` (default) = tightest useful span; `--decl` = whole enclosing `var body`/func; `--chain` = the modifier chain; `--full` = whole file. (SwiftSyntax-accurate.)
- `recipe <name>` / `recipes` — production patterns (template + real examples).
- `deprecated [<api>]` — deprecated APIs in use + modern replacement.
- `search <query>` — find APIs/recipes by keyword.
- `repo <owner/name>` — a repo's fingerprint, modernity, authority.
- `stats` — corpus overview.
- `doctor` — health check: confirms the catalog loads, prints version + corpus size (run first if unsure).

Shard / specialized:
- `conformances <protocol>` — real types conforming to `View`/`ViewModifier`/`Transition`/… (custom-component evidence).
- `bridges` — AppKit↔SwiftUI bridge usage (`NSViewRepresentable` etc.) across the corpus.
- `settings` — `Settings`/preferences-scene patterns in the wild.
- `valueBuilders <q>` — real Font/Color/Animation/gradient value expressions (e.g. spring presets).
- `rankings <dim>` — top repos by dimension: `by_total_unique_apis · by_modifier_breadth · by_custom_components · most_modern_stack`.
- `insights <section>` — corpus-level data: `modern-stack · deprecated · cooccurrence · external · components · categories`.

Global flags (all commands): `--json` · `--catalog <dir>` · `--limit N` (default 6) · `--platform macos|any` · `--offline` (catalog only, no live fetch).

## Agent contract
- **stdout** = data only (`--json` for the envelope); **stderr** = logs/errors.
- Envelope: `{ "ok", "schema_version":"v1", "result", "next_actions":[{cmd,why}], "error" }`.
- `next_actions` are literal follow-up commands — run one to drill in (e.g. `file <id>` after `lookup`).
- **Exit codes:** `0` ok · `2` usage · `3` not-found (`error.suggestion` has did-you-mean) · `4` network/retryable · `5` no catalog.

## Ranking (why an example is "recommended")
Composite quality score per repo: **author authority** (Σ stars of contributors' own + contributed-to projects)
+ **repo stars** + **modernity** (newest macOS APIs used / not deprecated) + **recency** + **contributor count**,
penalized for deprecated-form usage, demo/sample/tutorial repos, and non-macOS platform. Examples are de-duplicated
by argument shape so you see distinct real variations, top-ranked first. (No license/legal signals; no star velocity.)

## Pipeline (how the catalog is produced)
`scripts/00_harvest → 01_gate → 02_build_sdk_catalog (+02b_availability) → swiftui-scan (SwiftSyntax) →
04_run → 05_catalog → 06_discover/06b_gate → 07_enrich_authors → 05_catalog (re-rank) → 08_recipes`.
See `RUN.md`. The CLI reads only `catalog/`.
