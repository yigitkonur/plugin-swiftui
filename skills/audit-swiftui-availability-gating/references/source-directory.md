# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
**floor** claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this
file is the gating-specific *map* of which pages to fetch to place a floor. Floor *values* are the
reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — that table is this
skill's floor map; Sosumi is only for the symbol you cannot place from it.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify a floor (summary; full protocol in the shared sosumi reference)

1. **What is the symbol's macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line — **only the macOS arm** (ignore the iOS number; it can be higher, which over-gates the Mac).
   Absence of a macOS arm = the symbol is **macOS-ABSENT** → gate-06 (replace, don't gate).
2. **Need the precise per-platform array?** The raw `…/tutorials/data/documentation/swiftui/<symbol>.json`
   `introducedAt` works when it resolves; it **404s** on parenthesized-symbol families and can return an
   **SPA shell** for the `.task`-family — fall back to Sosumi's human URL. Never `WebFetch`
   `developer.apple.com`; never paper a 404 with a memory guess.
3. **Type-property floors (gate-08).** A static/type property page can inherit the enclosing type's
   "first available" badge in DocC — cross-check against `swiftui-ctx introduced_macos` and the property's
   own page per the shared sosumi reference §4 before trusting the top-of-page badge.
4. **Practice corroboration.** `swiftui-ctx lookup <api> --json` returns `introduced_macos` (the floor
   observed across real shipping repos) and a `diverse`/`recommended` example whose `min_macos` shows the
   gate real apps use — cross-check it against the Sosumi floor; they must agree.

---

## A. Common above-floor SwiftUI symbols this net catches (place via floors-master, confirm via the path)

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`).
Floor values are authoritative in `floors-master.md`; this maps where to confirm each.

| Symbol (floor in floors-master) | Path |
|---|---|
| `@Observable` / `@Bindable` (14.0) | `documentation/observation/observable` · `swiftui/bindable` |
| `glassEffect(_:in:)` & glass family (26.0) | `swiftui/view/glasseffect(_:in:)` — deep gating: liquid-glass |
| `scrollEdgeEffectStyle(_:for:)` (26.0) | `swiftui/view/scrolledgeeffectstyle(_:for:)` |
| `backgroundExtensionEffect()` (26.0) | `swiftui/view/backgroundextensioneffect()` |
| `symbolEffect(_:options:)` (14.0) | `swiftui/view/symboleffect(_:options:isactive:)` |
| `MeshGradient` (15.0) | `swiftui/meshgradient` |
| `TextRenderer` (protocol, 14.0; `textRenderer(_:)` modifier 15.0) | `swiftui/textrenderer` |
| `Tab(_:image:)` / `TabSection` (15.0) | `swiftui/tab` · `swiftui/tabsection` |
| `@Model class X: Y` inheritance (26.0) | `swiftdata/model()` |

**macOS-ABSENT → replace, never gate (gate-06; full list in hallucination-blacklist):**
`.glassBackgroundEffect()`, `WheelPickerStyle`, `ToolbarItemPlacement.topBarLeading`/`.topBarTrailing`,
`WindowStyle.volumetric`, `navigationBarTitleDisplayMode`, `.bottomBar`.

## B. Apple conceptual pages

| Page | Path | Anchors |
|---|---|---|
| Marking API availability in Swift | `documentation/xcode/marking-api-availability-in-swift` | `@available` / `#available`, the `*` wildcard, back-deployment |
| SwiftUI updating for the latest SDKs | `documentation/swiftui` (release-notes section) | which symbols floored at the current SDK |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2025/256 | What's new in SwiftUI | which symbols are new at macOS 26 (their floors) |
| wwdc2020/10120 | What's new in Swift (availability) | `#available` / `@available` / unavailable handling |

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Swift Evolution | `github.com/swiftlang/swift-evolution` (SE-0289 `#unavailable`) | the `#available`/`#unavailable`/`*` semantics | high |
| Majid Jabrayilov | `swiftwithmajid.com` (availability posts) | back-deployment + dual-target gating patterns | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 / SPA-shell caveat:
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
