# Hero transitions & matchedGeometryEffect (anim-08 · anim-09)

`matchedGeometryEffect(id:in:)` (macOS 11.0+) is the SwiftUI hero-transition primitive: two views sharing an
`id` in one `@Namespace` interpolate geometry when one replaces the other. Two defects: a **mis-wired**
match, and a **glass surface** that should morph with `glassEffectID` instead.

## anim-08 — mis-wired `matchedGeometryEffect` hero transition

A hero transition only works when ALL of these hold; the auditor READS to confirm each:

1. **One shared `@Namespace`** — both views reference the *same* namespace variable (often passed down; a
   per-view `@Namespace` never matches).
2. **Matching `id`** — identical `id:` on source and destination.
3. **Single transaction** — the swap happens inside one `withAnimation`/animated state change, with both
   views in the same `if/else` (conditional render), not two unrelated subtrees.
4. **Exactly one `isSource: true`** at a time among matched pairs.

- **swiftui-ctx** (`swiftui-ctx lookup matchedGeometryEffect --json`): `introduced_macos` **11**; consensus
  **93 % `(id, in)`** — the bare id+namespace form is the canonical shape. FIX cites it + the `recommended`
  permalink (`swiftui-ctx file <id> --smart`).

```swift
// ✅ shared namespace + matching id, swapped in one transaction
@Namespace private var hero
if isExpanded {
    DetailCard().matchedGeometryEffect(id: "card", in: hero)
} else {
    Thumbnail().matchedGeometryEffect(id: "card", in: hero)
}
// toggled via: withAnimation(.smooth) { isExpanded.toggle() }
```

## anim-09 — generic `matchedGeometryEffect` morphing a glass surface

When the two matched views are **Liquid Glass** surfaces (they carry `.glassEffect()`), the correct
morph primitive is **`glassEffectID(_:in:)`** inside a `GlassEffectContainer`, not a bare
`matchedGeometryEffect` — glass needs its sampling to morph, which `matchedGeometryEffect` does not drive.
Flag and **`cross_ref: liquid-glass`** (the glass-morph mechanics, `glass-17`, are owned there); this skill
owns only the "generic effect on a glass surface" smell. Do not audit the glass morph wiring here.

## VERIFY (step 5)

- Practice: `swiftui-ctx lookup matchedGeometryEffect --json` (consensus `(id, in)`, `co_occurs_with`
  including `animation`, `recommended` permalink).
- Spec: Sosumi `https://sosumi.ai/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)`.

## Sources

- Floors: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (Apple-sourced via Sosumi, 2026-06-07).
- Seam ownership (glass morph vs generic): `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`.
- Apple — `View.matchedGeometryEffect(id:in:…)`:
  `https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)`
  (via Sosumi, 2026-06-07).
