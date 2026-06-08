# Hallucinated APIs (macOS SwiftUI) — curr-13 / curr-14

The invented names AI confabulates for a surface it never saw (chiefly Liquid Glass, which shipped at
WWDC25 — after most training data). For a brand-new surface the most *probable* next token is a
plausible name, not an admission of absence. **Hard-fail on sight.** The canonical invented-name list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read it, do not restate it here.

> This skill flags only the *hallucinated names*. The Liquid-Glass *design* audit (placement, glass-on-
> glass, containers, morphing, gating depth) is `cross_ref audit-swiftui-liquid-glass` — do not audit
> glass design here.

---

## curr-13 · invented modifiers that do not exist on macOS

```swift
.glassBackground()        // ❌ not a SwiftUI API
.liquidGlass()            // ❌ not a SwiftUI API
LiquidGlassView { … }     // ❌ not a type
.material(.glass)         // ❌ not a SwiftUI API
.background(.glass)        // ❌ not a ShapeStyle
SomeView().cardStyle()    // ❌ invented convenience modifier
```

✅ The **real** Liquid Glass surface is `glassEffect(_:in:)`, `GlassEffectContainer`,
`.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` — all `macOS 26.0+`, gated with
`if #available(macOS 26.0, *)` below a 26 floor. For a non-glass invented helper (`.cardStyle()`) the
fix is the underlying real modifiers (`.clipShape`, `.background`, `.shadow`). `era: WWDC25/macOS-26`.

**The exit-3 corroboration (step VERIFY):** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup
glassBackground --json` returns **exit 3** (not-found, with a did-you-mean `suggestion`) → no shipping
Mac app uses the symbol → the hallucination finding is confirmed. A *real* symbol returns exit 0 with a
`consensus` shape and a `recommended` permalink; that is the signal it is NOT hallucinated.

## curr-14 · real-but-platform-wrong: `.glassBackgroundEffect()`

```swift
content.glassBackgroundEffect()      // ❌ REAL symbol but visionOS-only — ABSENT on macOS
content.glassEffect()                // ✅ the macOS Liquid Glass call (macOS 26.0+)
```

`.glassBackgroundEffect()` exists, so `swiftui-ctx lookup` will *not* exit 3 — but its
`introduced_macos` / platform list is visionOS, and Sosumi shows no macOS availability arm. Flag it on
any macOS target. **Do NOT confuse with `Glass.interactive(_:)`, which IS `macOS 26.0+`** (pointer-driven
on the Mac) — never flag that as invented or platform-wrong. `era: WWDC25/macOS-26`.

---

## Verify-don't-invent discipline

Never assert a symbol exists, or that a name is hallucinated, from memory. Confirm with **both**: (a)
`swiftui-ctx lookup <name> --json` (exit 0 + `consensus` = real; exit 3 + `suggestion` = hallucinated),
and (b) Sosumi for the platform/availability arm (`references/source-directory.md` for the path). If
neither resolves, carry the finding as `source: verify against Xcode 26 SDK`, never as fact.

## Sources

- Apple — `glassEffect(_:in:)` / `GlassEffectContainer` (real Liquid Glass, `macOS 26.0+`): https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) and https://developer.apple.com/documentation/swiftui/glasseffectcontainer (scraped 2026-06-06).
- Apple — `glassBackgroundEffect()` (visionOS-only): https://developer.apple.com/documentation/swiftui/view/glassbackgroundeffect(displaymode:) (scraped 2026-06-06).
- Apple — Adopting Liquid Glass: https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass (scraped 2026-06-06).
- HN, "Adding a feature because ChatGPT incorrectly thinks it exists" — https://news.ycombinator.com/item?id=44491071 (accessed 2026-06-06; illustrative of API hallucination).
- WWDC25 — "Meet Liquid Glass" (session 219); "Build a SwiftUI app with the new design" (session 323, 2025-06-09).
