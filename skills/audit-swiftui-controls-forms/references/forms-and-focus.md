# Reference — Grouped Form, Keyboard Focus & Tooltips (cf-01 · cf-02 · cf-03)

The three settings-pane defects that make a Mac app read as "an iPad app in a window": an **ungrouped
`Form`**, a **custom view that drops out of the Tab order**, and an **icon-only button with no tooltip**.
All three are absent from iOS habits — iOS forms are grouped by default, touch has no Tab-key focus ring,
and there is no iOS tooltip analog. These are *flag-only* defects (the correct fix is a judgment call: is
this a settings `Form`? should this control take focus? is the button truly icon-only?). Floors live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate. The ✅ here is the
swiftui-ctx **consensus shape** backed by a real macOS example permalink, not opinion.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2.

---

## cf-01 — plain `Form` with no `.formStyle(.grouped)` (warning, flag-only)

On macOS the default `Form` is **not** the grouped, inset, label-aligned style users expect from System
Settings. iOS forms render grouped out of the box, so AI assumes the same and ships an ungrouped, foreign
settings pane.

```swift
// ❌ WRONG — ungrouped on macOS; looks native only on iOS
Form {
    TextField("Name", text: $name)
    Toggle("Enabled", isOn: $enabled)
}                                   // no formStyle -> non-native macOS settings look
```
```swift
// ✅ CORRECT — grouped is the macOS System-Settings idiom
Form {
    TextField("Name", text: $name)
    Toggle("Enabled", isOn: $enabled)
}
.formStyle(.grouped)                // macOS 13.0+ — the grouped/inset settings look
```

**Grounded in the corpus.** `swiftui-ctx lookup formStyle --json` (run 2026-06-07) returns
`introduced_macos: 13.0`, `deprecated: false`, consensus shape `(_)` **100%** — every real use passes a
style argument; the bare ungrouped `Form` is the defect, not a corpus shape. Its `recommended` macOS-26
example is **`Form { … }.formStyle(.grouped)`** in `sindresorhus/Gifski`:
`https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/EditScreen.swift#L546`
(fetched live with `swiftui-ctx file ex_c4ac4d12ab --smart`; the enclosing `Form` carries `.formStyle`). In
FIX, put `.formStyle(.grouped)` in `## Correct` and that permalink (+ the Sosumi `doc:`) in `## Source`.
`co_occurs_with`: `focusedObject`, `windowToolbarLabelStyle`, `RenameButton`. The other documented styles
are `.columns` and `.automatic`; `.grouped` is the settings idiom.

> **Judge before flagging.** A `Form` is *not* always a settings pane — a small inline `Form` inside a
> popover or a one-off entry sheet may intentionally stay ungrouped. cf-01 LOCATES every `Form` without a
> `.formStyle` in its chain; you decide whether it is a settings/preferences pane that wants grouping.

## cf-02 — custom view not keyboard-focusable (warning, flag-only)

Mac users navigate by keyboard: Tab moves focus and a system-drawn focus ring tracks it. A **custom**
interactive view with no `.focusable()` / `@FocusState` can't receive focus, shows no ring, and Tab skips
it — inaccessible and non-native. Native controls (`TextField`, `Button`, `Toggle`) are *already*
focusable; the defect is a **hand-rolled** focus-taking control. AI omits the wiring because focus traversal
is invisible on touch.

```swift
// ❌ WRONG — custom field never joins the Tab order; no focus ring on macOS
struct SearchField: View {
    @State private var text = ""
    var body: some View {
        TextField("Search", text: $text)    // not focusable(); Tab skips the custom wrapper
    }
}
```
```swift
// ✅ CORRECT — participates in keyboard focus + the focus ring (all macOS 12.0+)
struct SearchField: View {
    @FocusState private var focused: Bool   // @FocusState: macOS 12.0+
    @State private var text = ""
    var body: some View {
        TextField("Search", text: $text)
            .focusable()                     // join keyboard focus (macOS 12.0+)
            .focused($focused)               // .focused(_:) binds the @FocusState (macOS 12.0+)
            .onAppear { focused = true }     // optionally focus on appear
    }
}
```

**Grounded in the corpus.** `swiftui-ctx lookup focusable --json` (run 2026-06-07) returns consensus
`.focusable()` **68%** · `.focusable(_:)` 31%, `deprecated: false`; its `recommended` macOS example is a
plain `.focusable()` in `nickustinov/itsypad-macos`:
`https://github.com/nickustinov/itsypad-macos/blob/d6ffd18f75d47a84fc4e3d86ad9665abb048edb6/Packages/Bonsplit/Sources/Bonsplit/Internal/Views/SplitViewContainer.swift#L27`.
`co_occurs_with`: `onMoveCommand`, `defaultFocus`, `focusEffectDisabled`, `prefersDefaultFocus`.

> **Floor correction (load-bearing).** The corpus reports `focusable` `introduced_macos: 10.15`, but
> `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` **corrects** `focusable`/`focused`/
> `@FocusState` to **macOS 12.0+** (a known corpus-vs-spec discrepancy). The reconciled floor wins — gate a
> focus fix on `#available(macOS 12, *)` only if the target is below 12. **Seam:** `@FocusState` (keyboard)
> is this skill; `AccessibilityFocusState` / `.accessibilityFocused` (VoiceOver focus) is
> `audit-swiftui-accessibility` — `cross_ref` it, don't claim it.

## cf-03 — icon-only button with no `.help` tooltip (warning, flag-only)

