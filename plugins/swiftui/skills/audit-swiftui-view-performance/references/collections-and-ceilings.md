# Reference — Collection cost & dataset ceilings (vperf-07, vperf-10, vperf-11)

Lists and grids are where per-render work multiplies by row count. Compute derived collections **once,
upstream**; iterate **lazily**; and respect the Mac's large-`Table` ceiling. The ✅ lazy-container shape
below is grounded in `swiftui-ctx` (a real macOS example, permalinked).

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain.**

---

## vperf-07 — filtering / sorting *inside* `ForEach`

A `.filter`/`.sorted`/`.map` written directly in the `ForEach(...)` argument is recomputed on **every
render**, inside the view tree — the worst place for it.

```swift
// ❌ WRONG — filter+sort recomputed every render, inside the view tree
ForEach(items.filter { $0.isActive }.sorted { $0.name < $1.name }) { … }
// ✅ CORRECT — compute upstream (model / @Query(sort:) / a cached derived array)
ForEach(activeSortedItems) { … }        // the model exposes the derived collection, computed once
```

Home the derived collection in an `@Observable` model property, a `@Query(sort:)` for SwiftData, or a
value cached when the inputs change — never recomputed per render. Same principle as vperf-06 (no work in
the hot path).

## vperf-11 — a large `ForEach` not inside a lazy container (eager build)

A `ForEach` placed directly in a `VStack`/`HStack`/`ScrollView`-without-lazy builds **all** its rows
eagerly. For a large collection, wrap it in a lazy container so only on-screen rows materialize. The
canonical macOS shape (consensus `LazyVStack(spacing:)` 52%, from `swiftui-ctx lookup LazyVStack`):

```swift
// ❌ WRONG — eager: a plain VStack builds every row up front
ScrollView { VStack { ForEach(items) { row($0) } } }
// ✅ CORRECT — LazyVStack materializes only visible rows (or List/Table, which are lazy by default)
ScrollView { LazyVStack(spacing: 0) { ForEach(items) { row($0) } } }
```

This ✅ is a real, permalinked macOS example (the `recommended` for `LazyVStack`):
`backnotprop/rig` — `ScrollView { LazyVStack(spacing: 0) { ForEach(items) { … } } }`
(https://github.com/backnotprop/rig/blob/a01d168fd8abd566f884537fa60f254a1556f71f/Rig/Views/ReferencesPanel.swift#L302).
READ to confirm the collection is genuinely large — a handful of rows in a plain `VStack` is **fine**;
don't flag a 3-item stack. `LazyVStack` is macOS 11.0+ (`floors-master.md`), so no gating concern.

## vperf-10 — SwiftUI `Table` large-dataset ceiling (measurement-bound)

SwiftUI `Table` has a known large-dataset performance issue — **FB13639482** (filed Feb 2024 against
macOS 14.3), with **no confirmed fix milestone in Apple release notes**. So do **not** assume any OS
version cleared it; **measure on your target**. By contrast, practitioner testing on **macOS 26** shows a
plain `List` of ~10,000 simple rows now scrolls smoothly (~50k still usable), so the old "few-hundred-row"
ceiling no longer holds for plain `List`. `Table` still trails `NSTableView` for large, interaction-heavy
grids.

```swift
// ❌ RISK — SwiftUI Table with 10k+ rows + complex editable cells → janky scrolling (FB13639482)
Table(tensOfThousandsOfRows) { /* heavy custom columns */ }
// ✅ CORRECT (for that scale) — bridge NSTableView for large, interaction-dense data grids
struct DataGrid: NSViewRepresentable { /* wrap NSScrollView + NSTableView; updateNSView reloads */ }
```

Carry this **advisory** with `source: verify against Xcode 26 SDK` — never assert a fixed row threshold
as fact. The **column-structure / layout** of the `Table` is `audit-swiftui-layout-and-tables`'s turf,
and the `NSTableView` **bridge implementation** is `audit-swiftui-appkit-interop`'s — `cross_ref` both;
this skill owns only the **dataset-size cost ceiling that justifies the bridge.**

---

## Sources

- WWDC23 "Demystify SwiftUI performance" (session 10160) — `List`/`ForEach` update cost:
  https://developer.apple.com/videos/play/wwdc2023/10160/ (accessed 2026-06-07).
- Apple — `LazyVStack`: https://developer.apple.com/documentation/swiftui/lazyvstack ·
  `Table`: https://developer.apple.com/documentation/swiftui/table (fetch via Sosumi; accessed 2026-06-07).
- SwiftUI `Table` large-dataset bug: FB13639482 (filed Feb 2024, macOS 14.3). No fix milestone confirmed
  in Apple release notes — **measure the row threshold against your own build.**
- Community practitioner reports (r/SwiftUI; macOS SwiftUI performance write-ups) for the macOS 26
  plain-`List` headroom (~10k smooth, ~50k usable) and the `Table`-vs-`NSTableView` ceiling — treat the
  numbers as guidance and profile your build (accessed 2026-06-07).
