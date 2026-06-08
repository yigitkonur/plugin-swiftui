# Reference — Navigation Shell & Columns (nav-01/02/03/04/09)

The in-window navigation shell of a Mac app: which container is the *shell*, two- vs three-column
initializers, the `columnVisibility` binding, and sidebar `List` styling. macOS wants a **persistent
multi-column sidebar**, not an iPhone push stack — the containers exist on both platforms but the idioms
diverge sharply. **Floor values are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — never restated here.** Every ✅ shape is
the **swiftui-ctx consensus** (run the `lookup` in step VERIFY for the live permalink), not opinion.

---

## nav-01 · `NavigationView` is deprecated

`NavigationView` is deprecated (macOS 10.15 → 26.5; Apple: "Use `NavigationStack` and
`NavigationSplitView` instead"). swiftui-ctx confirms: `deprecated NavigationView` → `deprecated:true`,
`migrate_to: NavigationStack`, note *"use NavigationStack for single-column, NavigationSplitView for
sidebar+detail."* `api-currency` owns the deprecation *flag*; **this skill owns the structural
migration** — emit `cross_ref: api-currency`.

```swift
// ❌ deprecated container (or iPhone push-IA as the Mac shell)
NavigationView {
    List(items) { Text($0.name) }
    Text("Detail")
}
```
```swift
// ✅ NavigationSplitView is the Mac shell — the swiftui-ctx consensus 2-column { } detail: { } shape
// (71% of 818 uses across 487 repos). Real macOS-26 call site (f/textream, ★3300, min_macos 26):
// https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/ContentView.swift#L412
// doc: https://sosumi.ai/documentation/swiftui/navigationsplitview
NavigationSplitView {
    List(items, selection: $selected) { Text($0.name) }
} detail: {
    DetailView(item: selected)
}
```

## nav-02 · `NavigationStack` as the Mac shell

`NavigationStack` is a *push/pop stack* — correct for drill-down *inside* a column, **wrong as the
top-level shell** of a Mac app that wants a persistent sidebar. The tell: a top-level `NavigationStack`
wrapping a `List(selection:)` that is clearly a sidebar. **READ to settle the role** — a `NavigationStack`
*inside* a `NavigationSplitView` detail closure is correct and must not be flagged.

The **shell test:** is this the top level and does it want a persistent sidebar? → `NavigationSplitView`.
Is it drill-down inside one column? → `NavigationStack`.

## nav-03 · Two-column vs three-column confusion

The two initializers differ only by the middle `content:` closure. `init(sidebar:detail:)` is
two-column; `init(sidebar:content:detail:)` is three-column. A 3-col init with an `EmptyView()` /
placeholder `content:` → a dead middle column; it should be 2-col. (This is the one structural tell with
a tier-2 ast-grep rule — `lint/ast-grep/nav-03-empty-middle-column.yml`.)

```swift
// ❌ 3-col init for a plain master/detail app → empty middle column
NavigationSplitView {
    List(items, selection: $selected) { Text($0.name) }
} content: {
    EmptyView()                                    // dead column
} detail: { DetailView(item: selected) }
```
```swift
// ✅ 2-col for sidebar → detail
NavigationSplitView {
    List(items, selection: $selected) { Text($0.name) }
} detail: { DetailView(item: selected) }

// ✅ 3-col for sidebar → content list → detail (Mail / Xcode / Keynote shape)
NavigationSplitView {
    SidebarView()
} content: {
    MessageList(folder: selectedFolder)
} detail: {
    MessageDetail(message: selectedMessage)
}
```

**swiftui-ctx grounding (run live in VERIFY):** `lookup NavigationSplitView --json` →
`consensus: [{shape:"{ }", pct:71}, {shape:"(columnVisibility)", pct:27}]`, `introduced_macos: 13.0`,
`recommended` a real macOS-26 trailing-closure example (a high-authority permalinked `var body`). The
71% trailing-closure `{ }` form is the canonical 2-column shell; `(columnVisibility)` is the 27% variant
for nav-04.

## nav-04 · No `columnVisibility` binding (frame hacks to hide a column)

Column show/hide is driven by the `columnVisibility:` initializer parameter bound to a
`NavigationSplitViewVisibility`, **not** by frame tricks. Cases: `.all` (all columns of a 3-col split),
`.doubleColumn` (content+detail in 3-col, or sidebar+detail in 2-col), `.detailOnly` (detail only),
`.automatic` (default). **macOS caveat:** macOS always displays the content column, so `.doubleColumn`
won't hide the sidebar on a Mac the way it collapses in compact-width iOS — treat the cases as hints,
not guarantees, on macOS.

```swift
// ❌ boolean + frame collapse → dead space, no real relayout (the nav-04 frame hack)
@State private var sidebarShown = true
HStack {
    if sidebarShown { SidebarView() }
    DetailView()
}
.frame(maxWidth: sidebarShown ? .infinity : 0)     // canvas never re-lays-out
```
```swift
// ✅ drive the columnVisibility binding (the 27%-consensus variant)
@State private var columnVisibility: NavigationSplitViewVisibility = .all
NavigationSplitView(columnVisibility: $columnVisibility) {
    SidebarView()
} content: { ContentView() } detail: { DetailView() }
// toggle from a toolbar button: columnVisibility = .detailOnly
```

> nav-04 is kept a **grep tell** (locates `.frame(...width: 0)`); the boolean↔frame↔container co-pattern
> can't be tied into one validated ast-grep rule without heavy false positives — READ the context.

## nav-09 · Sidebar `List` missing `.listStyle(.sidebar)`

Apply `.listStyle(.sidebar)` (`SidebarListStyle`, macOS 10.15+) to the `NavigationSplitView` sidebar
`List` for the correct translucent sidebar material and source-list selection highlight. The material is
semantic — it auto-adapts Light/Dark and respects "Reduce Transparency." Use `selection: $binding` for
single-selection navigation; add `.badge(_:)` on a `Label` for unread counts. *Sidebar `List` density /
control styling crosses into `audit-swiftui-controls-forms` — flag the style here, cross_ref the craft.*

```swift
// ✅ sidebar List with the correct style + selection + badge
List(folders, selection: $selectedFolder) { folder in
    Label(folder.name, systemImage: folder.icon).badge(folder.unread)
}
.listStyle(.sidebar)
```

---

## The column-map artifact (optional go-beyond)

`swiftui-audits/navigation-toolbars/_column-map.md`: one row per navigation container —
`file:line · role (shell | column-drilldown) · column-count (2 | 3) · visibility-binding (✅/❌) ·
sidebar-style (✅/❌)`. A `column-drilldown` `NavigationStack` is correct; a `shell` `NavigationStack` is
nav-02; a 3-column row with an empty `content:` is nav-03; a `shell` with no `columnVisibility` binding
that hides a column by frame is nav-04. Two runs over the same code produce an identical map.

---

## macOS notes (carry into the READ)

- **Default IA is columns, not a stack.** The Mac norm is a persistent 2–3-column `NavigationSplitView`
  with an always-visible sidebar; `NavigationStack` is for drill-down inside a column, never the shell.
- **`NavigationSplitView` auto-collapses** to a stack-style layout in compact width, so the same code
  adapts down to iPhone — but the *intent* on macOS is the expanded columns.
- **`preferredCompactColumn:`** (a real init variant, seen in the corpus) controls which column shows
  when collapsed; it does not change the Mac expanded layout.

## Sources

All Apple docs fetched via Sosumi (protocol: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`);
access 2026-06-07. Floors live in `floors-master.md`; the live consensus shape + permalink come from
`swiftui-ctx lookup NavigationSplitView` (see `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`).

- `NavigationSplitView` (2-/3-col inits, `columnVisibility:` / `preferredCompactColumn:` variants): https://developer.apple.com/documentation/swiftui/navigationsplitview
- `NavigationSplitViewVisibility` (`.all`/`.doubleColumn`/`.detailOnly`/`.automatic`; macOS always shows the content column): https://developer.apple.com/documentation/swiftui/navigationsplitviewvisibility
- `NavigationStack` (drill-down inside a column): https://developer.apple.com/documentation/swiftui/navigationstack
- `NavigationView` (deprecated `macOS 10.15–26.5`; "Use `NavigationStack` and `NavigationSplitView` instead"): https://developer.apple.com/documentation/swiftui/navigationview
- Migrating to new navigation types: https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types
- `SidebarListStyle` (`.sidebar`): https://developer.apple.com/documentation/swiftui/sidebarliststyle
- HWS — two-/three-column `NavigationSplitView` (auto-collapse to stack in compact width): https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-two-column-or-three-column-layout-with-navigationsplitview
