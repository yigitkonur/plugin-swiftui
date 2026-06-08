# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any affordance whose
existence/shape/floor is < ~100% certain. **Always fetch Apple docs via Sosumi** — the shared fetch
protocol with the curl/CLI commands and the JSON-404 caveat is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the nativeness-specific *map*
of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the practice-shape CLI is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the affordance exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Cross-check `introduced_macos` from `swiftui-ctx lookup <api> --json` against floors-master.
2. **Need the canonical call SHAPE?** `swiftui-ctx lookup <api> --json` → `consensus` + `recommended`
   permalink is the source of truth for the ✅ in `## Correct` (never hand-assert it).
3. **Never `WebFetch` developer.apple.com**; fetch the human URL via `sosumi.ai/...` (it never 404s on a
   valid page).

---

## A. The affordance symbol map (the absences this skill measures)

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`). Floors
are the reconciled values in floors-master.

| Affordance (absence = smell) | Path | Floor |
|---|---|---|
| `onHover(perform:)` (nat-01) | `view/onhover(perform:)` | macOS 10.15+ |
| `onContinuousHover(coordinateSpace:perform:)` | `view/oncontinuoushover(coordinatespace:perform:)` | macOS 14.0+ |
| `pointerStyle(_:)` (nat-05) | `view/pointerstyle(_:)` | macOS 15.0+ (macOS-only) |
| `contextMenu(menuItems:)` (nat-04) | `view/contextmenu(menuitems:)` | macOS 10.15+ |
| `help(_:)` (nat-02) | `view/help(_:)` | macOS 11.0+ |
| `focusable(_:)` (nat-03) | `view/focusable(_:)` | macOS **12.0+** (not 10.15) |
| `formStyle(_:)` (nat-06) | `view/formstyle(_:)` | macOS 13.0+ (verify badge vs Xcode 26 SDK) |
| `controlSize(_:)` / `listStyle(_:)` (nat-07) | `view/controlsize(_:)` · `view/liststyle(_:)` | macOS 10.15+ / 10.15+ |
| `Table` (nat-08) | `table` | macOS 12.0+ |
| `defaultSize(_:)` / `windowResizability(_:)` (nat-10) | `scene/defaultsize(_:)` · `scene/windowresizability(_:)` | macOS 13.0+ |
| `NavigationSplitView` / `navigationTitle(_:)` (nat-11/12) | `navigationsplitview` · `view/navigationtitle(_:)` | macOS 13.0+ / 11.0+ |
| `Settings` / `SettingsLink` / `MenuBarExtra` (nat-14) | `settings` · `settingslink` · `menubarextra` | macOS 11.0 / 14.0 / 13.0+ |
| `commands(content:)` / `CommandMenu` (nat-13) | `scene/commands(content:)` · `commandmenu` | macOS 11.0+ |

**Deprecated / iOS-only names you flag and route (nat-11/12):** `NavigationView` (deprecated),
`navigationBarTitle`, `navigationBarTitleDisplayMode`, `navigationBarLeading/Trailing` (deprecated),
`topBarLeading/topBarTrailing` (**unavailable on macOS** — the owner skill confirms the compile error).

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| HIG — Designing for macOS | `design/human-interface-guidelines/designing-for-macos` | pointer, menu bar, windows, density expectations |
| HIG — The menu bar | `design/human-interface-guidelines/the-menu-bar` | what belongs in the main menu vs in-window (nat-13) |
| HIG — Pointing devices | `design/human-interface-guidelines/pointing-devices` | hover, cursor, right-click affordances (nat-01/04/05) |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2022/10074 | The SwiftUI cookbook for navigation | `NavigationSplitView` as the Mac shell (nat-11) |
| wwdc2020/10104 | Build a SwiftUI view for widgets / Mac idioms | menu bar, Settings, window sizing |
| wwdc2021/10058 | SwiftUI on the Mac: Build the fundamentals | Table, sidebar, toolbar, commands (nat-08/13) |

## D. Practitioners (corroboration only — never primary; label findings low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| SerialCoder.dev | `serialcoder.dev/text-tutorials/macos-tutorials/macos-programming-implementing-a-focusable-text-field-in-swiftui/` | `focusable`/`@FocusState` on macOS (nat-03) | medium |
| Majid Jabrayilov | `swiftwithmajid.com/2021/04/14/mastering-toolbars-in-swiftui/` | toolbar placements (nat-12) | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Floors re-confirmed against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` the same day;
  practitioner URLs as listed (corroboration only).
