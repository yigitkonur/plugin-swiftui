---
name: audit-swiftui-charts
description: Audits a finished or in-progress macOS SwiftUI codebase for Swift Charts defects and writes per-finding Markdown to swiftui-audits/. Use when the user says a chart looks wrong, hand-built, slow, or inaccessible; when they ask to verify Chart, BarMark, LineMark, PointMark, SectorMark, chartXAxis, chartLegend, foregroundStyle(by:), chartXSelection, or chartScrollableAxes; when AI may have written BarChart, LineChart, PieChart, ChartView, PieMark, DonutMark, ScatterMark, ColumnMark, or chartType; when a chart is hand-rolled from a ForEach of Rectangle bars or a GeometryReader; when the wrong Mark is used for the data; when SectorMark, chartXSelection, or LinePlot may be ungated or over-gated under a lower deployment target; or when a chart lacks axes, a legend, interactivity, or a VoiceOver descriptor. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for Canvas-drawn charts (drawing-canvas), not for the blanket availability sweep, not for color theory, not for authoring new charts.
---

# Audit SwiftUI Charts

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way Swift Charts goes wrong: hallucinated chart/mark
names, charts hand-rolled from stacks of rectangles instead of `Chart`, the wrong `*Mark` for the data,
missing axes/legend/color-encoding, missing interactivity, version-floored symbols left ungated (or
needlessly over-gated), wrong-arm `iOS` gates, unscalable large-series plots, and missing chart
accessibility. Findings are written to disk in the toolkit's unified schema; certain mechanical defects
are fixed under the fix-safety protocol. This is never a from-scratch chart generator.

Swift Charts is macOS 13+; **`SectorMark`, the `chart*Selection` family, and `chartScrollableAxes` are
macOS 14 (not 13); `LinePlot`/`AreaPlot`/`BarPlot`/`PointPlot`/`SectorPlot`/`RectanglePlot`/`RulePlot` vectorized plots are macOS 15.** AI routinely mis-floors these
and reaches for iOS-shaped or invented chart types — be suspicious wherever AI wrote chart code.

## Boundary / seam note (stay in lane)

- **Canvas-drawn charts belong to `audit-swiftui-drawing-canvas`.** A chart hand-rolled with `Canvas {}`
  or `Path` is theirs; a chart hand-rolled from a `ForEach` of `Rectangle`/`Capsule` bars is **ours**
  (charts-02). When the bars are Canvas-drawn, note it in one line and `cross_ref` drawing-canvas.
- **The `Chart`/`Canvas` no-accessibility-descriptor finding is intentionally double-detected** with
  `audit-swiftui-accessibility` (keep-both per the cross-ref graph): we file the chart-descriptor gap and
  `cross_ref` accessibility; do not collapse it.
- **Per-series color theory / WCAG contrast** is `audit-swiftui-appearance-color`; we own only the
  *encoding choice* (`.foregroundStyle(by:)` vs a hardcoded per-mark color, charts-06) and `cross_ref`.
- **Large-dataset render cost** is shared with `audit-swiftui-view-performance`; we own the
  charts-specific scale fix (vectorized `LinePlot`/`chartScrollableAxes`, charts-10) and `cross_ref`.
- **The blanket "is every OS-floored API gated" sweep** belongs to `audit-swiftui-availability-gating`;
  this skill owns **Charts** gating in depth (charts-08/09) and defers non-charts gating there.

## Defect index (charts-01 … charts-11)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct),
**warning** (compiles but non-native), **advisory** (judgment / perf). `auto` = mechanical single-answer
fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| charts-01 | `BarChart`/`LineChart`/`PieChart`/`ChartView`/`PieMark`/`DonutMark`/`ScatterMark`/`ColumnMark`/`.chartType(` | hard-fail | auto | `charts-api-surface.md` |
| charts-02 | `Chart` hand-rolled from a `ForEach` of `Rectangle`/`Capsule` bars or a `GeometryReader` | warning | flag | `hand-rolled-and-mark-selection.md` |
| charts-03 | wrong `*Mark` for the data — `BarMark` for a continuous trend, `LineMark` across unordered categories | warning | flag | `hand-rolled-and-mark-selection.md` |
| charts-04 | default axis cluttered/wrong — no `.chartXAxis`/`.chartYAxis` customization where needed | advisory | flag | `axes-legend-color.md` |
| charts-05 | multi-series `.foregroundStyle(by:)` with the legend missing/hidden | advisory | flag | `axes-legend-color.md` |
| charts-06 | hardcoded per-mark color repeated per category instead of `.foregroundStyle(by:)` | advisory | flag | `axes-legend-color.md` |
| charts-07 | hand-rolled tap/drag hit-testing for selection instead of `.chartXSelection` (macOS 14) | warning | flag | `interactivity-and-scale.md` |
| charts-08 | a version-floored symbol (`SectorMark`/`chart*Selection`/`LinePlot`) ungated **or over-gated** vs its real floor | warning | flag | `availability-gating-charts.md` |
| charts-09 | `#available(iOS …, *)` gating a chart symbol in a macOS target (wrong arm) | warning | auto | `availability-gating-charts.md` |
| charts-10 | thousands of `BarMark`/`LineMark` from one array (no vectorized plot / no scroll) | advisory | flag | `interactivity-and-scale.md` |
| charts-11 | `Chart` with no VoiceOver descriptor (`.accessibilityLabel`/`.accessibilityValue` / summary) | warning | flag | `accessibility-charts.md` |

