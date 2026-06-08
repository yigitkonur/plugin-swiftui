# Reference — `Path` Math, Built-in Shapes, and Drawing Accessibility (draw-07/08/11)

The depth behind `Path` correctness, hand-rolled-vs-built-in shapes, and the `Canvas`/drawing a11y
descriptor. Floor *values* live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. `Path` and
the primitive shapes are macOS 10.15+ — the failure mode here is **math/judgment, not availability**.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## draw-07 — `Path` math smells

A `Path { p in … }` builder is imperative and easy to get subtly wrong. READ the whole builder; the
tells:

- **Unbalanced subpaths.** A `move(to:)` with no following draw command, or draw commands with no opening
  `move(to:)` (the first segment starts at an implicit origin and surprises).
- **No `closeSubpath()` where a fill is intended.** An open path filled by SwiftUI is auto-closed with a
  straight chord — usually not what the magic-number control points wanted. If the shape is `.fill`-ed,
  it should be explicitly closed.
- **Magic-number control points.** `addCurve(to:control1:control2:)` / `addQuadCurve(to:control:)` /
  `addArc(...)` with hard-coded literals that don't scale to the surface size — the curve breaks on
  resize. Control points should derive from the drawing rect, not be pinned to one size (couples to
  draw-04).

Advisory, `flag-only` — `Path` correctness is a human read against intent; the grep tell locates the
drawing commands, the auditor reads the geometry. There is no auto-fix for "the curve is wrong."

---

## draw-08 — hand-rolled `Path`/`Shape` for a built-in primitive

A `struct Foo: Shape { func path(in rect:) … }` (or an inline `Path`) that draws a plain circle, ellipse,
rounded rectangle, or capsule is reinventing a shipped primitive. SwiftUI provides `Circle`, `Ellipse`,
`Rectangle`, `RoundedRectangle(cornerRadius:)` / `RoundedRectangle(cornerSize:style:)`, and `Capsule` —
all `Shape`-conforming, all correct under resize, all clearer than the arc math. Prefer the built-in unless
the path is genuinely custom (a star, a speech bubble, a waveform). Advisory, `flag-only` — READ to confirm
the path is *not* doing something a primitive can't.

> `RoundedRectangle` is the correct modern corner rounding; the deprecated `.cornerRadius(_:)` *view
> modifier* is owned by `audit-swiftui-appearance-color` (api-currency seam) — note it, don't double-own.

---

## draw-11 — `Canvas`/hand-drawn data viz with no accessibility descriptor

A `Canvas` (and any hand-rolled, non-`Chart` drawing of data) renders pixels with **no** semantic tree, so
VoiceOver sees nothing. Every meaningful drawing needs at least `.accessibilityLabel(_:)` describing what
it depicts; a drawing that conveys *data* (a hand-rolled bar/line chart) should carry
`.accessibilityChartDescriptor(_:)` (an `AXChartDescriptor`) so VoiceOver can read values, or an
`.accessibilityValue`/`.accessibilityElement(children:)` summary.

This is a **keep-both seam** with `audit-swiftui-accessibility` — both plans intentionally double-detect
the Canvas-a11y gap. File the finding here in `accessibility/` AND emit `cross_ref: accessibility`; do not
collapse it into the a11y skill. (See `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`:
`Chart`/`Canvas` no a11y descriptor = keep-both.) Advisory, `flag-only` — the label text is author intent.

**✅ shape**

```swift
Canvas { ctx, size in drawBars(into: ctx, size) }
    .accessibilityLabel("Monthly revenue, January through June")
    .accessibilityChartDescriptor(RevenueDescriptor(data: data))   // when it depicts data
```

## Sources

- Apple — `Path` + `move(to:)`/`addLine(to:)`/`addCurve(...)`/`addArc(...)`/`closeSubpath()`:
  `https://developer.apple.com/documentation/swiftui/path` (via Sosumi, accessed 2026-06-07).
- Apple — primitive shapes (`Circle`/`Ellipse`/`Rectangle`/`RoundedRectangle`/`Capsule`):
  `https://developer.apple.com/documentation/swiftui/shape` (via Sosumi, accessed 2026-06-07).
- Apple — `View.accessibilityChartDescriptor(_:)` + `AXChartDescriptor`:
  `https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor(_:)` (via Sosumi,
  accessed 2026-06-07).
- Practice corpus: `swiftui-ctx lookup Path|Circle|Canvas --json` for consensus shapes + permalinked call
  sites (accessed 2026-06-07). CLI contract:
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
