---
name: audit-swiftui-navigation-toolbars
description: Audits a finished or in-progress macOS SwiftUI codebase for navigation-shell and toolbar defects on macOS 26 Tahoe and writes per-finding Markdown to swiftui-audits/. Use when the user says the sidebar, columns, split view, titlebar title, or toolbar look wrong, broken, or iPhone-shaped; when they ask to verify NavigationSplitView, NavigationStack, columnVisibility, toolbar placements, ToolbarItem, ToolbarSpacer, navigationTitle, or the inspector; when AI wrote a deprecated NavigationView, used NavigationStack as the app shell, used topBarLeading/topBarTrailing or navigationBarLeading/navigationBarTrailing placements, called navigationBarTitle/navigationBarTitleDisplayMode, or set navigationSplitViewColumnWidth on a detail column; or when a column is hidden by frame hacks instead of a columnVisibility binding. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for AppKit NSSplitViewController internals, menu-bar commands, window scene sizing, the general availability sweep, or writing new navigation UI from scratch.
---

# Audit SwiftUI Navigation & Toolbars

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way the in-window navigation shell and toolbar go
wrong on a macOS 26 (Tahoe) target: a deprecated `NavigationView`, an iPhone push-stack as the Mac
shell, two- vs three-column confusion, frame-hack column hiding, deprecated/platform-absent toolbar
placements, iOS-bar title concepts, and the detail-column-width no-op. Findings are written to disk in
the toolkit's unified schema; certain mechanical defects are fixed under the fix-safety protocol. This
is never a from-scratch navigation generator.

The Mac wants a **persistent multi-column sidebar** (`NavigationSplitView`), not an iPhone push stack.
The containers exist on both platforms but the idioms diverge sharply — be suspicious wherever AI wrote
navigation code from an iOS mental model.

## Boundary / seam note (stay in lane)

- **AppKit `NSSplitViewController` / `NSToolbar` internals are out of scope.** If audited code bridges to
  an AppKit split or toolbar, note it in one line and route the *whether-to-bridge* decision to
  `audit-swiftui-appkit-overuse` and the *how* to `audit-swiftui-appkit-interop` — do not audit AppKit
  internals here. An `HSplitView`/`NSSplitViewController` inspector is the legitimate workaround for
  nav-12 (named, not flagged).
- **`NavigationView` deprecation-flagging** is co-owned: `audit-swiftui-api-currency` owns the
  deprecation *flag*; **this skill owns the structural migration** to `NavigationSplitView`/`NavigationStack`.
  Emit a `cross_ref: api-currency` on a `NavigationView` finding.
- **Window scene sizing** (`.defaultSize` / `.windowResizability`) and `navigationTitle`-in-a-`Window`
  titlebar belong to `audit-swiftui-scenes-windows`; **content-frame** sizing
  (`.frame(min/ideal/max)`) belongs to `audit-swiftui-layout-and-tables`. Sidebar `List` *styling*
  density crosses into `audit-swiftui-controls-forms`; `@FocusedValue` detail-routing crosses into
  `audit-swiftui-menus-commands`; the `ToolbarSpacer` glass era crosses into `audit-swiftui-liquid-glass`.
  Cross_ref, don't double-own.

## The three non-negotiable macOS rules

1. **Mac shell = `NavigationSplitView`, never `NavigationView`/`NavigationStack`.** `NavigationView` is
   deprecated; `NavigationStack` is a push/pop stack for drill-down *inside* a column, not the app shell.
2. **Drive columns with the binding, never the frame.** Column show/hide is the `columnVisibility:`
   initializer parameter bound to a `NavigationSplitViewVisibility` — not a boolean `+`
   `.frame(maxWidth: 0)` hack.
3. **macOS has no navigation *bar* — only semantic toolbar placements + the window titlebar.**
   `.navigationBarLeading`/`.navigationBarTrailing` are deprecated iOS-only; `.topBarLeading`/
   `.topBarTrailing` are **unavailable on macOS** (compile error); `navigationBarTitle`/
   `navigationBarTitleDisplayMode` are no-ops. Use `.navigation`/`.principal`/`.primaryAction` and
   `navigationTitle`/`navigationSubtitle`.

