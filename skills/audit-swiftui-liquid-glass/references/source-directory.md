# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
glass claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`;
this file is the glass-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Absence from the SwiftUI index = treat as hallucinated until proven.
2. **Need the precise per-platform array?** The raw `…/tutorials/data/documentation/swiftui/<symbol>.json`
   `introducedAt` works when it resolves; it **404s** on parenthesized-symbol families — fall back to
   Sosumi (it never 404s on a valid human URL). Never `WebFetch` `developer.apple.com`; never paper a
   404 with a memory guess.
3. **Type-property floors** (e.g. `Glass.regular` statics) can inherit the enclosing type's floor in
   DocC — cross-check against WWDC provenance per the shared sosumi reference §4.

---

## A. SwiftUI glass symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`).
All glass symbols below are **macOS 26.0+** per floors-master (re-confirmed 2026-06-07).

| Symbol | Path |
|---|---|
| `glassEffect(_:in:)` | `view/glasseffect(_:in:)` |
| `GlassEffectContainer` | `glasseffectcontainer` |
| `.buttonStyle(.glass)` / `GlassButtonStyle` | `glassbuttonstyle` · `primitivebuttonstyle/glass` |
| `.glassProminent` / `GlassProminentButtonStyle` | `glassprominentbuttonstyle` · `primitivebuttonstyle/glassprominent` |
| `Glass` (struct) | `glass` |
| `Glass.interactive(_:)` | `glass/interactive(_:)` — **macOS 26.0+, NOT iOS-only** |
| `Glass.identity` / `Glass.tint(_:)` | `glass/identity` · `glass/tint(_:)` |
| `glassEffectID(_:in:)` | `view/glasseffectid(_:in:)` |
| `glassEffectUnion(id:namespace:)` | `view/glasseffectunion(id:namespace:)` |
| `glassEffectTransition(_:)` / `.materialize` | `view/glasseffecttransition(_:)` · `glasseffecttransition/materialize` |
| `backgroundExtensionEffect()` | `view/backgroundextensioneffect()` |
| `scrollEdgeEffectStyle(_:for:)` / `scrollEdgeEffectHidden(_:for:)` | `view/scrolledgeeffectstyle(_:for:)` · `view/scrolledgeeffecthidden(_:for:)` |
| `ToolbarContent.sharedBackgroundVisibility(_:)` | `toolbarcontent/sharedbackgroundvisibility(_:)` |
| `toolbarBackgroundVisibility(_:for:)` (macOS **15.0+**) | `view/toolbarbackgroundvisibility(_:for:)` |

**Absent from the index → hallucinated (never emit):** `.glassBackground()`, `.liquidGlass()`,
`LiquidGlassView`, `.material(.glass)`, `.background(.glass)`, `GlassContainer`,
`.buttonStyle(.liquidGlass)`. **Real-but-platform-wrong:** `.glassBackgroundEffect()` (visionOS-only).

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| Adopting Liquid Glass | `documentation/TechnologyOverviews/adopting-liquid-glass` | navigation-layer-only rule; "do so sparingly"; auto-adoption; `backgroundExtensionEffect` |
| Applying Liquid Glass to custom views | `documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views` | container blends/morphs; too-many-containers perf cost |
| HIG — Materials | `design/human-interface-guidelines/materials` (verify exact path against current HIG) | material design intent; defer contrast detail to `audit-swiftui-appearance-color` |

## C. WWDC25 sessions (`developer.apple.com/videos/play/wwdc2025/<id>`)

| id | Title | Covers |
|---|---|---|
| 219 | Meet Liquid Glass | navigation-layer only; "avoid glass on glass"; never mix variants; tint primary only |
| 323 | Build a SwiftUI app with the new design | `glassEffect`, `GlassEffectContainer`, grouping, morphing, auto-adoption |
| 256 | What's new in SwiftUI | the new design-system / glass guidance |

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Majid Jabrayilov | `swiftwithmajid.com/2025/07/01/liquid-glass-in-swiftui/` | Tab + `@SceneStorage`; `@available(obsoleted:26)` LabelStyle | high |
| Donny Wals | `donnywals.com/grouping-liquid-glass-components-using-glasseffectunion-on-ios-26/` | `glassEffectUnion` grouping (now Apple-corroborated) | high |
| tgrinblatt/tyler-app-style | `github.com/tgrinblatt/tyler-app-style` | macOS title-bar/toolbar fixes | medium |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