**One claim is FLOOR-SENSITIVE, not a fact about code: charts-08 fires for BOTH directions** — a symbol
*ungated* below its floor **and** a symbol *needlessly over-gated above* it (e.g. `chartXSelection`
behind `#available(macOS 15, *)` when it is macOS 14, or `SectorMark` treated as macOS 13 when it is 14).
Confirm the floor in `floors-master.md` + via `swiftui-ctx`/Sosumi before asserting either.

## The real API, at a glance

**Real (exist on macOS 13.0+ unless noted):** `Chart`, `BarMark`, `LineMark`, `PointMark`, `AreaMark`,
`RuleMark`, `RectangleMark`, `AxisMarks`, `AxisValueLabel`, `AxisGridLine`, `.chartXAxis`/`.chartYAxis`,
`.chartLegend`, `.foregroundStyle(by:)`, `.symbol(by:)`, `.position(by:)`. **macOS 14.0+:** `SectorMark`
(pie/donut), `.chartXSelection`/`.chartYSelection`/`.chartAngleSelection`, `.chartScrollableAxes`,
`.chartScrollPosition`, `.chartXVisibleDomain`/`.chartYVisibleDomain`. **macOS 15.0+:** `LinePlot`,
`AreaPlot`, `BarPlot`, `PointPlot`, `SectorPlot`, `RectanglePlot`, `RulePlot` (vectorized function/large-series plots).

**Hallucinated (never exist):** `BarChart`, `LineChart`, `PieChart`, `AreaChart`, `ChartView`,
`.chartType(...)`, `PieMark`, `DonutMark`, `ScatterMark`, `ColumnMark` — these are other-library /
invented shapes (`PieMark`→`SectorMark`, `ColumnMark`→`BarMark`, `ScatterMark`→`PointMark`,
`*Chart`/`ChartView`→`Chart { … }`).

### ✅ Correct (grounded reference shape)

The canonical `Chart` call is the `swiftui-ctx` **consensus** shape — `Chart { … }` (45%) and
`Chart(data) { … }` (44%) dominate; `Chart(data, id:) { … }` is the 11% tail. A real, current
(macOS 26 SDK) call site from the corpus:

```swift
// f/deeper · PlatformsView.swift (consensus shape: Chart(_) { SectorMark … }; SectorMark = macOS 14+)
Chart(store.platformStats) { stat in
    SectorMark(
        angle: .value("Chats", stat.chatCount),
        innerRadius: .ratio(0.6),
        angularInset: 2
    )
    .foregroundStyle(stat.platform.color)
    .cornerRadius(4)
}
.frame(height: 220)
```

Source (real permalink, verify before citing in a finding):
`https://github.com/f/deeper/blob/19b9f69fa0bbe2cd12dc8ba3729114a194bf1bf0/Deeper/Views/Platforms/PlatformsView.swift#L34`
· Apple spec via Sosumi `doc: https://sosumi.ai/documentation/charts/chart`. Every `## Correct` in a
finding is regenerated this way per the actual API — never hand-written — via `swiftui-ctx lookup <api>`
then `swiftui-ctx file <recommended.id> --smart`.

