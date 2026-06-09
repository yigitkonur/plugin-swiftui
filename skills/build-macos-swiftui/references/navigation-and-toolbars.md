# Navigation, Sidebars & Toolbars (macOS)

The in-window navigation chrome for a Mac app: `NavigationSplitView` (2–3 columns), sidebar `List`, column-visibility control, window-titlebar titles, and `.toolbar` placements. macOS wants a **persistent multi-column sidebar**, not an iPhone push stack — the containers exist on both platforms but the idioms diverge sharply.

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain.** Symbol names, availability floors, and deprecations are cross-checked against Apple's current SwiftUI documentation. **macOS-only:** every code block compiles on a Mac target; iOS-only APIs appear *only* as ❌ contrast. Where Apple renders a multi-platform availability string, only the macOS arm is reproduced.

---

## Why AI gets this wrong

**(1) iOS-default mental model.** Most training data is iPhone navigation: one `NavigationStack` (or legacy `NavigationView`) pushing detail screens. macOS wants a *persistent* multi-column sidebar — a different container entirely. **(2) Rename + deprecation churn.** `NavigationView` is deprecated (through OS 26.5); `navigationBarLeading`/`navigationBarTrailing` are deprecated; `navigationBarTitle`/`navigationBarTitleDisplayMode` are iOS-bar concepts with no macOS titlebar meaning. Models trained on 2020–2022 code emit the stale names confidently. **(3) Subtle column semantics.** Two- vs three-column initializers differ only by an extra `content:` closure; `NavigationSplitViewVisibility` cases mean different things in 2- vs 3-column mode. **(4) Undocumented macOS gaps.** `navigationSplitViewColumnWidth(min:ideal:max:)` silently no-ops on the detail column, so AI's "set the inspector width" code fails with no signal why.

---

## The six mistakes

### 1. Sidebar/document app wrapped in `NavigationStack` (or deprecated `NavigationView`)

`NavigationView` is deprecated. `NavigationStack` is a *push/pop stack* — correct for drill-down *inside* a column, wrong as the top-level shell of a Mac app that wants a persistent sidebar. The macOS-idiomatic container is `NavigationSplitView`.

```swift
// ❌ WRONG — deprecated container, or iPhone push-IA as the Mac shell
NavigationView {                          // deprecated macOS 10.15–26.5
    List(items) { Text($0.name) }
    Text("Detail")
}
NavigationStack { List(items) { … } }     // push/pop stack, not a Mac shell
```

```swift
// ✅ CORRECT — NavigationSplitView is the Mac shell
NavigationSplitView {                      // sidebar column
    List(items, selection: $selected) { Text($0.name) }
} detail: {                                // detail column
    DetailView(item: selected)
}
```

### 2. Two-column vs three-column confusion

The two initializers differ only by the middle `content:` closure. `init(sidebar:detail:)` is two-column; `init(sidebar:content:detail:)` is three-column. Pick wrong → a blank middle column, or a missing list level.

```swift
// ❌ WRONG — three-column init for a plain master/detail app => empty middle column
NavigationSplitView {
    List(items, selection: $selected) { Text($0.name) }
} content: {
    EmptyView()                            // nothing to put here -> dead column
} detail: {
    DetailView(item: selected)
}
```

```swift
// ✅ CORRECT — two-column for sidebar -> detail
NavigationSplitView {
    List(items, selection: $selected) { Text($0.name) }
} detail: {
    DetailView(item: selected)
}

// ✅ CORRECT — three-column for sidebar -> content list -> detail (Mail/Xcode/Keynote shape)
NavigationSplitView {
    SidebarView()                          // navigator
} content: {
    MessageList(folder: selectedFolder)    // middle list
} detail: {
    MessageDetail(message: selectedMessage)
}
```

### 3. No `columnVisibility` binding (frame hacks to hide a column)

Column show/hide is driven by the `columnVisibility:` initializer parameter bound to a `NavigationSplitViewVisibility`, **not** by frame tricks. Cases: `.all` (all columns of a 3-col split), `.doubleColumn` (content+detail in 3-col, or sidebar+detail in 2-col), `.detailOnly` (detail only), `.automatic` (default). **macOS caveat:** macOS always displays the content column, so `.doubleColumn` won't hide the sidebar on a Mac the way it collapses in compact-width iOS — treat these cases as hints, not guarantees, on macOS.

