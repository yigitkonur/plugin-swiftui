# Menus, Commands & Keyboard (macOS)

> **Scope: macOS only.** The persistent system menu bar has no iOS analogue, so this whole domain is a Mac reality. iPad / Catalyst surface `.commands` for hardware-keyboard menus, but the always-visible menu bar — and the `@FocusedValue` indirection it forces — is unique to the Mac. `.keyboardShortcut` is cross-platform but is *central* here.
>
> **Why AI gets this wrong:** iOS-default training bias. The iPhone has no menu bar, so the model has almost no examples of `.commands { }` at `App.body` level; its highest-probability answer to "add an Export action" is an in-window `Button`. Two structural traps follow: the **command-to-state gap** (a menu lives outside any window, so a closure can't close over a view's `@State` — it must reach the focused window via `@FocusedValue`) and **extend-don't-replace** (macOS already ships File/Edit/View/Window/Help; the correct move is surgical insertion via `CommandGroup(after:)`, not a parallel `CommandMenu("File")`).
>
> **The model:** app-level actions belong in the menu bar, attached to a scene with `.commands { }`. `CommandMenu` adds a *brand-new* top-level menu; `CommandGroup(replacing:/after:/before:)` slots into or overrides Apple's *standard* menus via a `CommandGroupPlacement`. A command reaches the active window's data through `@FocusedValue` / `@FocusedBinding`, disabling itself with `.disabled(value == nil)`. Shortcuts live on menu items so they both *fire* and *render* their key equivalent.

---

## The 6 mistakes (❌ WRONG / ✅ CORRECT)

### 1. Menu actions faked as in-window buttons — no `.commands` at all

The single most common failure: the menu bar is omitted entirely and "menu" actions become a button row inside the window.

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

Mac users expect these in the menu bar (File ▸ Export…), discoverable, with standard placement and a shown shortcut. In-window buttons are non-native and miss the entire menu system.

### 2. A whole `CommandMenu("File")` duplicating a standard menu instead of extending it

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

`CommandMenu` *always* adds a new top-level menu (inserted between the built-in View and Window menus); giving it an existing menu's name produces a duplicate. To add to or override a standard menu you must target a `CommandGroupPlacement`.

### 3. Menu command can't reach the active window's state — the `@FocusedValue` command-routing rule

This is the deepest macOS-only trap. The menu is global; closing over one view's `@State` is impossible (the menu is declared at app level) and would target the wrong window in a multi-window app.

```swift
// ❌ WRONG — the command closure has no handle on the focused document
CommandMenu("Note") {
    Button("Bold") { /* which note? no reference exists here */ }
}
```

```swift
// ✅ CORRECT — publish from the focused view, read with @FocusedValue, disable when nil
struct SelectedNoteKey: FocusedValueKey { typealias Value = Binding<Note> }
extension FocusedValues {
    var selectedNote: Binding<Note>? {
        get { self[SelectedNoteKey.self] }
        set { self[SelectedNoteKey.self] = newValue }
    }
}

// in the focused view — expose the binding to the menu:
NoteEditor(note: $note)
    .focusedValue(\.selectedNote, $note)

// in .commands — read it and auto-grey when nothing is focused:
struct NoteCommands: Commands {
    @FocusedValue(\.selectedNote) private var note
    var body: some Commands {
        CommandMenu("Note") {
            Button("Toggle Bold") { note?.wrappedValue.isBold.toggle() }
                .keyboardShortcut("b")
                .disabled(note == nil)          // ← the load-bearing line
        }
    }
}
```

`@FocusedValue` (read-only value) / `@FocusedBinding` (mutable binding shorthand that unwraps the optional for you) are the documented bridge between a global menu and the active window's data. The `.disabled(note == nil)` is mandatory — without it the command fires against nothing or the wrong window.

**`@Entry` shorthand (`macOS 10.15+`, back-deploys; requires Xcode 15+ / Swift 5.9+ toolchain to expand the macro).** The 3-part `FocusedValueKey` struct + `get`/`set` extension above collapses to one line with the `@Entry` macro:

```swift
extension FocusedValues {
    @Entry var selectedNote: Binding<Note>? = nil
}
```

Same call sites (`.focusedValue(\.selectedNote, $note)` / `@FocusedValue(\.selectedNote)`). The `@Entry` macro back-deploys to macOS 10.15 but requires the Xcode 15+ (Swift 5.9+) toolchain to expand; `@Entry` is the default on current SDKs.

### 4. `.keyboardShortcut` on an in-window button instead of a menu item

