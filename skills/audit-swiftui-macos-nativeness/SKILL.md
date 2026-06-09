---
name: audit-swiftui-macos-nativeness
description: Scores a finished macOS SwiftUI codebase 0-100 for native Mac-ness ("iPad-in-a-window" risk) and writes a routed punch-list to swiftui-audits/. Use when the user says the app feels like an iPad app in a window, feels non-native, feels touch-first, or asks "how Mac-native is this", "rate the macOS-ness", "what's missing for a real Mac app", or "do a nativeness pass". Detects missing pointer affordances (onHover, contextMenu, help, focusable, pointerStyle), ungrouped Forms and iOS control density, single-column Lists where a Table belongs, unsized windows, push-stack shells, navigationBarTitle, menu actions faked as buttons, and missing Settings/MenuBarExtra. AUDIT-ONLY, macOS-only, SwiftUI-only. This is a META-AUDIT: it SCORES and ROUTES each smell to the owner skill, it does NOT contain the fixes. Not for iOS/iPadOS, not for HIG snapshot review, not for writing UI from scratch, not for the deep per-domain fixes themselves.
---

# Audit SwiftUI macOS Nativeness

**AUDIT-ONLY · macOS-only · SwiftUI-only · META-AUDIT (score + route, never fix).** Run this on a
*finished or in-progress* macOS SwiftUI project to answer one question: **"how much does this read like
an iPad app dropped into a window?"** It emits a **0-100 nativeness score** and a **prioritized
punch-list** where every smell is **routed to the owner skill that fixes it** — this skill itself never
writes a code fix. Findings are written to disk in the toolkit's unified schema with `fix_mode:
flag-only`; the run index is a `kind: nativeness-dashboard`.

The Mac is **pointer-driven, not touch**: it has a cursor, a right mouse button, a Tab-key focus ring,
a resizable window, a sortable data grid, a main menu, and a Settings scene. iOS has none of these, so an
iOS-trained model emits code that compiles and looks plausible but is missing the entire Mac affordance
vocabulary. That gap is what this skill measures.

## Boundary / seam note (stay in lane)

This is a **router, not a repairer.** Every finding here carries a `cross_ref` to the **owner skill**;
the owner skill holds the ❌→✅ fix, the floor, and the auto-fix. Do **not** restate or apply those fixes.

- **Pointer/gesture affordances** (`onHover`, `contextMenu`, `pointerStyle`, `onContinuousHover`,
  touch-only swipe idioms) → **`audit-swiftui-pointer-gestures`**.
- **Control density, `formStyle`, `focusable`/`@FocusState`, `help`, control styles** →
  **`audit-swiftui-controls-forms`**.
- **`List`-where-`Table`, content-frame window sizing, `controlSize` sizing axis** →
  **`audit-swiftui-layout-and-tables`**.
- **Scene-level sizing (`defaultSize`/`windowResizability`), `Settings`/`MenuBarExtra` scenes** →
  **`audit-swiftui-scenes-windows`**.
- **Push-stack-as-shell, `navigationBarTitle`, toolbar placements** →
  **`audit-swiftui-navigation-toolbars`**.
- **Menu actions faked as buttons, `.commands` / `CommandMenu`** → **`audit-swiftui-menus-commands`**.
- **Glass chrome** is `audit-swiftui-liquid-glass`'s; **VoiceOver labels** are
  `audit-swiftui-accessibility`'s — this skill notes the seam and routes, never owns it.

Seam ownership + the exact `cross_ref` targets are in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` (the `macos-nativeness` row) — read it,
never restate it.

## The one rule

**A smell is the *absence* of a Mac affordance, not the presence of a bad one.** Most tells here are
"this interactive view has **no** `.onHover`", "this `Form` has **no** `.formStyle(.grouped)`", "this app
has **no** `Settings {}` scene". Grep/ast-grep **locate candidate sites**; the **absence judgment is
yours after READ**. Never score a smell you have not confirmed by reading the view in full.

## Smell index (nat-01 … nat-15)

`id · one-line tell · severity · routed owner skill · reference`. Severities: **warning** (compiles but
non-native), **advisory** (judgment / density). There are **no hard-fails** — nothing here breaks the
build; it breaks the *feel*. **`fix_mode` is `flag-only` for every row** (this skill routes, never
fixes).