```swift
// ❌ WRONG — boolean + frame collapse leaves dead space, no real relayout
@State private var sidebarShown = true
HStack {
    if sidebarShown { SidebarView() }
    DetailView()
}
.frame(maxWidth: sidebarShown ? .infinity : 0)   // canvas never re-lays-out
```

```swift
// ✅ CORRECT — drive the columnVisibility binding
@State private var columnVisibility: NavigationSplitViewVisibility = .all
NavigationSplitView(columnVisibility: $columnVisibility) {
    SidebarView()
} content: {
    ContentView()
} detail: {
    DetailView()
}
// toggle from a toolbar button: columnVisibility = .detailOnly  (hide all but detail)
```

### 4. Deprecated / iOS-only toolbar placements on macOS

`navigationBarLeading` / `navigationBarTrailing` are **deprecated** (and iOS-only to begin with). Their nominal replacements `topBarLeading` / `topBarTrailing` are **unavailable on macOS at all** — macOS is absent from Apple's platform list for those cases, so referencing them on a Mac target is a compile-time *unavailable* error, not just an "iOS-shaped" choice. On macOS use **semantic** placements (`.principal`, `.primaryAction`, `.navigation`, `.automatic`) so SwiftUI positions items correctly per platform.

On macOS the semantic placements resolve as: `.navigation` → leading (ahead of the inline title); `.primaryAction` → **leading edge** of the toolbar (Apple: "In macOS … the location for the primary action is the leading edge of the toolbar"); `.principal` and `.status` → centered.

```swift
// ❌ WRONG — deprecated iOS-only, and the topBar* "replacements" don't compile on macOS
.toolbar {
    ToolbarItem(placement: .navigationBarLeading)  { Button("Back") {} }  // deprecated, iOS-only
    ToolbarItem(placement: .navigationBarTrailing) { Button("Add")  {} }  // deprecated, iOS-only
    ToolbarItem(placement: .topBarLeading)         { Button("Back") {} }  // unavailable on macOS → compile error
    ToolbarItem(placement: .topBarTrailing)        { Button("Add")  {} }  // unavailable on macOS → compile error
}
```

```swift
// ✅ CORRECT — semantic placements; SwiftUI positions them per-platform on macOS
.toolbar {
    ToolbarItem(placement: .navigation)    { Button("Back") {} }   // leading, ahead of the title
    ToolbarItem(placement: .principal)     { TitleView() }         // centered on macOS
    ToolbarItem(placement: .primaryAction) { Button("Add")  {} }   // leading edge on macOS (not trailing)
    ToolbarItem { Button("Toggle") {} }                            // .automatic default
}
```

### 5. `navigationBarTitle` / `navigationBarTitleDisplayMode` instead of `navigationTitle`

macOS has no navigation *bar*; the title shows in the **window titlebar** (plus the Windows menu and Mission Control). The current cross-platform modifier is `navigationTitle(_:)`. `navigationBarTitleDisplayMode` and its `.inline`/`.large` modes are iOS/watchOS-only and are no-ops on the Mac.

```swift
// ❌ WRONG — iOS navigation-bar concepts; no macOS effect
DetailView()
    .navigationBarTitle("Inbox")                  // iOS bar concept
    .navigationBarTitleDisplayMode(.inline)       // iOS/watchOS-only, no-op on macOS
```

```swift
// ✅ CORRECT — navigationTitle drives the window titlebar on macOS
DetailView()
    .navigationTitle(item?.name ?? "Untitled")    // -> window title (titlebar / Windows menu / Mission Control)
    .navigationSubtitle("\(unread) unread")       // secondary line; macOS 11.0+ (also iOS/iPadOS 26.0+)
```

### 6. Assuming `navigationSplitViewColumnWidth` controls the detail column

`.navigationSplitViewColumnWidth(min:ideal:max:)` constrains *leading* columns, not the detail column — the detail grows past the stated max, and animating its frame to width 0 leaves the canvas un-relaid-out. For a true resizable/collapsible inspector, drop to `HSplitView` inside a two-column `NavigationSplitView`, or bridge AppKit's `NSSplitViewController`. *(Practitioner-confirmed limitation — verify against your Xcode 26 SDK.)*

```swift
// ❌ WRONG — no-op on the detail column; inspector ignores the max and won't collapse cleanly
NavigationSplitView {
    SidebarView()
} detail: {
    InspectorView()
        .navigationSplitViewColumnWidth(min: 200, ideal: 270, max: 400)  // ignored on detail
}
```

