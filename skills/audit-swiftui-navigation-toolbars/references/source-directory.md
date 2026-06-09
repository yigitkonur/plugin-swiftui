# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
navigation/toolbar claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the
curl/CLI commands and the JSON-404 caveat is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the navigation-specific *map*
of which pages to fetch. **The practice half is `swiftui-ctx`** — run `lookup <api> --json` /
`deprecated <api>` per `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Floor values
live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Spec — does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. A placement *absent* from the macOS arm = `macOS ABSENT` (replace, never gate — nav-05).
2. **Practice — how do shipping Mac apps write it + is it deprecated-in-the-wild?**
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` → `consensus` (the canonical
   shape), `deprecated`+`migrate_to`/`replacement`, `recommended` permalink, `introduced_macos`,
   `co_occurs_with`. A `lookup` **exit 3** corroborates a platform-wrong / invented-placement finding.
3. **Type-property floors** can inherit the enclosing type's floor in DocC — cross-check against WWDC
   provenance per the shared sosumi reference §4.

---

## A. SwiftUI navigation/toolbar symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`). Floor
values are reconciled in `floors-master.md`.

| Symbol | Path | macOS |
|---|---|---|
| `NavigationSplitView` | `navigationsplitview` | 13.0+ |
| `NavigationSplitViewVisibility` | `navigationsplitviewvisibility` | 13.0+ |
| `NavigationStack` | `navigationstack` | 13.0+ |
| `NavigationView` (deprecated) | `navigationview` | 10.15+ → 26.5 dep. |
| `navigationSplitViewColumnWidth(min:ideal:max:)` | `view/navigationsplitviewcolumnwidth(min:ideal:max:)` | 13.0+ (no-op on detail: verify-SDK) |
| `navigationTitle(_:)` | `view/navigationtitle(_:)-43srq` | 11.0+ |
| `navigationSubtitle(_:)` | `view/navigationsubtitle(_:)` | 11.0+ (iOS 26.0) |
| `ToolbarItemPlacement` | `toolbaritemplacement` | — |
| `ToolbarItemPlacement.primaryAction` (leading edge on macOS) | `toolbaritemplacement/primaryaction` | 11.0+ |
| `ToolbarItemPlacement.topBarLeading` / `.topBarTrailing` | `toolbaritemplacement/topbarleading` | **macOS ABSENT** |
| `ToolbarSpacer` / `SpacerSizing` | `toolbarspacer` · `spacersizing` | 26.0+ |
| `searchable(text:placement:prompt:)` | `view/searchable(text:placement:prompt:)-18a8f` | 12.0+ |
| `searchToolbarBehavior(_:)` (`.automatic` macOS-safe; `.minimize` iOS/iPadOS/Mac Catalyst/visionOS only) | `view/searchtoolbarbehavior(_:)` | 26.0+ |
| `inspector(isPresented:content:)` / `inspectorColumnWidth(_:)` | `view/inspector(ispresented:content:)` | 14.0+ |
| `ContentUnavailableView` | `contentunavailableview` | 14.0+ |
| `SidebarListStyle` (`.sidebar`) | `sidebarliststyle` | 10.15+ |

**Platform-wrong / no-op (never emit on a Mac target → see `hallucination-blacklist.md` §5):**
`ToolbarItemPlacement.topBarLeading`/`.topBarTrailing` (macOS ABSENT → compile error),
`.navigationBarTitle`/`.navigationBarTitleDisplayMode` (+ `.inline`/`.large`, no-op). **Deprecated:**
`NavigationView`, `.navigationBarLeading`/`.navigationBarTrailing`.

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| Migrating to new navigation types | `documentation/swiftui/migrating-to-new-navigation-types` | `NavigationView` → split/stack; column semantics |
| HIG — The macOS sidebar | `design/human-interface-guidelines/the-macos-sidebar` (verify exact path) | persistent multi-column sidebar idiom |
| HIG — Toolbars | `design/human-interface-guidelines/toolbars` (verify exact path) | placement intent; defer chrome glass to `audit-swiftui-liquid-glass` |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<YYYY>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2022/10058 | The SwiftUI cookbook for navigation | `NavigationSplitView`/`NavigationStack` introduction, column model |
| wwdc2023/10161 | Inspectors in SwiftUI | `.inspector(isPresented:)`, 225 pt, compact → sheet |
| wwdc2025/256 | What's new in SwiftUI | `ToolbarSpacer`, `searchToolbarBehavior`, the new design system |

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Michael Sena | `msena.com/posts/three-column-swiftui-macos/` | `navigationSplitViewColumnWidth` no-op on detail; `HSplitView`/`NSSplitViewController` workaround | medium |
| Hacking with Swift | `hackingwithswift.com/quick-start/swiftui/how-to-create-a-two-column-or-three-column-layout-with-navigationsplitview` | 2-/3-column inits; compact auto-collapse | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- swiftui-ctx CLI contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
