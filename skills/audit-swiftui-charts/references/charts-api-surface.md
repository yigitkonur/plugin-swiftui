# Reference — The Real Swift Charts API Surface (macOS 13–15)

The canonical allow-list of real SwiftUI Swift Charts symbols, plus the hallucination blacklist this skill
detects. This is the spine the other references cite. Per-platform floor *values* are not restated here —
they live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (the single source of
availability truth). This file carries the **signatures, the existence allow-list, the invented-name
detection content, and the ❌→✅ rewrites** (charts-01).

**As of:** 2026-06-07 · Swift Charts framework · Xcode 26 SDK.

---

## Why AI gets this wrong

1. **Other-library shapes.** SwiftUI Charts has **no** `BarChart`/`LineChart`/`PieChart`/`ChartView`
   type and **no** `.chartType(...)` modifier — those belong to Charts.framework (UIKit), SwiftUICharts
   (3rd-party), or web charting libs. SwiftUI uses a single `Chart { … }` container holding `*Mark`s.
2. **Invented marks.** `PieMark`, `DonutMark`, `ScatterMark`, `ColumnMark` read plausible but do not
   exist. Pie/donut is `SectorMark`; scatter is `PointMark`; columns are `BarMark`.
3. **Mis-floored real symbols.** The model assumes everything is macOS 13. `SectorMark`, the
   `chart*Selection` family, and `chartScrollableAxes` are **macOS 14**; `LinePlot`/`AreaPlot` are
   **macOS 15**. See `availability-gating-charts.md`.

---

## The real symbol allow-list

Confirm any floor against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; verify any uncertain
symbol via `swiftui-ctx lookup <api> --json` (`introduced_macos`) + Sosumi.

| Symbol | Role | Floor | Apple doc path (`/documentation/charts/…`) |
|---|---|---|---|
| `Chart` | the chart container | macOS 13 | `chart` |
| `BarMark` | bar / column | macOS 13 | `barmark` |
| `LineMark` | line (continuous trend) | macOS 13 | `linemark` |
| `PointMark` | scatter / point | macOS 13 | `pointmark` |
| `AreaMark` | filled area | macOS 13 | `areamark` |
| `RuleMark` | reference rule/threshold | macOS 13 | `rulemark` |
| `RectangleMark` | heatmap / cell | macOS 13 | `rectanglemark` |
| `AxisMarks` / `AxisValueLabel` / `AxisGridLine` | axis content | macOS 13 | `axismarks` |
| `.chartXAxis` / `.chartYAxis` / `.chartLegend` | axis & legend config | macOS 13 | `view/chartxaxis(content:)` etc. |
| `.foregroundStyle(by:)` / `.symbol(by:)` / `.position(by:)` | series encoding | macOS 13 | `chartcontent/foregroundstyle(by:)` |
| `SectorMark` | pie / donut sector | **macOS 14** | `sectormark` |
| `.chartXSelection` / `.chartYSelection` / `.chartAngleSelection` | value selection | **macOS 14** | `view/chartxselection(value:)` |
| `.chartScrollableAxes` / `.chartScrollPosition` / `.chartXVisibleDomain` | scroll & windowing | **macOS 14** | `view/chartscrollableaxes(_:)` |
| `LinePlot` / `AreaPlot` / `BarPlot` / `PointPlot` / `SectorPlot` / `RectanglePlot` / `RulePlot` | vectorized function / large-series plot | **macOS 15** | `lineplot` · `areaplot` · `barplot` · `pointplot` · `sectorplot` · `rectangleplot` · `ruleplot` |

**Consensus call shapes** (from `swiftui-ctx lookup`, the corpus of shipping macOS-26 apps):

```swift
// Chart — 45% trailing closure, 44% (_) data init, 11% (_, id:) keyed init
Chart(data) { row in
    BarMark(x: .value("Day", row.day), y: .value("Total", row.total))   // BarMark — 86% (x:, y:)
}
.chartXAxis { AxisMarks() }
```

`Chart(pieData, id: \.label)` is the keyed init; `BarMark` also offers `(x:, y:, width:)`,
`(x:, yStart:, yEnd:)`, and stacking variants — but **86% of shipping call sites are the plain
`(x:, y:)`** form. Confirm the exact signature you need with `swiftui-ctx lookup BarMark --json`.

---

## Hallucination blacklist (detect + replace, charts-01)

The canonical shared list (consumed across skills) is §4 of
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`; the charts-specific ❌→✅ this skill
applies:

| ❌ Hallucinated / wrong | Why wrong | ✅ Correct (macOS) |
|---|---|---|
| `BarChart` / `LineChart` / `PieChart` / `AreaChart` | no such SwiftUI type | `Chart { BarMark / LineMark / SectorMark / AreaMark }` |
| `ChartView` | no such type | `Chart { … }` |
| `.chartType(.bar)` | no such modifier — the mark *is* the type | choose the `*Mark` |
| `PieMark` | no such mark | `SectorMark(angle:)` (macOS 14) |
| `DonutMark` | no such mark | `SectorMark(angle:, innerRadius:)` (macOS 14) |
| `ScatterMark` | no such mark | `PointMark(x:, y:)` |
| `ColumnMark` | no such mark | `BarMark(x:, y:)` |

A `swiftui-ctx lookup` on each of `BarChart`/`LineChart`/`PieChart`/`ChartView`/`chartType` returns
**exit 3 (not-found)** — corroborating that no shipping Mac app uses them. `fix_mode: auto` only for the
1:1 mark renames (`PieMark`→`SectorMark`, `ColumnMark`→`BarMark`, `ScatterMark`→`PointMark`); the
container renames (`*Chart`→`Chart { }`) are `flag` because they restructure the body.

---

## Detection tells (for DETECT; deterministic version is `lint/grep-tells.tsv`)

- Invented (charts-01): `BarChart` · `LineChart` · `PieChart` · `AreaChart` · `ChartView` · `PieMark` ·
  `DonutMark` · `ScatterMark` · `ColumnMark` · `\.chartType\(`

---

## Sources

- Apple — Swift Charts symbol pages, fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/charts/chart`,
  `/documentation/charts/barmark`, `/documentation/charts/sectormark`,
  `/documentation/charts/lineplot`, `/documentation/swiftui/view/chartxselection(value:)`.
- WWDC22 — "Hello Swift Charts" (`/videos/play/wwdc2022/10136`); WWDC23 — "Explore pie charts and
  interactivity in Swift Charts" (`/videos/play/wwdc2023/10037`); WWDC24 — "Swift Charts: Vectorized and
  function plots" (`/videos/play/wwdc2024/10155`), via Sosumi.
- Practice corpus (`swiftui-ctx lookup Chart`/`BarMark`): consensus shapes + the recommended macOS-26
  example `https://github.com/f/deeper/blob/19b9f69fa0bbe2cd12dc8ba3729114a194bf1bf0/Deeper/Views/Platforms/PlatformsView.swift#L73`.