**The shell test:** is this container the *top level* of the app and does it want a persistent sidebar?
→ `NavigationSplitView`. Is it drill-down *inside* one column? → `NavigationStack`. Full reasoning +
the column-map artifact: `references/navigation-shell-and-columns.md`.

**Grounded ✅ (the consensus Mac shell).** `swiftui-ctx lookup NavigationSplitView` → the 2-column
`{ } detail: { }` shape is the consensus at **71%** of 818 uses across 487 repos (`introduced_macos: 13.0`,
`deprecated: false`); the `(columnVisibility)` variant is 27% (nav-04). This is the `## Correct` to put in
every shell finding — not a hand-written snippet. Real macOS-26 call site (`f/textream`, ★3300):

```swift
NavigationSplitView {
    pageSidebar
} detail: {
    mainContent
}
// https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/ContentView.swift#L412
// doc: https://sosumi.ai/documentation/swiftui/navigationsplitview
```

## Defect index (nav-01 … nav-12)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct on
macOS), **warning** (compiles but non-native / silently no-ops), **advisory** (judgment / craft). `auto`
= mechanical single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| nav-01 | `NavigationView {` — deprecated container (through macOS 26.5) | warning | flag | `navigation-shell-and-columns.md` |
| nav-02 | top-level `NavigationStack {` wrapping a sidebar `List(selection:)` → wrong Mac shell | warning | flag | `navigation-shell-and-columns.md` |
| nav-03 | three-column `init(sidebar:content:detail:)` whose `content:` is `EmptyView()`/placeholder → should be 2-column | warning | flag | `navigation-shell-and-columns.md` |
| nav-04 | boolean `+` `.frame(maxWidth: shown ? .infinity : 0)` (or `width: 0`) to hide a column | warning | flag | `navigation-shell-and-columns.md` |
| nav-05 | `.topBarLeading` / `.topBarTrailing` placement on a Mac target — **unavailable on macOS** (compile error) | hard-fail | auto | `toolbar-placements-and-titles.md` |
| nav-06 | `.navigationBarLeading` / `.navigationBarTrailing` placement — deprecated iOS-only | hard-fail | auto | `toolbar-placements-and-titles.md` |
| nav-07 | `.navigationBarTitle(` / `.navigationBarTitleDisplayMode(` — iOS-bar concept, no-op on macOS | hard-fail | auto | `toolbar-placements-and-titles.md` |
| nav-08 | `.navigationSplitViewColumnWidth(` on the **detail** closure — silent no-op on detail | warning | flag | `inspector-and-detail-width.md` |
| nav-09 | sidebar `List` missing `.listStyle(.sidebar)` → wrong material / selection highlight | advisory | flag | `navigation-shell-and-columns.md` |
| nav-10 | `.searchable(` on a column instead of the `NavigationSplitView` → wrong toolbar slot | advisory | flag | `toolbar-placements-and-titles.md` |
| nav-11 | `ToolbarSpacer(` / `SpacerSizing` used ungated under a < macOS 26 floor | warning | flag | `toolbar-placements-and-titles.md` |
| nav-12 | empty detail is a blank view, not `ContentUnavailableView` | advisory | flag | `inspector-and-detail-width.md` |

**One claim is UNVERIFIED — carry as the reference's `verify against Xcode 26 SDK`, never as fact:** the
`navigationSplitViewColumnWidth` **no-op on the detail column** (nav-08, practitioner-confirmed) and the
inspector standard width (**225 pt** Apple examples / **270 pt** community-observed). The
`navigationBar*` placement **exact deprecation version** is `verify-SDK` per `floors-master.md`.

## The real API, at a glance

