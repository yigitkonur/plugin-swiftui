---
name: swiftui-examples
description: Use BEFORE writing or editing ANY SwiftUI code (a View, modifier, Scene, @State/@Observable/@Environment, gesture, command, style) — and the moment you are about to write a SwiftUI API from memory, pick an argument shape, check the current idiom for an API, or plan a SwiftUI feature. Surfaces real production SwiftUI usage from 1,857 shipping macOS apps via the `swiftui-ctx` CLI, replacing guessing with real, quality-ranked, current examples that carry GitHub permalinks — stopping hallucinated and deprecated APIs. Do NOT use for official API signatures/semantics (use sosumi.ai), migrating an existing file off deprecated APIs (use swiftui-modernize), a whole-codebase audit (use audit-macos-swiftui-full), non-SwiftUI Swift (Foundation/Combine/AppKit), or Xcode/build config.
license: MIT
compatibility: Requires macOS with a Swift 6 toolchain (Xcode) to build the bundled CLI on first run; the file command needs network access. Using the CLI needs nothing else (the catalog is bundled).
---

# swiftui-examples — drive `swiftui-ctx`

`swiftui-ctx` answers **"how do shipping macOS apps actually write this SwiftUI?"** from **1,857 analyzed
production repos**, quality-ranked (author authority + stars + modernity) with GitHub permalinks. It is the
*practice* layer; the *spec* is **sosumi.ai** (official docs), which every result links to.

`swiftui-ctx` is the bundled wrapper at `${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx` — it downloads or builds the CLI on
first run and points it at the catalog automatically. Inside the plugin call `"$CLAUDE_PLUGIN_ROOT/scripts/swiftui-ctx" <cmd>`;
from a clone, run `make install` once to put `swiftui-ctx` on PATH. Both self-locate the catalog.

## The rule (do this first, every time)

**Writing SwiftUI from memory is how LLMs ship hallucinated and deprecated APIs — and it happens on routine code, not just exotic APIs.** This skill exists to stop that. So:

1. **Announce it.** Before writing any SwiftUI, say: *"Using swiftui-examples to ground this in production code."* (Committing out loud is what keeps you in the loop instead of reverting to memory.)
2. **Query before you write.** Do **not** emit a SwiftUI type, modifier, or property wrapper from memory. Run `swiftui-ctx lookup <api>` (or `recipe`/`search`) first. **No exceptions** — even for APIs you "know," because the catalog also tells you the *current* idiom and whether your call is *deprecated*.
3. **Do not return code until you have `file --smart` output in context.** A `lookup` line is a fragment; `file --smart` gives the real, compilable enclosing view. Returning the fragment is the #1 failure mode — don't.

## Why this beats your memory (the payoff)

| Querying gives you | Skipping it risks |
|---|---|
| The **current** idiom (e.g. `foregroundStyle`, `NavigationStack`, `@Observable`) | Shipping a **deprecated** API (`foregroundColor`, `NavigationView`) — flagged in 1,000+ real repos |
| The **consensus** argument shape real apps use | Guessing an overload that compiles but isn't idiomatic |
| A **compilable** enclosing view from a high-authority app | A plausible-looking fragment that doesn't actually work |
| **macOS-correct** patterns (MenuBarExtra, Settings, NSViewRepresentable bridges) | iOS-isms that don't fit a Mac app |
| A **GitHub permalink** the user can verify | Unverifiable, confidently-wrong code |

Full rationale + how ranking works (so you can trust `recommended`/`consensus`) → `references/why-this-matters.md`.

## When to use — fire on ANY of these
- About to **write/edit** a SwiftUI call: a `View`/`Scene` type, a `.modifier(...)`, `@State`/`@Binding`/`@Observable`/`@Environment`/`@AppStorage`/`@FocusState`, a gesture, a `Command`, a style.
- **Unsure** of an argument shape or which overload; verifying the **current idiom** for an API before you write it.
- **Planning** a SwiftUI feature (which APIs/recipes to reach for). For *migrating* an existing file off deprecated APIs use `swiftui-modernize`; for *symptoms* in finished code ("state not updating", "list is slow") or a whole-codebase pass, run the relevant `audit-swiftui-*` skill / `audit-macos-swiftui-full`.

