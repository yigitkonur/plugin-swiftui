---
name: audit-swiftui-layout-and-tables
description: Audits a macOS SwiftUI codebase for layout, window-sizing, and Table defects where an iPhone-shaped layout breaks on a resizable Mac window, and writes per-finding Markdown to swiftui-audits/. Use when the user says the window opens too small or collapses on drag, content overflows the window, or the app feels like an iPad app in a window; when they ask to verify the min/ideal/max content frame, a sortable Table, sortOrder, KeyPathComparator, controlSize density, fixedSize/layoutPriority, or a custom Layout protocol; when AI wrote a single-column List where macOS wants a Table, a Table with no sortOrder, default controlSize in a dense inspector, a blanket fixedSize on a container, or the deprecated tableStyle inset(alternatesRowBackgrounds:). AUDIT-ONLY, macOS-only, SwiftUI-only. Not for scene-modifier window sizing (scenes-windows), control style variants (controls-forms), NavigationSplitView columns (navigation-toolbars), large-Table render cost (view-performance), or new layout from scratch.
---

# Audit SwiftUI Layout & Tables

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way an iOS-shaped layout breaks on a Mac: a
resizable window with no min/ideal/max content frame, no scene sizing, a hand-rolled `List` where
macOS wants a sortable `Table`, a `Table` with no `sortOrder`, default `controlSize` in a dense pane, a
blanket `.fixedSize()` that overflows the window, a deprecated `.tableStyle` case, and a custom `Layout`
where a built-in would do. Findings are written to disk in the toolkit's unified schema; certain
mechanical defects are fixed under the fix-safety protocol. This is never a from-scratch layout generator.

The training corpus is overwhelmingly iOS — **one fixed canvas, no resizable window**. So AI has no
mental model that a Mac window has min/ideal/max dimensions the developer must declare, treats `List` as
the universal container, and leaves `controlSize` untouched. The result compiles and "works"; it just
looks and behaves like an iPad app dropped into a window. Be suspicious wherever AI sized a window or
modeled a data grid.

## Boundary / seam note (stay in lane)