**Real (exist on a Mac target):** `NavigationSplitView` (2-/3-col inits + `columnVisibility:` /
`preferredCompactColumn:` variants, macOS 13.0+), `NavigationSplitViewVisibility`
(`.all`/`.doubleColumn`/`.detailOnly`/`.automatic`), `NavigationStack` (drill-down inside a column),
`navigationTitle(_:)` (→ window titlebar, macOS 11.0+), `navigationSubtitle(_:)` (macOS 11.0+ — but iOS
floor is **26.0**, much higher), semantic `ToolbarItemPlacement` (`.navigation` → leading, `.principal`/
`.status` → centered, `.primaryAction` → **leading edge on macOS, not trailing**), `ToolbarItem` /
`ToolbarItemGroup`, `ToolbarSpacer` + `SpacerSizing` (`.fixed`/`.flexible`, macOS **26.0+** — gate it),
`.listStyle(.sidebar)`, `.inspector(isPresented:)` + `.inspectorColumnWidth` (macOS 14.0+),
`HSplitView` (the resizable-inspector escape hatch).

**Platform-wrong (macOS ABSENT → compile error, never gate, replace):**
`ToolbarItemPlacement.topBarLeading` / `.topBarTrailing`. **Deprecated:** `NavigationView` (→
`NavigationSplitView`/`NavigationStack`), `.navigationBarLeading` / `.navigationBarTrailing` (→
`.navigation` / `.primaryAction`). **No-op on macOS:** `navigationBarTitle`,
`navigationBarTitleDisplayMode` (+ `.inline`/`.large`).

Signatures, floors, and the full ❌→✅ rewrites: the routed `references/*.md`. Floor *values* are the
reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and the canonical
platform-wrong-name list in `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` §5 —
read, never restate them.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   nav-11 (`ToolbarSpacer`) fires **only** when the floor is **below macOS 26**; nav-01 deprecation
   prose depends on the floor relative to 26.5. Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-navigation-toolbars --dir <sources> --json /tmp/nav.json --sarif /tmp/nav.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + the tier-2 structural ast-grep rule
   (`lint/ast-grep/*.yml` — nav-03's empty-middle-column shape, which grep can't express; nav-04's
   frame-hack and nav-08's columnWidth-on-detail stay grep tells, READ-confirmed, per the rule-file note),
   plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a
   flagged file did not fully parse, so a structural miss can't masquerade as clean; READ those by hand.
   The runner only LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a
   `NavigationStack` is the *shell* or a *column drill-down*, whether a three-column `content:` is truly
   empty, and whether a `columnWidth` sits on the detail closure are all cross-line facts invisible to
   grep. Build a per-file inventory: each navigation container + its role (shell/column) + its columns +
   each toolbar placement + each title modifier.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a `.topBarLeading` placement on a Mac target, a `navigationBarTitle` call, a
   `NavigationView`).
