# Reference — Interactivity & Large-Series Scale (charts-07 / charts-10)

How a chart responds to the pointer (charts-07) and how it handles thousands of data points (charts-10).

---

## charts-07 — hand-rolled selection instead of `.chartXSelection`

**The floor correction that matters: `.chartXSelection` / `.chartYSelection` / `.chartAngleSelection` are
macOS 14, NOT macOS 15.** Many codebases predate them and hand-roll selection with an `.onTapGesture` or a
`DragGesture` plus manual coordinate→data math via a `chartProxy`/`GeometryReader`. That math is fragile
(ignores axis scale, plot insets, scrolling). On a macOS 14+ floor, prefer the declarative modifier.

```swift
// ❌ hand-rolled hit-testing (charts-07)
.chartOverlay { proxy in
    Rectangle().fill(.clear).contentShape(Rectangle())
        .onTapGesture { loc in /* manual proxy.value(atX:) math */ }
}
// ✅ declarative selection (macOS 14+)
@State private var selectedDay: Date?
Chart(data) { row in
    BarMark(x: .value("Day", row.day), y: .value("Total", row.total))
}
.chartXSelection(value: $selectedDay)
```

**Also macOS 14+:** `.chartGesture(_:)` — `func chartGesture((ChartProxy) -> some Gesture) -> some View`
provides a declarative gesture API backed by a `ChartProxy` without the manual `chartOverlay`/coordinate
math. Prefer it when `.chartXSelection` doesn't cover the gesture shape needed.

**Detection.** Tier-1 flags `.onTapGesture`/`DragGesture`/`.gesture(` — READ to confirm it's chart
hit-testing (not an unrelated gesture). `flag-only`. If the project floor is below macOS 14, the modifier
is unavailable — then this is a *gating* question, not a fix (see charts-08), or the hand-rolled path is
justified; note it.

---

## charts-10 — large series not vectorized / scrollable

Emitting thousands of individual `BarMark`/`LineMark` from one array (one mark per point) is slow — every
point is a separate plottable. Two scale fixes:

- **macOS 15+:** `LinePlot`, `AreaPlot`, `BarPlot`, `PointPlot`, `SectorPlot`, `RectanglePlot`, `RulePlot`
  are **vectorized** — one plot for the whole function/series instead of N marks. Prefer them for dense
  continuous data.
- **macOS 14+:** `.chartScrollableAxes(.horizontal)` + `.chartXVisibleDomain(length:)` windows a long
  series so only the visible slice renders; pair with downsampling for very large arrays.

```swift
// ✅ vectorized (macOS 15)
Chart { LinePlot(data, x: .value("t", \.time), y: .value("v", \.value)) }
// ✅ windowed scroll (macOS 14)
Chart(data) { LineMark(x: .value("t", $0.time), y: .value("v", $0.value)) }
    .chartScrollableAxes(.horizontal)
    .chartXVisibleDomain(length: 3600)
```

**Seam.** charts-10 owns the *charts-specific* scale fix; general render-cost analysis (`.drawingGroup()`,
diffing, body re-evaluation) is **`audit-swiftui-view-performance`** — `cross_ref` it. Advisory: only flag
when the series is genuinely large (hundreds–thousands of marks). Confirm `LinePlot`'s macOS 15 floor via
`swiftui-ctx lookup LinePlot --json` before recommending it under a lower target.

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/swiftui/view/chartxselection(value:)`,
  `/documentation/swiftui/view/chartscrollableaxes(_:)`,
  `/documentation/charts/lineplot`,
  `https://developer.apple.com/documentation/swiftui/view/chartgesture(_:)` (macOS 14.0+ / iOS 17.0+).
- WWDC23 — "Explore pie charts and interactivity in Swift Charts" (`/videos/play/wwdc2023/10037`);
  WWDC24 — "Swift Charts: Vectorized and function plots" (`/videos/play/wwdc2024/10155`), via Sosumi.
- Practice corpus — `swiftui-ctx lookup BarMark` `co_occurs_with` (`chartScrollPosition`,
  `chartXVisibleDomain`, `chartYVisibleDomain`, `LinePlot`) confirming scroll/vectorized scaling is the
  shipping pattern for dense series.