| id | One-line tell (the iPad-in-a-window smell) | Sev | Route → owner skill | Reference |
|---|---|---|---|---|
| nat-01 | custom interactive row/card with no `.onHover` (no pointer affordance) | warn | pointer-gestures | `smell-catalog.md` |
| nat-02 | icon-only `Button`/segment with no `.help` tooltip | warn | controls-forms | `smell-catalog.md` |
| nat-03 | custom focus-taking view with no `.focusable()` / `@FocusState` (Tab skips it) | warn | controls-forms | `smell-catalog.md` |
| nat-04 | row/item view with actions but no right-click `.contextMenu` | warn | pointer-gestures | `smell-catalog.md` |
| nat-05 | draggable / divider / clickable view with no `.pointerStyle` cursor | adv | pointer-gestures | `smell-catalog.md` |
| nat-06 | `Form` with no `.formStyle(.grouped)` (macOS default is ungrouped) | warn | controls-forms | `smell-catalog.md` |
| nat-07 | default control density — no `.listStyle`/`.controlSize`/`.pickerStyle(.menu)` (reads oversized) | adv | controls-forms | `smell-catalog.md` |
| nat-08 | single-column `List` of structured rows where a sortable `Table` belongs | warn | layout-and-tables | `smell-catalog.md` |
| nat-09 | `WindowGroup`/`Window` content with no min/ideal/max `.frame` | warn | layout-and-tables | `smell-catalog.md` |
| nat-10 | scene with no `.defaultSize` / `.windowResizability` | warn | scenes-windows | `smell-catalog.md` |
| nat-11 | `NavigationStack` / deprecated `NavigationView` as the **top-level shell** (push stack, not a Mac sidebar) | warn | navigation-toolbars | `smell-catalog.md` |
| nat-12 | `navigationBarTitle` / `navigationBarTitleDisplayMode` / `navigationBar*`/`topBar*` placements | warn | navigation-toolbars | `smell-catalog.md` |
| nat-13 | menu actions faked as in-window buttons; no `.commands {}` main-menu | warn | menus-commands | `smell-catalog.md` |
| nat-14 | no `Settings {}` scene / no `MenuBarExtra` (menu-bar app faked with `NSStatusItem`) | warn | menus-commands / scenes-windows | `smell-catalog.md` |
| nat-15 | `.swipeActions` / swipe-to-delete as the **only** way to act on a row (touch idiom) | adv | pointer-gestures | `smell-catalog.md` |

The **0-100 score** is computed from the confirmed smell set by category weight — the rubric, the
dashboard layout, and the punch-list ordering are in `references/nativeness-scoring.md`. The route table
+ how to emit `cross_ref` + the route-not-fix discipline are in `references/routing-map.md`.

## The real API, at a glance

These are the Mac affordances whose **absence** is the smell — all real on the floors below (the
reconciled values live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; never restated
here): `onHover` (macOS 10.15+), `help(_:)` (11+), `focusable(_:)` (**12+, not 10.15**), `contextMenu`
(10.15+), `controlSize` (10.15+), `formStyle` (13.0+), `Table` (12+), `pointerStyle(_:)` (15+),
`onContinuousHover` (14+), `defaultSize`/`windowResizability` (13+), `NavigationSplitView` (13+),
`Settings`/`SettingsLink` (11/14), `MenuBarExtra` (13+), `commands`/`CommandMenu`. The canonical
**shape** of each is fetched live from `swiftui-ctx` in VERIFY/FIX — never hand-assert a signature.
The deprecated/iOS-only names you flag (route them) are `navigationBarTitle`,
`navigationBarTitleDisplayMode`, `navigationBarLeading/Trailing`, `topBarLeading/Trailing` (the last two
are **unavailable on macOS** → owner skill confirms the compile error), and `NavigationView`.

## Grounded ✅ affordance (the canonical shape, from real code)

The `## Correct` block of a finding shows the **owner's route + the `swiftui-ctx` consensus affordance
shape backed by a real macOS-26 example** — never a hand-written snippet. Worked for nat-01 (`onHover`),
verified live (`swiftui-ctx lookup onHover --json` → `consensus` `{ }` at **96%**, `introduced_macos`
`10.15`; `swiftui-ctx file ex_ffa067d89d --smart` for the enclosing view):

