# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
SwiftData claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol (curl/CLI commands +
the JSON-404 caveat) is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the
SwiftData-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The practice half (consensus shape,
permalinked example, deprecation-in-the-wild) is `swiftui-ctx` — its contract is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

**As of:** 2026-06-07 · macOS 14+ · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftdata/<symbol-path>` and read the `**Available on:** … macOS N+`
   line. Cross-check against `floors-master.md`.
2. **Need the real shape / is it `low_corpus`?** Run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json`. A not-found on a known-real but
   sparse symbol (`ModelActor`) is `low_corpus`, **not** a hallucination — lean on Sosumi.
3. **The auto-save / window-close timing claims (sd-10)** are not Apple-documented guarantees — carry
   `advisory` with `source: verify against Xcode 26 SDK` unless Sosumi confirms.

---

## A. SwiftData symbol map (fetch via `sosumi.ai/documentation/swiftdata/<path>`)

| Symbol | Path | Floor |
|---|---|---|
| `@Model` macro | `model()` | macOS 14.0+ |
| `@Model` class inheritance (`@Model class X: Y`) | `model()` (WWDC25/291) | **macOS 26.0+** |
| `@Relationship(deleteRule:inverse:)` | `relationship` | macOS 14.0+ |
| `@Attribute` | `attribute` | macOS 14.0+ |
| `@Query` / `@Query(sort:)` | `query` | macOS 14.0+ |
| `ModelContext` / `.save()` / `.insert(_:)` | `modelcontext` | macOS 14.0+ |
| `ModelConfiguration(isStoredInMemoryOnly:)` | `modelconfiguration` | macOS 14.0+ |
| `ModelContainer(for:configurations:)` (variadic) | `modelcontainer` | **macOS 15.0+** |
| `ModelContainer(for:migrationPlan:configurations:)` | `modelcontainer` | macOS 14.0+ |
| `@ModelActor` | `modelactor` | macOS 14.0+ (`low_corpus` in swiftui-ctx) |
| `PersistentIdentifier` | `persistentidentifier` | macOS 13.0+ (the `Sendable` hand-off) |
| `#Index` / `#Unique` | `index` · `unique` | macOS 15.0+ |
| `HistoryDescriptor` / `fetchHistory(_:)` | `historydescriptor` | macOS 15.0+ |
| `HistoryDescriptor.sortBy` | `historydescriptor/sortby` | macOS 26.0+ (member badge: `verify-SDK`) |
| `.modelContainer(for:)` (SwiftUI scene modifier) | `swiftui/scene/modelcontainer(for:)` | macOS 14.0+ |

**Treat as hallucinated until Sosumi proves it:** any SwiftData name absent from the index. There is no
SwiftData-specific invented-name list — defer to
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`.

## B. Apple conceptual pages

| Page | Path | Anchors |
|---|---|---|
| SwiftData overview | `documentation/swiftdata` | the macro surface; floors |
| Preserving your app's model data across launches | `documentation/swiftdata/preserving-your-apps-model-data-across-launches` | container setup; `.modelContainer(for:)` |
| Adding and editing persistent data | `documentation/swiftdata/adding-and-editing-persistent-data-in-your-app` | insert / save / context |

## C. WWDC sessions (`developer.apple.com/videos/play/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2025/291 | SwiftData: Dive into inheritance and schema migration | `@Model` inheritance gate + versioned schema + register all types (sd-11) |
| wwdc2023/10196 | Dive deeper into SwiftData | the macro surface; the incomplete-`@Model` sample provenance |
| wwdc2024/10137 | What's new in SwiftData | `#Index`/`#Unique`, history API |

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Wade Tregaskis | `wadetregaskis.com/swiftdata-pitfalls/` | `let`-on-relationship crash, init-assignment NULL FK, missing init, `@Relationship(.cascade)` non-compile, unpersisted order, missing `save()` | high |
| Scott Driggers | `scottdriggers.com/blog/swiftdata-modelcontainer-creation-crash/` | `ModelContainer` `fatalError` trap + the three error causes + `Code=134504` | high |
| Paul Hudson | `hackingwithswift.com/quick-start/swiftdata/how-to-use-swiftdata-in-swiftui-previews` | in-memory preview container | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- swiftui-ctx CLI contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
