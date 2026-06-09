# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
layout/Table claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this
file is the layout-specific *map* of which pages to fetch. The **practice** side (consensus shape +
permalinked example) comes from `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Floor
values live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Cross-check `introduced_macos` from `swiftui-ctx lookup <api> --json` against it and against
   `floors-master.md`. Absence from both = treat as hallucinated until proven (a `lookup` **exit 3**
   corroborates).
2. **Deprecation:** Sosumi shows the deprecation banner; `swiftui-ctx deprecated <api>` shows
   corpus-level deprecation. **Case-level** deprecation (e.g. `tableStyle(.inset(alternatesRowBackgrounds:))`)
   is NOT in the corpus — confirmed directly on `developer.apple.com` as `macOS 12.0–26.5 Deprecated`;
   cite `https://developer.apple.com/documentation/swiftui/tablestyle/inset(alternatesrowbackgrounds:)`.
3. **Scene-sizing depth** (`defaultSize`/`windowResizability`) is `scenes-windows`' to own — verify the
   floor here, defer the depth there.

---

## A. SwiftUI layout / Table / sizing symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`). Floors
are the reconciled truth in `floors-master.md` — never restate them here.

| Symbol | Path |
|---|---|
| `frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)` | `view/frame(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:alignment:)` |
| `Table` / `TableColumn` / `TableRow` | `table` · `tablecolumn` · `tablerow` |
| `TableColumnForEach` | `tablecolumnforeach` |
| `KeyPathComparator` (Foundation) | `documentation/foundation/keypathcomparator` |
| `tableStyle(_:)` (case `.inset(alternatesRowBackgrounds:)` **deprecated 26.5**) | `view/tablestyle(_:)` |
| `alternatingRowBackgrounds(_:)` (macOS 14.0+, macOS-only) | `view/alternatingrowbackgrounds(_:)` |
| `controlSize(_:)` / `ControlSize` | `view/controlsize(_:)` · `controlsize` |
| `fixedSize()` / `fixedSize(horizontal:vertical:)` | `view/fixedsize()` · `view/fixedsize(horizontal:vertical:)` |
| `layoutPriority(_:)` | `view/layoutpriority(_:)` |
| `containerRelativeFrame(_:alignment:)` | `view/containerrelativeframe(_:alignment:)` |
| `Layout` (protocol) / `Grid` / `GridRow` / `ViewThatFits` | `layout` · `grid` · `gridrow` · `viewthatfits` |
| `defaultSize(_:)` / `windowResizability(_:)` (**owned by scenes-windows**) | `scene/defaultsize(_:)` · `scene/windowresizability(_:)` |

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| Tables (HIG) | `design/human-interface-guidelines/tables` (verify exact path against current HIG) | column/sort/selection conventions; the Mac data-grid look |
| Windows (HIG) | `design/human-interface-guidelines/windows` | resizable-window expectations; min/default sizing intent |
| Layout fundamentals | `documentation/swiftui/layout-fundamentals` | frame, priority, fixedSize, custom `Layout` overview |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2022/10056 | Compose custom layouts with SwiftUI | the `Layout` protocol, `Grid`, `ViewThatFits` (when to hand-roll vs built-in) |
| wwdc2021/10062 | SwiftUI on the Mac: Build the fundamentals | `Table`, multi-column sort, window sizing on the Mac |
| wwdc2021/10289 | SwiftUI on the Mac: The finishing touches | `Table` sorting wiring, selection, density |

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| createwithswift.com | `createwithswift.com/understanding-scenes-for-your-macos-app/` | scene/window sizing modifiers on macOS | medium |
| Majid Jabrayilov | `swiftwithmajid.com/2022/06/22/building-custom-layout-in-swiftui/` | the custom `Layout` protocol (lt-08) | high |
| Sarunw | `sarunw.com/posts/swiftui-table/` | `Table`/`TableColumn`/`sortOrder` wiring on macOS | medium |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- Practice corpus contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
