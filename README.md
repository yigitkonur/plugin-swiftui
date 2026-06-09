# skill-swiftui

**real-world swiftui for ai agents — grounded in 1,857 shipping macOS apps.**

[![version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/yigitkonur/skill-swiftui/releases) [![license](https://img.shields.io/badge/license-MIT-green)](LICENSE) [![platform](https://img.shields.io/badge/platform-macOS-lightgrey)](https://developer.apple.com/macos/)

---

ai agents write bad swiftui. not wrong-syntax bad — confidently-stale bad. deprecated modifiers, api shapes that never existed, idioms from three wwdc generations ago. docs tell the agent *what* an api does. they don't tell it *how shipping mac apps actually use it in 2026*.

this plugin fills that gap. it gives claude a queryable corpus of 1,857 real open-source macOS apps — parsed with swiftsyntax (the real compiler parser, not regex), ranked by quality, and wrapped in a cli that answers: **"how do actual shipping apps write this?"** every result includes a github permalink pinned to a commit sha, and links back to the matching [sosumi.ai](https://sosumi.ai) doc so the spec and the practice are always one hop apart.

on top of the lookup layer sits a complete **macOS swiftui audit suite** — 29 skill-driven auditors covering everything from accessibility and concurrency to liquid glass and app-store sandboxing, each backed by a 334-rule static lint engine.

---

## numbers

| stat | value |
|---|---|
| repos analyzed | **1,857** macOS swiftui apps |
| parsed with | **swiftsyntax** — exact attributes, modifiers, property wrappers, call shapes |
| sdk surface matched against | macOS 26.5 `.swiftinterface` + `swift symbolgraph-extract` |
| api coverage | 511 modifiers · 402 types · ~120 style values · property wrappers · env keys · 12 whole-pattern recipes |
| audit rules | **334** (282 ripgrep + 52 ast-grep structural) across 29 domain auditors |
| skills | **33** (4 write/lookup + 29 audit) |
| commands | **4** (`/swiftui` · `/swiftui-review` · `/swiftui-audit` · `/swiftui-settings`) |
| ranking | composite quality score: author authority + repo stars + api modernity + recency |

---

## install

```
/plugin marketplace add yigitkonur/skill-swiftui
/plugin install swiftui
```

the cli (`swiftui-ctx`) auto-installs on first use — downloads a prebuilt universal binary, or builds from source if you have xcode. no manual paths, no environment setup.

optional audit deps: [`ast-grep`](https://ast-grep.github.io) + [`ripgrep`](https://github.com/BurntSushi/ripgrep) unlock the structural lint tier.

```sh
brew install ast-grep ripgrep   # optional but recommended for full audit
```

without them the audit suite degrades gracefully to the ripgrep-only tier.

### cli only (no plugin)

```sh
git clone https://github.com/yigitkonur/skill-swiftui && cd skill-swiftui
make install          # downloads/builds the cli + symlinks swiftui-ctx onto PATH
swiftui-ctx doctor    # verify the install
```

---

## the four commands

### `/swiftui <api or intent>`

look up any swiftui api — how it's actually used, what argument shapes shipping apps prefer, which apis appear alongside it, and the best real-world example with a github permalink.

```
/swiftui NavigationSplitView
/swiftui @Observable
/swiftui "drag and drop between lists"
/swiftui .searchable
```

### `/swiftui-review [file or diff]`

review a swift file or the current diff for deprecated apis, non-idiomatic patterns, and consensus deviations. produces a prioritized finding list with migration paths and real counterexamples.

```
/swiftui-review MyView.swift
/swiftui-review                   # reviews the current diff
```

### `/swiftui-audit [directory]`

full codebase audit. the orchestrator routes your source tree through the relevant domain auditors in dependency-ordered waves, runs the static lint engine, and rolls everything into `_SUMMARY.md`.

```
/swiftui-audit Sources/
/swiftui-audit .                  # from the project root
```

### `/swiftui-settings`

create or update `.claude/swiftui.local.md` — per-project plugin config (deprecation hook on/off, audit strictness). the file is gitignored automatically.

---

## skills

skills fire automatically when you describe a task. the commands above are the explicit entry points.

### write / look up (4 skills)

| skill | when it fires |
|---|---|
| `swiftui-examples` | writing or looking up a swiftui api — returns consensus arg shape + ranked real examples |
| `swiftui-modernize` | upgrading existing code — finds deprecated apis and produces concrete migration patches |
| `macos-app-patterns` | scaffolding a whole feature — menu-bar app, settings screen, master-detail, nsview bridge, document app… |
| `build-macos-swiftui` | broader write / review / refactor — @observable state, native mac idioms, hig conformance |

### audit suite (29 skills)

the `audit-macos-swiftui-full` orchestrator runs the right subset automatically. each domain auditor pairs the lint engine (locates candidates) with `swiftui-ctx` evidence (the auditor judges — the engine never reports a finding as fact).

| domain | skill | what it catches |
|---|---|---|
| **orchestrator** | `audit-macos-swiftui-full` | routes all domains, dependency-ordered waves, rolls up to `_SUMMARY.md` |
| accessibility | `audit-swiftui-accessibility` | missing labels, traits, hints; visionOS considerations; dynamic type |
| animation & motion | `audit-swiftui-animation-motion` | deprecated `.animation(_:)`, missing `withAnimation`, spring tuning |
| api currency | `audit-swiftui-api-currency` | deprecated/renamed apis, floor mismatches, successor migrations |
| appearance & color | `audit-swiftui-appearance-color` | hardcoded colors, missing dark-mode adaption, semantic color usage |
| appkit interop | `audit-swiftui-appkit-interop` | NSViewRepresentable wiring, coordinator patterns, update-path gaps |
| appkit overuse | `audit-swiftui-appkit-overuse` | appkit used where a native swiftui equivalent exists |
| async / data loading | `audit-swiftui-async-data` | missing `.task`, retain cycles, `.onAppear` anti-patterns, cancellation |
| availability gating | `audit-swiftui-availability-gating` | missing `#available`, floor mismatches, deployment-target drift |
| charts | `audit-swiftui-charts` | swift charts patterns, accessibility marks, missing axis labels |
| concurrency safety | `audit-swiftui-concurrency-safety` | main-actor violations, sendable gaps, data races via @State on background |
| controls & forms | `audit-swiftui-controls-forms` | focus management, form layout, button styles, picker patterns |
| document model | `audit-swiftui-document-model` | ReferenceFileDocument vs ValueType, undo manager wiring |
| drawing & canvas | `audit-swiftui-drawing-canvas` | Canvas misuse, GeometryReader overuse, MeshGradient floor |
| layout & tables | `audit-swiftui-layout-and-tables` | Table column types, list/table selection, geometry proxies |
| liquid glass | `audit-swiftui-liquid-glass` | macOS 26 liquid glass adoption, glassEffect placement, material misuse |
| localization | `audit-swiftui-localization` | string literals, missing LocalizedStringKey, RTL layout gaps |
| macOS nativeness | `audit-swiftui-macos-nativeness` | hig conformance, keyboard navigation, context menus, toolbar patterns |
| menus & commands | `audit-swiftui-menus-commands` | CommandMenu wiring, keyboard shortcut conflicts, missing separators |
| navigation & toolbars | `audit-swiftui-navigation-toolbars` | NavigationStack/Split patterns, toolbar placement, deprecated nav apis |
| pointer & gestures | `audit-swiftui-pointer-gestures` | hover effects, cursor styles, drag/drop, simultaneous gesture conflicts |
| previews | `audit-swiftui-previews` | #Preview macro migration, PreviewProvider removal, preview traits |
| sandbox & files | `audit-swiftui-sandbox-files` | security-scoped bookmarks, entitlement gaps, FileImporter patterns |
| scenes & windows | `audit-swiftui-scenes-windows` | Settings scene, WindowGroup sizing, openWindow misuse, MenuBarExtra |
| state & observation | `audit-swiftui-state-observation` | @Observable vs ObservableObject, @Bindable, environment propagation |
| state restoration | `audit-swiftui-state-restoration` | SceneStorage, AppStorage, restoration identifiers |
| swiftdata | `audit-swiftui-swiftdata` | @Model schema, ModelContext threading, migration plans |
| typography & text | `audit-swiftui-typography-text` | font scaling, AttributedString usage, markdown rendering |
| view performance | `audit-swiftui-view-performance` | expensive body recomputes, equatable conformance, lazy stack misuse |

---

## cli reference

the cli speaks `--json` (stable envelope: `{ok, schema_version, result, next_actions, error}`) with semantic exit codes (0 ok · 2 lint-hard · 3 not-found · 4 invalid · 5 env). every result ends with a `next_actions` block — literal commands to drill in.

```sh
# look up an api — consensus shape + ranked examples + co-occurring apis
swiftui-ctx lookup NavigationSplitView
swiftui-ctx lookup @Observable --json

# full-text search by intent
swiftui-ctx search "command palette"
swiftui-ctx search "drag files between lists"

# pull the enclosing view live from github (syntax-accurate span)
swiftui-ctx file ex_4bdd3cf4d9 --smart

# whole patterns
swiftui-ctx recipe menubar-app
swiftui-ctx recipes                      # list all 12

# deprecation guard
swiftui-ctx deprecated foregroundColor   # → .foregroundStyle
swiftui-ctx deprecated listStyle         # → lists all deprecated forms

# sdk / conformance info
swiftui-ctx conformances View            # what protocols View conforms to
swiftui-ctx bridges                      # all known nsview / uiview bridge patterns

# quality + coverage
swiftui-ctx rankings                     # top-quality repos in the corpus
swiftui-ctx stats                        # corpus summary
swiftui-ctx insights                     # usage patterns + outliers

# environment
swiftui-ctx doctor                       # verify install, catalog, sdk surface
swiftui-ctx settings                     # show active config paths
```

api names are flexible — `@State`, `.frame`, `frame(width:height:)` all resolve correctly.

---

## per-project settings

run `/swiftui-settings` once to configure this project. it creates `.claude/swiftui.local.md`:

```markdown
---
enabled: true       # false → silences the deprecation hook
strict_audit: true  # false → /swiftui-audit is advisory only (no non-zero exit on hard findings)
---
```

the file is gitignored automatically (`.claude/*.local.md`). restart claude code after editing for hook changes to take effect. you can also set `SWIFTUI_GUARD=off` as an env var to disable the hook without a config file.

---

## how the data was built

it's reproducible. `scripts/00..08_*.sh` do the full pipeline (see [`RUN.md`](RUN.md)):

```
00 harvest awesome-mac
 → 01 gate (recent commits + actually swiftui)
  → 02 build sdk symbol catalog from .swiftinterface
   → swiftui-scan (swiftsyntax) parses every .swift file
    → 04 clone → scan → delete loop across all 1,857 repos
     → 05 aggregate shards into catalog/
      → 06 discover more via macos-exclusive github code search
       → 07 author-authority enrichment (contributor aggregate stars)
        → 08 recipe extraction
```

the cli reads from `catalog/` (plain json, checked in). the 92mb raw decl dump is excluded — regenerate with the pipeline if you need it.

---

## honesty

- **macOS-first**: ~83% of the corpus is a proper macOS app. for iOS/cross-platform examples, pass `--platform any`.
- **evidence tiers**: `low_corpus: true` means < 10 repos — thin evidence, cross-check the sosumi doc.
- **the ranking is a heuristic**: `recommended` ≈ "how a current, high-quality mac app writes it." trust it over memory; verify the spec on sosumi.
- **audit findings are candidates**: the lint engine locates. the auditor skill judges. a grep match is never a confirmed bug — the agent reads the surrounding code and decides.
- **sdk surface**: matched against macOS 26.5. floor annotations in `references/_shared/floors-master.md` are verified against apple's published release notes; anything marked `verify-SDK` needs xcode confirmation.

---

## credits

- [sosumi.ai](https://sosumi.ai) — apple docs as markdown for llms. we link to every matching doc.
- [awesome-mac](https://github.com/jaywcjlove/awesome-mac) by jaywcjlove — the seed corpus.
- apple swiftsyntax + swift-argument-parser — the parser and the cli scaffolding.
- the 1,857 authors who shipped real macOS apps in the open. every example permalink points back to your repo.

---

## license

mit. see [`LICENSE`](LICENSE).