```swift
// ❌ WRONG — shortcut on a buried button, expected to behave like a global ⌘S
struct EditorView: View {
    var body: some View {
        TextEditor(text: $text)
        Button("Save") { save() }
            .keyboardShortcut("s")              // fires only while this view is focused; shows nothing in the menu
    }
}
```

```swift
// ✅ CORRECT — the action lives in .commands; the shortcut renders "⌘S" in the menu bar
.commands {
    CommandGroup(replacing: .saveItem) {
        Button("Save") { save() }
            .keyboardShortcut("s", modifiers: .command)   // displays ⌘S in File menu
    }
}
```

`keyboardShortcut` only fires when its control is within the focused scene. The discoverable, always-available home for app shortcuts is the menu bar — and a shortcut on a real menu item also *displays* its key equivalent, which a buried button never does. (`.saveItem` is a standard `CommandGroupPlacement`, `macOS 11.0+` — see the placement table below.)

### 5. Can't replace or remove a built-in item (duplicate About / New)

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

Adding parallel items leaves Apple's defaults in place — two "About" / "New" entries with conflicting behavior. `CommandGroup(replacing:)` is how you override or strip a built-in.

### 6. Reinventing Help / Sidebar / Toolbar built-ins from scratch

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

Hand-rolling duplicates system structure and loses standard ordering, the Help-menu search field, and localization. `SidebarCommands()` / `ToolbarCommands()` are built-in `Commands` conformers, both `macOS 11.0+`.

---

## Standard `CommandGroupPlacement` cases

The slots `CommandGroup(replacing:/after:/before:)` can target. `CommandGroupPlacement` is `macOS 11.0+`; every case below is confirmed to exist (developer.apple.com). All are `macOS 11.0+` **except `.singleWindowList`, which is `macOS 13.0+`**.

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

Companion built-in `Commands` conformers (drop into `.commands { }` directly, no placement needed): `SidebarCommands()`, `ToolbarCommands()`, `TextEditingCommands()`, `TextFormattingCommands()` are `macOS 11.0+`; `ImportFromDevicesCommands()` (Continuity Camera "Import from iPhone/iPad", macOS-only) is `macOS 12.0+`; `InspectorCommands()` (standard "Show/Hide Inspector" toggle, ⌃⌘I) is `macOS 14.0+`; `EmptyCommands()` is `macOS 11.0+`.

---

## Detection tells

Grep-able signals that this domain is broken:

- A scene (`WindowGroup` / `Window`) with **no `.commands { }` anywhere in the app** → menu bar faked as in-window buttons (mistake 1).
- `CommandMenu("File"|"Edit"|"View"|"Window"|"Help")` — a `CommandMenu` whose title matches a *standard* menu → should be `CommandGroup(… : .somePlacement)` (mistake 2).
- A `CommandMenu` / `CommandGroup` closure that **references a concrete `@State` / model instance directly** instead of `@FocusedValue` → wrong-window or won't-compile bug (mistake 3).
- `.keyboardShortcut(` on a `Button` that is **not inside `.commands { }`** and is expected to be app-global → misplaced shortcut, renders nothing in the menu (mistake 4).
- **Two "About" / "New" / "Help" entries**, or a hand-rolled Help / Sidebar menu → missing `CommandGroup(replacing:)` / `SidebarCommands()` / `ToolbarCommands()` (mistakes 5, 6).
- **No `.disabled(focusedValue == nil)`** on a command that needs a focused document → menu item acts on nothing / the wrong window (mistake 3).

---

## Canonical pattern

The `.commands` skeleton to quote verbatim — focused-state publishing, standard-menu extension, a replace, a new top menu acting on the focused document, and the built-in groups:

