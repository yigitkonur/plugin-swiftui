# Reference — @Query Ordering & macOS-26 @Model Inheritance (sd-08, sd-11)

Two persistence-layer defects: trusting an unpersisted relationship-array order, and the new macOS-26
`@Model` class-inheritance feature that is gated and migration-bound. Floor *values* live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the macOS-arm gating rule lives in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`. Get the canonical `@Query` ✅ from
`swiftui-ctx` (bottom of this file).

**As of:** 2026-06-07 · macOS 14+ (inheritance is macOS 26+) · Xcode 26 SDK.

---

## sd-08 — relationship-array order is NOT persisted

SwiftData does **not** persist element order; the underlying SQLite uses a random uniquing integer, so
a to-many relationship array comes back *shuffled* after a reload. `Array` is contractually ordered in
Swift, so AI assumes the order survives — it doesn't. Never index a relationship array
(`house.floors[0]`) to mean "the first floor," and never `ForEach`/`Table` over a raw relationship
expecting stable order.

❌ assume relationship-array order survives a reload:
```swift
let first = house.floors[0]         // ❌ order not persisted → wrong element after relaunch
ForEach(house.floors) { … }         // ❌ unordered; reshuffles on reload
```
✅ order via `@Query(sort:)` / `SortDescriptor` (or store an explicit `sortIndex` and sort on read):
```swift
@Query(sort: \Trip.name, order: .forward) private var trips: [Trip]   // ✅ explicit order
// multi-sort: @Query(sort: [SortDescriptor(\Trip.startDate), SortDescriptor(\Trip.name)])
```
**Detection:** grep `sd-08` (`.<name>[0]` indexing, or `ForEach(`); the agent READS to confirm the
collection is a `@Model` relationship driven with no `@Query(sort:)` / `SortDescriptor`. Severity
**warning**, `fix_mode: flag-only`.

## sd-11 — macOS-26 `@Model` class inheritance: gated + migration-bound + register all types

WWDC25 session 291 adds subclassing of `@Model` classes — the one new SwiftData feature this cycle. It
is gated and schema-bound:

- Every `@Model` **subclass** needs `@available(macOS 26, *)`.
- Adding a subclass is a **schema change**: define a **versioned schema** and a `MigrationStage` for it.
- The container must register the base **and every subclass**:
  `.modelContainer(for: [Base.self, SubA.self, SubB.self])`.
- Filter a query to one subclass with a type check in the predicate:
  `@Query(filter: #Predicate<Base> { $0 is SubType })`.

✅ shape:
```swift
@available(macOS 26, *)
@Model final class BusinessTrip: Trip {                 // macOS 26.0+; subclass needs the gate
    var account: String
    init(name: String, account: String) { self.account = account; super.init(name: name) }
}
// register base + every subclass:
WindowGroup { ContentView() }
    .modelContainer(for: [Trip.self, BusinessTrip.self])
```
**Detection:** ast-grep `sd-11` (a `class_declaration` whose `modifiers` hold a `@Model` attribute AND
which has an `inheritance_specifier` = a `@Model` subclass — the attribute-to-class binding and the
inheritance clause co-occur, which grep can't express). The grep tell `sd-11` catches the
`@available(macOS 26` gate string for cross-checking. The agent READS to confirm the gate is present
(fire only when the project floor includes macOS 26 and the subclass is ungated, or the container
fails to register every type). Severity **hard-fail**, `fix_mode: flag-only`. **Seam:** the blanket
"is everything gated" sweep is `audit-swiftui-availability-gating`; this skill owns the
`@Model`-inheritance gate in depth — defer non-SwiftData gating there, cross-checking the macOS-arm
rule in `macos-arm-gating.md`.

> `HistoryDescriptor.sortBy` (sorted-history fetches) is also **macOS 26.0+** (member badge:
> `verify-SDK` in `floors-master.md`); `#Index` / `#Unique` and the base history API are macOS 15.0+.
> Verify any of these against `floors-master.md` + Sosumi before asserting a floor.

---

## The canonical @Query ✅ — from swiftui-ctx

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Query --json` returns the real idiom: the
dominant consensus shape is **`(sort: \Video.id)` at 29%** (a sorted `@Query`), with `(filter:
#Predicate<…> { … }, sort: \.id)` close behind — confirming `@Query(sort:)` and predicate-filtered
sorted queries are how shipping Mac apps order their data. `Query` `co_occurs_with` `modelContext`,
`Model`, `Relationship`, `modelContainer`, `FetchDescriptor`. Put the `consensus` shape in `## Correct`,
fetch the enclosing body with `swiftui-ctx file <recommended.id> --smart`, and put its permalink + the
Sosumi `doc:` in `## Source`.

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://wadetregaskis.com/swiftdata-pitfalls/ | practitioner blog | high | "randomly reordering elements … it fails to record the order" — to-many relationship arrays come back shuffled after a reload. Accessed 2026-06-06. |
| https://developer.apple.com/videos/play/wwdc2025/291/ | Apple WWDC25 (session 291, "SwiftData: Dive into inheritance and schema migration") | high | macOS-26 `@Model` inheritance: subclasses need `@available(macOS 26, *)`; adding one is a schema change requiring a versioned schema + `MigrationStage`; register every type via `.modelContainer(for: [Base.self, SubA.self, …])`; filter by subclass with `#Predicate { $0 is SubType }`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftdata | primary-doc | high | `@Query(sort:)` is macOS 14.0+; `#Index`/`#Unique` and the history API are macOS 15.0+; `HistoryDescriptor.sortBy` is macOS 26.0+. Confirmed 2026-06-07. |
