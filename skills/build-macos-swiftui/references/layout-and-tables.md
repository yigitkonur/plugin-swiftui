# Layout, Window Sizing & Tables (macOS)

> **macOS-only.** This domain is where an iPhone-shaped layout breaks on a Mac. iOS has **one fixed canvas** — no resizable window, no scene-sizing modifiers — so a window's min/ideal/max dimensions, `.defaultSize`, and `.windowResizability` are load-bearing on the Mac and largely irrelevant on iOS. `Table` is *macOS-first*: multi-column, sortable, clickable headers since macOS 12; on iOS the same `Table` collapses to a single column on compact width, so AI rarely sees it modeled.

The training corpus is overwhelmingly iOS, so AI (a) has **no mental model** that a window has min/ideal/max dimensions the developer must declare, (b) treats `List` as the universal container because that is what iOS tutorials use, and (c) leaves `controlSize` untouched because the iOS default density is usually fine. The result compiles and "works" — it just looks and behaves like an iPad app dropped into a window.

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain.** Cross-checked against `references/api-currency.md`. Every code block compiles on a Mac target; iOS-only APIs appear *only* as ❌ contrast. Where Apple renders a multi-platform availability string, only the macOS arm is reproduced.

---

## The five mistakes

### 1. No min/ideal/max frame → window opens awkwardly or content collapses

Without an ideal or minimum size, a resizable Mac window can open too small (content clipped) or let the user drag it down until the layout collapses. iOS habits never surface this — the screen size is fixed. Declare the frame on the **root content view**; the constraints then feed `.windowResizability(.contentMinSize)`.

```swift
// ❌ WRONG — no frame constraints; window opens too small/large, collapses on drag
WindowGroup {
    ContentView()                              // unconstrained on a free-resizing Mac window
}
```

```swift
// ✅ CORRECT — declare min/ideal/max on the root content
WindowGroup {
    ContentView()
        .frame(minWidth: 480, idealWidth: 720, maxWidth: .infinity,
               minHeight: 320, idealHeight: 480, maxHeight: .infinity)
}
```

### 2. Single-column `List` where macOS wants a sortable `Table`

Structured, multi-field rows on macOS belong in a `Table` — real columns, column headers, **multi-column sorting via clickable headers**, and row selection for free (the standard Mac data-grid look). A hand-rolled `HStack`-in-`List` has none of that and reads as non-native. Drive sorting with a `sortOrder:` binding to `[KeyPathComparator]`; columns built with `value:` become clickable/sortable automatically.

```swift
// ❌ WRONG — HStack-in-List fakes columns; no headers, no sort, no native grid
List(people) { person in
    HStack { Text(person.name); Spacer(); Text("\(person.age)") }
}
```

```swift
// ✅ CORRECT — Table + TableColumn + sortOrder (clickable sortable headers, Mac-first)
@State private var people: [Person] = Person.sample
@State private var sortOrder = [KeyPathComparator(\Person.name)]

Table(people, sortOrder: $sortOrder) {
    TableColumn("Name", value: \.name)         // value: => sortable, clickable header
    TableColumn("Age", value: \.age) { Text("\($0.age)") }   // sortable + custom cell
    TableColumn("Notes") { Text($0.notes) }    // no value: => non-sortable column
}
.onChange(of: sortOrder) { _, newOrder in people.sort(using: newOrder) }
```

### 3. No `.defaultSize` / `.windowResizability` on the scene

iOS never makes you size a window — the screen *is* the size, so AI never learned the **scene-level** sizing modifiers (they live at `App.body`, a spot iOS tutorials rarely exercise). Without them the first-run window opens at an arbitrary system size and a utility window can be stretched to absurd dimensions. These are scene modifiers, distinct from the content `.frame` in mistake 1 — use both.

```swift
// ❌ WRONG — no scene sizing; auxiliary window opens at an unhelpful default, resizes unbounded
Window("Inspector", id: "inspector") {
    InspectorView()
}
```

