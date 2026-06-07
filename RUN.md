# SwiftUI Usage Catalog over awesome-mac — pipeline

Builds a navigable catalog of **how real open-source macOS apps use SwiftUI** from
[jaywcjlove/awesome-mac](https://github.com/jaywcjlove/awesome-mac): every repo is filtered,
its default branch ("main") cloned, AST-parsed with Apple **SwiftSyntax**, the clone deleted,
and results streamed to one JSONL per repo. A final aggregator builds a sharded JSON catalog
keyed by symbol → real call sites with GitHub permalinks ("how to use X on Y").

## Requirements
- macOS with Xcode (Swift 6.3.x toolchain), `gh` authenticated, `git`, `jq`, `python3`.
- The scanner pins `swift-syntax 603.0.1` (matches Swift 6.3). Built once into `swiftui-scan/.build/release/`.

## Stages (run in order)

```bash
# 0. Harvest owner/repo + category from the awesome-mac README
python3 scripts/00_harvest.py                       # -> data/00_candidates.json (584)

# 1. Gate via GitHub API (recency ≥2024-06-07, Swift share ≥0.2 & ≥3KB) — deterministic, no agents
python3 scripts/01_gate.py                           # -> data/01_repos_meta.jsonl, data/01_included.json (207)

# 2. Build the SDK reference catalog from symbol graphs (multi-module + stdlib denylist)
mkdir -p sg sg_std
SDK="$(xcrun --show-sdk-path --sdk macosx)"
for m in SwiftUI SwiftUICore Observation SwiftData Charts; do \
  swift symbolgraph-extract -module-name $m -target arm64-apple-macos14.0 -sdk "$SDK" \
    -minimum-access-level public -emit-extension-block-symbols -output-dir sg/; done
for m in Swift Combine Foundation; do \
  swift symbolgraph-extract -module-name $m -target arm64-apple-macos14.0 -sdk "$SDK" \
    -minimum-access-level public -output-dir sg_std/; done
# flatten sg/*.symbols.json -> symbols_all.tsv ; build stdlib_method_names.json from sg_std/
python3 scripts/02_build_sdk_catalog.py              # -> sdk_catalog.json

# 3. Build the scanner (one-time)
( cd swiftui-scan && swift build -c release )        # -> swiftui-scan/.build/release/swiftui-scan

# 4. Clone ▸ scan ▸ delete over all included repos (resumable, bounded parallelism)
python3 scripts/04_run.py --jobs 6                   # -> repos/{owner}__{repo}.jsonl, run_state.jsonl, errors.jsonl
#   pilot a few first:   --only owner/repo,owner/repo
#   cap for testing:     --limit N

# 5. Aggregate into the navigable catalog (re-runnable without re-cloning)
python3 scripts/05_catalog.py                        # -> catalog/*
```

## Outputs
- `data/01_included.json` — the gated corpus (full_name, stars, swift_share, categories…).
- `repos/{owner}__{repo}.jsonl` — per repo: line 1 summary (sha, permalink_base, stars…),
  one line per Swift file (`imports`, `occurrences[]` with `{sym,kind,line,args,src}`, `decls[]`),
  last line `{"type":"done",...}`. Self-contained (stores source lines) — survives clone deletion.
- `catalog/index.json` — corpus stats + shard map.
- `catalog/{modifiers,types,propertyWrappers,environmentKeys,styleValues,macros}.json` —
  per-symbol: `{total_uses, repo_count, top_repos, examples:[{repo,path,line,permalink,src}]}`.
- `catalog/customComponents.json` — every custom View/ViewModifier/Style/Shape + permalink.
- `catalog/by_repo/{owner}__{repo}.json` — per-repo API profile.
- `catalog/insights.json` — modern-stack adoption %, discovered third-party API, co-occurrence,
  per-category fingerprints. `catalog/rankings.json` — repos by unique-API breadth / custom components.

## v2 additions (post-audit)
- `scripts/02b_availability.py` — extracts per-symbol `introduced_macos` / `deprecated` / `renamed` from the symbol graphs into `sdk_catalog.json` (run after `02`).
- Scanner now captures: function/extension attributes (`@ViewBuilder func`), `extension Foo: View` + `NSViewRepresentable` bridges, `.environment(\.key)` keypaths, generic `List<T>()`, `var body`/`some View` helpers, and **scopes every occurrence to its enclosing type** (`scope` field).
- New catalog shards: `valueBuilders.json` (Font/Color/Animation/gradient/material vocab), `conformances.json` (custom `ButtonStyle`/`Layout`/…), `bridges.json` (AppKit/UIKit wrappers), `settings.json` (settings/preferences screens + the Form vocabulary used inside each). `modifiers.json` entries gain `arg_shapes`; all entries gain `availability`; `insights.json` gains `deprecated_api_usage`; `rankings.json` gains `most_modern_stack` (inferred min-macOS).
- Regression test: `python3 swiftui-scan/fixtures/check.py` (13 assertions over `fixtures/Sample.swift`).

## Design notes
- **Matching is decoupled from parsing**: scanner emits raw, SDK-agnostic occurrences; Stage 5
  matches them against `sdk_catalog.json`, so the catalog can be rebuilt/re-sliced without re-cloning.
- **Precision**: Stage 5 only mines files importing SwiftUI/SwiftUICore/Charts; the SDK modifier
  set subtracts Swift/Combine/Foundation method-name collisions (`.map`/`.filter`/`.encode`…),
  protecting a small set of real SwiftUI modifiers (`padding`/`frame`/`offset`/`tag`…).
- **Resumable**: a repo with a `done`-terminated JSONL is skipped. **Disk-bounded**: clone→delete
  streaming, peak ≈ jobs × largest shallow clone.
- **Gate rationale**: junk (vscode/joplin/brew) has Swift `share≈0.00`; real Obj-C/Swift hybrids
  (iTerm2 0.32, NetNewsWire 0.62) are kept. Threshold: `share≥0.2 AND swift_bytes≥3000`.
