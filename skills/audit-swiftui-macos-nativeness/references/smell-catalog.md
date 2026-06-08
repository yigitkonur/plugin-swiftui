# Reference — The iPad-in-a-Window Smell Catalog (nat-01 … nat-15)

The per-smell depth for the meta-audit: for each smell, **the tell** (what reads as "an iPad app in a
window"), **why AI emits it** (the iOS-corpus blind spot), **the absence-detection method** (this is a
META-AUDIT of *absent* affordances — you confirm by READing, not by a grep hit), and **the owner skill
it routes to**. This skill **never fixes** — the canonical ❌→✅, floor, and auto-fix live in the owner
skill. Floors are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (never restated here); the routing table is
`routing-map.md`; the score is `nativeness-scoring.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

> **The unifying root cause.** The Mac is **pointer-driven, not touch**: cursor + hover, right mouse
> button, Tab-key focus ring, resizable window, sortable data grid, main menu, Settings scene. iOS has
> none of these, so an iOS-trained model never learned the affordances — the code compiles and *looks*
> right but is missing the Mac vocabulary. Every smell below is a specific missing piece of it.

---

## Group A — Pointer affordances → `audit-swiftui-pointer-gestures`

### nat-01 · custom interactive view with no `.onHover`
**Tell.** A custom row/card/control that responds to clicks but never highlights or changes on pointer
enter/exit — it feels *dead* under the cursor. **Why AI misses it.** iOS is touch; there is no hover, so
the corpus has almost no `.onHover` and the model never emits it. **Detect.** READ each custom
interactive view; if it has a tap/selection but **no** `.onHover { … }` in its modifier chain, smell.
(Native `Button`/`List` rows highlight for free — only *custom* views need it.) **Route**
pointer-gestures.

### nat-04 · row/item with actions but no right-click `.contextMenu`
**Tell.** A list/grid row exposes actions only via buttons or swipe — right-clicking it does nothing.
**Why AI misses it.** The same modifier triggers via long-press on iOS, so the *interaction* is invisible
to an iOS model. **Detect.** A row view with verbs (delete/rename/duplicate) but **no** `.contextMenu`.
Mark destructive items `role: .destructive`. **Route** pointer-gestures.

### nat-05 · draggable / divider / clickable with no `.pointerStyle`
**Tell.** A column divider, drag handle, or link-like view keeps the default arrow cursor — the Mac
signals affordance by changing the cursor (resize, grabbing, link). **Why AI misses it.** No iOS
equivalent; `pointerStyle(_:)` is macOS 15.0+ only. **Detect.** A `Divider`/drag-handle/`onTapGesture`
target with **no** `.pointerStyle(…)` — **only flag under a ≥ macOS 15 floor**. **Route** pointer-gestures.

### nat-15 · `.swipeActions` / swipe-to-delete as the *only* row action
**Tell.** The single way to act on a row is a touch swipe — there is no right-click path. **Why AI misses
it.** Swipe-to-delete is the canonical iOS list idiom. **Detect.** `.swipeActions`/`onDelete` present
**and** no `.contextMenu` on the same row. **Route** pointer-gestures (keep the swipe; *add* the menu).

---

## Group B — Control density & forms → `audit-swiftui-controls-forms`

### nat-02 · icon-only control with no `.help` tooltip
**Tell.** A toolbar/segment button shows only an SF Symbol; hovering reveals no tooltip, so the user
can't tell what it does. **Why AI misses it.** Tooltips are pointer-only; touch has none. **Detect.** A
`Button`/segment whose label is `Image(systemName:)` with no adjacent `Text` and **no** `.help("Title
Case")` in the chain (the tier-2 `nat-02` ast-grep locates this). **Route** controls-forms; **cross_ref**
`audit-swiftui-accessibility` (the VoiceOver `.accessibilityLabel` is a *keep-both* seam — see
`cross-ref-graph.md`).

### nat-03 · custom focus-taking view with no `.focusable()` / `@FocusState`
**Tell.** A custom interactive view never receives keyboard focus — Tab skips it, no focus ring. **Why AI
misses it.** Focus traversal is invisible on touch. **Detect.** A custom view that should be reachable by
Tab with **no** `.focusable()` / `@FocusState` (native `TextField`/`Button` are already focusable —
**don't** flag those). Floor: `focusable` is **macOS 12.0+** (not 10.15 — confirm via floors-master).
**Route** controls-forms.

### nat-06 · `Form` with no `.formStyle(.grouped)`
**Tell.** A settings/preferences `Form` renders flat and ungrouped — on iOS a `Form` is grouped by
default, on **macOS the default is ungrouped** and non-native. **Why AI misses it.** The iOS default
already looks grouped, so the model never learned to ask. **Detect.** `Form { … }` with **no**
`.formStyle(.grouped)`. **Route** controls-forms.

### nat-07 · default control density everywhere
**Tell.** Lists, buttons, pickers, and toolbars sit at default sizing and read **oversized** — the
classic "iPad app in a window" look. **Why AI misses it.** iOS touch targets rarely shrink, so the model
leaves `.controlSize`/`.listStyle`/`.pickerStyle` untouched. **Detect.** A dense Mac surface (toolbar,
inspector, sidebar, settings grid) with **no** `.listStyle(.sidebar/.inset)`, **no** compact
`.controlSize(.small/.mini)`, **no** `.pickerStyle(.menu)`. Advisory (judgment). **Route** controls-forms.

---

## Group C — Data grid & windows → `audit-swiftui-layout-and-tables` / `audit-swiftui-scenes-windows`

### nat-08 · single-column `List` where a sortable `Table` belongs
**Tell.** Structured multi-field rows are faked with `HStack`-in-`List` — no real columns, no clickable
sort headers, no native data-grid look. **Why AI misses it.** iOS tutorials use `List` as the universal
container; `Table` collapses to one column on iOS so it's rarely modeled. **Detect.** A `List`/`ForEach`
whose row is an `HStack` of 2+ fields (name + value + …) that is really tabular data. **Route**
layout-and-tables (it owns the `Table` migration + `sortOrder:` binding).

### nat-09 · window content with no min/ideal/max `.frame`
**Tell.** The window opens too small/large and **collapses when dragged** — iOS never makes you size a
canvas. **Why AI misses it.** No mental model that a window has dimensions the dev must declare.
**Detect.** A `WindowGroup`/`Window`/`DocumentGroup` whose root content view has **no**
`.frame(minWidth:/idealWidth:/…)`. This is the **content-frame** layer. **Route** layout-and-tables.

### nat-10 · scene with no `.defaultSize` / `.windowResizability`
**Tell.** The first-run window opens at an arbitrary system size; a utility window stretches unbounded.
**Why AI misses it.** The **scene-level** sizing modifiers live at `App.body`, a spot iOS tutorials never
exercise. **Detect.** A scene (`WindowGroup`/`Window`/`Settings`) with **no** `.defaultSize` /
`.windowResizability`. Distinct from nat-09 (use both). **Route** scenes-windows (the scene-modifier
layer — see the two-layer window-sizing split in `cross-ref-graph.md`).

---

## Group D — Navigation shell → `audit-swiftui-navigation-toolbars`

### nat-11 · push-stack used as the top-level shell
**Tell.** A Mac sidebar/document app is wrapped in `NavigationStack` (or deprecated `NavigationView`) —
an iPhone push/pop stack instead of a persistent multi-column sidebar. **Why AI misses it.** Most
training data is iPhone navigation. **Detect.** `NavigationStack`/`NavigationView` nested **directly in
`WindowGroup`** as the shell (the tier-2 `nat-11` ast-grep locates the containment). A `NavigationStack`
*inside a detail column* is legitimate — READ to distinguish. **Route** navigation-toolbars (it owns the
`NavigationSplitView` migration); `NavigationView`'s deprecation flag is `api-currency`'s — note, route.

### nat-12 · `navigationBarTitle` / `navigationBar*` / `topBar*`
**Tell.** iOS-bar API on a Mac target. `navigationBarTitle`/`navigationBarTitleDisplayMode` have **no
macOS titlebar meaning**; `topBarLeading`/`topBarTrailing` are **unavailable on macOS** (compile error);
`navigationBarLeading/Trailing` are deprecated. **Why AI misses it.** Models trained on 2020–2022 code
emit the stale names confidently. **Detect.** Any of those identifiers present (the grep tell fires
directly). **Route** navigation-toolbars (use `navigationTitle` + macOS `.navigation`/`.primaryAction`
placements).

---

## Group E — Menus & scenes → `audit-swiftui-menus-commands` / `audit-swiftui-scenes-windows`

### nat-13 · menu actions faked as in-window buttons
**Tell.** Commands a Mac user expects in the **main menu bar** (New, Find, app actions) are only
in-window buttons; the menu bar is empty/default. **Why AI misses it.** iOS has no main menu, so
`.commands {}` is never modeled. **Detect.** App body with **no** `.commands {}` / `CommandMenu` /
`CommandGroup`, while in-window buttons carry the verbs. **Route** menus-commands.

### nat-14 · no `Settings {}` scene / no `MenuBarExtra` (faked menu-bar app)
**Tell.** Preferences are a custom in-window screen instead of the `Settings {}` scene (⌘,); a menu-bar
app is hand-built with `NSStatusItem` instead of `MenuBarExtra`. **Why AI misses it.** Both are
Mac-only scene primitives absent from iOS. **Detect.** A preferences UI with **no** `Settings {}` scene,
or `NSStatusItem` where `MenuBarExtra` belongs. **Route** menus-commands (commands/SettingsLink) and
**scenes-windows** (the scene + the `MenuBarExtra` activation trap). The scene-vs-contents tiebreaker is
in `cross-ref-graph.md` §2.

---

## Sources

- `onHover(perform:)` (*"…when the user moves the pointer over or away from the view's frame."*; pointer-only): https://developer.apple.com/documentation/swiftui/view/onhover(perform:)
- `contextMenu(menuItems:)` (right-click on Mac, long-press on iOS): https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:)
- `focusable(_:)` (macOS 12.0+): https://developer.apple.com/documentation/swiftui/view/focusable(_:)
- `help(_:)` (macOS 11.0+): https://developer.apple.com/documentation/swiftui/view/help(_:)
- `pointerStyle(_:)` (macOS 15.0+, macOS-only): https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)
- `formStyle(_:)` / `Table`: https://developer.apple.com/documentation/swiftui/view/formstyle(_:) · https://developer.apple.com/documentation/swiftui/table
- `defaultSize(_:)` / `windowResizability(_:)`: https://developer.apple.com/documentation/swiftui/scene/defaultsize(_:) · https://developer.apple.com/documentation/swiftui/scene/windowresizability(_:)
- `NavigationSplitView` / `navigationTitle(_:)`: https://developer.apple.com/documentation/swiftui/navigationsplitview · https://developer.apple.com/documentation/swiftui/view/navigationtitle(_:)
- `Settings` scene / `MenuBarExtra` / `commands(content:)`: https://developer.apple.com/documentation/swiftui/settings · https://developer.apple.com/documentation/swiftui/menubarextra · https://developer.apple.com/documentation/swiftui/scene/commands(content:)
- Apple docs fetched via Sosumi (access 2026-06-07); floors re-confirmed against floors-master.md the same day.
