# Reference — Axes, Legend & Color Encoding (charts-04 / charts-05 / charts-06)

How a `Chart` communicates: its axes (charts-04), its legend (charts-05), and how series are colored
(charts-06). All macOS 13+.

---

## charts-04 — axis legibility

`Chart` auto-generates axes, but the defaults are frequently wrong for the data: unformatted dates,
overlapping labels, a y-axis that doesn't start at zero for a bar chart, or too many ticks. Customize with
`.chartXAxis`/`.chartYAxis` + `AxisMarks`/`AxisValueLabel`.

```swift
// ✅ formatted, decluttered axis
Chart(data) { row in
    LineMark(x: .value("Date", row.date), y: .value("Count", row.count))
}
.chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday()) } }
.chartYAxis { AxisMarks(position: .leading) }
```

**Advisory.** Only flag when the default is demonstrably wrong (dates as raw numbers, label collisions,
misleading non-zero baseline). A clean default axis is fine — do not flag a chart just for omitting
`.chartXAxis`.

---

## charts-05 — missing legend on a multi-series chart

When a chart encodes a series dimension (`.foregroundStyle(by:)`, `.symbol(by:)`, `.position(by:)`), the
reader needs a legend to decode the colors. SwiftUI shows one automatically — but it is lost if the dev
wrote `.chartLegend(.hidden)`, or hand-colored each mark (charts-06) so no `by:` dimension exists to drive
a legend. Flag a multi-series chart whose series are unlabeled.

```swift
// ✅ legend shows automatically from the `by:` encoding
Chart(data) { row in
    BarMark(x: .value("Month", row.month), y: .value("Sales", row.sales))
        .foregroundStyle(by: .value("Region", row.region))
}
// (.chartLegend(.visible) to force it; do NOT .hidden a needed legend)
```

---

## charts-06 — hardcoded color vs `.foregroundStyle(by:)`

Repeating `.foregroundStyle(.red)` / `.foregroundStyle(Color(...))` per category hardcodes the palette,
breaks the automatic legend, and ignores Dark-Mode/accent adaptation.

```swift
// ❌ hardcoded per category (charts-06)
ForEach(regions) { r in
    BarMark(...).foregroundStyle(r == .north ? .red : .blue)
}
// ✅ data-driven encoding → auto palette + legend
BarMark(...).foregroundStyle(by: .value("Region", row.region))
```

**Seam.** charts-06 owns only the *encoding choice* (`by:` vs hardcoded). **Color theory, contrast ratios,
and Differentiate-Without-Color** belong to `audit-swiftui-appearance-color` — `cross_ref` it; do not
audit WCAG here. A deliberate single-series brand color is fine; flag the *repeated-per-category* pattern.

**Advisory, `flag-only`.** Show the `.foregroundStyle(by:)` ✅; the dev maps the palette.

---

## Sources

- Apple — Swift Charts axis & legend docs, fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/charts/axismarks`,
  `/documentation/charts/customizing-axes-in-swift-charts`,
  `/documentation/swiftui/view/chartlegend(_:)`,
  `/documentation/charts/chartcontent/foregroundstyle(by:)`.
- WWDC22 — "Hello Swift Charts" (`/videos/play/wwdc2022/10136`) and "Design an effective chart"
  (`/videos/play/wwdc2022/110340`), via Sosumi.
- Practice corpus — `swiftui-ctx lookup Chart` `co_occurs_with` (`chartYAxis`, `AxisMarks`,
  `AxisGridLine`, `AxisValueLabel`) confirming axis/legend customization is the common shipping pattern.