Signatures, floors, and the full ❌→✅ rewrites: `references/charts-api-surface.md`. Floor *values* are
the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and the canonical
invented-name list (incl. the Charts section) in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate them.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree`/`find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   charts-08 fires when a symbol's floor (14 for `SectorMark`/selection/scroll, 15 for `LinePlot`) is
   above the project floor and the call is ungated — or when a gate sits *above* the real floor. Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-charts --dir <sources> --json /tmp/charts.json --sarif /tmp/charts.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the hand-rolled-bars containment + wrong-arm gate-scope rules grep can't
   express), plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`**
   — a flagged file did not fully parse, so a structural miss can't masquerade as clean; READ those by
   hand. The runner only LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a frame
   dimension is data-driven, whether a Mark fits the data's shape, axis/legend wiring, and gate scope are
   invisible to grep. Build a per-file inventory: each chart, its `*Mark`(s), data shape, axes/legend,
   interactivity, gate, and accessibility.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a hallucinated name, an `iOS` gate arm over a chart, a `SectorMark` ungated under a
   macOS 13 floor).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, a
   "wrong Mark" judgment), run **both** evidence sources. (a) **Practice** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
   lookup <api> --json` (and `swiftui-ctx deprecated <api>` for a currency rule): read its `consensus`
   (the canonical call shape), `introduced_macos`, `deprecated`+`replacement`, `recommended`/`diverse`
   permalink, and `co_occurs_with`; a `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`)
   corroborates a hallucination — no shipping Mac app uses the symbol. (b) **Spec** — confirm via
   **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the
   path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never
   `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the
   Sosumi `doc:` floor. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or discard.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (charts-01 1:1 mark renames, charts-09 wrong-arm gate), one conventional
   commit per finding citing its `rule_id`, never weaken a check. The ✅ "Correct" is **not a hand-written
   snippet** — it is the swiftui-ctx **consensus shape** put in `## Correct`, backed by a real macOS-26
   example fetched with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart`
   whose GitHub permalink (plus the Sosumi `doc:`) goes in `## Source`. Leave `flag-only` findings `open`
   with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence in
   `## Fix applied?`. Re-confirm every citation still resolves and still says the expected floor. If a fix
   introduced a new tell (e.g. a `SectorMark` you added now needs a macOS 14 gate), loop that file back to
   DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can become
a finding — never emit a speculative finding. Auto-fix only the mechanical set (charts-01 mark renames,
charts-09 wrong-arm); everything else is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/charts/<context>/NN-slug.md` (one finding per file, zero-padded, ordered).
  Per-run index: `swiftui-audits/charts/_index.md`.
- `domain: charts`. Frontmatter is the canonical schema; `fix_mode` is `auto` for charts-01/09, else
  `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date
  (fetched via Sosumi) plus a `swiftui-ctx` permalink, or `verify against Xcode 26 SDK`. Emit `cross_ref`
  on shared-seam findings (charts-02 Canvas → drawing-canvas; charts-06 → appearance-color; charts-10 →
  view-performance; charts-11 → accessibility).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `hallucinated-api/` | a chart/mark name doesn't exist on macOS (charts-01) |
| `hand-rolled-vs-chart/` | a chart is built from stacks/`GeometryReader` instead of `Chart` (charts-02) |
| `mark-selection/` | the `*Mark` doesn't fit the data shape (charts-03) |
| `axes-legend-color/` | axes are cluttered, the legend is missing, or color encoding is hardcoded (charts-04/05/06) |
| `interactivity/` | selection is hand-rolled instead of `.chartXSelection` (charts-07) |
| `availability-gating/` | a version-floored symbol is ungated or mis-gated, or gated on the `iOS` arm (charts-08/09) |
| `scale-performance/` | a large series isn't vectorized/scrollable (charts-10) |
| `accessibility/` | a chart has no VoiceOver descriptor (charts-11) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/charts/` with a lowercase-hyphen slug naming the sub-category, and note it in the run's
`_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a hard
requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/charts-api-surface.md` | a name/signature/existence question — the real mark/plot allow-list + hallucination ❌→✅ + floors (charts-01) |
| `references/hand-rolled-and-mark-selection.md` | a chart built from primitives, or the wrong `*Mark` for the data (charts-02/03) |
| `references/axes-legend-color.md` | axis customization, the legend, and `.foregroundStyle(by:)` vs hardcoded color (charts-04/05/06) |
| `references/interactivity-and-scale.md` | `.chartXSelection` vs hand-rolled selection, and large-series vectorized/scrollable plots (charts-07/10) |
| `references/availability-gating-charts.md` | Charts gating depth, the corrected floors, over-gating, the wrong-arm trap (charts-08/09) |
| `references/accessibility-charts.md` | the chart VoiceOver descriptor gap, keep-both with accessibility (charts-11) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (incl. §4 Charts) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm failure (charts-09) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys + `cross_ref` |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps VERIFY · FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-charts --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, charts-01/02/03/04/05/06/07/08/09/10/11)
+ **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` — charts-02 hand-rolled-bars containment,
charts-09 wrong-arm gate-scope) that grep cannot express. It runs a per-file **parse probe** (surfaces
"did not fully parse" so a structural miss can't look clean), emits unified **JSON + SARIF**, exits **2**
on any hard-fail (charts-01/08/09) for a CI gate, and **degrades to grep-only with a notice** if ast-grep
is unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES
— always READ each hit in full before reporting (step READ). The legacy `scripts/charts-lint.sh` is a thin
pointer to this runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