```swift
// ✅ CORRECT — scene .defaultSize + .windowResizability
Window("Inspector", id: "inspector") {
    InspectorView()
}
.defaultSize(width: 320, height: 600)          // initial window size
.windowResizability(.contentSize)              // clamp to content's frame limits
// .contentMinSize => window can't shrink below content's min, but can grow freely
```

### 4. Default control sizing everywhere → wrong Mac density

macOS supports a range of control densities (`.large` / `.regular` / `.small` / `.mini`); a toolbar, inspector, or settings grid that should be compact looks oversized at the default — again reading as "iPad app in a window." Pointer-driven dense Mac layouts routinely use `.small` / `.mini`; iOS touch targets rarely shrink, so AI leaves it untouched. `.controlSize` applies to every control in the subtree.

```swift
// ❌ WRONG — every control at default size in a dense inspector/toolbar => oversized
HStack {
    Button("Apply") { }
    Picker("Mode", selection: $mode) { /* … */ }
}
```

```swift
// ✅ CORRECT — tune density for the pane
HStack {
    Button("Apply") { }
    Picker("Mode", selection: $mode) { /* … */ }
}
.controlSize(.small)                           // applies to controls in this subtree
```

### 5. `fixedSize()` / `layoutPriority` confusion when content truncates

Wrapping a whole subtree in `.fixedSize()` to "stop truncation" forces the view to its ideal size in *both* axes and can blow past the window, defeating the flexible layout a resizable window depends on. The targeted fix for "which view gives up space first" is `layoutPriority`; to stop a single label wrapping without freezing height, use single-axis `fixedSize(horizontal:vertical:)`.

```swift
// ❌ WRONG — blanket both-axis fixedSize on a container; ignores proposed size, overflows window
HStack {
    Text(longTitle)
    Spacer()
    Text(subtitle)
}
.fixedSize()                                   // freezes BOTH axes for the whole subtree
```

```swift
// ✅ CORRECT — layoutPriority decides who keeps space; single-axis fixedSize stops wrap only
HStack {
    Text(longTitle).layoutPriority(1)          // this Text keeps its space
    Spacer()
    Text(subtitle)                             // this one truncates first
}
// to stop a label wrapping without freezing height:
Text(label).fixedSize(horizontal: false, vertical: true)
```

---

## macOS-specific notes

- **Resizable windows are the whole point.** iOS has one fixed canvas; Mac windows resize freely, so `minWidth`/`idealWidth`/`maxWidth` (content `.frame`) + `.defaultSize` + `.windowResizability` (scene) are load-bearing on the Mac. Use both layers — content frame *and* scene modifiers. *See also:* `.containerRelativeFrame(_:alignment:)` (macOS 14.0+) sizes a view relative to its nearest container (e.g. `.containerRelativeFrame(.horizontal) { w, _ in w * 0.4 }`) instead of hard-coding absolute CGFloats — handy when a pane should track the window rather than a fixed number.
- **`Table` is macOS-first.** Multi-column, sortable, header-clickable tables are a macOS strength (since macOS 12.0); on iOS the same `Table` collapses to a single column on compact width. A `TableColumn` built with `value:` is sortable; one built with only a content closure is not.
- **Variable column count → `TableColumnForEach`** (macOS 14.4+). When the number of columns is known only at runtime, use `TableColumnForEach` — the `ForEach` equivalent for `TableColumn`. Mix it with static columns:

  ```swift
  Table(rows) {
      TableColumn("Name") { Text($0.name) }
      TableColumnForEach(channels) { channel in
          TableColumn(channel.name) { row in Text(row.value(for: channel)) }
      }
  }
  ```
