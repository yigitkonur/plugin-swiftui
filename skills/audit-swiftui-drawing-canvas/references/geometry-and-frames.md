# Reference — Geometry, Frames, and `MeshGradient` Gating (draw-03/04/05/06/12)

The depth behind `GeometryReader`-as-layout, absolute frames vs `containerRelativeFrame`, and the one
genuine availability concern in this domain — `MeshGradient` (macOS **15.0+**). Floor *values* are not
restated here; the reconciled truth is `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and the
macOS-arm gating rule is `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## draw-03 — `GeometryReader` arranges children (layout), not drawing geometry

`GeometryReader` has two uses; only one belongs here.

- **Correct (stays here).** Read a size into drawing math: `GeometryReader { geo in Canvas { … } /* use
  geo.size */ }` or feeding a `Path(in:)`. The reader *measures*; nothing is positioned by it.
- **Smell draw-03 (route out).** `GeometryReader` wrapping children and `.position()`/`.offset()`-ing them
  to *arrange* a layout. `GeometryReader` greedily takes all offered space and top-leading-aligns its
  children — using it as a layout container is the classic anti-pattern. The job is the **`Layout`
  protocol** (custom arrangement) or **`containerRelativeFrame(_:alignment:)`** (proportional sizing).

`Layout`-protocol *mechanics* are owned by `audit-swiftui-layout-and-tables`; this skill flags the
drawing-geometry smell and emits a `cross_ref: layout-and-tables` — it does not audit `Layout` conformance.
The ast-grep rule `draw-03` proves the positioning sits inside the `GeometryReader` closure; READ to
confirm it arranges (vs only measures). Warning, `flag-only`.

---

## draw-04 — absolute hard-coded frames for a resizable drawing surface

`.frame(width: 400, height: 300)` / `.position(x: 200, y: 150)` pins a drawing to fixed points. A Mac
window resizes freely, so a stretchable canvas drawn at fixed coordinates clips, letterboxes, or drifts.

- A genuinely fixed-size element (an icon, a 1pt hairline) keeping a literal frame is **fine** — READ
  before flagging.
- A surface meant to fill/track its container should derive size from the parent:
  `containerRelativeFrame(_:alignment:)` (floor macOS 14.0) for a proportion of the container, or a
  `GeometryReader`-fed size into the `Canvas`/`Path` math (the correct draw-03 use).

Advisory, `flag-only` — "fixed icon vs stretchable canvas" is a human read.

---

## draw-05 / draw-12 — `MeshGradient` availability (the one gating concern)

`MeshGradient(width:height:points:colors:)` is **macOS 15.0+** (confirmed: `swiftui-ctx lookup
MeshGradient` → `introduced_macos: 15.0`; Sosumi `doc:` floor macOS 15.0). It is **real** — never flag it
as invented. It must be gated only when the deployment floor is **below macOS 15**.

- **draw-05 (ungated below floor, warning).** A `MeshGradient(...)` not inside `if #available(macOS 15,
  *)` while the project floor is < 15. The ast-grep rule `draw-05` proves the absence of an enclosing
  availability gate; the **deployment target read in ORIENT decides whether it fires** — floor ≥ 15 means
  no gate is needed and there is no finding. `flag-only` (the right gate placement is a human call).
- **draw-12 (wrong arm, hard-fail, `fix_mode: auto`).** `if #available(iOS 15, *)` guarding `MeshGradient`
  in a macOS target — the iOS arm never evaluates true on a Mac, so the gradient is dead. Rewrite the
  condition to `#available(macOS 15, *)`. This is the single mechanical auto-fix in the domain; the
  ast-grep rule `draw-12` proves the gate scope wraps `MeshGradient`. Rule + failure shape:
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`.

**✅ correct — swiftui-ctx consensus shape `(width, height, points, colors)` (70% of real call sites;
`+smoothsColors` 18%; the `+background/+colorSpace` overloads in the long tail), macOS-arm gated:**

```swift
if #available(macOS 15, *) {
    MeshGradient(
        width: 3, height: 3,
        points: [ /* 9 SIMD2<Float> control points */ ],
        colors: [ /* 9 colors */ ])
} else {
    LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)  // pre-15 fallback
}
```

Live consensus + a real call site: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup MeshGradient
--json` then `file <recommended.id> --smart`.

---

## draw-06 — `MeshGradient` arity (points/colors vs width×height)

`MeshGradient` lays out a `width × height` control grid, so `points.count` and `colors.count` must each
equal `width * height` (a 3×3 mesh needs 9 of each). A literal-`width:`/`height:` call with array lengths
that don't multiply out is the tell. Whether a mismatch is a **compile error vs a runtime no-op** on macOS
15+ is **UNVERIFIED** — flag the arity smell, assert no crash, mark `source: verify against Xcode 26 SDK`.
The grep tell catches the literal-arity form; READ the arrays to count. Warning, `flag-only`.

## Sources

- Apple — `MeshGradient`: `https://developer.apple.com/documentation/swiftui/meshgradient` (macOS 15.0+,
  via Sosumi, accessed 2026-06-07).
- Apple — `View.containerRelativeFrame(_:alignment:)`:
  `https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:)` (macOS
  14.0+, via Sosumi, accessed 2026-06-07).
- Apple — `GeometryReader` (note its greedy-space / top-leading behavior):
  `https://developer.apple.com/documentation/swiftui/geometryreader` (via Sosumi, accessed 2026-06-07).
- Practice corpus: `swiftui-ctx lookup MeshGradient --json` → `introduced_macos: 15.0`, consensus
  `(width, height, points, colors)` 70% (accessed 2026-06-07). CLI contract:
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