On macOS `.help` renders as the standard tooltip after the pointer rests on a view for a moment, and feeds
accessibility. An icon-only toolbar/inspector button without it is opaque — the user can't tell what it
does. There is no iOS tooltip analog, so AI rarely emits it, yet it is mandatory polish for any glyph-only
control.

```swift
// ❌ WRONG — icon-only button with no tooltip; user can't tell what it does
Button { addItem() } label: { Image(systemName: "plus") }
```
```swift
// ✅ CORRECT — tooltip on pointer rest (macOS) + feeds accessibility, title case (macOS 11.0+)
Button { addItem() } label: { Image(systemName: "plus") }
    .help("Add a new item")                 // standard macOS tooltip; title-case text
```

**Grounded in the corpus.** `swiftui-ctx lookup help --json` (run 2026-06-07) returns
`introduced_macos: 11.0` (matches floors-master's corrected floor — **NOT** 10.15), `deprecated: false`
(confirmed by `swiftui-ctx deprecated help`), consensus `(_)` **100%**; its `recommended` example is
`.help(error.localizedDescription)` in `sindresorhus/Gifski`:
`https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/EstimatedFileSize.swift#L152`.

> **keep-both seam (do NOT collapse).** An icon-only control with **no `.help` AND no `.accessibilityLabel`**
> is detected by BOTH this skill (the `.help` tooltip) and `audit-swiftui-accessibility` (the VoiceOver
> label). Per `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` this is intentional —
> file the `.help` finding here with `cross_ref: accessibility`; accessibility reuses your `.help` text as
> its label. `.help` text is title-case and especially required on icon-only toolbar buttons and every icon
> segment of a segmented control.

---

## Canonical pattern (the native-settings-pane exemplar — controls half only)

```swift
// Native macOS settings pane: grouped form, keyboard focus, tooltip, explicit density.
// (Hover / right-click affordances are audit-swiftui-pointer-gestures' half — omitted here on purpose.)
struct SettingsPane: View {
    @State private var name = ""
    @State private var enabled = false
    @FocusState private var nameFocused: Bool          // macOS 12.0+

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .focusable().focused($nameFocused)      // join Tab order + focus ring (macOS 12.0+)
            Toggle("Enabled", isOn: $enabled)
            Button { showHelp() } label: { Image(systemName: "questionmark.circle") }
                .help("Shows contextual help")          // tooltip on pointer rest (macOS 11.0+)
                .buttonStyle(.borderless)
        }
        .formStyle(.grouped)                            // macOS grouped settings look (macOS 13.0+)
        .controlSize(.regular)                          // explicit Mac density (see control-styles-density.md)
        .onAppear { nameFocused = true }                // focus first field on appear
    }
}
```

**Rules recap:** (1) `.formStyle(.grouped)` for settings/forms — the macOS default is ungrouped (cf-01).
(2) `.focusable()` + `@FocusState` + `.focused($_)` so a custom view joins the Tab order and shows the focus
ring (cf-02). (3) `.help` for a tooltip on every icon-only control, title case (cf-03). Density and the
`List`/`Button`/`Picker` style choice are in `control-styles-density.md` (cf-04…cf-08); the pointer/cursor
affordances are `audit-swiftui-pointer-gestures`' half.

---

## Sources

- Apple — `formStyle(_:)`: *"Sets the style for forms in a view hierarchy."* (`.automatic`/`.columns`/
  `.grouped`; macOS 13.0+ — body was nav-only on the scrape, floor confirmed via the corpus
  `introduced_macos`): `https://developer.apple.com/documentation/swiftui/view/formstyle(_:)` (via Sosumi,
  accessed 2026-06-07).
- Apple — `focusable(_:)`: *"Specifies if the view is focusable."* — **macOS 12.0+** (floors-master
  corrects the corpus's reported 10.15): `https://developer.apple.com/documentation/swiftui/view/focusable(_:)`
  (via Sosumi, accessed 2026-06-07).
- Apple — `focused(_:)` (binds focus to a `@FocusState`; macOS 12.0+):
  `https://developer.apple.com/documentation/swiftui/view/focused(_:)`; `@FocusState` (macOS 12.0+):
  `https://developer.apple.com/documentation/swiftui/focusstate` (via Sosumi, accessed 2026-06-07).
- Apple — `help(_:)`: *"Adds help text to a view that people see as a tooltip…"* — **macOS 11.0+** (not
  10.15): `https://developer.apple.com/documentation/swiftui/view/help(_:)` (via Sosumi, accessed 2026-06-07).
- Practice corpus (the ✅ permalinks): `swiftui-ctx lookup formStyle` →
  `https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/EditScreen.swift#L546`;
  `swiftui-ctx lookup focusable` →
  `https://github.com/nickustinov/itsypad-macos/blob/d6ffd18f75d47a84fc4e3d86ad9665abb048edb6/Packages/Bonsplit/Sources/Bonsplit/Internal/Views/SplitViewContainer.swift#L27`;
  `swiftui-ctx lookup help` →
  `https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/EstimatedFileSize.swift#L152`
  (1,857-repo macOS catalog, SwiftSyntax, macOS 26.5 SDK; accessed 2026-06-07).
- SerialCoder.dev — *Implementing a focusable text field in SwiftUI* (macOS; corroboration only):
  `https://serialcoder.dev/text-tutorials/macos-tutorials/macos-programming-implementing-a-focusable-text-field-in-swiftui/`
