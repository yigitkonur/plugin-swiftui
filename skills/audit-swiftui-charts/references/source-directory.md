# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence Swift
Charts claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI commands
and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the
charts-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The practice corpus (consensus shapes +
permalinked examples) is reached with `swiftui-ctx`, contract in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

**As of:** 2026-06-07 · Swift Charts · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/charts/<symbol-path>` (or `/documentation/swiftui/<modifier-path>` for
   the chart view modifiers) and read the `**Available on:** … macOS N+ …` line. Absent from the Charts
   index = treat as hallucinated until proven.
2. **Practice cross-check.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` →
   `introduced_macos` + `consensus` + a `recommended`/`diverse` permalink; **exit 3** corroborates a
   hallucination. Never `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess.

---

## A. Swift Charts symbol map

Doc path = `developer.apple.com/documentation/charts/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Path | Floor |
|---|---|---|
| `Chart` | `chart` | macOS 13 |
| `BarMark` / `LineMark` / `PointMark` / `AreaMark` | `barmark` · `linemark` · `pointmark` · `areamark` | macOS 13 |
| `RuleMark` / `RectangleMark` | `rulemark` · `rectanglemark` | macOS 13 |
| `AxisMarks` / `AxisValueLabel` / `AxisGridLine` | `axismarks` · `axisvaluelabel` · `axisgridline` | macOS 13 |
| `SectorMark` | `sectormark` | **macOS 14** |
| `LinePlot` / `AreaPlot` / `BarPlot` / `PointPlot` / `SectorPlot` / `RectanglePlot` / `RulePlot` | `lineplot` · `areaplot` · `barplot` · `pointplot` · `sectorplot` · `rectangleplot` · `ruleplot` | **macOS 15** |

## B. Chart view modifiers (`documentation/swiftui/view/<path>`)

| Modifier | Path | Floor |
|---|---|---|
| `.chartXAxis` / `.chartYAxis` / `.chartLegend` | `chartxaxis(content:)` · `chartyaxis(content:)` · `chartlegend(_:)` | macOS 13 |
| `.foregroundStyle(by:)` | `documentation/charts/chartcontent/foregroundstyle(by:)` | macOS 13 |
| `.chartXSelection` / `.chartYSelection` / `.chartAngleSelection` | `chartxselection(value:)` · `chartyselection(value:)` · `chartangleselection(value:)` | **macOS 14** |
| `.chartScrollableAxes` / `.chartScrollPosition` / `.chartXVisibleDomain` | `chartscrollableaxes(_:)` · `chartscrollposition(x:)` · `chartxvisibledomain(length:)` | **macOS 14** |
| `.accessibilityChartDescriptor(_:)` | `accessibilitychartdescriptor(_:)` | macOS 12 |

**Absent from the index → hallucinated (never emit):** `BarChart`, `LineChart`, `PieChart`, `AreaChart`,
`ChartView`, `.chartType(...)`, `PieMark`, `DonutMark`, `ScatterMark`, `ColumnMark`.

## C. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| Creating accessible charts | `documentation/charts/creating-accessible-charts` | per-mark labels; audio graph; `AXChartDescriptor` |
| Customizing axes in Swift Charts | `documentation/charts/customizing-axes-in-swift-charts` | `AxisMarks`/`AxisValueLabel` declutter |
| HIG — Charting data | `design/human-interface-guidelines/charting-data` (verify exact path against current HIG) | mark choice; legibility; defer color/contrast to `audit-swiftui-appearance-color` |

## D. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2022/10136 | Hello Swift Charts | `Chart`, marks, axes, legend, accessibility |
| wwdc2022/110340 | Design an effective chart | which mark for which data |
| wwdc2023/10037 | Explore pie charts and interactivity | `SectorMark`, `.chartAngleSelection`, selection |
| wwdc2024/10155 | Swift Charts: Vectorized and function plots | `LinePlot`/`AreaPlot` for large/continuous series |

## E. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Swift Charts shipping examples | via `swiftui-ctx lookup Chart`/`BarMark` (`diverse`/`recommended` permalinks) | real macOS-26 call shapes | high (real code) |
| Apple Sample — "Visualizing your app's data" | `developer.apple.com/documentation/charts/visualizing_your_app_s_data` | end-to-end chart construction | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practice corpus reached via `swiftui-ctx` (contract in the shared swiftui-ctx-reference); permalinks are
  real GitHub macOS-26 call sites surfaced by `lookup`/`recipe`.
