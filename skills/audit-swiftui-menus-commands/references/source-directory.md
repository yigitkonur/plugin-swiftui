# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
menu/command/shortcut claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with
the curl/CLI commands and the JSON-404 caveat is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the menus-specific *map* of
which pages to fetch. The PRACTICE half (consensus shape + permalinked example) is `swiftui-ctx`
(`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`). Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi + swiftui-ctx references)

1. **Does the symbol exist + its macOS floor?** Practice first — `swiftui-ctx lookup <api> --json`
   (`introduced_macos`, `recommended` permalink; an **exit 3** with a did-you-mean `suggestion`
   corroborates a hallucination, e.g. `lookup FocusedDocument`). Spec — fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+`
   line. Cross-check both against `floors-master.md`. Never `WebFetch` `developer.apple.com`.
2. **The canonical shape for a fix's ✅?** `swiftui-ctx lookup <api>` `consensus` + `file <recommended.id>
   --smart` for the real enclosing `var body` (the permalink goes in `## Source`).
3. **Reserved-shortcut facts** are HIG / Apple-Support, not a SwiftUI symbol doc — cite the HIG page.

---

## A. SwiftUI menus / commands / focus symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`). Floors
per floors-master (re-confirmed 2026-06-07).

| Symbol | Path | Floor |
|---|---|---|
| `commands(content:)` (the scene modifier) | `scene/commands(content:)` | macOS 11.0+ |
| `CommandMenu` | `commandmenu` | macOS 11.0+ |
| `CommandGroup` | `commandgroup` | macOS 11.0+ |
| `CommandGroupPlacement` | `commandgroupplacement` | macOS 11.0+ (`.singleWindowList` 13.0+) |
| `keyboardShortcut(_:modifiers:)` | `view/keyboardshortcut(_:modifiers:)` | macOS 11.0+ |
| `KeyboardShortcut` / `KeyEquivalent` / `EventModifiers` | `keyboardshortcut` · `keyequivalent` · `eventmodifiers` | macOS 11.0+ |
| `FocusedValue` / `FocusedBinding` / `FocusedValueKey` | `focusedvalue` · `focusedbinding` · `focusedvaluekey` | macOS 11.0+ |
| `focusedValue(_:_:)` | `view/focusedvalue(_:_:)` | macOS 11.0+ |
| `@Entry` macro (on `FocusedValues`) | `focusedvalues/entry()` | macOS 10.15+ (Xcode 15+/Swift 5.9+ to expand) |
| `SidebarCommands` / `ToolbarCommands` | `sidebarcommands` · `toolbarcommands` | macOS 11.0+ |
| `TextEditingCommands` / `TextFormattingCommands` / `EmptyCommands` | `texteditingcommands` etc. | macOS 11.0+ |
| `ImportFromDevicesCommands` | `importfromdevicescommands` | macOS 12.0+ |
| `InspectorCommands` | `inspectorcommands` | macOS 14.0+ |
| `commandsRemoved()` / `commandsReplaced(content:)` | `scene/commandsremoved()` · `scene/commandsreplaced(content:)` | macOS 13.0+ |

**Absent from the index → hallucinated (never emit):** `@FocusedDocument` (use a custom `FocusedValues`
key — `swiftui-ctx lookup FocusedDocument` exits 3). **`@FocusedBinding` *does* exist** — verify the key
it references exists before flagging.

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| HIG — The menu bar | `design/human-interface-guidelines/the-menu-bar` | standard menu contents, item order |
| HIG — Menus | `design/human-interface-guidelines/menus` | ellipsis rules, item naming |
| Apple Support — Mac keyboard shortcuts | `support.apple.com/en-us/HT201236` | reserved combinations (⌘Q/⌘H/⌘,/⌘Space/⌘Tab) |
| Building and customizing the menu bar with SwiftUI | `documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui` | `.commands`, `CommandGroup` placements, replacing built-ins |

## C. WWDC sessions (`developer.apple.com/videos/play/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2020/10119 | Build a SwiftUI view for the macOS menu bar (Commands intro) | `.commands`, `CommandMenu`, `CommandGroup` |
| wwdc2021/10057 | Bring multiple windows to your SwiftUI app | scene commands, focused values across windows |

## D. Practitioners (corroboration only — never primary; label findings low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Troz (Sarah Reichelt) | `troz.net/post/2025/mac_menu_data/` | `@FocusedValue` routing + `.disabled(value == nil)` | high |
| Fatbobman | `fatbobman.com/en/posts/swiftui2-commands/` | `.commands`/`CommandMenu`/`CommandGroup` usage | high |
| SerialCoder | `serialcoder.dev/text-tutorials/swiftui/working-with-the-main-menu-in-swiftui/` | `CommandGroup(replacing:)`/`(after:)`, empty-closure removal | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practice layer: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` (`swiftui-ctx
  lookup`/`file --smart`), accessed 2026-06-07.
- Practitioner URLs as listed (trust labelled; corroboration only).