```swift
// ✅ The Mac affordance whose ABSENCE is nat-01 — the 96%-consensus closure shape.
// Real macOS-26 site (sindresorhus/Gifski, ★8409), an icon Button that highlights on hover:
Button("Toggle Trimmer", systemImage: "chevron.compact.down", action: action)
    .labelStyle(.iconOnly)
    .background(Capsule().fill(.white.opacity(isHovered ? 0.2 : 0.05)))
    .onHover { isHovered = $0 }     // ← the missing piece a custom interactive view needs
```

- **Source (real permalink, goes in `## Source`):** https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Components/TrimmingAVPlayer.swift#L729
- **Spec (Sosumi):** doc: https://sosumi.ai/documentation/swiftui/view/onhover(perform:) — `onHover(perform:)`, macOS 10.15+.
- **Route:** the *fix* (adding the affordance) belongs to `audit-swiftui-pointer-gestures`; this skill only flags the absence and hands off. Re-derive the shape live per API in VERIFY/ROUTE — never trust this snippet as a static signature.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET` or `Package.swift` `platforms:`) — it bounds which
   affordances are even *available* to expect (`pointerStyle` only ≥15, `onContinuousHover` only ≥14).
   Find the `@main App` scene body: it anchors nat-09/10/11/13/14.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-macos-nativeness --dir <sources> --json /tmp/nat.json --sarif /tmp/nat.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 ast-grep structural rules
   (`lint/ast-grep/*.yml` — icon-button-no-help, stack-as-shell), a per-file **parse probe**, and emits
   unified JSON + SARIF. **Read `parse_warnings`** — a file that didn't fully parse must be READ by
   hand. The runner only **LOCATES candidate sites**; presence-of-an-idiom or presence-of-an-interactive
   -view is never itself a finding. Engine + rule format:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full**. The smell is an **absence** (no `.onHover`, no
   `.formStyle`, no `Settings` scene) — invisible to grep, decidable only by reading the whole view +
   the App body. Build a per-view inventory: each interactive view + which Mac affordances it carries
   and which it lacks.
4. **DETECT.** Apply the index. A smell counts **only at 100% certainty** that the affordance is truly
   absent *and* the floor supports it (e.g. don't flag missing `pointerStyle` under a macOS-14 floor).
   Assign each its category for scoring.
5. **VERIFY.** For any affordance whose existence/shape/floor you are < ~100% sure of, run **both**
   evidence sources. (a) **Practice** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api>
   --json`: read its `consensus` (the canonical shape), `introduced_macos`, `recommended` permalink, and
   `co_occurs_with`; for a deprecation route (nat-11/12) also `swiftui-ctx deprecated <api>`. A `lookup`
   **exit 3** means the symbol you expected is not real. (b) **Spec** — confirm the floor via **Sosumi**:
   `curl -sSL https://sosumi.ai/<apple-path>` per `references/source-directory.md` and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` (never `WebFetch` developer.apple.com).
   Cross-check `introduced_macos` against `floors-master.md`. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
   **Deeper corpus evidence (benchmark the score):** anchor the 0-100 to the real-Mac-app baseline —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx stats --json` (`.result.modern_stack`) +
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx insights modern-stack --json`
   (`.result.data` = `modern_stack_adoption_pct`) +
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx rankings most_modern_stack --json`. Over 1,857 shipping
   repos, adoption is `@Observable` **23.4%**, `NavigationStack/SplitView` **41%**, `Settings` scene
   **30.1%**, `MenuBarExtra` **21.6%** — phrase findings as "real apps adopt X at N%; this app M%", and use
   `rankings most_modern_stack` (e.g. `0xCUB3/wBlock`, 205 unique APIs) as the top-decile exemplar.
6. **SCORE + REPORT.** Compute the 0-100 nativeness score (`references/nativeness-scoring.md`). Write
   each confirmed smell as a finding (output contract below), one per file, with its `cross_ref` to the
   owner skill. Write the run's `_index.md` as the **nativeness dashboard** (`kind: nativeness-dashboard`):
   the score, the per-category breakdown, and the prioritized punch-list.
7. **ROUTE (this skill's "FIX").** This skill is `fix_mode: flag-only` for **every** smell — it applies
   **no** code change. The `## Correct` of each finding is **not a fix here**; it is (a) a one-line "run
   `<owner-skill>` to fix this" route, and (b) the `swiftui-ctx` **consensus shape** as the canonical ✅
   affordance, backed by a real macOS-26 example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   goes in `## Source`. The fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`) still governs: since nothing is
   `fix_mode: auto`, **no commit is made by this skill** — it hands off.
8. **DOUBLE-CHECK.** Re-confirm each finding's `cross_ref` names a valid sibling slug (per
   `cross-ref-graph.md`) and the routed owner actually owns that fix (no double-ownership). Re-confirm
   every floor citation still resolves. Recompute the score from the final finding set so the dashboard
   total equals the sum of its parts.

## Confidence gating (load-bearing)

Score a smell **only at 100% certainty** the affordance is absent and in-floor. Anything less goes to
VERIFY (step 5) first. This skill never auto-fixes (`fix_mode: flag-only` everywhere) — it routes.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized:

- Findings: `swiftui-audits/macos-nativeness/<context>/NN-slug.md` (one per file, zero-padded, ordered).
- Run index: `swiftui-audits/macos-nativeness/_index.md` with `kind: nativeness-dashboard` (the score +
  category breakdown + prioritized punch-list — layout in `references/nativeness-scoring.md`).
- `domain: macos-nativeness`. `fix_mode: flag-only` on **every** finding. Every finding carries a
  `cross_ref` to its owner skill (`status: open`, never `fixed` by this skill). `availability` reads
  from `floors-master.md`. `source` is an Apple URL via Sosumi or `verify against Xcode 26 SDK`.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a smell here when… |
|---|---|
| `pointer-affordances/` | missing `onHover`/`contextMenu`/`pointerStyle`, or a touch-only swipe idiom (nat-01, nat-04, nat-05, nat-15) |
| `control-density-forms/` | missing `help`/`focusable`, ungrouped `Form`, or iOS control density (nat-02, nat-03, nat-06, nat-07) |
| `data-grid-windows/` | a `List`-where-`Table`, or content-frame/scene window sizing is absent (nat-08, nat-09, nat-10) |
| `navigation-shell/` | a push stack used as the shell, or stale `navigationBar*` API (nat-11, nat-12) |
| `menus-scenes/` | menu actions faked as buttons, or a missing `Settings`/`MenuBarExtra` scene (nat-13, nat-14) |

**New-folder rule:** *if a smell does not fit an existing context folder, create a new lowercase-hyphen
folder under `swiftui-audits/macos-nativeness/` and note it in the run's `_index.md`. Prefer an existing
folder when the fit is reasonable; two runs over the same code produce structurally identical trees.*

## Reference routing

| File | Open when |
|---|---|
| `references/smell-catalog.md` | the per-smell depth — the iPad-in-a-window tell, why AI emits it, the absence-detection method (nat-01 … nat-15) |
| `references/nativeness-scoring.md` | step SCORE+REPORT — the 0-100 rubric, category weights, the `nativeness-dashboard` layout, punch-list ordering |
| `references/routing-map.md` | step ROUTE — smell → owner-skill table, how to emit `cross_ref`, the route-not-fix discipline |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` (`nat-02-icon-button-no-help.yml`, `nat-11-stack-as-shell.yml`) | step LOCATE — this skill's declarative rule set fed to the shared runner (tier-1 grep + tier-2 structural); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule when an affordance needs a floor gate |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7 — here only the no-auto-fix / hand-off clause) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus affordance shape + permalink (steps 5 VERIFY · 7 ROUTE) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | the `macos-nativeness` seam row + every `cross_ref` target (this skill's whole output is routes) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-macos-nativeness --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv` — the stale-API and touch-idiom
*presence* tells + the interactive-primitive *locators* nat-01…nat-15) + **tier-2 ast-grep** structural
rules (`lint/ast-grep/*.yml` — `nat-02` icon-button-no-help co-occurrence-absence, `nat-11` push-stack
nested directly in `WindowGroup`) that grep cannot express. **Most nat-* tells are *absence* of an
affordance**, which neither grep nor ast-grep can decide — the runner only **locates candidate sites**;
the absence judgment is the LLM's after READ (step 3). It runs a per-file **parse probe**, emits unified
**JSON + SARIF**, exits **0** (no hard-fail rules — nativeness breaks feel, not the build), and
**degrades to grep-only with a notice** if ast-grep is unreachable. The thin `scripts/nativeness-lint.sh`
is a pointer to this runner. Engine + rule-file format + JSON/SARIF shape:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