```swift
// ✅ CORRECT — HSplitView inside a 2-column detail, gated by @State; or bridge NSSplitViewController
@State private var inspectorVisible = true
NavigationSplitView {
    SidebarView()
} detail: {
    HSplitView {
        CanvasView()
        if inspectorVisible { InspectorView() }
    }
    .toolbar {
        ToolbarItem {
            Button { inspectorVisible.toggle() } label: { Image(systemName: "sidebar.right") }
        }
    }
}
```

> **macOS 14+ alternative:** for a contextual metadata panel (not a structural column), prefer the first-party `.inspector(isPresented:)` with `.inspectorColumnWidth(min:ideal:max:)` — it places under the toolbar and auto-presents as a sheet in compact width. Standard system inspector width is **225 pt (Apple-documented examples); 270 pt is a community-observed value — verify against Xcode 26 SDK**. `HSplitView`/AppKit is for a *user-resizable structural* third pane.

---

## macOS-specific notes

- **Default IA is columns, not a stack.** The Mac norm is a persistent 2–3-column `NavigationSplitView` with an always-visible sidebar; `NavigationStack` is for drill-down inside a column, never the app shell.
- **Sidebar `List` style.** Apply `.listStyle(.sidebar)` to the sidebar `List` for the correct translucent sidebar material and source-list selection highlight. The material is semantic — it auto-adapts Light/Dark and respects "Reduce Transparency." Use `selection: $binding` for single-selection navigation; add `.badge(_:)` on a `Label` for unread counts.
- **No navigation bar → titlebar.** `navigationTitle` maps to the window titlebar (+ Windows menu / Mission Control). `navigationSubtitle` adds the secondary line (macOS 11.0+, also iOS/iPadOS 26.0+ — but it's a Mac-first idiom). `navigationBarTitle`, `navigationBarTitleDisplayMode`, `.inline`/`.large` are iOS/watchOS bar concepts with no macOS effect.
- **Toolbar placements diverge.** Prefer **semantic** placements so SwiftUI positions per-platform. On macOS: `.navigation` is leading (ahead of the title), `.primaryAction` lands on the **leading edge** (not trailing), and `.principal`/`.status` are centered. `navigationBarLeading`/`navigationBarTrailing` are deprecated iOS-only; `topBarLeading`/`topBarTrailing` are **unavailable on macOS** (compile error on a Mac target), never the Mac default.
- **`NavigationSplitView` auto-collapses** to a stack-style layout in compact width, so the same code adapts down to iPhone — but the *intent* on macOS is the expanded columns.
- **Built-in toolbar toggles.** Use the system-provided `.toggleSidebar` and `.toggleInspector` toolbar items (AppKit identifiers; SwiftUI surfaces equivalents) to get correct icons, labels, localization, and behavior for free. Anchor the sidebar toggle at the leading edge; keep the inspector toggle trailing-most.
- **`ToolbarSpacer` (macOS 26.0+; also iOS/iPadOS 26.0+).** Insert deliberate gaps between toolbar items with `ToolbarSpacer(_:placement:)` and a `SpacerSizing`: `ToolbarSpacer(.fixed, placement:)` for a single system-standard gap, `ToolbarSpacer(.flexible, placement:)` to push items toward opposite ends of a region. Gate behind `#available(macOS 26, *)`.

  ```swift
  if #available(macOS 26, *) {
      ToolbarSpacer(.fixed, placement: .primaryAction)      // system-standard gap
      ToolbarSpacer(.flexible, placement: .primaryAction)   // pushes following items apart
  }
  ```
- **`.status` placement is centered.** Items at `placement: .status` render in the toolbar **center** on macOS (alongside `.principal`), not at an edge — useful for a sync/progress indicator.
- **`.searchable` goes on the split view, not a column** — otherwise it lands in the wrong toolbar slot on macOS.
- **Empty detail → `ContentUnavailableView`**, never a blank view; it's the native empty-state component and matches system apps.
- **Detail-column width is not fully controllable** in pure SwiftUI; real resizable/collapsible structural panes need `HSplitView` or an AppKit `NSSplitViewController` bridge.

---

## Detection tells

How to catch the mistake cluster in review:

- `NavigationView {` anywhere → deprecated container (mistake 1).
- A top-level `NavigationStack {` wrapping a `List(selection:)` that is clearly a sidebar → wrong shell for macOS (mistake 1).
- A three-column `init(sidebar:content:detail:)` whose `content:` is empty / `EmptyView()` / a placeholder → should be two-column (mistake 2).
- A boolean + `.frame(maxWidth: visible ? .infinity : 0)` (or `width: 0`) to hide a column → use a `columnVisibility` binding or `HSplitView` (mistakes 3 / 6).
- `placement: .navigationBarLeading` / `.navigationBarTrailing` → deprecated iOS-only; flag for `.primaryAction` / `.principal` / `.navigation` (mistake 4). `.topBarLeading` / `.topBarTrailing` on a macOS target → **won't compile** (unavailable on macOS); replace with a semantic placement.
- `.navigationBarTitle(` or `.navigationBarTitleDisplayMode(` → iOS-only; flag for `.navigationTitle` (mistake 5).
- `.navigationSplitViewColumnWidth(` on the **detail** closure → known no-op on detail (mistake 6).
- Sidebar `List` missing `.listStyle(.sidebar)` → wrong material / selection style on macOS.

---

## Canonical pattern

```swift
// macOS-idiomatic three-column navigation (macOS 13.0+)
struct RootView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selected: Item?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(items, selection: $selected) { Text($0.name) }   // sidebar
                .navigationTitle("Library")
        } content: {
            CanvasView(item: selected)                            // content list / canvas
        } detail: {
            InspectorView(item: selected)                         // detail
                .navigationTitle(selected?.name ?? "Untitled")    // -> window titlebar
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Add") {} }   // semantic, per-platform
        }
    }
}
```

**Rules:** (1) Mac shell = `NavigationSplitView`, not `NavigationView`/`NavigationStack`. (2) Two-column = `init(sidebar:detail:)`; three-column = `init(sidebar:content:detail:)`. (3) Control columns with a `columnVisibility:` binding to `NavigationSplitViewVisibility` (`.all`/`.doubleColumn`/`.detailOnly`/`.automatic`). (4) Title with `navigationTitle`, never `navigationBarTitle`/`navigationBarTitleDisplayMode`. (5) Prefer semantic toolbar placements (`.principal`/`.primaryAction`/`.navigation`/`.automatic`); avoid deprecated `navigationBarLeading`/`navigationBarTrailing`. (6) For a real collapsible inspector, use `HSplitView` or an AppKit `NSSplitViewController` bridge.

---

## Sources

All scraped from developer.apple.com 2026-06-07 unless dated otherwise.

- `NavigationSplitView` (2-/3-col inits, `columnVisibility:` variants): https://developer.apple.com/documentation/swiftui/navigationsplitview
- `NavigationSplitViewVisibility` (`.all`/`.doubleColumn`/`.detailOnly`/`.automatic`; macOS always shows the content column): https://developer.apple.com/documentation/swiftui/navigationsplitviewvisibility
- `ToolbarItemPlacement` (`.primaryAction` = leading edge on macOS; `.principal`/`.status` centered; `navigationBarLeading`/`Trailing` deprecated iOS-only; `topBarLeading`/`topBarTrailing` unavailable on macOS): https://developer.apple.com/documentation/swiftui/toolbaritemplacement
- `ToolbarSpacer` + `SpacerSizing` (macOS 26.0+; also iOS/iPadOS 26.0+; `.fixed`/`.flexible` toolbar gaps): https://developer.apple.com/documentation/swiftui/toolbarspacer
- `navigationTitle(_:)` (macOS → window titlebar / Windows menu / Mission Control): https://developer.apple.com/documentation/swiftui/view/navigationtitle(_:)-43srq
- `navigationSubtitle(_:)` (macOS 11.0+, also iOS/iPadOS 26.0+): https://developer.apple.com/documentation/swiftui/view/navigationsubtitle(_:)
- `NavigationView` (deprecated `macOS 10.15–26.5`; "Use `NavigationStack` and `NavigationSplitView` instead"): https://developer.apple.com/documentation/swiftui/navigationview
- Migrating to new navigation types: https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types
- HWS — two-/three-column `NavigationSplitView` (auto-collapse to stack in compact width): https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-two-column-or-three-column-layout-with-navigationsplitview
- Michael Sena — *Three Column Editors in SwiftUI on macOS* (`navigationSplitViewColumnWidth` no-op on detail; `HSplitView` / `NSSplitViewController` workaround; 2023-03-30): https://msena.com/posts/three-column-swiftui-macos/
- WWDC 2023 Session 10161 "Inspectors in SwiftUI" (`.inspector(isPresented:)`, 225 pt per Apple examples / 270 pt community-observed — verify against Xcode 26 SDK, compact → sheet)