## Do NOT use (and what to use instead)
- **Official signatures/semantics** → **sosumi.ai** (the `doc:` link in every result).
- **Non-SwiftUI Swift** (Foundation, Combine, standalone AppKit, language syntax). **Xcode/build/signing** config.
- **iOS-only code** → only with `--platform any` (the corpus is macOS-first).

## First run / discovery
The CLI + catalog ship with the plugin. The bundled wrapper downloads or builds the CLI on first use and finds the
catalog automatically — no manual paths.
```sh
CTX="${CLAUDE_PLUGIN_ROOT:-.}/scripts/swiftui-ctx"   # or just `swiftui-ctx` after `make install` from a clone
"$CTX" doctor     # confirms the catalog loads (exit 5 = catalog missing → STOP, tell the user, do not fabricate)
```
First run may take ~1-2 min (downloads a prebuilt binary, or builds from source if a Swift toolchain is present).
Names work as you write them: `lookup @State`, `lookup .searchable`, `lookup frame(width:height:)` all resolve.
Add `--json` for the machine envelope; default is human markdown ending in a literal `Next:` block.

## The loop (non-negotiable)
1. Run the **first command** for your situation (table below).
2. **Read `next_actions`** and **run the highest-priority one** — almost always `swiftui-ctx file <id> --smart`.
3. Only then write code. **Stop after** `lookup` + `file --smart` on the `recommended` example; go deeper
   (`examples`, `file --full`) only if the consensus shape is ambiguous for your task.

## Scenario → command playbook (situation → first command → required follow-up)
| Situation | First command | Then |
|---|---|---|
| Writing a call to a known API | `swiftui-ctx lookup <api>` | `swiftui-ctx file <recommended.id> --smart` |
| Choosing the argument shape / overload | `swiftui-ctx lookup <api>` → read `consensus` | `swiftui-ctx examples <api> --shape "(…)"` |
| Is it current / deprecated? | `swiftui-ctx deprecated <api>` | if deprecated → `swiftui-ctx lookup <replacement>` |
| Building a known pattern | `swiftui-ctx recipe <name>` | `swiftui-ctx file <example.id> --smart` |
| Planning a feature (unknown APIs) | `swiftui-ctx search "<intent>"` | `swiftui-ctx lookup <each candidate>` |

(Migrating a file off deprecated APIs → `swiftui-modernize`. Reviewing/auditing finished code or a whole project → the `audit-swiftui-*` skills / `audit-macos-swiftui-full`. This skill is the *write/lookup* layer those skills call for the consensus shape.)

Worked transcripts for each row + the recipe list → `references/playbook.md`.

## Reading results (trust the ranking)
- Prefer **`recommended`** over `diverse` — it's the highest production-quality call site (authority + stars + modernity).
- Follow **`consensus`** — write the shape most apps use; rare shapes are edge cases.
- **Never emit a `deprecated` API** — use the `replacement` the tool gives.
- `co_occurs_with` = APIs used *disproportionately* with this one (real pattern signal). `low_corpus: true` = thin evidence, cross-check the `doc:` link.

## Errors → actions (exit codes)
`3` not-found → `swiftui-ctx search "<broader term>"`. `4` network (only `file` w/o `--offline`) → retry once, then `--offline`.
`5` no catalog → **STOP, tell the user, do NOT fabricate from memory.** Full command/flag/field/exit contract → `references/commands.md`.

## Anti-patterns (don't)
- Writing the modifier first and "checking later" → you won't; the deprecated/wrong idiom ships. Query **first**.
- Returning the one-line `lookup` `src` as the answer → it's a fragment. `file --smart` or it didn't happen.
- Inventing an API when `lookup` 404s → run `search`; if still nothing, say so and use sosumi — never fabricate.

## References
| File | Read when |
|---|---|
| `references/playbook.md` | You need the worked command transcripts per scenario + the recipe catalog. |
| `references/commands.md` | You need the exact flags, `--json` field schema, and exit-code contract. |
| `references/why-this-matters.md` | You doubt the tool / want to know how ranking works and what "production-grade" means here. |
