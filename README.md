# skill-swiftui

real-world swiftui, not vibes.

this is a claude/agent skill + a little cli that answers one question: **how do actual shipping macos apps write this swiftui?** it's built from **1,857 real open-source mac apps** scraped + parsed off github, ranked by quality, and handed to your ai agent so it stops writing swiftui from memory (which is how you end up with deprecated `.foregroundColor` and apis that don't exist).

think of it like this: [sosumi.ai](https://sosumi.ai) gives an llm apple's *docs* (the spec). this gives it the *practice* — how the world actually uses the api, with a github permalink to prove it. they pair up. every result here links back to the matching sosumi doc.

## why i made this

i kept fighting my ai agent on swiftui. it'd confidently emit stuff that was either deprecated, the old idiom, or straight up hallucinated. docs help but docs don't tell you *how people actually write it* in 2026. so i scraped the open-source mac swiftui world, parsed every `.swift` file with apple's own parser, ranked the examples by how legit the author/repo is, and wired it into a cli an agent can drive. now when it writes swiftui it grounds it in real code first.

## the gist (the numbers)

- **1,857** macos swiftui repos analyzed (from [awesome-mac](https://github.com/jaywcjlove/awesome-mac) + github code-search discovery)
- parsed with **swiftsyntax** (the real compiler parser), not regex — exact attributes, modifiers, property wrappers, call shapes
- matched against the **real sdk surface** (pulled from the macos 26.5 `.swiftinterface` + `swift symbolgraph-extract`)
- every example ranked by a composite **quality score**: author authority (contributors' aggregate stars) + repo stars + modernity (uses current apis, penalized for deprecated) + recency
- coverage: **511 modifiers · 402 types · ~120 style values · property wrappers · env keys · 12 recipes**
- everything carries a **github permalink** pinned to a commit sha

## install

it's a claude code plugin. one marketplace add, one install:

```
/plugin marketplace add yigitkonur/skill-swiftui
/plugin install swiftui
```

that's it. you get **33 skills** — write/lookup (swiftui-examples, macos-app-patterns), modernize (swiftui-modernize), and a 28-skill macos-swiftui **audit suite** (orchestrated by `audit-macos-swiftui-full`) — plus **2 commands** (`/swiftui`, `/swiftui-review`), a **reviewer agent**, and an opt-in **deprecation hook**. the cli auto-installs on first use — it downloads a prebuilt universal binary, or builds from source if you've got xcode. no manual paths, no setup.

prefer the cli alone (no plugin)?

```sh
git clone https://github.com/yigitkonur/skill-swiftui && cd skill-swiftui
make install          # downloads/builds the cli + symlinks `swiftui-ctx` onto PATH
swiftui-ctx doctor    # sanity check
```

no toolchain and offline? the prebuilt binary covers you; worst case `catalog/*.json` is plain json you can read directly.

## what the cli does

```sh
swiftui-ctx lookup searchable          # how it's really used: consensus arg shapes + the best example + co-occurring apis
swiftui-ctx file ex_4bdd3cf4d9 --smart # pull the real enclosing view live from github (syntax-accurate span)
swiftui-ctx recipe menubar-app         # whole patterns: menu-bar app, master-detail, settings screen, nsview bridge…
swiftui-ctx deprecated foregroundColor # ⚠️ deprecated → use .foregroundStyle (anti-pattern guard)
swiftui-ctx search "command palette"   # intent → the apis/recipes that build it
swiftui-ctx lookup @State              # names work however you write them (@State, .frame, frame(width:height:))
```

every command speaks `--json` (stable envelope: `{ok, result, next_actions, error}`) with semantic exit codes, so an agent drives it without guessing. it ends each result with a `next_actions` block — literal commands to drill in.

## how the data was built (the pipeline)

it's reproducible. `scripts/00..08` do the whole thing (see [`run.md`](RUN.md)):

```
00 harvest awesome-mac → 01 gate (recent + actually-swift) → 02 build the sdk symbol catalog
→ swiftui-scan (swiftsyntax) parses every repo → 04 clone▸scan▸delete → 05 aggregate into catalog/
→ 06 discover MORE via macos-exclusive code-search → 07 author-authority enrichment → 08 recipes
```

the cli contract is in [`cli.md`](CLI.md). the catalog shards in `catalog/` are the queryable output (the 92mb raw decl dump is excluded — regenerate it with the pipeline if you want it).

## what's in the plugin

follows the [agent skills](https://agentskills.io) + claude code plugin specs (`.claude-plugin/`).

**33 skills**, all driving the same `swiftui-ctx` cli + bundled catalog. the agent reaches for them automatically.

- **write / look up:**
  - `swiftui-examples` — writing/looking up a swiftui api → real usage + consensus shape.
  - `swiftui-modernize` — upgrading existing code → find + migrate deprecated apis.
  - `macos-app-patterns` — scaffolding a feature → menu-bar app, settings, master-detail, nsview bridge…
  - `build-macos-swiftui` — broader write/review/refactor guidance (@observable state, native mac idioms…).
- **audit (28 skills):**
  - `audit-macos-swiftui-full` — the orchestrator: routes a codebase through the relevant domain audits in dependency-ordered waves and rolls everything into one `_SUMMARY.md`.
  - 27 domain auditors — `audit-swiftui-{accessibility, concurrency-safety, state-observation, liquid-glass, navigation-toolbars, swiftdata, macos-nativeness, view-performance, scenes-windows, charts, …}`. each pairs a shared grep+ast-grep lint engine (locates candidates) with `swiftui-ctx` evidence (the auditor *judges*, the engine never reports a finding as fact).
- **commands/** — `/swiftui <api|intent>` (quick lookup) · `/swiftui-review [file]` (deprecation + consensus audit).
- **agents/** — `swiftui-reviewer`, a review subagent for swiftui diffs.
- **hooks/** — opt-in `PostToolUse` guard: edit a `.swift` that adds a deprecated api → it nudges the fix (static grep, no latency, warn-only; `SWIFTUI_GUARD=off` to disable).

the cli contract is in [`cli.md`](CLI.md). the shared audit infra lives in `references/_shared/` + `scripts/swiftui-lint.sh`.

**audit deps:** the audit lint tier wants [`ast-grep`](https://ast-grep.github.io) (structural rules) + [`ripgrep`](https://github.com/BurntSushi/ripgrep) (`brew install ast-grep ripgrep`). without ast-grep it degrades to the ripgrep/grep tier. `swiftui-ctx` itself needs neither.

## honesty / caveats

- it's **macos-first** (~83% of the corpus is a real mac app). pass `--platform any` for ios/library examples.
- `examples` shows a curated ≤25-per-api sample; the percentages (`consensus`) are over *all* uses — read the % not the sample count.
- `low_corpus: true` = thin evidence (<10 repos), cross-check the sosumi doc.
- the ranking is a heuristic, not gospel. `recommended` ≈ "how a high-quality, currently-maintained mac app writes it." trust it over memory, verify the spec on sosumi.

## credits

- [sosumi.ai](https://sosumi.ai) / nshipster — apple docs for llms, the spec half. we link to it everywhere.
- [awesome-mac](https://github.com/jaywcjlove/awesome-mac) by jaywcjlove — the seed corpus.
- apple swiftsyntax + swift-argument-parser — the parser + the cli.
- all 1,857 repo authors who shipped real mac apps in the open. this is your code; permalinks point home.

## license

mit. see [`license`](LICENSE).
