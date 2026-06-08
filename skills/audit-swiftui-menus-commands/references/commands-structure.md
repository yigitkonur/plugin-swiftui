# Reference — Commands Structure: `.commands`, `CommandMenu` vs `CommandGroup`, Placements

The structural spine of this skill: where app actions belong (`.commands` on a scene, never in-window
buttons), when to add a *new* top-level menu (`CommandMenu`) versus slot into Apple's standard menus
(`CommandGroup(after:/before:/replacing: .placement)`), and the built-in `Commands` conformers that
replace hand-rolled Help/Sidebar/Toolbar menus. Floor *values* are not restated here — they live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. This file carries the structure, the
placement table, and the ❌→✅ rewrites for menu-01/02/05/06.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## Why AI gets this wrong

iOS-default training bias. The iPhone has no persistent menu bar, so the model has few `.commands { }`
examples at `App.body` level; its highest-probability answer to "add an Export action" is an in-window
`Button`. And because it knows `CommandMenu` exists, it reaches for `CommandMenu("File")` — which makes
a *second* File menu — instead of `CommandGroup(after: .importExport)`. The mental model to enforce:
**app-level actions belong in the menu bar, attached to a scene with `.commands { }`. `CommandMenu`
adds a brand-new top-level menu; `CommandGroup(replacing:/after:/before:)` slots into or overrides
Apple's standard menus via a `CommandGroupPlacement`.**

---

## menu-01 — menu actions faked as in-window buttons (no `.commands` at all)

The single most common failure: the menu bar is omitted entirely and "menu" actions become a button
row inside the window. This is a **whole-app** judgment — confirm there is no `.commands { }` anywhere
in the `App` body, not just on one line.

```swift
// ❌ WRONG — "menu" actions live as a button row inside the window
struct ContentView: View {
    var body: some View {
        HStack {
            Button("Export…") { export() }
            Button("Import…") { performImport() }
        }
    }
}
```

```swift
// ✅ CORRECT — real File ▸ Export…, discoverable, with a standard placement + shortcut
WindowGroup { ContentView() }
    .commands {
        CommandGroup(after: .importExport) {
            Button("Export…") { export() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
```

Mac users expect these in the menu bar, discoverable, with standard placement and a shown shortcut.
In-window buttons are non-native and miss the entire menu system. (A *toolbar* button that should be a
menu action is the seam to `audit-swiftui-navigation-toolbars` — `cross_ref` it.)

---

## menu-02 — a whole `CommandMenu("File")` duplicating a standard menu

```swift
// ❌ WRONG — creates a SECOND "File" menu next to the real one
.commands {
    CommandMenu("File") {
        Button("New") { newDoc() }
    }
}
```

```swift
// ✅ CORRECT — slot into the standard File menu via a placement
.commands {
    CommandGroup(after: .newItem) {                 // add beside Apple's New
        Button("New From Template…") { newFromTemplate() }
    }
    CommandGroup(replacing: .newItem) {             // OR replace Apple's New entirely
        Button("New Document") { newDoc() }
            .keyboardShortcut("n")
    }
}
// Reserve CommandMenu for a genuinely NEW top-level menu:
.commands {
    CommandMenu("Tools") {
        Button("Run") { run() }.keyboardShortcut("r")
    }
}
```

`CommandMenu` *always* adds a new top-level menu (inserted between the built-in View and Window menus);
giving it an existing menu's name produces a duplicate. To add to or override a standard menu you must
target a `CommandGroupPlacement`. The corpus consensus for `CommandGroup` is `(replacing:)` 56% /
`(after:)` 37% — `replacing` is the dominant production shape (run `swiftui-ctx lookup CommandGroup`).

---

## menu-05 — can't replace or remove a built-in (duplicate About / New)

```swift
// ❌ WRONG — adds a second "About"; Apple's default still sits above it
.commands {
    CommandGroup(after: .appInfo) {
        Button("About MyApp") { showCustomAbout() }
    }
}
```

```swift
// ✅ CORRECT — replace the built-in; remove a group by replacing with an empty closure
.commands {
    CommandGroup(replacing: .appInfo) {
        Button("About MyApp") { showCustomAbout() }
    }
    CommandGroup(replacing: .newItem) { }   // removes Apple's New entirely
}
```

`CommandGroup(after: .appInfo)` leaves Apple's default About in place — two "About" entries.
`CommandGroup(replacing:)` overrides; an empty `replacing:` closure strips a built-in. (`after:` is
correct when you genuinely want an *additional* item, e.g. "New From Template…" beside Apple's New —
READ to tell intent from defect.)

---

## menu-06 — reinventing Help / Sidebar / Toolbar built-ins

```swift
// ❌ WRONG — hand-rolls a Help menu and a "Show Sidebar" toggle
.commands {
    CommandMenu("Help") {
        Button("MyApp Help") { openHelp() }
    }
    // …and a "Show Sidebar" toggle re-implemented under a hand-rolled View menu
}
```

```swift
// ✅ CORRECT — slot into the standard placements; use the built-in Commands conformers
.commands {
    CommandGroup(replacing: .help) {
        Button("MyApp Help") { openHelp() }
    }
    SidebarCommands()    // standard "Show/Hide Sidebar" (⌃⌘S)
    ToolbarCommands()    // standard "Show/Hide Toolbar", "Customize Toolbar…"
}
```

