# Reference — Canvas, the Redraw Source, and `.drawingGroup()` (draw-01/02/09/10)

The depth behind the view-vs-`Canvas` choice, the `Timer`→`TimelineView` redraw fix, and the
`.drawingGroup()` usage/misuse decision. Floor *values* are not restated here — they live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The ✅ "Correct" shapes below are the
**swiftui-ctx consensus** for each API (get the live one with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
lookup <api> --json` and a real call site with `… file <recommended.id> --smart`), never a hand-invented
snippet.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK. APIs here are long-stable (macOS 12/10.15).

---

## draw-01 — many drawing views where one `Canvas` belongs

**Smell.** A `ForEach`/`ZStack` paints dozens of sibling `Image`/`Circle`/`Rectangle`/`Path`/`Shape`
views, each rendering one static glyph of a single scene (a starfield, a grid, a waveform, a particle
field). Every sibling is its own layout node + view-identity + render pass.

**The Canvas test (apply per element).** Is the element *interactive or independently identified* — its
own gesture, its own a11y node, its own animation/transition? → keep it a view. Is it *bulk static or
procedurally-drawn paint* with no individual identity? → fold it into one `Canvas { ctx, size in … }`,
which draws everything in a single immediate-mode pass with no per-element view machinery.

**❌ wrong**

```swift
ZStack {
    ForEach(stars) { star in
        Circle().fill(.white).frame(width: 2, height: 2).position(star.point)
    }
}
```

**✅ correct — swiftui-ctx consensus for `Canvas` is the trailing-closure `{ }` form (90% of real call
sites; `(rendersAsynchronously)` 9%, `(opaque, colorMode, rendersAsynchronously)` 1%):**

```swift
Canvas { context, size in
    for star in stars {
        let r = CGRect(x: star.x, y: star.y, width: 2, height: 2)
        context.fill(Path(ellipseIn: r), with: .color(.white))
    }
}
```

**Real verified call site (the `## Source` shape — `swiftui-ctx lookup Canvas` → `recommended`
`ex_94cad9e72b`, the `{ }` consensus form at 90%, macOS 12.0+, 251 repos / 672 uses, fetched 2026-06-07):**

```swift
// github.com/sindresorhus/Gifski … CropOverlayView.swift#L21  — Canvas { context, size in … }
Canvas { context, size in
    let entireCanvasPath = Path { $0.addRect(.init(origin: .zero, size: size)) }
    context.fill(entireCanvasPath, with: .color(.black.opacity(0.5)))
    let holePath = Path { $0.addRect(cropFrame) }
    context.blendMode = .clear
    context.fill(holePath, with: .color(.black))
}
```

- Permalink: `https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Crop/CropOverlayView.swift#L21`
- Sosumi `doc:` `https://sosumi.ai/documentation/swiftui/canvas` (macOS 12.0+).

Refresh the live consensus + permalink for any finding's `## Source`:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Canvas --json` then `file <recommended.id> --smart`.
`Canvas` `co_occurs_with` gestures
(`RotateGesture`, `RotationGesture`) and keyframe drivers — a Canvas that *is* interactive keeps its
gesture; that is the line between draw-01 (consolidate) and "leave it a view."

Advisory, `flag-only`: consolidation is an architecture call a human signs off — the auditor shows the ✅
and the per-element verdict (the `_redraw-map.md` go-beyond artifact), never auto-rewrites a view tree.

---

## draw-02 — `Timer` + `@State` redraw loop instead of `TimelineView`

**Smell.** A `Timer.publish`/`Timer.scheduledTimer`/`.onReceive(timer)` handler mutates `@State`
(`now = Date()`, `tick += 1`) for the sole purpose of forcing `body` to recompute so a time-based drawing
advances. That is a hand-rolled render loop SwiftUI already owns — it is not vsync-aligned, it churns the
whole `body`, and it keeps ticking off-screen.

**✅ correct — `TimelineView` (swiftui-ctx consensus shape is `(_)` at 99% — a single schedule argument +
trailing closure; floor macOS 12.0):**

```swift
TimelineView(.animation) { context in           // .animation = redraw every frame, vsync-aligned
    Canvas { gc, size in
        draw(at: context.date, into: gc, size)   // derive the frame from context.date — no @State tick
    }
}
```

Schedules: `.animation` (per-frame, optional `minimumInterval`/`paused`), `.periodic(from:by:)` (a fixed
cadence — a clock), `.explicit(_:)` (you supply the dates). Pick the slowest schedule that still looks
right; `.animation` on a clock that only needs `.periodic(by: 1)` is wasted frames.

Verify the schedule + a real call site:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup TimelineView --json`. Warning, `flag-only` — the
ast-grep rule `draw-02` proves the handler assigns; READ to confirm the mutation exists *only* to repaint
(a `Timer` that also writes a model or logs is a real side effect, not draw-02). The motion *curve* of the
animation is `animation-motion`'s; `TimelineView`-as-clock is ours at that seam.

---

## draw-09 / draw-10 — `.drawingGroup()`: the usage decision (and its misuse)

`.drawingGroup()` (floor macOS 10.15) flattens its subtree into **one** offscreen Metal layer rendered as
a unit — a win for *expensive, static, many-primitive* vector art that would otherwise re-rasterize each
frame. swiftui-ctx consensus is the bare `()` form (82%; `(opaque)` 13%).

- **draw-09 (missing).** A large/complex *static* `Path`/shape composition with no `.drawingGroup()`
  re-rasterizes every frame. Add `.drawingGroup()` to flatten it. Advisory; the render-*cost* number is
  `view-performance`'s — emit a `cross_ref` on the shared site, own the *usage decision* here.
- **draw-10 (misapplied).** `.drawingGroup()` on a *tiny*, *fast-animating*, or *text-bearing* subtree is
  a pessimization: it forces an offscreen pass for cheap content, can break blend modes against the
  surrounding view, and **may** drop text rasterization fidelity. The text-fidelity claim is **UNVERIFIED**
  — carry as `advisory`, `source: verify against Xcode 26 SDK`; never assert it as fact or auto-remove.

The `.drawingGroup()` *rationale* lives at the `view-performance` seam (cost) ↔ here (usage); see
`${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`.

---

## The redraw map (go-beyond artifact)

`swiftui-audits/drawing-canvas/_redraw-map.md`: one row per drawing surface — its **redraw source**
(`static` / `time-driven` / `state-driven`), the **Canvas test verdict** (`view` / `Canvas`), and whether
it carries the right driver (`TimelineView` for time, `.drawingGroup()` for expensive static). It makes
draw-01/02/09 legible at a glance and is reproducible run-to-run.

## Sources

- Apple — `Canvas` (immediate-mode drawing): `https://developer.apple.com/documentation/swiftui/canvas`
  (via Sosumi, accessed 2026-06-07).
- Apple — `TimelineView` + `TimelineSchedule` (`.animation`/`.periodic`/`.explicit`):
  `https://developer.apple.com/documentation/swiftui/timelineview` (via Sosumi, accessed 2026-06-07).
- Apple — `View.drawingGroup(opaque:colorMode:)`:
  `https://developer.apple.com/documentation/swiftui/view/drawinggroup(opaque:colormode:)` (via Sosumi,
  accessed 2026-06-07).
- Practice corpus (consensus shapes + permalinked call sites): `swiftui-ctx lookup Canvas|TimelineView|
  drawingGroup --json` — e.g. `Canvas` `{ }` 90%, `TimelineView` `(_)` 99%, `drawingGroup` `()` 82%
  (accessed 2026-06-07). CLI contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
