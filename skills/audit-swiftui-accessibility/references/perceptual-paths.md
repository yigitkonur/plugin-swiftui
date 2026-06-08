# Color-only state, Reduce-Motion path, Chart/Canvas representation (a11y-05/06/07)

The *alternative-perception* axis: information must survive when color, motion, or sighted reading is
unavailable. Each defect here is a **shared seam** — emit the noted `cross_ref`. Floors in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; per `cross-ref-graph.md`, construction belongs to
the sibling skill, "the accessibility flag is ignored" belongs here.

## a11y-05 — state by color alone (warning, flag-only) · cross_ref appearance-color

A status shown only as red/green/orange (a connection dot, a validity tick, a diff highlight) is invisible to
color-blind users. Add a second channel — a symbol, a shape, or text — and/or honor the environment flag:

```
@Environment(\.accessibilityDifferentiateWithoutColor) private var noColor
…
Circle().fill(isOnline ? .green : .red)
    .overlay { if noColor { Image(systemName: isOnline ? "checkmark" : "xmark") } }
    .accessibilityLabel(isOnline ? "Online" : "Offline")   // always present for VoiceOver
```

**Seam:** WCAG contrast ratios and the color *construction* are `audit-swiftui-appearance-color`'s; this skill
owns the *missing non-color cue / missing label*. Emit `cross_ref appearance-color`.

## a11y-06 — motion ignores Reduce Motion (advisory, flag-only) · cross_ref animation-motion

A `withAnimation`, `.transition`, `repeatForever`, `.phaseAnimator`, or `.keyframeAnimator` that always runs
ignores a user who set **Reduce Motion** (System Settings → Accessibility). Read the flag and replace motion
with a cross-fade or nothing:

```
@Environment(\.accessibilityReduceMotion) private var reduceMotion
…
.animation(reduceMotion ? nil : .spring, value: expanded)
// or branch the transition:  .transition(reduceMotion ? .opacity : .slide)
```

**Seam:** the *motion construction* (spring tuning, phase/keyframe design) is `audit-swiftui-animation-motion`'s;
this skill owns only **"the Reduce-Motion flag is never read."** Emit `cross_ref animation-motion`. (Liquid
Glass morphs are a Reduce-Transparency seam with `liquid-glass`, not handled here.)

## a11y-07 — undescribed Chart / Canvas (warning, flag-only) · cross_ref charts / drawing-canvas

A `Chart` or `Canvas` renders pixels with no semantic content; VoiceOver lands on an opaque blob. Supply a
representation — the tier-2 ast-grep rule `a11y-07-chart-no-descriptor.yml` locates a `Chart {…}` with **no**
descriptor anywhere inside:

```
Chart(series) { … }
    .accessibilityChartDescriptor(SalesDescriptor(series))   // Audio Graph, macOS 12+
// a custom Canvas → proxy it with a standard control's semantics:
Canvas { … }
    .accessibilityRepresentation { Slider(value: $level, in: 0...1) }   // macOS 12+
// minimum bar: a label + summarizing value
.accessibilityLabel("Monthly sales").accessibilityValue("peak \(peak) in \(peakMonth)")
```

**Seam:** this is **intentional double-detection** (cross-ref-graph "keep-both") — the `charts` skill files the
chart-descriptor finding and `drawing-canvas` files the Canvas one; this skill cross-links rather than
collapsing. Emit `cross_ref charts` (or `drawing-canvas` for a `Canvas`). `accessibilityChartDescriptor` and
`accessibilityRepresentation` are both **macOS 12.0+** — gate if the floor is lower.

## Sources

- Apple — `accessibilityChartDescriptor(_:)`: `https://sosumi.ai/documentation/swiftui/view/accessibilitychartdescriptor(_:)`;
  `accessibilityRepresentation(representation:)`: `https://sosumi.ai/documentation/swiftui/view/accessibilityrepresentation(representation:)`
  (via Sosumi; access 2026-06-07).
- Apple — Environment values `accessibilityReduceMotion` / `accessibilityDifferentiateWithoutColor`:
  `https://sosumi.ai/documentation/swiftui/environmentvalues/accessibilityreducemotion` (access 2026-06-07).
- Floors (both descriptor APIs macOS 12, env flags 10.15): `_shared/floors-master.md` (re-confirmed 2026-06-07).
- Seam ownership ("keep-both" double-detection): `_shared/cross-ref-graph.md`.
