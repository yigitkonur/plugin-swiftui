# Reference — Hand-Rolled Charts & Choosing the Right Mark (charts-02 / charts-03)

Two related defects: a chart built from layout primitives instead of `Chart` (charts-02), and a real
`Chart` that uses the wrong `*Mark` for its data shape (charts-03).

---

## charts-02 — hand-rolled bar/line charts

**The shape.** A `ForEach` over data emitting `Rectangle`/`RoundedRectangle`/`Capsule` whose
`.frame(height:)` (or `width:`) is computed from the value, often wrapped in a `GeometryReader` to scale
to the container. This reinvents — badly — what `Chart` gives for free: axes, gridlines, tick formatting,
a legend, animation, selection, and VoiceOver.

```swift
// ❌ hand-rolled (charts-02)
GeometryReader { geo in
    HStack(alignment: .bottom) {
        ForEach(data) { row in
            Rectangle()
                .frame(width: 20, height: geo.size.height * row.fraction)
        }
    }
}
```

```swift
// ✅ Chart (consensus shape from swiftui-ctx lookup BarMark — 86% (x:, y:))
Chart(data) { row in
    BarMark(x: .value("Day", row.day), y: .value("Total", row.total))
}
.chartXAxis { AxisMarks() }
```

**Detection.** The tier-2 ast-grep rule `charts-02-hand-rolled-bars.yml` matches a
`Rectangle/RoundedRectangle/Capsule().frame(…)` **inside a `ForEach`** — the containment grep can't
express. READ the file to confirm the frame dimension is **data-driven** (a fixed-size spacer/divider is
fine — not a chart). Tier-1 also flags a lone `GeometryReader` as a weaker tell.

**Seam.** If the bars are drawn with `Canvas {}` or `Path`, that is **`audit-swiftui-drawing-canvas`'s**
hand-rolled-drawing finding — file it there or `cross_ref` drawing-canvas, don't double-own. Our charts-02
is specifically the *layout-primitive* (stack/`GeometryReader`) reinvention.

**Fix mode.** `flag-only` — converting to `Chart` restructures the body and requires choosing a Mark and
`PlottableValue` keys; show the ✅, the dev applies.

---

## charts-03 — wrong Mark for the data

Each mark encodes a different data relationship. The wrong one misleads the reader even though it
compiles.

| Data shape | Right mark | Wrong-mark tell |
|---|---|---|
| Discrete categories, magnitude | `BarMark` | a `LineMark` connecting unordered categories (implies a trend that isn't there) |
| Continuous/time-ordered trend | `LineMark` / `AreaMark` | a `BarMark` per timestamp for a dense series (should be a line) |
| Parts of a whole | `SectorMark` (macOS 14) | many `BarMark`s the reader must sum mentally |
| Correlation of two quantities | `PointMark` | a `LineMark` across unsorted x (zig-zag spaghetti) |
| Threshold / target overlay | `RuleMark` | a hardcoded `Rectangle` overlay |

**Judgment, not mechanics.** charts-03 is a `warning`/`flag` — the "right" mark depends on intent. When
unsure whether a Mark fits, VERIFY the data's domain and check `swiftui-ctx lookup <Mark> --json`
`co_occurs_with` (e.g. `LineMark` co-occurs with `chartScrollPosition`/`chartXVisibleDomain` → it's a
trend series; `SectorMark` co-occurs with `chartAngleSelection` → parts-of-whole). Cite the consensus
example permalink as the ✅, never a hand-written snippet.

---

## Sources

- Apple — "Swift Charts" framework overview + mark pages, fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/charts`,
  `/documentation/charts/barmark`, `/documentation/charts/linemark`, `/documentation/charts/sectormark`.
- WWDC22 — "Design an effective chart" (`/videos/play/wwdc2022/110340`) and "Design app experiences with
  charts" (`/videos/play/wwdc2022/110342`) — mark-choice guidance, via Sosumi.
- Practice corpus — `swiftui-ctx recipe charts-bar` (the `Chart`+`BarMark`+`chartXAxis` template) and
  `swiftui-ctx lookup BarMark` (consensus `(x:, y:)` shape + recommended permalink).
