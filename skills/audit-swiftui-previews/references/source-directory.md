# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
preview claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this
file is the previews-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The practice corpus (consensus shape +
permalinked example) comes from `swiftui-ctx` per
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Absence from the SwiftUI index = treat as hallucinated/platform-wrong until proven (e.g. the
   `windowStyle:` `#Preview` overload is **absent** from the macOS `#Preview` page — visionOS-only).
2. **Need the practice idiom?** `swiftui-ctx lookup <api> --json` → `consensus` (canonical shape),
   `recommended` (permalinked real macOS example), `co_occurs_with`. A `lookup` **exit 3** corroborates a
   hallucination/platform-wrong finding. A `low_corpus:true` (e.g. `Previewable`, `Entry` — sparse in the
   corpus because they are compile-time macros, not runtime call sites) means lean on Sosumi for the spec.
3. **Type-property floors** can inherit the enclosing type's floor in DocC — cross-check against WWDC
   provenance per the shared sosumi reference §4.

---

## A. Preview symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Path | macOS floor |
|---|---|---|
| `#Preview` / `Preview(_:traits:_:body:)` | `preview(_:traits:_:body:)` | 14.0+ |
| `@Previewable` | `previewable()` | 14.0+ |
| `@Entry` | `entry()` | 10.15+ (Xcode 15 to expand; practical 14) |
| `.fixedLayout(width:height:)` / `.sizeThatFitsLayout` / `.defaultLayout` traits | `previewtrait` family | 14.0+ |
| `PreviewModifier` / `.modifier(_:)` trait | `previewmodifier` · `previewtrait/modifier(_:)` | 15.0+ (`verify-SDK`) |
| `PreviewProvider` (legacy, NOT deprecated) | `previewprovider` | 10.15+ |
| `.modelContainer(for:inMemory:)` | `view/modelcontainer(for:inmemory:onsetup:)` | 14.0+ |
| `.environment(_:)` (type-keyed Observable) | `view/environment(_:)` | 10.15+ |
| `FocusedValueKey` / focused values | `focusedvaluekey` | 11.0+ |

**Absent from the macOS index → platform-wrong (never emit on a Mac target):**
`Preview(_:windowStyle:traits:body:)` (visionOS-only — there is **no** `windowStyle:` `#Preview` on
macOS). **Wrong injector for an `@Observable`:** `.environmentObject(_:)` (takes only an
`ObservableObject`). Canonical list:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`.

---

## B. WWDC provenance (fetch via Sosumi `/videos/play/...`)

| Session | Covers | Path |
|---|---|---|
| WWDC23 10252 | Programmatic `#Preview` macro, `@Previewable` | `/videos/play/wwdc2023/10252` |
| WWDC23 10149 | `@Observable` + `.environment(_:)` injection | `/videos/play/wwdc2023/10149` |
| WWDC24 10144 | `PreviewModifier`, shared cached fixtures | `/videos/play/wwdc2024/10144` |

---

## C. Practitioner corroboration (the canvas-crash symptom)

| Source | Use |
|---|---|
| swiftlang/swift #66537 | SwiftData preview crashes without an in-memory container (prev-06 symptom) |
| swiftui-ctx `recommended` permalinks | the canonical ✅ — a real macOS app's `.modelContainer`/`.environment` body |

---

## Sources

- Apple SwiftUI documentation (fetched via Sosumi `https://sosumi.ai/documentation/swiftui/...`, accessed 2026-06-07) — the symbol pages mapped above.
- Apple WWDC sessions 2023/10252, 2023/10149, 2024/10144 (via Sosumi `/videos/play/...`, accessed 2026-06-07).
- swiftlang/swift issue #66537 — https://github.com/swiftlang/swift/issues/66537 — accessed 2026-06-07.
