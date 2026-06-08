# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
accessibility claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file
is the accessibility-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + its macOS floor?** Fetch `https://sosumi.ai/documentation/swiftui/<symbol-path>`
   and read the `**Available on:** … macOS N+ …` line. Absence from the SwiftUI index = treat as hallucinated
   (a11y-10) until proven. Corroborate with `swiftui-ctx lookup <api>` — an **exit 3** is a strong
   "this API does not exist" signal.
2. **Need the precise per-platform array?** The raw `…/data/documentation/swiftui/<symbol>.json` `introducedAt`
   works when it resolves; it **404s** on parenthesized-symbol families — fall back to Sosumi. Never `WebFetch`
   `developer.apple.com`; never paper a 404 with a memory guess.

## A. SwiftUI accessibility symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Path | Floor |
|---|---|---|
| `accessibilityLabel(_:)` (`StringProtocol`) | `view/accessibilitylabel(_:)-1d7jv` | macOS 11.0 |
| `accessibilityLabel(_:)` (`LocalizedStringResource`) | `view/accessibilitylabel(_:)` | macOS 13.0 |
| `accessibilityValue(_:)` | `view/accessibilityvalue(_:)` | macOS 11.0 |
| `accessibilityHint(_:)` | `view/accessibilityhint(_:)` | macOS 13.0 |
| `accessibilityHidden(_:)` | `view/accessibilityhidden(_:)` | macOS 11.0 |
| `accessibilityElement(children:)` | `view/accessibilityelement(children:)` | macOS 10.15 |
| `accessibilityAddTraits(_:)` | `view/accessibilityaddtraits(_:)` | macOS 11.0 |
| `AccessibilityTraits.isToggle` | `accessibilitytraits/istoggle` | **macOS 14.0** |
| `accessibilityFocused(_:)` / `AccessibilityFocusState` | `view/accessibilityfocused(_:)` · `accessibilityfocusstate` | macOS 12.0 |
| `accessibilitySortPriority(_:)` | `view/accessibilitysortpriority(_:)` | macOS 11.0 |
| `accessibilityChartDescriptor(_:)` | `view/accessibilitychartdescriptor(_:)` | macOS 12.0 |
| `accessibilityRepresentation(representation:)` | `view/accessibilityrepresentation(representation:)` | macOS 12.0 |
| `EnvironmentValues.accessibilityReduceMotion` | `environmentvalues/accessibilityreducemotion` | macOS 10.15 |
| `EnvironmentValues.accessibilityDifferentiateWithoutColor` | `environmentvalues/accessibilitydifferentiatewithoutcolor` | macOS 10.15 |

**Absent from the index → hallucinated (a11y-10, never emit):** `.voiceOverLabel`, `.a11yLabel`,
`.accessibilityText`, `.screenReaderLabel`, `.accessibilityName`, `.voiceOverHint`.
**Real-but-legacy (a11y-11):** the combined `.accessibility(label:/hint:/addTraits:/value:)` modifier.

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| HIG — Accessibility | `design/human-interface-guidelines/accessibility` | label every control; don't rely on color/motion alone; VoiceOver |
| SwiftUI Accessibility fundamentals | `documentation/swiftui/accessibility-fundamentals` | labels, values, traits, grouping |
| Audio Graphs (chart descriptors) | `documentation/accessibility/audiographs` | `AXChartDescriptor` for Charts |

## C. WWDC sessions (`developer.apple.com/videos/play/<event>/<id>`)

| Event/id | Title | Covers |
|---|---|---|
| wwdc2019/238 | SwiftUI accessibility | labels, values, traits, `accessibilityElement` |
| wwdc2021/10119 | SwiftUI accessibility: Beyond the basics | rotors, custom actions, charts, focus |
| wwdc2023/10034 | Build accessible apps with SwiftUI and UIKit | `.isToggle`, zoom, accessibility content |

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Apple Developer — Accessibility | `developer.apple.com/accessibility/` | first-party guidance | high |
| Mela / WWDC sample-code repos in the `swiftui-ctx` corpus | via `swiftui-ctx lookup <api>` `recommended` permalink | real production label/value/grouping shapes | high |

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practice permalinks from the bundled `swiftui-ctx` corpus (`recommended` field of each `lookup`).
