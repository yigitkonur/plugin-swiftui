# Reference — Design Rules & The Glass Placement Map

The judgment core of the audit: the three non-negotiable Liquid Glass rules, the navigation-vs-content
placement test, glass-on-glass, container grouping, and variant/tint discipline. These are *flag-only*
defects (the ✅ pattern is shown; restructuring the view is the dev's call), with one auto-fixable
exception noted. Floors live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; real
symbols in `glass-api-surface.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## What Liquid Glass is (so the rules make sense)

A real-time light-lensing **navigation-layer material** — not a blur, not `NSVisualEffectView`
renamed. You declare placement, shape, and tint; the system owns lensing, motion, and accessibility.
The rules below all flow from one fact: **glass samples the content behind it, and it cannot sample
glass.**

---

## The three non-negotiable rules

1. **Navigation layer only — never content.** Glass belongs on the topmost layer where the user
   navigates and acts (toolbars, floating controls, sidebars), never on the information itself (list
   rows, cells, cards, text, images, charts, form fields, full-screen backgrounds). On content it
   defeats the material's purpose and hurts legibility. Apple ships zero content-glass exceptions.
2. **Never glass-on-glass.** Glass can't sample glass; stacking renders incorrectly and clutters. One
   glass layer over plain content.
3. **Group siblings in a `GlassEffectContainer`.** Two+ sibling glass elements without an enclosing
   container each sample the background independently → mismatched blur/tint, extra render passes
   (each `.glassEffect()` allocates a backdrop layer with offscreen textures), and no morphing.

---

## The placement test (the navigation-vs-content classifier)

For each glassed view, ask: **remove the element.**

- Lost the ability to **navigate or act** (a button, a tab, a toolbar, a floating control) → it is the
  **navigation layer** → glass is correct here.
- Lost **information** (a row, a value, a card, a label, an image, a chart) → it is **content** → glass
  is wrong here (glass-03).

Structural signals that corroborate the verdict:

- Inside `List {` / `ForEach {` / `Table {`, or on a `Text(` / `Image(` / card view → **content**.
- On a `.toolbar`, a floating overlay/`ZStack` control, or a sidebar column → **navigation**.

> **Go-beyond — the placement map artifact.** A run may emit
> `swiftui-audits/liquid-glass/_placement-map.md` classifying **every** glassed view as
> `navigation` or `content` with its file:line and verdict, plus a container-coverage score (fraction
> of sibling glass groups that sit inside a `GlassEffectContainer`). This turns a finding list into a
> whole-app picture and makes glass-03 obvious at a glance.

---

## The defects in this reference (❌ → ✅)

**glass-03 — glass on content (warning, flag-only).**
```swift
// ❌ glass on a list row — content layer
List(items) { item in
    Text(item.name).glassEffect(.regular, in: .rect(cornerRadius: 8))
}
// ✅ plain content; a floating control carries the glass in a ZStack/overlay
ZStack(alignment: .bottomTrailing) {
    List(items) { item in Text(item.name) }
    Button("Add", systemImage: "plus") { … }
        .buttonStyle(.glassProminent)
        .padding()
}
```

**glass-04 — glass-on-glass (warning, flag-only).** Two+ `.glassEffect(` on nested/stacked views.
✅ keep glass on exactly one layer; the inner content is plain.

**glass-05 — siblings with no container (warning, flag-only).**
```swift
// ❌ two sibling glass controls, no container — independent sampling, no morph
HStack { ControlA().glassEffect(); ControlB().glassEffect() }
// ✅ group them; frame the INNER content, not the container
GlassEffectContainer(spacing: 12) {
    HStack(spacing: 12) { ControlA().glassEffect(); ControlB().glassEffect() }
}
```
Note: creating too many containers degrades performance (Apple) — group genuine sibling sets, don't
wrap every view.

**glass-08 — mixed variants in one group (warning, flag-only).** `.glassEffect(.regular` and
`.glassEffect(.clear` in one container/stack. `.regular` and `.clear` have different characteristics;
`.clear` requires a dimming layer or other treatment beneath for legibility. ✅ one variant per group.

**glass-09 — tint spam (warning, flag-only).** Two+ `.tint(` / `.glassProminent` among sibling glass
controls. ✅ tint/`.glassProminent` exactly **one** primary action per screen; siblings use `.glass`.

**glass-14 — hand-rolled glass button (advisory, flag-only).**
`Button{}.padding().glassEffect(.regular).clipShape(.capsule)` gets shape/tint wrong. ✅ use
`.buttonStyle(.glass)` / `.glassProminent`, which adopt the material context-aware.

---

## The canonical "correct" exemplar (steer fixes toward this)

```swift
@available(macOS 26.0, *)
struct FloatingToolPalette: View {
    @Namespace private var ns
    var body: some View {
        GlassEffectContainer(spacing: 16) {          // rule 3 — one container groups the siblings
            HStack(spacing: 16) {
                Button("Pen",   systemImage: "pencil") { }.buttonStyle(.glass)
                Button("Erase", systemImage: "eraser") { }.buttonStyle(.glass)
                Button("Done",  systemImage: "checkmark") { }
                    .buttonStyle(.glassProminent)        // rule: tint exactly one primary action
            }
            .padding()
        }
        // navigation layer (a floating palette), single variant, single prominent action, gated.
    }
}
```

---

## Sources

- Apple — "Adopting Liquid Glass": *"Liquid Glass applies to the topmost layer of the interface, where
  you define your navigation."* + *"do so sparingly."*
  `https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass` (via Sosumi,
  accessed 2026-06-07).
- Apple — "Applying Liquid Glass to custom views": container blends/morphs; *"Creating too many Liquid
  Glass effect containers … can degrade performance."*
  `https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views` (via
  Sosumi, accessed 2026-06-07).
- WWDC25 — "Meet Liquid Glass" (`/videos/play/wwdc2025/219`): "always avoid glass on glass"; never mix
  variants; tint primary only (via Sosumi).
