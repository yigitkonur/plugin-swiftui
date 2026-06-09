# Reference — Focused Command Routing: `@FocusedValue`, `.disabled(value == nil)`, `@FocusedDocument`

The deepest macOS-only trap in this domain: a menu is *global* and lives outside any window, so a
command closure can't close over a view's `@State` — it must reach the active window's data through
`@FocusedValue` / `@FocusedBinding`, and disable itself when nothing is focused. This file carries
menu-03 (wrong state route), menu-07 (missing `.disabled`), and menu-08 (the hallucinated
`@FocusedDocument`). Floor *values* live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the canonical invented-name list lives in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## The command-to-state gap (menu-03)

The menu is declared at `App` level, not inside a window. Closing over one view's `@State` is
impossible to express there, and in a multi-window app would target the wrong window even if it
compiled. The documented bridge is `@FocusedValue` (read-only value) / `@FocusedBinding` (mutable
binding shorthand that unwraps the optional for you).

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
                .disabled(note == nil)          // ← the load-bearing line (menu-07)
        }
    }
}
```

`swiftui-ctx lookup CommandMenu` confirms this is the real production idiom — `CommandMenu`
`co_occurs_with` `FocusedValue` / `focusedValue` / `FocusedObject` in the corpus; `swiftui-ctx lookup
focusedValue` shows the dominant shape is `focusedValue(_, _)` (94%). The menu-03 finding is **warning**
when the closure references a concrete `@State`/model directly (it targets the wrong window in a
multi-window app; in the narrower case of a direct @State property reference across the App/Scene
boundary it is also a compile error); READ the closure to confirm it reaches `@FocusedValue`, not a captured instance.

---

## The `@Entry` shorthand (macOS 10.15+, back-deploys)

The 3-part `FocusedValueKey` struct + `get`/`set` extension collapses to one line with the `@Entry`
macro:

```swift
extension FocusedValues {
    @Entry var selectedNote: Binding<Note>? = nil
}
```

Same call sites (`.focusedValue(\.selectedNote, $note)` / `@FocusedValue(\.selectedNote)`). `@Entry`
back-deploys to **macOS 10.15** (per floors-master) but requires the **Xcode 15+ / Swift 5.9+**
toolchain to *expand the macro* — a build-environment fact, not a runtime floor, so carry it as
advisory context, never a hard finding. `@Entry` is the default on current SDKs. (SEAM: an `@Entry` /
`FocusedValueKey` co-located with a `CommandMenu`/`CommandGroup` is **this skill's**; one in a
preview/general environment setup is `audit-swiftui-previews`' — `cross_ref` it.)

---

## Missing `.disabled(focusedValue == nil)` (menu-07)

```swift
// ❌ WRONG — no guard; the item is always enabled and fires against nothing / the wrong window
CommandMenu("Note") {
    Button("Toggle Bold") { note?.wrappedValue.isBold.toggle() }
        .keyboardShortcut("b")
}
```

```swift
// ✅ CORRECT — the guard greys the item out when no document is focused
Button("Toggle Bold") { note?.wrappedValue.isBold.toggle() }
    .keyboardShortcut("b")
    .disabled(note == nil)
```

The `.disabled(value == nil)` is mandatory for any command that acts on a focused document — without
it the command fires when nothing is focused, or against the wrong window in a multi-window app. A
command that reads a `@FocusedValue` but never disables on `nil` is menu-07.

---

## `@FocusedDocument` is hallucinated (menu-08)

```swift
// ❌ WRONG — @FocusedDocument is not a real Apple symbol
struct DocCommands: Commands {
    @FocusedDocument var document   // does not exist
    var body: some Commands { … }
}
```

```swift
// ✅ CORRECT — a custom FocusedValues key (the real mechanism)
extension FocusedValues {
    @Entry var document: Binding<MyDocument>? = nil
}
struct DocCommands: Commands {
    @FocusedValue(\.document) private var document
    var body: some Commands { … }
}
```

**`@FocusedDocument` is not a real Apple symbol** (per the shared hallucination-blacklist). The real
mechanism is a custom `FocusedValues` key via `@Entry` / `FocusedValueKey` + `@FocusedValue(\.key)`.
This is corroborated by practice: `swiftui-ctx lookup FocusedDocument` exits **3** ("no usage found for
'FocusedDocument'", `suggestion: did you mean: focusedObject, FocusedObject, openDocument, focusedValue,
FocusedValue?`) — no shipping macOS app uses the symbol, the strongest "this API does not exist" signal.
This is a **hard-fail** (build break). Note: **`@FocusedBinding` *does* exist** — verify the *key* it
references exists before flagging anything around it.

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07): `/documentation/swiftui/focusedvalue`,
  `/documentation/swiftui/focusedvalues/entry()`. Paths + protocol in `source-directory.md` +
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- Practice — `swiftui-ctx lookup CommandMenu` (`co_occurs_with` FocusedValue/focusedValue),
  `swiftui-ctx lookup focusedValue` (shape `(_, _)` 94%), `swiftui-ctx lookup FocusedDocument` (**exit
  3**, did-you-mean suggestion) — accessed 2026-06-07
  (`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`). `@FocusedDocument` non-existence
  is the shared `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`.
- https://troz.net/post/2025/mac_menu_data/ — "The Mac Menubar and SwiftUI" (2025): the `@FocusedValue`
  command-routing + `.disabled(value == nil)` pattern (practitioner, high).
