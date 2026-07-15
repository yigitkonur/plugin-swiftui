# SwiftUI production intelligence for Claude Code and Codex

**real-world SwiftUI for coding agents — grounded in 1,857 shipping macOS apps.**

[![version](https://img.shields.io/badge/version-1.4.2-blue)](https://github.com/yigitkonur/plugin-swiftui/releases) [![license](https://img.shields.io/badge/license-MIT-green)](LICENSE) [![platform](https://img.shields.io/badge/platform-macOS-lightgrey)](https://developer.apple.com/macos/)

---

coding agents write bad swiftui. not wrong-syntax bad — confidently-stale bad. deprecated modifiers, api shapes that never existed, idioms from wwdc three years ago. the docs tell an agent *what* an api does; they don't tell it *how 2026 shipping mac apps actually use it.*

this plugin fills that gap. it gives the agent a queryable corpus of **1,857 real open-source macOS apps** — parsed with swiftsyntax (apple's own compiler parser, not regex), ranked by code quality, and wrapped in a cli that answers one question: **how do actual shipping apps write this?**

every result carries a github permalink pinned to a commit sha and links to the matching [sosumi.ai](https://sosumi.ai) doc so the spec and the practice are always one hop apart.

on top of the lookup layer sits a complete **macOS swiftui audit suite** — 29 skill-driven domain auditors, each backed by a 334-rule static lint engine that locates candidates and lets claude judge.

---

## the numbers

| | |
|---|---|
| repos analyzed | **1,857** open-source macOS SwiftUI apps |
| parser | **swiftsyntax** — exact attributes, modifiers, property wrappers, call shapes; not regex |
| sdk surface | macOS 26.5 `.swiftinterface` + `swift symbolgraph-extract` |
| api coverage | 511 modifiers · 402 types · ~120 style values · property wrappers · env keys · 12 whole-pattern recipes |
| audit rules | **334** total (282 ripgrep + 52 ast-grep structural) |
| skills | **33** — 4 write/lookup + 29 audit |
| explicit workflows | **4** — Claude `/swiftui…` · Codex `$swiftui…` |
| quality ranking | composite score: author authority (aggregate stars) + repo stars + api modernity + recency |

---

## install

Git is the primary distribution channel: both marketplaces are self-contained in this repository. npm packages are optional mirrors and are not required for installation or runtime catalog queries.

The repository moved from `yigitkonur/claude-swiftui-plugin` to `yigitkonur/plugin-swiftui`. GitHub redirects the old repository URL, while the installed plugin and marketplace identifiers remain stable for existing users.

### Claude Code

```
/plugin marketplace add yigitkonur/plugin-swiftui
/plugin install swiftui@claude-swiftui-plugin
```

When upgrading, run `/plugin marketplace update claude-swiftui-plugin`, reinstall `swiftui@claude-swiftui-plugin`, and start a new Claude Code conversation so the refreshed commands, skills, agent, and hook are loaded.

### Codex CLI, app, and IDE

Install from the Git marketplace:

```sh
codex plugin marketplace add yigitkonur/plugin-swiftui
codex plugin add swiftui@swiftui-plugins
codex plugin list --json
codex mcp list --json
```

To upgrade—or to repair a marketplace added before the Codex plugin became self-contained—refresh its cached Git snapshot and reinstall:

```sh
codex plugin marketplace upgrade swiftui-plugins
codex plugin add swiftui@swiftui-plugins
```

Start a new Codex thread, then verify the explicit lookup workflow:

```text
$swiftui NavigationSplitView
```

Review and trust the optional deprecation hook with `/hooks`; only enable it after inspecting the command. The hook remains advisory and never blocks an edit.

To test the Codex plugin directly from a source checkout:

```sh
git clone https://github.com/yigitkonur/plugin-swiftui
cd plugin-swiftui
npm ci
npm run build:codex-dev
codex plugin marketplace add "$PWD/dist/codex-dev-marketplace"
codex plugin add swiftui@swiftui-local
```

the cli (`swiftui-ctx`) auto-installs on first use — downloads a prebuilt universal binary, or builds from source if xcode is available. no manual paths or env setup needed.

**audit deps** — `jq` is required to run the audit/lint tier; `ast-grep` + `ripgrep` are optional (they unlock the structural lint tier):

```sh
brew install jq            # required for the audit suite
brew install ast-grep ripgrep   # optional — structural + faster grep tiers
```

without `ast-grep`/`ripgrep` the audit suite degrades gracefully to the grep-only tier — it still runs 282 rules, just not the 52 ast-grep structural ones. without `jq` the audit scripts exit early with a clear message.

### cli-only install (no plugin)

```sh
git clone https://github.com/yigitkonur/plugin-swiftui
cd plugin-swiftui
make install       # downloads/builds swiftui-ctx and symlinks it onto PATH
swiftui-ctx doctor # verify the install
```

---

## the four explicit workflows

Claude Code uses slash commands. Codex uses explicit skills with the same names:

| workflow | Claude Code | Codex |
|---|---|---|
| lookup | `/swiftui …` | `$swiftui …` |
| review | `/swiftui-review …` | `$swiftui-review …` |
| full audit | `/swiftui-audit …` | `$swiftui-audit …` |
| settings | `/swiftui-settings` | `$swiftui-settings` |

### `/swiftui <api or intent>`

look up any swiftui api by name, modifier, property wrapper, or plain english intent. returns the consensus argument shape (ranked by how production apps actually call it), the best real-world example with a github permalink, co-occurring apis, and a link to the sosumi doc.

```
/swiftui NavigationSplitView
/swiftui @Observable
/swiftui .searchable
/swiftui "drag and drop between lists"
/swiftui frame(width:height:)
$swiftui NavigationSplitView          # Codex
```

### `/swiftui-review [file]`

review a swift file or the current diff for deprecated apis, non-idiomatic patterns, and consensus deviations. produces a prioritized finding list with migration paths and real counterexamples pulled from the corpus.

```
/swiftui-review ContentView.swift
/swiftui-review                    # reviews the current diff
$swiftui-review                    # Codex
```

### `/swiftui-audit [directory]`

full codebase audit. the orchestrator routes your source tree through the relevant domain auditors in dependency-ordered waves, runs the static lint engine, and rolls everything into `_SUMMARY.md` with per-finding severity ratings and fix guidance.

```
/swiftui-audit Sources/
/swiftui-audit .
$swiftui-audit .                   # Codex
```

### `/swiftui-settings`

create or update `.swiftui-plugin/settings.md` — platform-neutral per-project plugin configuration. the legacy `.claude/swiftui.local.md` remains a read-only fallback during migration.

---

## skills

the original 33 skills fire automatically when their domain applies. the four workflows above are explicit-only entry points.

### write / look up (4 skills)

| skill | fires when you… |
|---|---|
| `swiftui-examples` | write or look up a swiftui api — returns consensus arg shape + ranked real examples with permalinks |
| `swiftui-modernize` | upgrade existing code — finds deprecated apis, produces concrete migration patches with before/after |
| `macos-app-patterns` | scaffold a whole feature — menu-bar app, settings screen, master-detail, nsview bridge, document app, toolbar… |
| `build-macos-swiftui` | write / review / refactor broadly — @Observable state, native mac idioms, hig conformance |

### audit suite (29 skills)

`audit-macos-swiftui-full` is the orchestrator — it routes your codebase through the right subset of auditors automatically, runs them in dependency order, and produces `_SUMMARY.md`.

each domain auditor pairs the lint engine (which *locates* candidates) with `swiftui-ctx` evidence (which lets claude *judge*). the engine never reports a finding as fact — it surfaces lines for review.

| domain | skill | what it catches |
|---|---|---|
| **orchestrator** | `audit-macos-swiftui-full` | routes all domains in dependency-ordered waves, rolls up to `_SUMMARY.md` |
| accessibility | `audit-swiftui-accessibility` | missing labels/traits/hints, visionOS notes, dynamic type, reduce-motion |
| animation & motion | `audit-swiftui-animation-motion` | deprecated `.animation(_:)`, missing `withAnimation`, spring misconfiguration |
| api currency | `audit-swiftui-api-currency` | deprecated/renamed apis, floor mismatches, migration paths to successors |
| appearance & color | `audit-swiftui-appearance-color` | hardcoded colors, missing dark-mode adaptation, missing semantic color usage |
| appkit interop | `audit-swiftui-appkit-interop` | `NSViewRepresentable` wiring, coordinator update-path gaps, representable lifecycle |
| appkit overuse | `audit-swiftui-appkit-overuse` | appkit used where a native swiftui equivalent exists and should be preferred |
| async & data loading | `audit-swiftui-async-data` | missing `.task`, retain cycles, `.onAppear` anti-patterns, missing cancellation |
| availability gating | `audit-swiftui-availability-gating` | missing `#available`, floor mismatches, deployment-target drift |
| charts | `audit-swiftui-charts` | swift charts patterns, accessibility marks, missing axis labels, wrong mark types |
| concurrency safety | `audit-swiftui-concurrency-safety` | main-actor violations, sendable gaps, @State mutation off main thread |
| controls & forms | `audit-swiftui-controls-forms` | focus management, form layout, button styles, picker patterns, toggle wiring |
| document model | `audit-swiftui-document-model` | `ReferenceFileDocument` vs value-type, undo manager wiring, autosave |
| drawing & canvas | `audit-swiftui-drawing-canvas` | `Canvas` misuse, `GeometryReader` overuse, `MeshGradient` availability |
| layout & tables | `audit-swiftui-layout-and-tables` | `Table` column types, list/table selection, `GeometryProxy` misuse, lazy stacks |
| liquid glass | `audit-swiftui-liquid-glass` | macOS 26 liquid glass adoption, `.glassEffect` placement, material misuse |
| localization | `audit-swiftui-localization` | raw string literals, missing `LocalizedStringKey`, RTL layout gaps |
| macOS nativeness | `audit-swiftui-macos-nativeness` | hig conformance, keyboard navigation, context menus, toolbar idioms, window chrome |
| menus & commands | `audit-swiftui-menus-commands` | `CommandMenu` wiring, keyboard shortcut conflicts, missing separators |
| navigation & toolbars | `audit-swiftui-navigation-toolbars` | `NavigationStack`/`NavigationSplitView` patterns, toolbar placement, deprecated nav apis |
| pointer & gestures | `audit-swiftui-pointer-gestures` | hover effects, cursor styles, drag/drop wiring, simultaneous gesture conflicts |
| previews | `audit-swiftui-previews` | `#Preview` macro migration, `PreviewProvider` removal, preview traits |
| sandbox & files | `audit-swiftui-sandbox-files` | security-scoped bookmarks, entitlement gaps, `FileImporter`/`FileExporter` patterns |
| scenes & windows | `audit-swiftui-scenes-windows` | `Settings` scene, `WindowGroup` sizing, `openWindow` misuse, `MenuBarExtra` wiring |
| state & observation | `audit-swiftui-state-observation` | `@Observable` vs `ObservableObject`, `@Bindable`, environment propagation |
| state restoration | `audit-swiftui-state-restoration` | `SceneStorage`, `AppStorage`, restoration identifier coverage |
| swiftdata | `audit-swiftui-swiftdata` | `@Model` schema, `ModelContext` threading, migration plans, relationship cascade |
| typography & text | `audit-swiftui-typography-text` | font scaling, `AttributedString` usage, markdown rendering, dynamic type |
| view performance | `audit-swiftui-view-performance` | expensive body recomputes, `Equatable` conformance, lazy stack misuse, heavy initializers |

---

## cli reference

`swiftui-ctx` is the engine behind every skill and command. it speaks `--json` everywhere (stable envelope: `{ok, schema_version, result, next_actions, error}`) with semantic exit codes:

| code | meaning |
|---|---|
| 0 | success |
| 2 | usage error |
| 3 | not found |
| 4 | network error |
| 5 | no catalog / env error |

every result ends with a `next_actions` block — literal commands to drill in further. agents use this to chain calls without guessing.

```sh
# look up how a production app writes a specific api
swiftui-ctx lookup NavigationSplitView
swiftui-ctx lookup @Observable --json
swiftui-ctx lookup frame(width:height:)       # name formats are flexible

# search by intent
swiftui-ctx search "command palette"
swiftui-ctx search "drag files between windows"

# pull the real enclosing view from github (syntax-accurate span)
swiftui-ctx file ex_4bdd3cf4d9
swiftui-ctx file ex_4bdd3cf4d9 --smart        # expand to the full enclosing view

# whole patterns
swiftui-ctx recipe menubar-app                # menu-bar app scaffold
swiftui-ctx recipe settings-screen
swiftui-ctx recipe nsview-bridge
swiftui-ctx recipes                           # list all 12 recipes

# deprecation guard
swiftui-ctx deprecated foregroundColor        # → .foregroundStyle
swiftui-ctx deprecated listStyle             # lists all deprecated forms

# sdk and conformance info
swiftui-ctx conformances View                 # what protocols View conforms to
swiftui-ctx bridges                           # all nsview/uiview bridge patterns

# corpus quality and coverage
swiftui-ctx rankings                          # top-quality repos in the corpus
swiftui-ctx stats                             # corpus summary (repos, coverage, sdk)
swiftui-ctx insights                          # usage patterns and outliers

# environment
swiftui-ctx doctor                            # verify install, catalog, sdk surface
swiftui-ctx settings                          # show active config paths
```

---

## per-project settings

run `/swiftui-settings` in Claude Code or `$swiftui-settings` in Codex to create `.swiftui-plugin/settings.md`:

```markdown
---
enabled: true       # false → silences the deprecation hook entirely
strict_audit: true  # false → /swiftui-audit is advisory (no non-zero exit on hard findings)
---
```

the file is gitignored automatically. restart the agent host after editing for hook changes to take effect. you can also set `SWIFTUI_GUARD=off` to disable the deprecation hook without a settings file. when the neutral file is absent, `.claude/swiftui.local.md` is read for backward compatibility.

**what the deprecation hook does:** every time you edit a `.swift` file, a fast static grep checks whether any deprecated swiftui api names appear in the edit. if they do, it adds a non-blocking nudge — never denies the write, just surfaces the issue so the agent can address it.

---

## how the data was built

the pipeline is reproducible. `scripts/00..08_*.py` do the full thing (run manually, step-by-step, per [`RUN.md`](RUN.md) — this is a dev-only offline build, not an install step):

```
00  harvest seed repos from awesome-mac
 ↓
01  gate: filter to recent commits + actually-swiftui repos
 ↓
02  build sdk symbol catalog from macOS .swiftinterface + symbolgraph-extract
 ↓
03  swiftui-scan (swiftsyntax) — parse every .swift file for exact api usage
 ↓
04  clone → scan → delete loop across all 1,857 repos
 ↓
05  aggregate shards into catalog/ json files
 ↓
06  discovery pass: macOS-exclusive github code search for more repos
 ↓
07  author-authority enrichment: contributors' aggregate stars
 ↓
08  recipe extraction: whole-pattern scaffolds from the best examples
```

the cli reads from `catalog/` (plain json, committed to the repo). the 92mb raw declaration dump is excluded — regenerate it with the pipeline if you need it.

---

## caveats

- **macOS-first**: ~83% of the corpus is a proper macOS app. for iOS or cross-platform examples, pass `--platform any`.
- **evidence tiers**: `low_corpus: true` means fewer than 10 repos matched — thin evidence. cross-check the sosumi doc before trusting the consensus.
- **the ranking is a heuristic**: `recommended` ≈ "how a current, high-quality mac app writes it." trust it over claude's memory; verify the spec on sosumi.
- **audit findings are candidates**: the lint engine locates, the auditor judges. a grep match is never a confirmed bug — claude reads the surrounding code and decides.
- **sdk surface**: matched against macOS 26.5. floor annotations in `references/_shared/floors-master.md` are verified against apple's published release notes; anything marked `verify-SDK` should be confirmed in xcode.

---

## credits

- [sosumi.ai](https://sosumi.ai) — apple docs as markdown for llms. every result links to the matching doc.
- [awesome-mac](https://github.com/jaywcjlove/awesome-mac) by jaywcjlove — the seed corpus.
- apple swiftsyntax + swift-argument-parser — the parser and the cli scaffolding.
- the 1,857 authors who shipped real macOS apps in the open. every example permalink points back to your repo.

---

## license

mit. see [`LICENSE`](LICENSE).