Hand-rolling duplicates system structure and loses standard ordering, the Help-menu search field, and
localization. `SidebarCommands()` / `ToolbarCommands()` are built-in `Commands` conformers — see the
floors in `command-api-availability.md`.

---

## Standard `CommandGroupPlacement` cases (the slots `replacing:/after:/before:` target)

`CommandGroupPlacement` is `macOS 11.0+`; all cases below are `macOS 11.0+` **except `.singleWindowList`,
which is `macOS 13.0+`** (see `command-api-availability.md`).

| Placement | Standard menu / role |
|---|---|
| `.appInfo` | App ▸ About |
| `.appSettings` | App ▸ Settings… |
| `.appVisibility` | App ▸ Hide / Hide Others / Show All |
| `.systemServices` | App ▸ Services submenu |
| `.appTermination` | App ▸ Quit |
| `.newItem` | File ▸ New / Open / Open Recent |
| `.saveItem` | File ▸ Save / Save As / Revert |
| `.importExport` | File ▸ Import / Export |
| `.printItem` | File ▸ Page Setup / Print |
| `.undoRedo` | Edit ▸ Undo / Redo |
| `.pasteboard` | Edit ▸ Cut / Copy / Paste / Delete / Select All |
| `.textEditing` | Edit ▸ Find / spelling / substitutions |
| `.textFormatting` | Format ▸ font / text |
| `.sidebar` | View ▸ Show/Hide Sidebar |
| `.toolbar` | View ▸ Show/Hide & Customize Toolbar |
| `.windowList` | Window ▸ list of the app's open windows |
| `.singleWindowList` | Window ▸ commands that describe and reveal windows the app defines (`macOS 13.0+`) |
| `.windowArrangement` | Window ▸ arrangement (Bring All to Front, etc.) |
| `.windowSize` | Window ▸ size / zoom |
| `.help` | Help menu — search field is system-provided, not removable |

Companion built-in `Commands` conformers (drop into `.commands { }` directly, no placement needed):
`SidebarCommands()` · `ToolbarCommands()` · `TextEditingCommands()` · `TextFormattingCommands()` ·
`EmptyCommands()` (all macOS 11.0+) · `ImportFromDevicesCommands()` (macOS 12.0+, Continuity-Camera) ·
`InspectorCommands()` (macOS 14.0+). Floors: `command-api-availability.md`.

---

## The canonical `.commands` skeleton (quote verbatim)

The shape to put in a finding's `## Correct`. The ✅ in a finding is **not** this static snippet alone —
back it with a real macOS-26 example fetched live: `swiftui-ctx lookup CommandMenu` recommends
`tahseen-kakar/harbor` `DownloadCommands.swift` (a genuine new top menu, `min_macos: 26`),
`swiftui-ctx lookup CommandGroup` recommends `sindresorhus/Gifski` `App.swift`. Put the consensus shape
here and the permalink in `## Source`.

```swift
// 1. Publish focused state from the active view (see focused-routing.md for @FocusedValue)
extension FocusedValues {
    @Entry var document: Binding<Document>? = nil   // @Entry: macOS 10.15+, back-deploys
}

struct EditorView: View {
    @State private var doc = Document()
    var body: some View {
        DocumentBody(document: $doc)
            .focusedValue(\.document, $doc)   // expose to the menu
    }
}

// 2. Build the menus
struct AppCommands: Commands {
    @FocusedValue(\.document) private var document
    var body: some Commands {
        CommandGroup(after: .newItem) {                 // extend a standard menu
            Button("New From Template…") { /* … */ }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .appInfo) {             // replace a built-in
            Button("About MyApp") { /* … */ }
        }
        CommandMenu("Document") {                        // a brand-new top menu, acting on the focused doc
            Button("Rename…") { document?.wrappedValue.beginRename() }
                .keyboardShortcut("r")
                .disabled(document == nil)              // ← load-bearing
        }
        SidebarCommands()                               // standard system groups
        ToolbarCommands()
    }
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { EditorView() }
            .commands { AppCommands() }
    }
}
```

**Rules:** (a) app actions → `.commands`, never in-window buttons. (b) Add to / override Apple's menus →
`CommandGroup(after:/before:/replacing: .placement)`; only a *new* top menu → `CommandMenu`. (c)
Commands reach the active window via `@FocusedValue` + `.focusedValue`, guarded with
`.disabled(value == nil)` (see `focused-routing.md`). (d) Shortcuts live on menu items so they render
their key equivalent (see `shortcuts-and-reserved.md`).

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07): `/documentation/swiftui/commandmenu` (*"inserted
  between the built-in View and Window menus"*), `/documentation/swiftui/commandgroupplacement`,
  `/documentation/swiftui/commandgroup`, `/documentation/swiftui/sidebarcommands`,
  `/documentation/swiftui/toolbarcommands`. Paths + protocol in `source-directory.md` +
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- Practice — `swiftui-ctx lookup CommandMenu` / `CommandGroup` (consensus `(replacing:)` 56% / `(after:)`
  37%; `recommended` permalinks `tahseen-kakar/harbor` + `sindresorhus/Gifski`, min_macos 26), accessed
  2026-06-07 (`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`).
- https://fatbobman.com/en/posts/swiftui2-commands/ — `.commands`/`CommandMenu`/`CommandGroup` usage
  (practitioner). https://serialcoder.dev/text-tutorials/swiftui/working-with-the-main-menu-in-swiftui/
  — `CommandGroup(replacing:)`/`(after:)`, removing items via empty closure (practitioner).
