# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
typography claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this
file is the typography-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Absence from the SwiftUI/Foundation index = treat as hallucinated until proven (corroborate with a
   `swiftui-ctx lookup` exit-3).
2. **Is it deprecated, and when?** For txt-01/02 run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
   deprecated <api>` and cross-check the Sosumi "Deprecated" banner against `floors-master.md` (Text `+`
   closes 26.0; `Font.system(_:design:)` design-only closes 26.5).
3. **Never** `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess.

---

## A. SwiftUI / Foundation symbol map

Human doc path = `developer.apple.com/documentation/<framework>/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Path | Floor |
|---|---|---|
| `Text` (+ the deprecated `+` operator) | `swiftui/text` | 10.15+ (`+` deprecated 26.0) |
| `Text(_:format:)` where `F.FormatOutput == AttributedString` | `swiftui/text/init(_:format:)` | 15.0+ |
| `AttributedString` | `foundation/attributedstring` | 12.0+ |
| `AttributeContainer` | `foundation/attributecontainer` | 12.0+ |
| `Font.system(_:design:weight:)` | `swiftui/font/system(_:design:weight:)` | 13.0+ |
| `Font.system(_:design:)` (deprecated) | `swiftui/font/system(_:design:)` | 10.15+ (deprecated 26.5) |
| `@ScaledMetric` | `swiftui/scaledmetric` | 11.0+ |
| `lineLimit(_:reservesSpace:)` | `swiftui/view/linelimit(_:reservesspace:)` | 13.0+ |
| `TextRenderer` (protocol) | `swiftui/textrenderer` | 14.0+ |
| `textRenderer(_:)` (modifier) | `swiftui/view/textrenderer(_:)` | 15.0+ |
| `LabeledContent` | `swiftui/labeledcontent` | 13.0+ |
| `monospacedDigit()` | `swiftui/text/monospaceddigit()` | 12.0+ |

**Absent from the index → hallucinated (never emit):** `.fontSize(_:)`, `.textStyle(_:)`,
`Text(styled:)`, `.attributedText(_:)`, `.font(size:)`. See `_shared/hallucination-blacklist.md`.

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| HIG — Typography | `design/human-interface-guidelines/typography` | Dynamic Type, text styles, weights |
| Rich text & AttributedString | `documentation/foundation/attributedstring` | AttributeContainer, runs, styled spans |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2021/10109 | What's new in Foundation | `AttributedString` introduction |
| wwdc2023/10157 | Rich text rendering with TextRenderer | `TextRenderer` / `textRenderer(_:)` |
| wwdc2025/256 | What's new in SwiftUI | Text composition + deprecations guidance |

## D. Practitioners (corroboration only — never primary; label findings low-confidence / verified-by-research)

| Source | Reliable for | Trust |
|---|---|---|
| Majid Jabrayilov — swiftwithmajid.com | `AttributedString` in `Text`, Dynamic Type | high |
| Sarah Reichelt / Hacking with Swift | `LabeledContent`, `monospacedDigit` | medium |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Corpus consensus/recommended examples via `swiftui-ctx lookup` (ScaledMetric, textRenderer, lineLimit),
  accessed 2026-06-07.
