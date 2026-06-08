# Reference — Charts Availability Gating (charts-08 / charts-09)

Swift Charts spans three macOS floors, and AI mis-floors the newer symbols in both directions. The floor
*values* are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read,
never restate them here. This file is the **gating logic** for the Charts domain. The macOS-arm rule and
the wrong-arm failure mode are in `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`.

---

## The three Charts floors (confirm each in floors-master)

| Floor | Symbols |
|---|---|
| **macOS 13** | `Chart`, `BarMark`, `LineMark`, `PointMark`, `AreaMark`, `RuleMark`, `RectangleMark`, `AxisMarks`, `.chartXAxis`/`.chartYAxis`/`.chartLegend`, `.foregroundStyle(by:)` |
| **macOS 14** | `SectorMark`, `.chartXSelection`/`.chartYSelection`/`.chartAngleSelection`, `.chartScrollableAxes`/`.chartScrollPosition`/`.chartXVisibleDomain` |
| **macOS 15** | `LinePlot`, `AreaPlot`, `BarPlot`, `PointPlot`, `SectorPlot`, `RectanglePlot`, `RulePlot` (vectorized function/series plots) |

Two AI failure shapes — **charts-08 fires for both**:

1. **Under-gated.** A macOS-14 symbol (`SectorMark`, `.chartXSelection`) or a macOS-15 symbol
   (`LinePlot`) used **ungated** under a deployment target below its floor → compile/availability error.
   The model assumed "Charts = macOS 13".
2. **Over-gated.** The mirror mistake: `.chartXSelection` wrapped in `#available(macOS 15, *)` when it is
   actually **macOS 14**, or `SectorMark` treated as macOS 13. The chart is needlessly unavailable on a
   whole OS version. Over-gating is a real defect — flag it and cite the corrected floor.

```swift
// ✅ correctly gated to the REAL floor (SectorMark = macOS 14)
if #available(macOS 14, *) {
    Chart(slices) { SectorMark(angle: .value("Share", $0.share)) }
} else {
    // pre-14 fallback (e.g. BarMark, macOS 13)
}
```

**ORIENT is load-bearing.** charts-08 only fires when the symbol's floor is **above** the project's
`MACOSX_DEPLOYMENT_TARGET`. If the floor is ≥ the symbol's introduction, no gate is needed and an existing
gate is the over-gating defect. Always confirm the floor via `swiftui-ctx lookup <api> --json`
(`introduced_macos`) **and** Sosumi before asserting either direction.

---

## charts-09 — wrong-arm gate

An `#available(iOS …, *)` (or `#if os(iOS)`) gate around a Charts symbol in a macOS target: the iOS arm
never runs on the Mac, so the chart is unreachable and the macOS path is silently empty. iOS Charts floors
(16 = base, 17 = `SectorMark`/selection, 18 = `LinePlot`) are why the model writes `#available(iOS 17, *)`.

```swift
// ❌ wrong arm (charts-09) — never true on macOS
if #available(iOS 17, *) { Chart(slices) { SectorMark(...) } }
// ✅ gate the macOS arm
if #available(macOS 14, *) { Chart(slices) { SectorMark(...) } }
```

**Detection.** The tier-2 ast-grep rule `charts-09-wrong-arm-gate.yml` matches an `#available(iOS …)`
whose body **contains** a `Chart`/`BarMark`/`LineMark`/`SectorMark`/`PointMark` — the gate-scope
containment grep can't express. `fix_mode: auto`: rewrite the platform arm to `macOS` at the correct floor
(per macos-arm-gating + floors-master).

---

## Sources

- Apple — availability annotations on the Swift Charts symbol pages, fetched via Sosumi (access
  2026-06-07): `https://developer.apple.com/documentation/charts/sectormark`,
  `/documentation/swiftui/view/chartxselection(value:)`, `/documentation/charts/lineplot`.
- Apple — "Availability condition" (`#available`) in *The Swift Programming Language* / SwiftUI platform
  gating, via Sosumi.
- Practice corpus — `swiftui-ctx lookup SectorMark`/`chartXSelection`/`LinePlot --json` `introduced_macos`
  values (14, 14, 15 respectively) confirming the floors against shipping code.
