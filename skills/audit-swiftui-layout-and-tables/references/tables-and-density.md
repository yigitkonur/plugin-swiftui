# Reference — Tables, Sorting & Control Density (lt-03 · lt-04 · lt-05 · lt-07)

`Table` is *macOS-first*: multi-column, sortable, header-clickable since macOS 12. On iOS the same `Table`
collapses to a single column on compact width, so AI rarely models it. These are *flag-only* defects
except lt-07 (the deprecated `tableStyle` case, `fix_mode: auto`). Floors live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate. The ✅ here is the
swiftui-ctx **consensus shape** backed by a real macOS-26 permalink, not opinion.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2.

---

## lt-03 — `List` where macOS wants a `Table` (warning, flag-only)

Structured, multi-field rows on macOS belong in a `Table` — real columns, clickable headers, multi-column
sort, and row selection for free (the standard Mac data-grid look). A hand-rolled `HStack`-in-`List` has
none of that and reads as non-native.

```swift
// ❌ WRONG — HStack-in-List fakes columns; no headers, no sort, no native grid
List(people) { person in
    HStack { Text(person.name); Spacer(); Text("\(person.age)") }
}
```
```swift
// ✅ CORRECT — Table + TableColumn (real columns; add sortOrder for sortable headers — lt-04)
Table(people) {
    TableColumn("Name") { Text($0.name) }
    TableColumn("Age")  { Text("\($0.age)") }
}
```
A `List` of plain single-field strings is fine as a `List` — judge whether the rows are genuinely a
struct's *fields* before flagging.

## lt-04 — `Table` with no `sortOrder` (warning, flag-only)

On a click-to-sort platform a non-sortable table is non-native. Drive sorting with a `sortOrder: $binding`
to `[KeyPathComparator]`; columns built with `value:` become clickable/sortable automatically.

```swift
// ❌ WRONG — no sortOrder; headers don't sort
Table(people) {
    TableColumn("Name") { Text($0.name) }
}
```
```swift
// ✅ CORRECT — sortOrder + value: columns + onChange (the one wiring)
@State private var people: [Person] = Person.sample
@State private var sortOrder = [KeyPathComparator(\Person.name)]

Table(people, sortOrder: $sortOrder) {
    TableColumn("Name", value: \.name)                      // value: => sortable, clickable header
    TableColumn("Age",  value: \.age) { Text("\($0.age)") } // sortable + custom cell
    TableColumn("Notes") { Text($0.notes) }                 // no value: => intentionally non-sortable
}
.onChange(of: sortOrder) { _, newOrder in people.sort(using: newOrder) }
```
SwiftUI draws the header sort-arrow and cycles ascending → descending automatically.

**Grounded in the corpus.** `swiftui-ctx lookup Table --json` (run 2026-06-07) returns
`introduced_macos: 12.0`, `deprecated: false`, and consensus shapes `(_, selection)` 34% · `(_)` 26% ·
`(_, selection, sortOrder)` 17% · `(_, sortOrder)` — i.e. real shipping Mac apps overwhelmingly carry a
`selection` and/or `sortOrder` binding; the bare `Table(_)` is the minority. Its `recommended` macOS-26
example is **`Table(of: DownloadItem.self, selection: $center.selectedDownloadID) { TableColumn… }`** —
`https://github.com/tahseen-kakar/harbor/blob/064c6b7c706c255ca30ae2c0ce607b6ba21e2edd/Harbor/Views/DownloadsContentView.swift#L13`.
In FIX, put the consensus shape in `## Correct` and that permalink (via `swiftui-ctx file ex_0af837984c
--smart`) in `## Source`. `co_occurs_with`: `TableColumn`, `TableColumnForEach`, `tableStyle`, `TableRow`.

> **Variable column count → `TableColumnForEach`** (macOS 14.4+, gate below that floor):
> ```swift
> Table(rows) {
>     TableColumn("Name") { Text($0.name) }
>     TableColumnForEach(channels) { ch in TableColumn(ch.name) { row in Text(row.value(for: ch)) } }
> }
> ```

## lt-05 — default control density in a dense pane (advisory, flag-only)

macOS supports a range of densities (`.large`/`.regular`/`.small`/`.mini`); a toolbar, inspector, or
settings grid that should be compact looks oversized at the default — "iPad app in a window." Pointer-
driven dense Mac layouts routinely use `.small`/`.mini`; iOS touch targets rarely shrink, so AI leaves it.
`.controlSize` applies to every control in the subtree.

