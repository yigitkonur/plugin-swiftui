# Reference — Keyboard Shortcuts: Placement & Reserved-Shortcut Conflicts

`keyboardShortcut` is cross-platform but *central* on macOS. Two defects: a shortcut on a buried
in-window button instead of a menu item (menu-04 — it fires only while focused and renders nothing in
the menu bar), and a shortcut that collides with a system-reserved combination (menu-09). Floor
*values* live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## menu-04 — shortcut on an in-window button instead of a menu item

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

`keyboardShortcut` only fires when its control is within the focused scene. The discoverable,
always-available home for an app-wide shortcut is the menu bar — and a shortcut on a real menu item
also *displays* its key equivalent, which a buried button never does. (A deliberately view-local
shortcut — e.g. a focus-cycling key inside one view — is legitimate; READ to distinguish intent from
defect. The structural lint rule already excludes shortcuts that ARE inside `.commands` /
`CommandMenu` / `CommandGroup`.)

`swiftui-ctx lookup keyboardShortcut` (accessed 2026-06-07): consensus split `(_, modifiers)` 50% /
`(_)` 50%; `co_occurs_with` `CommandMenu` and `FocusedValue` — i.e. real apps place the shortcut on the
command, alongside the focused-value route. `recommended` example: `sindresorhus/Gifski`
`Utilities.swift` (`min_macos: 26`). Put the consensus shape in a finding's `## Correct`, the permalink
in `## Source`. `.saveItem` and the other placements are in `commands-structure.md`.

---

## menu-09 — reserved-shortcut conflicts

macOS reserves a set of system-wide combinations; an app must never bind them to its own command.
Overriding ⌘Q, ⌘H, ⌘, , or ⌘Space breaks deeply-ingrained user muscle memory and (for ⌘Space) the
shortcut is intercepted by the system before the app ever sees it.

| Reserved | System role | What to do instead |
|---|---|---|
| ⌘Q | Quit (App ▸ Quit, `.appTermination`) | never rebind; Quit is system-managed |
| ⌘H | Hide (App ▸ Hide, `.appVisibility`) | never rebind |
| ⌘, (comma) | Settings… (App ▸ Settings, `.appSettings`) | use the `Settings { }` scene; never rebind ⌘, to a custom action |
| ⌘Space | Spotlight (system) | intercepted by the system — your binding never fires; pick another key |
| ⌘Tab / ⌘` | app / window switcher (system) | never rebind |

```swift
// ❌ WRONG — hijacks Settings (⌘,) and Quit (⌘Q)
Button("Preferences") { openCustomPrefs() }.keyboardShortcut(",", modifiers: .command)
Button("Close App")   { quit() }.keyboardShortcut("q", modifiers: .command)
```

```swift
// ✅ CORRECT — use the standard Settings scene for ⌘,; leave Quit to the system
Settings { SettingsView() }            // gives App ▸ Settings… ⌘, automatically
// (no manual ⌘Q binding — App ▸ Quit is system-managed via .appTermination)
```

menu-09 is **advisory** (the build compiles; it is a HIG / muscle-memory defect). The reserved set is
Apple-HIG / Apple-Support fact, not a SwiftUI symbol floor — cite the HIG page, not a symbol doc. ⌘W
(Close), ⌘M (Minimize), ⌘N (New), ⌘S (Save), ⌘O (Open) are standard *menu* shortcuts you should keep on
the matching `CommandGroupPlacement` rather than reinvent — re-binding them to an unrelated action is
also menu-09.

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07):
  `/documentation/swiftui/view/keyboardshortcut(_:modifiers:)` (*"Defines a keyboard shortcut and
  assigns it to the modified control."* `macOS 11.0+`; `func keyboardShortcut(_ key: KeyEquivalent,
  modifiers: EventModifiers = .command) -> some View`). Path + protocol in `source-directory.md` +
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- Practice — `swiftui-ctx lookup keyboardShortcut` (consensus `(_, modifiers)` 50% / `(_)` 50%;
  `co_occurs_with` CommandMenu/FocusedValue; `recommended` `sindresorhus/Gifski` `Utilities.swift`,
  min_macos 26), accessed 2026-06-07
  (`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`).
- Apple HIG — Menus / The menu bar; Apple Support — "Mac keyboard shortcuts" (reserved combinations,
  item order, ellipsis rules), accessed 2026-06-07.