- **Sorting is one wiring.** `sortOrder: $binding` to `[KeyPathComparator]` + `.onChange(of: sortOrder) { _, new in data.sort(using: new) }`. SwiftUI draws the header sort-arrow and cycles ascending → descending on click automatically.
- **Alternating rows / inset style.** ❌ `Table { … }.tableStyle(.inset(alternatesRowBackgrounds: true))` is **DEPRECATED (macOS 26.5)** — Apple: *"Use the `.inset` style with the `.alternatingRowBackgrounds()` view modifier."* (same for the `.bordered` variant). ✅ `Table { … }.tableStyle(.inset).alternatingRowBackgrounds()` — `alternatingRowBackgrounds(_:)` is **macOS 14.0+** and macOS-only. `BorderedTableStyle` (`.bordered`) is likewise macOS-only.
- **Scale to AppKit at size.** SwiftUI `Table`/`List` render via `NSTableView` but struggle past ~5,000 rows or with heavy custom cells; bridge `NSTableView` via `NSViewRepresentable` for high-complexity / high-row-count grids (per `appkit-interop`).
- **`controlSize` matters more on Mac.** Pointer-driven dense layouts (inspectors, toolbars, settings grids) routinely use `.small`/`.mini`; iOS touch targets rarely shrink. Cross-ref `references/version-and-hallucination.md` for control styles.

---

## Detection tells

Grep-able signals that catch these in review:

- **`WindowGroup {` or `Window(` with no `.defaultSize`, no `.windowResizability`, and no `.frame(minWidth:` on the root content** → unsized resizable window (mistakes 1 / 3).
- **`List(` wrapping rows that are `HStack { Text … Spacer() Text … }` of a struct's fields** → should be `Table` + `TableColumn` (mistake 2).
- **`Table(` present but no `sortOrder:` binding / no `KeyPathComparator`** → non-sortable table on a platform where users expect clickable headers (mistake 2).
- **No `controlSize(` anywhere in a dense Mac pane** (settings / inspector / toolbar) → likely wrong density (mistake 4).
- **`.fixedSize()` (both-axis, no arguments) applied to a *container*** rather than a single `Text` → wrong tool; expect `layoutPriority` or single-axis `fixedSize(horizontal:vertical:)` (mistake 5).

---

## Canonical pattern

The canonical resizable macOS window with a sortable data `Table`, to quote verbatim:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            PeopleTable()
                .frame(minWidth: 480, idealWidth: 720, maxWidth: .infinity,
                       minHeight: 320, idealHeight: 480, maxHeight: .infinity)
        }
        .defaultSize(width: 720, height: 480)            // scene: initial size
        .windowResizability(.contentMinSize)             // scene: can't shrink below content min
    }
}

struct PeopleTable: View {
    @State private var people: [Person] = Person.sample
    @State private var sortOrder = [KeyPathComparator(\Person.name)]