Seam verdicts are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`
— apply them in the tells and emit `cross_ref` on a shared-seam finding; do not double-own.

- **Window sizing is a deliberate two-layer split.** The **content `.frame(min/ideal/max)`** layer is
  **this skill** (lt-01). The **scene modifiers** `.defaultSize` / `.windowResizability` are owned by
  `audit-swiftui-scenes-windows`; lt-02 here is a **companion note** — flag the obvious absence, emit
  `cross_ref: scenes-windows`, and defer scene-modifier depth there.
- **Control density.** The `controlSize` **sizing axis** is **this skill** (lt-05). Style variants
  (`.buttonStyle` / `.pickerStyle` / `.formStyle(.grouped)`) belong to `audit-swiftui-controls-forms`;
  it owns `controlSize` only *inside* a `Table`/inspector seam — `cross_ref` there when style is the issue.
- **`NavigationSplitView` columns / sidebar sizing** belong to `audit-swiftui-navigation-toolbars`.
- **Large-`Table` / large-`List` render cost** (≳5,000 rows, heavy cells, the `NSTableView` bridge
  decision) belongs to `audit-swiftui-view-performance`; note the ceiling in one line and `cross_ref`.
- **A `GeometryReader` feeding a `Canvas`** (drawing geometry) belongs to `audit-swiftui-drawing-canvas`;
  this skill owns `GeometryReader`/`Layout` only when it is doing **layout arrangement**.

## The five layout rules (the judgment core)

1. **Resizable windows are the whole point.** Declare `min/ideal/max` `.frame` on the **root content**
   view; iOS never makes you, the Mac always does (lt-01).
2. **Structured Mac data is a `Table`, not a `List`.** Multi-field rows want real columns, clickable
   headers, multi-column sort, and free row selection — a hand-rolled `HStack`-in-`List` has none of it
   (lt-03).
3. **A Mac `Table` is sortable.** Drive it with `sortOrder: $binding` to `[KeyPathComparator]`; columns
   built with `value:` become clickable/sortable automatically (lt-04).
4. **Tune density per pane.** Pointer-driven dense panes (inspectors, toolbars, settings grids) routinely
   use `.controlSize(.small)`/`.mini`; the iOS default reads as oversized (lt-05).
5. **Reach for the targeted tool before the blunt one.** `layoutPriority` / single-axis
   `fixedSize(horizontal:vertical:)` / `containerRelativeFrame` before a blanket `.fixedSize()` (lt-06)
   or a custom `Layout` (lt-08).

Full ❌→✅ + the canonical resizable-window-with-sortable-Table exemplar:
`references/layout-window-sizing.md` and `references/tables-and-density.md`.

## Defect index (lt-01 … lt-08)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (deprecated / never-correct),
**warning** (compiles but non-native), **advisory** (judgment / density). `auto` = mechanical
single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| lt-01 | scene root content with no `.frame(minWidth:idealWidth:…)` → window opens awkward / collapses on drag | warning | flag | `layout-window-sizing.md` |
| lt-02 | scene (`WindowGroup`/`Window`/`Settings`) with no `.defaultSize` / `.windowResizability` | warning | flag | `layout-window-sizing.md` |
| lt-03 | `List(` wrapping `HStack { Text … Spacer() Text … }` of a struct's fields → wants `Table` + `TableColumn` | warning | flag | `tables-and-density.md` |
| lt-04 | `Table(` with no `sortOrder:` binding / no `KeyPathComparator` → non-sortable on a click-to-sort platform | warning | flag | `tables-and-density.md` |
| lt-05 | dense Mac pane (inspector/settings/toolbar) with no `.controlSize(.small/.mini)` → oversized density | advisory | flag | `tables-and-density.md` |
| lt-06 | blanket both-axis `.fixedSize()` on a *container* → freezes both axes, overflows a resizable window | advisory | flag | `layout-window-sizing.md` |
| lt-07 | `.tableStyle(.inset(alternatesRowBackgrounds:))` / `.bordered(alternatesRowBackgrounds:)` — DEPRECATED (macOS 26.5) | hard-fail | flag | `tables-and-density.md` |
| lt-08 | custom `: Layout` conformance where a built-in (`Grid`/`ViewThatFits`/`containerRelativeFrame`) fits | advisory | flag | `custom-layout.md` |

**lt-07 is the only deprecation; lt-02 and lt-05 cross-ref siblings.** The macOS 26.5 case-level
deprecation of `tableStyle(.inset(alternatesRowBackgrounds:))` is confirmed on `developer.apple.com`
(swiftui-ctx tracks deprecation at the API level, not the case level — see VERIFY;
primary source: `https://developer.apple.com/documentation/swiftui/tablestyle/inset(alternatesrowbackgrounds:)`).

## The real API, at a glance

**Real (exist on macOS, floors are the reconciled truth in `floors-master.md` — read, never restate):**
`frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)`, `Table` / `TableColumn`,
`KeyPathComparator` (Foundation), `TableColumnForEach`, `controlSize(_:)` (`.large`/`.regular`/`.small`/
`.mini`), `fixedSize()` / `fixedSize(horizontal:vertical:)`, `layoutPriority(_:)`,
`containerRelativeFrame(_:alignment:)`, `alternatingRowBackgrounds(_:)`, the `Layout` protocol,
`Grid`/`GridRow`, `ViewThatFits`. The **scene** modifiers `defaultSize(_:)` / `windowResizability(_:)`
exist but are **owned by `scenes-windows`** (lt-02 companion).

**Deprecated:** `tableStyle(.inset(alternatesRowBackgrounds:))` and the `.bordered` variant — macOS 26.5,
→ `.tableStyle(.inset).alternatingRowBackgrounds()` (lt-07).

No invented names are central to this domain; if audited code reaches for a layout symbol you can't place
(e.g. a made-up `Table` modifier), confirm via swiftui-ctx (`lookup` **exit 3** = likely hallucination) +
Sosumi before flagging, and cross-check the canonical invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`. Signatures + full ❌→✅:
`references/layout-window-sizing.md`, `references/tables-and-density.md`, `references/custom-layout.md`.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`) — it sets which floor
   a fix may rely on (e.g. `TableColumnForEach` is macOS 14.4+, `containerRelativeFrame` 14.0+,
   `alternatingRowBackgrounds` 14.0+). Note whether the app declares any `App`/`Scene` (window sizing is
   moot for a library target). Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-layout-and-tables --dir <sources> --json /tmp/lt.json --sarif /tmp/lt.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`, lt-01…lt-08) + tier-2 structural
   ast-grep rules (`lint/ast-grep/*.yml` — lt-01 frame-absence, lt-04 Table-without-sortOrder), plus a
   per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a flagged
   file did not fully parse, so a structural miss can't masquerade as clean; READ those by hand. The
   runner only LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. The placement of
   a `.frame` (root content vs nested subview), whether a `List`'s rows are a struct's fields, whether a
   `.fixedSize()` sits on a container vs a single `Text`, and whether a pane is genuinely dense are all
   invisible to grep. Build a per-file inventory: each scene + its content-frame + its scene modifiers;
   each `List`/`Table` + its column wiring + its sort wiring; each dense pane + its `controlSize`.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a `Table` whose call span carries no `sortOrder`, a container `.fixedSize()`, the
   deprecated `tableStyle` case). A lone glanceable signal (a tiny static `Table`, a `List` of plain
   strings) is *not* a defect — judge it.
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you can't place, a floor you're unsure of, a
   deprecation you want to confirm, the canonical shape), run **both** evidence sources. (a) **Practice**
   — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and
   `swiftui-ctx deprecated <api>` for a currency/deprecation rule): read its `consensus` (the canonical
   shape), `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and `co_occurs_with`;
   a `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a hallucination — no
   shipping Mac app uses the symbol. (b) **Spec** — confirm via **Sosumi**:
   `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi
   `doc:` floor. The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
   **lt-07's case-level deprecation is confirmed on `developer.apple.com`** (`deprecated tableStyle` returns
   `deprecated:false` at the modifier level in swiftui-ctx, but both `inset(alternatesRowBackgrounds:)` and
   `bordered(alternatesRowBackgrounds:)` show `macOS 12.0–26.5 Deprecated` directly) — cite
   `source: https://developer.apple.com/documentation/swiftui/tablestyle/inset(alternatesrowbackgrounds:)`.
   **Deeper corpus evidence (lt-08 custom `Layout`):** before flagging a `: Layout` conformer as needless,
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx conformances Layout` for real conformers + permalinks (and
   `examples Table --shape` for real `Table` call sites) — 198 shipping repos write a custom `Layout`, almost
   all `FlowLayout` (e.g. AerialScreensaver/Aerial), the one shape no built-in covers; cite that permalink to
   distinguish a legit wrap-flow `Layout` from one a `Grid`/`ViewThatFits` would replace.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (lt-07 — the deprecated `tableStyle` case is a mechanical single-answer
   swap), one conventional commit per finding citing its `rule_id`, never weaken a check. The ✅
   "Correct" is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape** put in
   `## Correct`, backed by a real macOS-26 example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source` as the canonical example. The lt-04 ✅ is grounded in the
   live `swiftui-ctx lookup Table` consensus + its recommended macOS-26 permalink (see
   `references/tables-and-density.md`). Leave `flag-only` findings `open` with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep / re-run the lint over each fixed file to confirm the tell no longer matches;
   record the evidence in `## Fix applied?`. Re-confirm every citation still resolves. If a fix introduced
   a new tell (e.g. a `Table` you made sortable now needs an `.onChange(of: sortOrder)`), loop that file
   back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. Auto-fix only lt-07 (the deprecated `tableStyle`
case → `.inset` + `.alternatingRowBackgrounds()`); everything else is `fix_mode: flag-only` because the
correct fix is a structural/judgment call (which view keeps space, whether a table should sort, what
density a pane wants).

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/layout-and-tables/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/layout-and-tables/_index.md`.
- `domain: layout-and-tables`. Frontmatter is the canonical schema; `fix_mode` is `auto` for lt-07, else
  `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date
  (fetched via Sosumi); lt-07's case-level deprecation is confirmed at `https://developer.apple.com/documentation/swiftui/tablestyle/inset(alternatesrowbackgrounds:)`. Emit
  `cross_ref` on lt-02 (→ `scenes-windows`), lt-05 (→ `controls-forms`, when style not sizing), and any
  large-Table perf note (→ `view-performance`).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `window-sizing/` | the root content lacks a min/ideal frame, or the scene lacks `.defaultSize`/`.windowResizability` (lt-01, lt-02) |
| `list-vs-table/` | structured multi-field rows are a hand-rolled `List` that macOS wants as a `Table` (lt-03) |
| `table-sorting/` | a `Table` has no `sortOrder`/`KeyPathComparator`, or the deprecated `tableStyle` case (lt-04, lt-07) |
| `control-density/` | a dense Mac pane runs default `controlSize` where `.small`/`.mini` is wanted (lt-05) — `cross_ref` controls-forms |
| `sizing-fixedsize/` | a blanket both-axis `.fixedSize()` on a container overflows the window (lt-06) |
| `custom-layout/` | a custom `Layout` conformance where a built-in container fits (lt-08) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/layout-and-tables/` with a lowercase-hyphen slug naming the sub-category, and note it in
the run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/layout-window-sizing.md` | window content-frame, scene-sizing companion note, and the `fixedSize`/`layoutPriority` confusion (lt-01/02/06) + the canonical resizable-window exemplar |
| `references/tables-and-density.md` | `List`-vs-`Table`, the sort wiring, `controlSize` density, and the deprecated `tableStyle` case (lt-03/04/05/07) |
| `references/custom-layout.md` | a custom `Layout` conformance vs a built-in container, and the `GeometryReader`-vs-`Layout` seam (lt-08) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells lt-01…lt-08 + tier-2 structural lt-01 frame-absence / lt-04 Table-without-sortOrder); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability/deprecation value (the reconciled truth — `Table` 12.0, `controlSize` 10.15, `TableColumnForEach` 14.4, the `tableStyle` 26.5 deprecation) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (cross-check a made-up layout/Table symbol) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (a fix that uses a 14.x floor under a lower target needs a gate) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys + context-folder ownership |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (window-sizing split, controlSize axis, large-Table perf) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-layout-and-tables --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, lt-01…lt-08) + **tier-2
ast-grep** structural rules (`lint/ast-grep/*.yml` — lt-01 scene-content-no-frame, lt-04
table-without-sortOrder) that grep cannot express (the **absence** of a `.frame` across a closure, the
**absence** of `sortOrder` inside a `Table` call span — both anchored on a `kind: call_expression`). It
runs a per-file **parse probe** (surfaces "did not fully parse" so a structural miss can't look clean),
emits unified **JSON + SARIF**, exits **2** on any hard-fail (lt-07) for a CI gate, and **degrades to
grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`; faster:
`brew install ast-grep`). It only LOCATES — always READ each hit in full before reporting (step 3). The
thin `scripts/lt-lint.sh` is a pointer to this runner. Engine + rule-file format + JSON/SARIF shape +
safety rails: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