```swift
// ❌ WRONG — every control at default size in a dense inspector/toolbar => oversized
HStack { Button("Apply") { }; Picker("Mode", selection: $mode) { /* … */ } }
```
```swift
// ✅ CORRECT — tune density for the pane
HStack { Button("Apply") { }; Picker("Mode", selection: $mode) { /* … */ } }
    .controlSize(.small)                          // applies to controls in this subtree
```
`swiftui-ctx lookup controlSize --json` (run 2026-06-07): `introduced_macos: 10.15`, `deprecated: false`,
consensus shape `(_)` 100%, recommended permalink
`https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/EstimatedFileSize.swift#L163`.
**Seam:** the `controlSize` *sizing axis* is this skill; *style variants* (`.buttonStyle`/`.pickerStyle`/
`.formStyle(.grouped)`) are `controls-forms` — when the issue is the style not the density, `cross_ref`
controls-forms. (`.extraLarge` exists at macOS 14 but resolves to `.large` on platforms other than visionOS — a no-op on macOS.)

## lt-07 — deprecated `tableStyle` case (hard-fail, **fix_mode: auto**)

`.tableStyle(.inset(alternatesRowBackgrounds:))` (and the `.bordered` variant) is **DEPRECATED (macOS
26.5)**. Apple: *"Use the `.inset` style with the `.alternatingRowBackgrounds()` view modifier."*

```swift
// ❌ DEPRECATED (macOS 26.5)
Table(rows) { /* … */ }.tableStyle(.inset(alternatesRowBackgrounds: true))
```
```swift
// ✅ CORRECT — split the style and the modifier (alternatingRowBackgrounds is macOS 14.0+, macOS-only)
Table(rows) { /* … */ }.tableStyle(.inset).alternatingRowBackgrounds()
```
**Confirmed (primary source):** swiftui-ctx tracks deprecation at the **API** level — `swiftui-ctx deprecated
tableStyle` returns `deprecated:false` because the *modifier* isn't deprecated, only the specific **case**
is. Both `inset(alternatesRowBackgrounds:)` and `bordered(alternatesRowBackgrounds:)` show `macOS 12.0–26.5 Deprecated`
on `developer.apple.com` — cite `source: https://developer.apple.com/documentation/swiftui/tablestyle/inset(alternatesrowbackgrounds:)`.
The floor/deprecation row is in `floors-master.md`; the auto-fix is a
mechanical single-answer swap (fix-safety protocol).

---

## macOS-specific notes

- **`Table` is macOS-first** (macOS 12.0+); on iOS it collapses to one column on compact width. A
  `TableColumn` built with `value:` is sortable; one with only a content closure is not.
- **Scale to AppKit at size.** SwiftUI `Table`/`List` render via `NSTableView` but struggle past ~5,000
  rows or with heavy custom cells — that ceiling and the `NSViewRepresentable` bridge decision are
  `view-performance`'s; note it in one line and `cross_ref view-performance`, don't own it here.

---

## Sources

- Apple — `Table`: *"A container that presents rows of data arranged in one or more columns, optionally
  providing the ability to select one or more members."* — `iOS 16.0+ … macOS 12.0+`.
  `https://developer.apple.com/documentation/swiftui/table` (via Sosumi, accessed 2026-06-07).
- Apple — `tableStyle(_:)`: `.inset(alternatesRowBackgrounds:)` **deprecated (macOS 26.5)**: *"Use the
  .inset style with the .alternatingRowBackgrounds() view modifier."* (same for `.bordered`).
  `https://developer.apple.com/documentation/swiftui/view/tablestyle(_:)` (via Sosumi, accessed
  2026-06-07).
- Apple — `alternatingRowBackgrounds(_:)`: *"Sets the alternating row background style of rows in this
  table."* — macOS 14.0+, macOS-only.
  `https://developer.apple.com/documentation/swiftui/view/alternatingrowbackgrounds(_:)` (via Sosumi,
  accessed 2026-06-07).
- Apple — `TableColumnForEach`: *"A structure that computes columns on demand…"* — macOS 14.4+.
  `https://developer.apple.com/documentation/swiftui/tablecolumnforeach` (via Sosumi, accessed
  2026-06-07).
- Apple — `controlSize(_:)`: *"Sets the size for controls within this view."* — `iOS 15.0+, macOS 10.15+`.
  `https://developer.apple.com/documentation/swiftui/view/controlsize(_:)` (via Sosumi, accessed
  2026-06-07).
- Practice corpus (the ✅ permalinks): `swiftui-ctx lookup Table` →
  `https://github.com/tahseen-kakar/harbor/blob/064c6b7c706c255ca30ae2c0ce607b6ba21e2edd/Harbor/Views/DownloadsContentView.swift#L13`;
  `swiftui-ctx lookup controlSize` →
  `https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/EstimatedFileSize.swift#L163`
  (1,857-repo macOS catalog, SwiftSyntax, macOS 26.5 SDK; accessed 2026-06-07).
