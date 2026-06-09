---
name: audit-swiftui-view-performance
description: Audits a finished or in-progress macOS SwiftUI codebase for view-rendering performance defects — needless body re-evaluation and view recreation — and writes per-finding Markdown to swiftui-audits/. Use when a view re-renders too much, the app feels janky, the window stutters on resize, a list scrolls poorly, or body runs constantly; when asked to verify render cost, find why a view re-renders, or check Self._printChanges; or when AI may have written a DateFormatter/NumberFormatter/JSONDecoder inside body, .id(UUID()), AnyView, a closure passed as a child view prop, GeometryReader wrapping a whole screen, logic in View.init, a .filter/.sorted inside ForEach, a high-frequency value in @Environment, or a SwiftUI Table with tens of thousands of rows. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for state-correctness (won't-update, state-resets, which is state-observation), animation-cost UX, Table column-structure or layout, Liquid Glass GPU cost, or writing new views from scratch.
---

# Audit SwiftUI View Performance

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way view rendering goes needlessly expensive:
heavyweight allocations in `body`, identity churn that recreates subtrees, type-erasure that defeats
diffing, un-skippable children, greedy `GeometryReader`, work in `init`, per-render filter/sort, and
high-frequency `@Environment` fan-out. Findings are written to disk in the toolkit's unified schema;
only the genuinely mechanical defects are fixed under the fix-safety protocol. This is never a
from-scratch view generator.

SwiftUI re-renders are driven by view **identity** and **dependency tracking**. These anti-patterns
force needless `body` re-evaluation or full view recreation. They bite **harder on macOS**: a
resizable, long-lived, multi-window Mac app re-renders far more than a transient iOS screen, so a
greedy `GeometryReader` or an `@Environment` timer tick fires constantly on every drag of a window edge.

## Boundary / seam note (stay in lane)

- **State *correctness*** — "the view won't update", "state resets", wrong ownership wrapper — belongs
  to `audit-swiftui-state-observation`. This skill owns the **render-cost** of over-broad observation
  and the computed-`some View` smell (the perf number); state-observation owns the granularity /
  correctness angle. Emit a `cross_ref` on that shared seam — don't double-own.
- **Animation cost** (`.repeatForever`, expensive `withAnimation` driving re-renders) — the **UX
  restraint** call is `audit-swiftui-animation-motion`'s; this skill takes only the render-cost angle
  and `cross_ref`s it.
- **`.drawingGroup()` usage decision** belongs to `audit-swiftui-drawing-canvas`; this skill measures
  only its cost and `cross_ref`s. **`Table` column structure / large-grid *layout*** belongs to
  `audit-swiftui-layout-and-tables`; this skill flags the **dataset-size ceiling** and `cross_ref`s.
- **`NSTableView`/`NSTextView` bridge *implementation*** is `audit-swiftui-appkit-interop`'s; the
  **render-cost ceiling that justifies the bridge** is ours — `cross_ref` it. **Liquid Glass GPU
  cost** is `audit-swiftui-liquid-glass`'s API/placement turf; we note the high-frequency-glass smell
  and route there.
- **The blanket "is every OS-floored API gated" sweep** belongs to `audit-swiftui-availability-gating`;
  this skill gates the one floored API it suggests (`Text(_:format:)`, macOS 12.0+ for `FormatOutput == String` / macOS 15.0+ for `AttributedString`) and defers there.

## The rendering model (three load-bearing facts)

1. **`body` runs on every dependency change.** Anything allocated or computed inside it pays that price
   on every render — hoist heavyweight work to `static let`, `.task`, or an `@Observable` method.
2. **Identity is the diffing key.** A fresh `.id(UUID())` or an `AnyView` throws away the identity
   SwiftUI needs to *skip* an unchanged subtree, forcing recreation and state loss.
3. **Dependencies fan out by where they're read.** A fast-changing value in `@Environment`
   re-evaluates every subscriber's subtree on every tick; a closure prop a child can't value-compare
   makes that child un-skippable. Keep fast state narrowly scoped (WWDC25 session 306).

**The render test:** drop `Self._printChanges()` as the first line of a suspect `body` (it prints which
dependency — `@self`, a named property, or `@identity` — caused that re-evaluation). `@identity`
churn → identity bug (vperf-02/03); a property you didn't expect → over-broad observation
(vperf-09). Full recipe + reasoning: `references/rendering-model-and-profiling.md`.

## Defect index (vperf-01 … vperf-12)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (never-correct / build-break),
**warning** (compiles but wasteful), **advisory** (judgment / measure-first). `auto` = mechanical
single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| vperf-01 | `DateFormatter(`/`NumberFormatter(`/`JSONDecoder(`/`ISO8601DateFormatter(`/`JSONEncoder(`/`RelativeDateTimeFormatter(` built inside `body` or a computed view prop | warning | flag | `body-and-init-cost.md` |
| vperf-02 | `.id(UUID())` / `.id(UUID().uuidString)` — fresh identity every render | warning | auto | `identity-and-erasure.md` |
| vperf-03 | `AnyView(` in view code — erases the type SwiftUI diffs on | warning | flag | `identity-and-erasure.md` |
| vperf-04 | a closure passed as a child view's stored prop (child can't be skipped) | advisory | flag | `skippability-and-observation.md` |
| vperf-05 | `GeometryReader` wrapping a whole screen / large subtree | advisory | flag | `body-and-init-cost.md` |
| vperf-06 | non-trivial statements inside a `View`'s `init` | warning | flag | `body-and-init-cost.md` |
| vperf-07 | `.filter`/`.sorted`/`.map` directly inside a `ForEach(...)` argument | warning | flag | `collections-and-ceilings.md` |
| vperf-08 | a fast-changing value (timer/drag/scroll geometry) stored in `@Environment` read by many views | advisory | flag | `skippability-and-observation.md` |
| vperf-09 | a view reads a whole broad `@Observable` model where one field would do (over-broad observation) | advisory | flag | `skippability-and-observation.md` |
| vperf-10 | `Table(` over a 10k+ row dataset with heavy/editable cells (FB13639482 ceiling) | advisory | flag | `collections-and-ceilings.md` |
| vperf-11 | a large `ForEach` not inside a `LazyVStack`/`LazyVGrid`/`List`/`Table` (eager build) | advisory | flag | `collections-and-ceilings.md` |
| vperf-12 | `Self._printChanges()` left in a shipping `body` | advisory | auto | `rendering-model-and-profiling.md` |

