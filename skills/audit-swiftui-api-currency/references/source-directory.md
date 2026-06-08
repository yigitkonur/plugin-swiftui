# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
currency claim (a deprecation date, a successor signature, a floor). **Always fetch Apple docs via
Sosumi** — the shared fetch protocol with the curl/CLI commands and the JSON-404 caveat is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the currency-specific *map*
of which pages to fetch. Floor/deprecation values are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The **practice** half of VERIFY is
`swiftui-ctx` (`lookup`/`deprecated`) per `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Is it deprecated, and what is the current call?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N–M
   Deprecated …` line + the "Use X instead" guidance. Corroborate the practice with `swiftui-ctx
   deprecated <api>` (returns `deprecated`+`replacement`).
2. **Does the replacement exist + what's its floor?** `swiftui-ctx lookup <replacement> --json` →
   `introduced_macos` + `consensus`; cross-check the Sosumi `**Available on:**` arm. Absence from the
   SwiftUI index + a `lookup` exit 3 = treat as hallucinated.
3. **Never `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess.** The raw JSON
   `introducedAt` 404s on parenthesized-symbol families — fall back to the human Sosumi URL.

---

## A. Deprecated/renamed symbol map (curr-01 … curr-12)

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Path | Deprecation / floor |
|---|---|---|
| `NavigationView` | `navigationview` | dep `macOS 10.15–26.5` → `NavigationStack`/`NavigationSplitView` |
| `foregroundColor(_:)` | `view/foregroundcolor(_:)` | dep → `foregroundStyle(_:)` (macOS 12+) |
| `cornerRadius(_:)` | `view/cornerradius(_:)` | dep → `clipShape(.rect(cornerRadius:))` (macOS 10.15+) |
| `onChange(of:perform:)` (1-param) | `view/onchange(of:perform:)` | dep macOS 11.0–14.0 → `onChange(of:initial:_:)` |
| `tabItem(_:)` | `view/tabitem(_:)` | → `Tab` struct (`tab`, macOS 15+) |
| `NavigationLink(_:destination:)` | `navigationlink` | inline-in-`List` → `navigationDestination(for:destination:)` (macOS 13+) |
| `Text` `+` operator | `text/+(_:_:)` | dep `macOS 10.15–26.0` → interpolation/`AttributedString` |
| `MagnificationGesture` / `RotationGesture` | `magnificationgesture` · `rotationgesture` | renamed → `MagnifyGesture`/`RotateGesture` (macOS 14+) |
| `Font.system(_:design:)` | `font/system(_:design:)` | design-only dep macOS 26.5 → `system(_:design:weight:)` |
| `accentColor(_:)` | `view/accentcolor(_:)` | dep macOS 26.5 → `tint(_:)` (macOS 12+) |
| `dropDestination(for:action:isTargeted:)` | `view/dropdestination(for:action:istargeted:)` | 3-arg dep macOS 26.5 → `dropDestination(for:isEnabled:action:)` — **verify signature** |

## B. Hallucinated / platform-wrong (curr-13 / curr-14)

Absent from the index → hallucinated: `.glassBackground()`, `.liquidGlass()`, `LiquidGlassView`,
`.material(.glass)`, `.background(.glass)`, `.cardStyle()`. Real-but-visionOS-only:
`.glassBackgroundEffect()` → `view/glassbackgroundeffect(displaymode:)`. The full invented-name list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`.

## C. Apple conceptual pages

| Page | Path | Anchors |
|---|---|---|
| Migrating to new navigation types | `documentation/swiftui/migrating-to-new-navigation-types` | `NavigationView` → Stack/Split rationale |
| Migrating from ObservableObject to @Observable | `documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro` | the observation era (state-observation seam) |
| Adopting Liquid Glass | `documentation/TechnologyOverviews/adopting-liquid-glass` | the real glass surface (curr-13 replacement) |

## D. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2022 | The SwiftUI cookbook for navigation | `NavigationStack`/`NavigationSplitView` migration |
| wwdc2023/10149 | Discover Observation in SwiftUI | `@Observable`, 2-param `onChange` era |
| wwdc2025/256 | What's new in SwiftUI | the macOS-26 design-system + currency deltas |

## E. Practitioners (corroboration only — never primary; label `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Paul Hudson (Hacking with Swift) | `hackingwithswift.com/articles/281/what-to-fix-in-ai-generated-swift-code` | the AI-stale deprecation set + hallucination prevalence | high |
| Use Your Loaf | `useyourloaf.com/blog/swiftui-onchange-deprecation/` | the `onChange` 1-param deprecation text | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
