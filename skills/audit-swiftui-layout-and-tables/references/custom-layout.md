# Reference — Custom `Layout` vs a Built-in Container (lt-08)

This skill **owns** the custom-layout context (per `finding-schema.md` §5 and `cross-ref-graph.md`). The
defect is *flag-only*: a hand-rolled `Layout`-protocol conformance where a built-in container would do the
same job with less code, fewer bugs, and free adaptivity. Floors live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2.

---

## The defect (lt-08, advisory, flag-only)

The `Layout` protocol (macOS 13.0+) lets you compute `sizeThatFits` / `placeSubviews` by hand. It is a
real, correct tool — for genuinely custom arrangements (radial menus, flow layouts, masonry). But AI
reaches for it to reproduce things a **built-in already does**, paying the cost of a bespoke geometry
engine for no gain.

```swift
// ❌ OFTEN UNNECESSARY — a custom Layout that just stacks two columns
struct TwoColumnLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { /* … */ }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) { /* … */ }
}
```
```swift
// ✅ CORRECT — a built-in container expresses the same intent (pick the one that matches the arrangement)
Grid { GridRow { LeftPane(); RightPane() } }                 // aligned rows/columns
ViewThatFits { WideLayout(); NarrowLayout() }                // pick the first that fits the proposed size
SomePane().containerRelativeFrame(.horizontal) { w, _ in w * 0.4 }  // size relative to the container
```

**Decision test — keep the custom `Layout` only if all are true:** (1) the arrangement is genuinely not a
stack/grid/`ViewThatFits`; (2) it needs cross-subview measurement a built-in can't express; (3) the code
is simpler or more correct than composing built-ins. Otherwise flag it toward the built-in.

**Grounded in the corpus.** `swiftui-ctx lookup Layout --json` (run 2026-06-07): `introduced_macos: 13.0`,
`deprecated: false`, **`low_corpus: true`** — i.e. very few shipping Mac apps hand-roll `Layout`, which is
itself the signal that most uses are unnecessary. `swiftui-ctx lookup ViewThatFits` / `Grid` returns the
built-in's consensus shape + a real permalink for the ✅; e.g. `ViewThatFits` →
`https://github.com/tahseen-kakar/harbor/blob/064c6b7c706c255ca30ae2c0ce607b6ba21e2edd/Harbor/Views/DownloadDetailView.swift#L136`.
In FIX, put the built-in's consensus shape in `## Correct` and that permalink in `## Source`.

---

## Seam — `GeometryReader` vs `Layout` vs `Canvas`

`cross-ref-graph.md` splits these precisely; apply it:

- A `GeometryReader` / `Layout` doing **layout arrangement** (positioning sibling views) → **this skill**.
- A `GeometryReader` **feeding a `Canvas`** (drawing geometry, not view placement) →
  `audit-swiftui-drawing-canvas`; note it in one line and `cross_ref drawing-canvas`, don't own it.
- A `Layout` whose real cost is **render performance** under many subviews → `cross_ref view-performance`.

A `GeometryReader` used merely to read a size for a one-off `.frame` is often replaceable by
`containerRelativeFrame` or an intrinsic-size modifier — flag toward the simpler tool, but only when the
read is genuinely doing layout.

---

## Sources

- Apple — `Layout`: *"A type that defines the geometry of a collection of views."* — macOS 13.0+.
  `https://developer.apple.com/documentation/swiftui/layout` (via Sosumi, accessed 2026-06-07).
- Apple — `ViewThatFits`: *"A view that adapts to the available space by providing the first child view
  that fits."* — macOS 13.0+.
  `https://developer.apple.com/documentation/swiftui/viewthatfits` (via Sosumi, accessed 2026-06-07).
- Apple — `Grid` / `GridRow`: *"A container view that arranges other views in a two-dimensional layout."*
  — macOS 13.0+. `https://developer.apple.com/documentation/swiftui/grid` (via Sosumi, accessed
  2026-06-07).
- Apple — `containerRelativeFrame(_:alignment:)` — macOS 14.0+.
  `https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:)` (via
  Sosumi, accessed 2026-06-07).
- Practice corpus: `swiftui-ctx lookup Layout` (`low_corpus:true`) ·
  `swiftui-ctx lookup ViewThatFits` →
  `https://github.com/tahseen-kakar/harbor/blob/064c6b7c706c255ca30ae2c0ce607b6ba21e2edd/Harbor/Views/DownloadDetailView.swift#L136`
  (1,857-repo macOS catalog; accessed 2026-06-07).