**One claim is measurement-bound — carry as `advisory`, never assert a fixed threshold as fact**
(flagged in its reference + becomes `source: verify against Xcode 26 SDK`): the `Table` row count where
jank starts (vperf-10) — FB13639482 has **no confirmed fix milestone in Apple release notes**, and
practitioner reports put a plain `List` at ~10k smooth / ~50k usable on **macOS 26**, so the old
"few-hundred-row" ceiling no longer holds for plain `List`. **Measure on your target.**

## The real API, at a glance

These are the **fix targets** — all real on macOS, confirmed via `swiftui-ctx lookup` (see VERIFY):

- `Text(_:format:)` (FormatStyle overload, **macOS 12.0+** for `FormatOutput == String`; macOS 15.0+ for `FormatOutput == AttributedString`) — replaces a `DateFormatter` in `body`.
- `@ViewBuilder` (returns `some View`) — replaces an `AnyView`-returning helper.
- `EquatableView` / `Equatable` conformance (macOS 10.15+) — makes a child with a closure prop
  skippable by comparing its *other* props.
- `LazyVStack` / `LazyVGrid` / `List` / `Table` — lazy containers for large collections.
- `Layout` (macOS 13.0+) / `.frame` / `.alignmentGuide` / `containerRelativeFrame` (macOS 14.0+) — replace a greedy
  `GeometryReader` when you only need arrangement, not the measured size.
- `.task` / `@Observable` model methods / `static let` — homes for work wrongly placed in `init`/`body`.

