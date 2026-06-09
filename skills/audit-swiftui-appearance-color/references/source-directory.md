# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
appearance/color claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the
curl/CLI commands and the JSON-404 caveat is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the appearance-specific *map*
of which pages to fetch. Floor values live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Absence from the SwiftUI/Foundation index = treat as hallucinated until proven (corroborate with
   a `swiftui-ctx lookup` exit-3).
2. **Is it deprecated, and when?** For ac-03/ac-04 run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
   deprecated <api>` and cross-check the Sosumi "Deprecated" banner against `floors-master.md`
   (`foregroundColor` and `accentColor` both close at 26.5).
3. **Never** `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess.

---

## A. SwiftUI / Foundation symbol map

Human doc path = `developer.apple.com/documentation/<framework>/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Path | Floor |
|---|---|---|
| `Color` | `swiftui/color` | 10.15+ |
| `Color(_:bundle:)` (named asset color) | `swiftui/color/init(_:bundle:)` | 10.15+ |
| `foregroundStyle(_:)` | `swiftui/view/foregroundstyle(_:)` | 12.0+ |
| `foregroundColor(_:)` (deprecated) | `swiftui/view/foregroundcolor` | 10.15+ (deprecated 26.5) |
| `tint(_:)` (Color overload) | `swiftui/view/tint(_:)` | 12.0+ |
| `tint(_:)` (ShapeStyle overload) | `swiftui/view/tint(_:)-93mfq` | 13.0+ |
| `accentColor(_:)` (deprecated) | `swiftui/view/accentcolor` | 10.15+ (deprecated 26.5) |
| `Material` | `swiftui/material` | 12.0+ |
| `preferredColorScheme(_:)` | `swiftui/view/preferredcolorscheme(_:)` | 11.0+ |
| `EnvironmentValues.colorScheme` | `swiftui/environmentvalues/colorscheme` | 10.15+ |
| `EnvironmentValues.colorSchemeContrast` | `swiftui/environmentvalues/colorschemecontrast` | 10.15+ |

**Absent from the index → hallucinated / cross-platform (never emit as SwiftUI macOS):** `.textColor(_:)`,
`.backgroundColor(_:)`, `.tintColor(_:)`, `.foregroundColour(_:)`, `UIColor`. See
`_shared/hallucination-blacklist.md`.

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| HIG — Color | `design/human-interface-guidelines/color` | semantic colors, Dark variants |
| HIG — Dark Mode | `design/human-interface-guidelines/dark-mode` | appearance, not forcing scheme |
| HIG — Materials | `design/human-interface-guidelines/materials` | vibrancy, chrome fills |
| Asset catalog color sets | `documentation/xcode/specifying-your-apps-color-scheme` | Any/Dark/High-Contrast variants |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2019/214 | Implementing Dark Mode on macOS | semantic colors, asset variants |
| wwdc2021/10018 | What's new in SwiftUI | `Material`, `ShapeStyle` hierarchy |
| wwdc2025/256 | What's new in SwiftUI | appearance + deprecations guidance |

## D. Practitioners (corroboration only — never primary; label findings low-confidence / verified-by-research)

| Source | Reliable for | Trust |
|---|---|---|
| Majid Jabrayilov — swiftwithmajid.com | `ShapeStyle` hierarchy, `Material`, environment colors | high |
| Hacking with Swift | asset-catalog colors, `colorScheme` environment | medium |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Corpus consensus/recommended examples via `swiftui-ctx lookup` (`foregroundStyle`, `tint`, `Material`)
  and `deprecated` (`foregroundColor`, `accentColor`), accessed 2026-06-07.
