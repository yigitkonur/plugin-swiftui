# Reference — Chart Accessibility Descriptor (charts-11)

A `Chart` renders as a single opaque image to VoiceOver unless the developer supplies a descriptor. Sighted
users see the trend; VoiceOver users get nothing. This finding is **intentionally double-detected** with
`audit-swiftui-accessibility` (keep-both per
`${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`): file the chart-descriptor gap here and
`cross_ref` accessibility — do not collapse it.

---

## The defect

A `Chart` with no per-mark `.accessibilityLabel`/`.accessibilityValue` and no chart-level summary. Swift
Charts gives each mark a default audio-graph entry, but unlabeled `.value(...)` keys produce unusable
read-out ("1, 2, 3"). Provide meaningful labels and, ideally, a summary.

```swift
// ✅ per-mark labels + a chart-level summary
Chart(data) { row in
    BarMark(x: .value("Day", row.day), y: .value("Total", row.total))
        .accessibilityLabel(row.day.formatted(.dateTime.weekday(.wide)))
        .accessibilityValue("\(row.total) items")
}
.accessibilityLabel("Items completed per day")
```

For richer audio-graph navigation, conform the data to `AXChartDescriptorRepresentable`
(`.accessibilityChartDescriptor(_:)`) — but the per-mark labels above are the common, high-value baseline.

**Detection.** Tier-1 flags any `Chart(`/`Chart {` (same locate as charts-04); READ the chart's modifier
chain to confirm whether *any* accessibility affordance is present. `warning`, `flag-only` — accessibility
copy is human judgment, never auto-written.

**Seam.** We own the *chart-descriptor gap*; general VoiceOver/Dynamic-Type/Differentiate-Without-Color
auditing is `audit-swiftui-accessibility`. The two are deliberately kept separate and cross-linked.

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/charts/creating-accessible-charts`,
  `/documentation/swiftui/view/accessibilitychartdescriptor(_:)`,
  `/documentation/swiftui/axchartdescriptorrepresentable` (the protocol lives in the SwiftUI module, not Accessibility).
- WWDC21 — "Bring accessibility to charts in your app" (`/videos/play/wwdc2021/10122`); WWDC22 — "Hello
  Swift Charts" (`/videos/play/wwdc2022/10136`) accessibility section, via Sosumi.