```swift
// 1. Publish focused state from the active view
struct DocumentKey: FocusedValueKey { typealias Value = Binding<Document> }
extension FocusedValues {
    var document: Binding<Document>? {
        get { self[DocumentKey.self] }
        set { self[DocumentKey.self] = newValue }
    }
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
        // extend a standard menu
        CommandGroup(after: .newItem) {
            Button("New From Template…") { /* … */ }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        // replace a built-in
        CommandGroup(replacing: .appInfo) {
            Button("About MyApp") { /* … */ }
        }
        // a brand-new top-level menu, acting on the focused document
        CommandMenu("Document") {
            Button("Rename…") { document?.wrappedValue.beginRename() }
                .keyboardShortcut("r")
                .disabled(document == nil)
        }
        // standard system groups
        SidebarCommands()
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

**Rules:** (a) app actions → `.commands`, never in-window buttons. (b) Adding to / overriding Apple's menus → `CommandGroup(after:/before:/replacing: .placement)`; only a *new* top menu → `CommandMenu`. (c) Commands reach the active window via `@FocusedValue` + `.focusedValue`, guarded with `.disabled(value == nil)`. (d) Shortcuts live on menu items so they render their key equivalent. (e) Respect reserved shortcuts — never override ⌘Q, ⌘H, ⌘, , ⌘Space, ⌘Tab.

---

## Per-scene command overrides (`macOS 13.0+`)

`.commands` applies app-wide. To tune the menus of *one* scene — typically a secondary `Window` or `Settings` that should not carry the main window's File/Edit verbs — use the two scene modifiers (both `macOS 13.0+`):

```swift
var body: some Scene {
    WindowGroup { ContentView() }
        .commands { AppCommands() }

    // A secondary utility window with NO inherited menu commands:
    Window("Inspector", id: "inspector") { InspectorView() }
        .commandsRemoved()                         // strip all menu commands from this scene

    // Or fully override one scene's commands instead of stripping:
    Window("Console", id: "console") { ConsoleView() }
        .commandsReplaced { ConsoleCommands() }    // replace this scene's commands wholesale
}
```

`commandsRemoved()` suppresses a scene's menu commands; `commandsReplaced(content:)` substitutes a new `Commands` set for them. Both are scene modifiers (not view modifiers): `macOS 13.0+`, `iOS 16.0+`.

---

## Sources

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/commandgroupplacement | `macOS 11.0+`. All standard cases confirmed to exist (`.appInfo` / `.appSettings` / `.appVisibility` / `.systemServices` / `.appTermination` / `.newItem` / `.saveItem` / `.importExport` / `.printItem` / `.undoRedo` / `.pasteboard` / `.textEditing` / `.textFormatting` / `.sidebar` / `.toolbar` / `.windowList` / `.windowArrangement` / `.windowSize` / `.help`, all `macOS 11.0+`); `.singleWindowList` is `macOS 13.0+` — *"commands that describe and reveal windows the app defines."* | high |
| https://developer.apple.com/documentation/swiftui/commandmenu | *"Command menus are realized as menu bar menus on macOS, inserted between the built-in View and Window menus."* `macOS 11.0+` | high |
| https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:) | *"Defines a keyboard shortcut and assigns it to the modified control."* `macOS 11.0+`; `func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View` | high |
| https://developer.apple.com/documentation/swiftui/focusedvalue | `@FocusedValue` / `FocusedValueKey` / `.focusedValue` — the Mac menu↔window bridge, `macOS 11.0+` | high |
| https://developer.apple.com/documentation/swiftui/focusedvalues/entry() | `@Entry` macro on a `FocusedValues` extension — one-line replacement for the `FocusedValueKey` + `get`/`set` boilerplate; `macOS 10.15+` (back-deploys; requires Xcode 15+ / Swift 5.9+ toolchain to expand) | high |
| https://developer.apple.com/documentation/swiftui/scene/commandsremoved() | `commandsRemoved()` — *"Removes all commands defined by the modified scene."* Scene modifier, `macOS 13.0+`, `iOS 16.0+` | high |
| https://developer.apple.com/documentation/swiftui/scene/commandsreplaced(content:) | `commandsReplaced(content:)` — replaces the modified scene's commands with the supplied `Commands`. Scene modifier, `macOS 13.0+`, `iOS 16.0+` | high |
| https://developer.apple.com/documentation/swiftui/importfromdevicescommands | `ImportFromDevicesCommands()` — Continuity Camera "Import from iPhone/iPad" group (macOS-only), `macOS 12.0+` | high |
| https://developer.apple.com/documentation/swiftui/inspectorcommands | `InspectorCommands()` — standard "Show/Hide Inspector" toggle (⌃⌘I), `macOS 14.0+` | high |
| https://troz.net/post/2025/mac_menu_data/ | "The Mac Menubar and SwiftUI" (2025) — `@FocusedValue` command-routing and `.disabled(value == nil)` pattern | high (practitioner) |
| https://fatbobman.com/en/posts/swiftui2-commands/ | "SwiftUI 2.0 — Commands (macOS Menu)" — `.commands` / `CommandMenu` / `CommandGroup` usage | high (practitioner) |
| https://serialcoder.dev/text-tutorials/swiftui/working-with-the-main-menu-in-swiftui/ | "Working with the Main Menu in SwiftUI" — `CommandGroup(replacing:)` / `(after:)`, removing items via empty closure | high (practitioner) |
| Apple HIG — Menus / The menu bar; Apple Support — Mac keyboard shortcuts (March 2026) | standard menu contents, item order, reserved shortcuts, ellipsis rules | high |