5. **VERIFY.** For anything ≤ ~70% confidence (a placement you're unsure resolves on macOS, a floor you
   can't place, the detail-column no-op behavior), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and
   `swiftui-ctx deprecated <api>` for a currency/deprecation rule): read its `consensus` (the canonical
   shape), `deprecated`+`replacement`/`migrate_to`, `recommended` permalink, `introduced_macos`, and
   `co_occurs_with`; a `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a
   platform-wrong / invented-placement finding — no shipping Mac app uses the symbol. (b) **Spec** —
   confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using
   `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi
   `doc:` floor. The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
   Promote with the citation or discard. Carry nav-08's no-op + inspector width as
   `source: verify against Xcode 26 SDK` — never as fact.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit `cross_ref` on shared-seam findings (nav-01 → `api-currency`). Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (nav-05/06/07 — the mechanical placement/title renames), one conventional
   commit per finding citing its `rule_id`, never weaken a check. The ✅ "Correct" is **not a
   hand-written snippet** — it is the swiftui-ctx **consensus shape** put in `## Correct`, backed by a
   real macOS-26 example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source` as the canonical example. Leave `flag-only` findings
   `open` with that ✅ in `## Correct`. (E.g. the `NavigationSplitView` consensus shape is the trailing
   `{ … }` two-column form — see the routed reference for the live permalink.)
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves and still says its `macOS` floor. If a
   fix introduced a new tell (e.g. a swapped placement now needs a `ToolbarSpacer` gate), loop that file
   back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding (especially nav-02 shell-vs-drill-down and nav-03
empty-middle-column, which need a READ to settle). Auto-fix only the mechanical placement/title set
(nav-05/06/07); everything else is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/navigation-toolbars/<context>/NN-slug.md` (one finding per file,
  zero-padded, ordered). Per-run index: `swiftui-audits/navigation-toolbars/_index.md`.
- `domain: navigation-toolbars`. Frontmatter is the canonical schema; `fix_mode` is `auto` for
  nav-05/06/07, else `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL
  + access date (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` per the
  boundary/seam note.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `navigation-shell/` | a deprecated `NavigationView`, or a `NavigationStack` used as the Mac shell (nav-01, nav-02) |
| `column-structure/` | a 3-col init with an empty middle, a frame-hack column hide, or a missing sidebar style (nav-03, nav-04, nav-09) |
| `toolbar-placement/` | a platform-absent/deprecated placement, or `.searchable` on the wrong slot (nav-05, nav-06, nav-10) |
| `titlebar-title/` | an iOS-bar title concept used instead of `navigationTitle`/`navigationSubtitle` (nav-07) |
| `inspector-detail-width/` | a `columnWidth` no-op on detail, or a blank empty-detail (nav-08, nav-12) |
| `availability-gating/` | `ToolbarSpacer`/`SpacerSizing` ungated under a < macOS 26 floor (nav-11) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/navigation-toolbars/` with a lowercase-hyphen slug naming the sub-category, and note it
in the run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs
is a hard requirement.* Two runs over the same code produce structurally identical trees.

> **Go-beyond artifact (optional):** `swiftui-audits/navigation-toolbars/_column-map.md` classifying
> every navigation container as `shell`/`column-drilldown` with a column-count and visibility-binding
> coverage score — see `references/navigation-shell-and-columns.md`.

## Reference routing

| File | Open when |
|---|---|
| `references/navigation-shell-and-columns.md` | shell-vs-stack, 2-/3-column inits, `columnVisibility` binding, sidebar `List` style, the column map (nav-01/02/03/04/09) |
| `references/toolbar-placements-and-titles.md` | semantic vs deprecated/platform-absent placements, `navigationTitle`/`navigationSubtitle` vs iOS-bar titles, `.searchable` slot, `ToolbarSpacer` gating (nav-05/06/07/10/11) |
| `references/inspector-and-detail-width.md` | the detail-column-width no-op, `HSplitView`/`NSSplitViewController` / `.inspector` workaround, empty-detail `ContentUnavailableView` (nav-08/12) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | §5 toolbar/navigation platform-wrong placements |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + the `macOS ABSENT` "replace, never gate" rule (nav-05, nav-11) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-navigation-toolbars --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
nav-01/02/04/05/06/07/08/09/10/11/12) + the **tier-2 ast-grep** structural rule (`lint/ast-grep/*.yml` —
nav-03 empty-middle-column shape) that grep cannot express; nav-04 frame-hack and nav-08
`columnWidth`-on-`detail:` stay grep tells (READ-confirmed) because they can't be a clean ast-grep rule.
It runs
a per-file **parse probe** (surfaces "did not fully parse" so a structural miss can't look clean), emits
unified **JSON + SARIF**, exits **2** on any hard-fail (nav-05/06/07/11) for a CI gate, and **degrades
to grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`; faster:
`brew install ast-grep`). It only LOCATES — always READ each hit in full before reporting (step 3). The
thin `scripts/nav-lint.sh` is a pointer to this runner. Engine + rule-file format + JSON/SARIF shape +
safety rails: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
