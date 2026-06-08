# Reduce-Motion & motion restraint (anim-10 · anim-11)

Motion has an accessibility contract and a cost budget. These two defects sit on **shared seams** — emit
`cross_ref` and do not double-own the neighbour's mechanics.

## anim-10 — motion ignores `accessibilityReduceMotion`

Continuous, parallax, autoplay, or large-displacement motion that runs unconditionally ignores the user's
**Reduce Motion** setting. The auditor checks that the view reads
`@Environment(\.accessibilityReduceMotion)` and provides a reduced path (cross-fade or instant) when it is
`true`. The seam (`cross-ref-graph.md`): **animation-motion** owns *"the motion is wrong / has no reduced
path"*; **accessibility** owns *"the app ignores the flag entirely"* across all surfaces. Flag with
`cross_ref: accessibility`.

```swift
// ✅ a reduced path when Reduce Motion is on
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// …
.animation(reduceMotion ? nil : .smooth, value: isExpanded)
```

`accessibilityReduceMotion` is **macOS 10.15+** — no floor concern; the defect is the missing branch.

## anim-11 — `.repeatForever` / always-on motion (restraint + cost)

`.repeatForever(autoreverses:)` and other always-running animations are rarely native on the Mac (the HIG
favours restraint) and they keep the view tree re-rendering every frame. This is a **shared seam**: the
**UX-restraint** verdict is this skill's; the **render-cost** verdict belongs to **view-performance**. Flag
advisory with `cross_ref: view-performance`; do not re-derive the perf math here.

```swift
// ⚠️ always-on — questionable UX + per-frame render cost
.animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spin)
// ✅ run only while genuinely needed, and respect Reduce Motion (anim-10)
```

> Treat a `.repeatForever` as guilty until READ proves it is (a) needed, (b) reduce-motion-gated, and
> (c) not on a large/expensive subtree.

## VERIFY (step 5)

- Practice: `swiftui-ctx lookup animation --json` → `co_occurs_with` to see what restrained motion ships
  beside in real apps.
- Spec: Sosumi `https://sosumi.ai/documentation/swiftui/environmentvalues/accessibilityreducemotion`.

## Sources

- Seam ownership: `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` (Reduce-Motion seam ·
  repeatForever cost seam).
- Floors: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (Apple-sourced via Sosumi, 2026-06-07).
- Apple — `EnvironmentValues.accessibilityReduceMotion`:
  `https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion` (via
  Sosumi, 2026-06-07).
- Apple HIG — Motion: `https://developer.apple.com/design/human-interface-guidelines/motion` (via Sosumi,
  2026-06-07).