    var body: some View {
        Table(people, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)                       // sortable header
            TableColumn("Age", value: \.age) { Text("\($0.age)") }   // sortable + custom cell
        }
        .onChange(of: sortOrder) { _, newOrder in people.sort(using: newOrder) }
        .controlSize(.regular)
    }
}
```

**Rules:** (1) Declare `min/ideal/max` `.frame` on the **root content** view. (2) Set scene `.defaultSize` + `.windowResizability` — distinct from the content frame; use both. (3) For structured multi-field Mac data use `Table` + `TableColumn` (+ `sortOrder:` / `KeyPathComparator`), never a hand-rolled `List`; `value:` makes a column sortable. (4) Tune `controlSize` for dense panes. (5) Reach for `layoutPriority` / single-axis `fixedSize(horizontal:vertical:)` before a blanket `.fixedSize()`.

---

## Availability table

| API | Min macOS | iOS-parity note |
|---|---|---|
| `frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)` | macOS 10.15+ | cross-platform; load-bearing only where windows resize |
| `defaultSize(_:)` / `defaultSize(width:height:)` | macOS 13.0+ | scene sizing; iOS has no windows to size. Exact iOS/visionOS badge **UNVERIFIED — verify against your Xcode 26 SDK** |
| `windowResizability(_:)` (`.automatic`/`.contentSize`/`.contentMinSize`) | macOS 13.0+ | iOS 17.0+ but no resizable windows; effectively Mac/visionOS-relevant |
| `Table` / `TableColumn` | macOS 12.0+ | iOS 16.0+, single-column on compact width |
| `KeyPathComparator` (Foundation; with `Table` `sortOrder:`) | macOS 12.0+ | cross-platform type; sortable-header behavior is Mac-first |
| `controlSize(_:)` (`ControlSize`: `.large`/`.regular`/`.small`/`.mini`) | macOS 10.15+ | iOS 15.0+; used far more on Mac. `.extraLarge` exists (macOS 14) but resolves to `.large` on macOS |
| `fixedSize()` / `fixedSize(horizontal:vertical:)` | macOS 10.15+ | cross-platform |
| `containerRelativeFrame(_:alignment:)` | macOS 14.0+ | cross-platform; size relative to nearest container instead of absolute CGFloats |
| `layoutPriority(_:)` | macOS 10.15+ | cross-platform |
| `TableColumnForEach` | macOS 14.4+ | macOS-first (Mac tables); `ForEach` equivalent for a runtime-variable number of `TableColumn`s |
| `tableStyle(.inset)` + `alternatingRowBackgrounds(_:)` | macOS 14.0+ | macOS-only; replaces the deprecated `.inset(alternatesRowBackgrounds:)` |
| `tableStyle(.inset(alternatesRowBackgrounds:))` | macOS 12.0+ | **DEPRECATED (macOS 26.5)** — use `.inset` + `.alternatingRowBackgrounds()` |

---

## Sources

All Apple-doc availability strings were scraped 2026-06-06. Items are primary-source-cited; UNVERIFIED strings are flagged inline and in the availability table.

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/table | *"A container that presents rows of data arranged in one or more columns, optionally providing the ability to select one or more members."* — availability `iOS 16.0+…macOS 12.0+visionOS 1.0+` | high |
| https://developer.apple.com/documentation/swiftui/scene/windowresizability(_:) | *"Sets the resizability of windows created by this scene."* — macOS 13.0+; cases `.automatic`/`.contentSize`/`.contentMinSize` | high |
| https://developer.apple.com/documentation/swiftui/scene/defaultsize(_:) | *"Sets a default size for a scene."* — macOS 13.0+ (exact iOS/visionOS badge not re-scraped) | high |
| https://developer.apple.com/documentation/swiftui/view/controlsize(_:) | *"Sets the size for controls within this view."* — availability `iOS 15.0+, macOS 10.15+, …` | high |
| https://developer.apple.com/documentation/swiftui/view/fixedsize() | *"Fixes this view at its ideal size."* — macOS 10.15+ (page body nav-only this scrape; signature long-stable) | medium |
| https://developer.apple.com/documentation/swiftui/view/layoutpriority(_:) | *"Sets the priority by which a parent layout should apportion space to this child."* — macOS 10.15+ | medium |
| https://developer.apple.com/documentation/swiftui/scenes | Scenes index — `Window` / `WindowGroup` sizing primitives | medium |
| https://www.createwithswift.com/understanding-scenes-for-your-macos-app/ | "Understanding scenes for your macOS app" — scene/window sizing modifiers | medium |
| https://developer.apple.com/documentation/swiftui/table/tablestyle(_:) | `.inset(alternatesRowBackgrounds:)` **deprecated (macOS 26.5)**: *"Use the .inset style with the .alternatingRowBackgrounds() view modifier."* (same for `.bordered`) | high |
| https://developer.apple.com/documentation/swiftui/view/alternatingrowbackgrounds(_:) | *"Sets the alternating row background style of rows in this table."* — macOS 14.0+, macOS-only | high |
| https://developer.apple.com/documentation/swiftui/tablecolumnforeach | *"A structure that computes columns on demand from an underlying collection of identified data."* — macOS 14.4+ | high |
| https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:) | *"Positions this view within an invisible frame with a size relative to the nearest container."* — macOS 14.0+ | high |
| (Apple doc snippet) | SwiftUI `Table` sort wiring: `Table(items, sortOrder: $sortOrder) { … }.onChange(of: sortOrder) { items.sort(using: $0) }` | medium |