**No view-performance defect is a hallucinated symbol** — `AnyView`, `GeometryReader`, `.id(_:)`,
`@Environment` all **exist and are real**; the defect is *misuse*, not invention. (Confirmed:
`swiftui-ctx deprecated AnyView` → not deprecated, no replacement — it's a real API used wrongly.) So
findings here are `warning`/`advisory`, **never `hard-fail` for a "fake API."** Floor *values* are the
reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate.

## Grounded ✅ — the consensus shape (real, permalinked, not invented)

The ✅/`## Correct` block a finding embeds is the **swiftui-ctx consensus shape** of a real call site,
never a hand-written snippet. Worked example for the large-collection ceiling (vperf-07/10/11), confirmed
live via `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Table --json` → consensus
`(_, selection)` 34% · `(_)` 26% · `(of, selection)` 5%; `Table` `introduced_macos: 12.0`,
`deprecated: false`. The `recommended` site (pulled with `file ex_0af837984c --smart`) virtualizes rows
through the model's already-derived array — rows are materialized lazily by `Table`, never eagerly built,
and **no `.filter`/`.sorted` sits in the `ForEach` argument**:

```swift
// real macOS-26 call site — github.com/tahseen-kakar/harbor …/DownloadsContentView.swift#L13
Table(of: DownloadItem.self, selection: $center.selectedDownloadID) {
    TableColumn("Name")    { item in DownloadNameCell(item: item) }
    TableColumn("Updated") { item in Text(DownloadFormatting.dateString(item.updatedAt)).font(.caption) }
} rows: {
    ForEach(center.filteredDownloads) { item in TableRow(item) }  // derived array from the model — NOT a .filter/.sorted in the ForEach arg
}
```

- Real example permalink (goes in `## Source`):
  `https://github.com/tahseen-kakar/harbor/blob/064c6b7c706c255ca30ae2c0ce607b6ba21e2edd/Harbor/Views/DownloadsContentView.swift#L13`
- Apple spec via Sosumi (the `doc:` line): `https://sosumi.ai/documentation/swiftui/table`

This is the **shape of the grounding**, not a template to paste — re-run `lookup`/`file --smart` per fix
target (e.g. `Text` → `Text(_:format:)` for vperf-01) so the ✅ is current real code, then cite *that*
permalink. The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target** (`project.pbxproj`
   `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). Load-bearing for the one floored fix
   (`Text(_:format:)`: macOS 12.0+ for `FormatOutput == String`, macOS 15.0+ for `AttributedString`); record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-view-performance --dir <sources> --json /tmp/vperf.json --sarif /tmp/vperf.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the formatter-inside-`body` and logic-in-`init` containment rules grep
   can't express), plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its
   `parse_warnings`** — a flagged file didn't fully parse, so a structural miss can't masquerade as
   clean; READ those by hand. The runner only LOCATES. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a
   formatter is *inside* `body`, whether a `ForEach` is *inside* a lazy container, whether a closure
   prop is *stored* in the child, and how broad an `@Observable` read is are all invisible to a flat
   grep. Build a per-file inventory: each suspect view + which of the three rendering facts it breaks.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a literal `DateFormatter()` lexically inside `body`, an `.id(UUID())`, an
   `AnyView(` in view code). Anything judgment-bound (vperf-04/05/08/09/10/11) needs the READ first.
5. **VERIFY.** For anything ≤ ~70% confidence (a fix target whose floor you can't place, a behavior
   claim, the `Table` threshold), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and
   `swiftui-ctx deprecated <api>` for a currency claim): read its `consensus` (the canonical shape),
   `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and `co_occurs_with`. A
   `lookup` **exit 3** would corroborate a hallucination — but **this domain has none** (all symbols
   are real-but-misused), so use the lookup to ground the **✅ shape**, not to prove nonexistence. (b)
   **Spec** — confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using
   `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md`. The CLI contract
   is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Carry the `Table` threshold
   as `advisory` with `source: verify against Xcode 26 SDK` — never as a fixed number.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (vperf-02 `.id(UUID())`→stable id, vperf-12 strip the debug line), one
   conventional commit per finding citing its `rule_id`, never weaken a check. The ✅ "Correct" is
   **not a hand-written snippet** — it is the swiftui-ctx **consensus shape** put in `## Correct`,
   backed by a real macOS-era example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub
   permalink (plus the Sosumi `doc:`) goes in `## Source`. Leave `flag-only` findings `open` with that
   ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Confirm every citation still resolves. If a fix introduced a new tell (e.g.
   hoisting a formatter to a `static let` you then mis-floored), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. The lexical defects (vperf-01 in `body`, vperf-02,
vperf-03, vperf-12) clear that bar on a READ; the judgment defects (vperf-04/05/08/09/10/11) must pass
the READ — a lone `GeometryReader` that genuinely needs the measured size is *correct*, a small
`ForEach` outside a lazy container is *fine*. Anything ≤ ~70% goes to VERIFY before it becomes a
finding. Auto-fix only the mechanical set (vperf-02, vperf-12); everything else is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/view-performance/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/view-performance/_index.md`.
- `domain: view-performance`. Frontmatter is the canonical schema; `fix_mode` is `auto` for
  vperf-02/12, else `flag-only`. `availability` reads from `floors-master.md` (relevant only for the
  `Text(_:format:)` fix target). `source` is an Apple URL + access date (via Sosumi) or
  `verify against Xcode 26 SDK` (the `Table` threshold).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `body-cost/` | a heavyweight is allocated in `body`/a computed view prop, or `GeometryReader` wraps a large subtree (vperf-01, vperf-05) |
| `identity-churn/` | identity is thrown away — `.id(UUID())` or an `AnyView` in view code (vperf-02, vperf-03) |
| `skippability/` | a child can't be skipped — a closure prop, a high-frequency `@Environment` value, or over-broad observation (vperf-04, vperf-08, vperf-09) |
| `init-cost/` | real logic runs in a `View`'s `init` (vperf-06) |
| `collection-cost/` | per-render filter/sort in `ForEach`, an eager non-lazy `ForEach`, or the large-`Table` ceiling (vperf-07, vperf-10, vperf-11) |
| `profiling-leftovers/` | a `Self._printChanges()` was left in shipping code (vperf-12) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/view-performance/` with a lowercase-hyphen slug naming the sub-category, and note it in
the run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is
a hard requirement.* Two runs over the same code produce structurally identical trees.

> **Go-beyond artifact (optional):** `swiftui-audits/view-performance/_render-cost-map.md` listing each
> suspect view + the `Self._printChanges()` dependency that drives its re-render — see
> `references/rendering-model-and-profiling.md`.

## Reference routing

| File | Open when |
|---|---|
| `references/body-and-init-cost.md` | a heavyweight in `body`, greedy `GeometryReader`, or logic in `init` — the ❌→✅ hoist patterns (vperf-01/05/06) |
| `references/identity-and-erasure.md` | identity churn or type-erasure — `.id(UUID())`, `AnyView`, `@ViewBuilder` (vperf-02/03) |
| `references/skippability-and-observation.md` | un-skippable children — closure props (`Equatable`/`EquatableView`), high-frequency `@Environment`, over-broad `@Observable` (vperf-04/08/09) |
| `references/collections-and-ceilings.md` | collection cost — per-render filter/sort in `ForEach`, lazy containers, the `Table`/`List` dataset ceiling (vperf-07/10/11) |
| `references/rendering-model-and-profiling.md` | the identity/dependency model, `Self._printChanges()`, the SwiftUI Instrument, the leftover-debug strip (vperf-12) + the render-cost map |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth — e.g. `Text(_:format:)`: macOS 12.0+ (String) / 15.0+ (AttributedString)) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (state-observation, animation-motion, drawing-canvas, layout-and-tables, appkit-interop, liquid-glass) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-view-performance --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
vperf-02/03/04/07/08/09/10/11/12) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` —
vperf-01 formatter-inside-`body`, vperf-06 logic-in-`init`) that grep cannot express. It runs a
per-file **parse probe** (surfaces "did not fully parse" so a structural miss can't look clean), emits
unified **JSON + SARIF**, and **degrades to grep-only with a notice** if ast-grep is unreachable
(`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). This domain has **no
hard-fail** tell (every defect is real-but-misused, not a build break), so the runner exits **0** here —
the value is the located candidate set, not a CI gate. It only LOCATES — always READ each hit in full
before reporting (step 3). The thin `scripts/vperf-lint.sh` is a pointer to this runner. Engine +
rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
