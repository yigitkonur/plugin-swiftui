# SwiftData (macOS)

SwiftData (`@Model`, `ModelContainer`/`ModelContext`, `@Query`, `.modelContainer(for:)`) is the current first-party persistence layer on **macOS 14+** — a thin macro façade over Core Data. That façade is exactly why AI gets it wrong: the *Swift-language* semantics an LLM reasons about (`let` is immutable, a non-optional is non-optional, `init` assigns stored properties) are silently violated by the Core Data machinery underneath, and **almost none of the violations produce a compiler diagnostic.** The code compiles, looks idiomatic, and then crashes at runtime, loses data on relaunch, or kills the preview canvas. Apple's own samples make it worse: they show no `@Model` initializer, ship a non-compiling `@Relationship(.cascade)`, and recommend `fatalError` on container creation.

> macOS-only reference. SwiftData is byte-for-byte identical on iOS 17+, so iOS appears here only as a ❌ contrast. The genuinely macOS-divergent angles are environmental, not API: save-on-window-close / Quit timing, the App-Sandbox store location, and multi-process (app + menu-bar helper + widget) container access — called out where they bite.

Every example below targets **macOS 14+**, except the variadic `ModelContainer(for:configurations:)` init (used in the preview/container examples), which is `macOS 15.0+` — each such call notes the `macOS 14.0+` alternative `ModelContainer(for:migrationPlan:configurations:)` inline.

---

## The eight mistakes

### 1. `let` on a bidirectional relationship — compiles clean, crashes at runtime (most damaging)

SwiftData presumes every relationship is **mutable** (and optional); the Core Data backing writes the relationship through a `ReferenceWritableKeyPath`. A `let` can't be written outside `init`, so the write fails — but only at runtime, with an opaque cast crash. Every member that bidirectionally references another `@Model` class **must** be `var`, regardless of intended semantics.

❌ **WRONG** — `let` on a relationship; no warning, then a runtime crash:
```swift
@Model final class House {
    @Relationship(deleteRule: .cascade, inverse: \Floor.house)
    let floors: [Floor] = []        // ❌ let → 💣 at runtime, never at compile
}
// crash: "Could not cast value of type 'Swift.KeyPath<House, Array<Floor>>'
//         to 'Swift.ReferenceWritableKeyPath<…>'."
```

✅ **CORRECT** — relationships are always `var`, defaulted:
```swift
@Model final class House {                              // macOS 14+
    @Relationship(deleteRule: .cascade, inverse: \Floor.house)
    var floors: [Floor] = []        // ✅ var, even if you think of it as constant
}
```

### 2. Assigning a relationship inside `init` — data silently vanishes on relaunch

No compile or runtime error. Everything works until you Quit and relaunch — then the relationship is empty, because the in-`init` assignment bypasses SwiftData's hooks and the child rows' foreign key back to the parent is saved as `NULL`. **Never assign a relationship in `init`.** You may `append` to it inside `init`, or assign it *outside* `init`.

❌ **WRONG** — direct relationship assignment in `init`; empty after relaunch:
```swift
@Model final class House {
    var floors: [Floor] = []
    init(floors: [Floor]) {
        self.floors = floors        // ❌ bypasses hooks → child FK saved NULL → empty on relaunch
    }
}
```

✅ **CORRECT** — default to `[]`, then `append`:
```swift
@Model final class House {                              // macOS 14+
    var floors: [Floor] = []
    init(floors: [Floor]) {
        self.floors.append(contentsOf: floors)   // ✅ append in init, or assign outside init
    }
}
```

### 3. Incomplete `@Model` — no initializer (copied from Apple's first sample)

Apple's very first SwiftData sample omits the initializer, so the class can't actually be constructed; Apple *never* shows a complete `@Model`, which is precisely why developers and AI fall into the relationship pits above. A related Apple snippet (`@Relationship(.cascade) var accommodation: Accommodation?`) is a **compile-time type error**, not a stylistic slip: `.cascade` is a `Schema.Relationship.DeleteRule`, but the macro's first variadic parameter is `Schema.Relationship.Option` (whose only case is `.unique`), so the types don't match. The fix is the named argument `@Relationship(deleteRule: .cascade)`. Apple's *current* docs still ship the broken `@Relationship(.cascade)` form, which is why AI keeps copying it. Always write a full `@Model` with an explicit initializer.

❌ **WRONG** — no `init`; can't be constructed; `@Relationship(.cascade)` is a type error:
```swift
@Model class Trip {                 // ❌ no init — Apple's incomplete first sample
    var name: String
    @Relationship(.cascade) var stops: [Stop]?   // ❌ .cascade is a DeleteRule, not an .Option → won't compile
}
```

✅ **CORRECT** — full `@Model`, explicit `init`, named `deleteRule:`:
```swift
@Model final class Trip {                               // macOS 14+
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Stop.trip)
    var stops: [Stop] = []
    init(name: String) {            // ✅ Apple omits this — you must write it
        self.name = name
    }
}
```

### 4. `#Preview` with no in-memory container — the canvas crashes

Constructing a `@Model` value (or touching `\.modelContext`) with no `ModelContainer` in scope crashes the preview (*"failed to find a currently active container"*). Previews gate the whole edit loop, so this is high-friction. Inject an **in-memory** `ModelContainer` built from a `ModelConfiguration(isStoredInMemoryOnly: true)` and insert sample data so `@Query` finds something. `try!` is acceptable **in a preview only** (never in shipping code — see mistake 5).

❌ **WRONG** — model created with no container; preview crashes:
```swift
#Preview {
    EditingView(trip: Trip(name: "Test"))   // ❌ no container in scope → preview crash
}
```

✅ **CORRECT** — in-memory container + sample data, attached with `.modelContainer`:
```swift
#Preview {                                              // macOS 15+ (see init note below)
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Trip.self, configurations: config) // try! OK in preview
    let trip = Trip(name: "Sample")
    container.mainContext.insert(trip)       // ✅ insert so @Query has data
    return EditingView(trip: trip)
        .modelContainer(container)
}
```
> **Init availability:** the variadic convenience `ModelContainer(for: Trip.self, configurations: config)` is **`macOS 15.0+`** — not 14.0. On a **macOS-14** target use the full init that takes `migrationPlan:` (which *is* `macOS 14.0+`): `try! ModelContainer(for: Trip.self, migrationPlan: nil, configurations: config)`. (`@Model`, `ModelContext`, `ModelConfiguration`, `isStoredInMemoryOnly` are all `macOS 14+`.)

### 5. `fatalError` on `ModelContainer` creation — Apple's sample, shipped as-is

`ModelContainer.init` throws for **several recoverable, real-world reasons**: a schema/migration mismatch (`Code=134504`, *"Cannot use staged migration with an unknown model version"*), no free disk space (which produces *no* logs), or two processes migrating concurrently (`Code=134110` / `134100`). Apple's getting-started code wraps this in `fatalError(error.localizedDescription)` — turning every one into a hard crash with no usable diagnostic (the `SwiftDataError` `_explanation` is typically `nil`). On macOS, the multi-process case is routine (app + menu-bar helper + widget on one container), so this is not a corner case. Catch and classify; recover or surface a real message.

❌ **WRONG** — copy Apple's `fatalError`; every recoverable error becomes a crash:
```swift
do {
    container = try ModelContainer(for: Trip.self)
} catch {
    fatalError(error.localizedDescription)   // ❌ schema mismatch / no disk / concurrent migrate → blind crash
}
```

✅ **CORRECT** — classify and recover; never blind-`fatalError`:
```swift
let container: ModelContainer
do {
    // variadic `configurations:` init is macOS 15+; on macOS 14 add `migrationPlan: nil,`
    container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration())
} catch {
    // 134504 schema mismatch · no-free-space · 134110/134100 concurrent migration (common on macOS)
    // recover (serialize multi-process opens with a lock file; check disk; clear+recreate on
    // an unrecoverable schema mismatch) or surface a real message — do NOT fatalError(error).
    container = try! ModelContainer(                 // last-resort fallback, not the first response
        for: Trip.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}
```

### 6. Treating `@Model` to-many arrays as ordered — relies on insertion order

SwiftData does **not** persist element order; the underlying SQLite uses a random uniquing integer, so a to-many relationship array comes back *shuffled* after a reload. `Array` is contractually ordered in Swift, so AI assumes the order survives — it doesn't. Order explicitly: drive lists from `@Query(sort:)` / a `SortDescriptor`, or store an explicit `sortIndex` and sort on read. Never index a relationship array (`house.floors[0]`) to mean "the first floor."

❌ **WRONG** — assume relationship-array order survives a reload:
```swift
let first = house.floors[0]         // ❌ order is not persisted → wrong element after relaunch
ForEach(house.floors) { … }         // ❌ unordered; reshuffles on reload
```

✅ **CORRECT** — order via `@Query(sort:)` / `SortDescriptor`:
```swift
struct TripList: View {                                 // macOS 14+
    @Query(sort: \Trip.name, order: .forward) private var trips: [Trip]   // ✅ explicit order
    var body: some View {
        // multi-sort also works: @Query(sort: [SortDescriptor(\Trip.startDate),
        //                                      SortDescriptor(\Trip.name)])
        Table(trips) { /* macOS-rich, sortable columns */ }
    }
}
```

### 7. Mutating `@Model` objects off the main/model context — data race (should be `@ModelActor`)

The view's `@Environment(\.modelContext)` is the `mainContext`, which is **`@MainActor`-isolated**. `@Model` objects are **not `Sendable`** and are bound to the `ModelContext` that created them. Fetching on `mainContext` and then mutating those objects (or passing them) inside a background `Task` is a data race that the Swift 6 language mode flags as a hard **error**, or that crashes at runtime. Do background SwiftData work inside a `@ModelActor` (which owns its own `ModelContext`) and hand off `PersistentIdentifier` — which *is* `Sendable` — across the boundary, never the model object.

❌ **WRONG** — main-context objects mutated off-main in a detached task:
```swift
@Environment(\.modelContext) private var context        // mainContext, @MainActor
func importAll(_ raw: [RawTrip]) {
    Task.detached {
        for r in raw { context.insert(Trip(name: r.name)) }   // ❌ off-main use of @MainActor context
        try? context.save()                                   // ❌ non-Sendable @Model across actors
    }
}
```

✅ **CORRECT** — a `@ModelActor` owns its own context; hand off `PersistentIdentifier`:
```swift
@ModelActor                                             // macOS 14+; generates an actor with its own context
actor DataImporter {
    func importTrips(_ raw: [RawTrip]) throws {
        for r in raw { modelContext.insert(Trip(name: r.name)) }
        try modelContext.save()          // ✅ save on the actor's own context
    }
}
// hand a Sendable identifier across the boundary, not the @Model object:
let id: PersistentIdentifier = trip.persistentModelID
```

### 8. Relying on auto-save — `try modelContext.save()` is omitted (silent data loss)

The docs promise periodic implicit saves, but in practice the auto-save period is *tens of seconds*, and changes made shortly before window close / app Quit are frequently **lost** — there are no deinit/window-close/app-exit hooks. This bites *harder on macOS*: Mac windows are free-floating and independently closable, and users expect state to persist when they close one. Call `try modelContext.save()` explicitly after meaningful mutations (and on `ScenePhase` change / window close), handling the thrown error.

❌ **WRONG** — mutate and trust auto-save; changes lost on a fast Quit:
```swift
func rename(_ trip: Trip, to name: String) {
    trip.name = name
    // ❌ no save() — auto-save may not fire before window close / Quit → change lost
}
```

✅ **CORRECT** — explicit `try modelContext.save()`, error handled:
```swift
@Environment(\.modelContext) private var context
func rename(_ trip: Trip, to name: String) {
    trip.name = name
    do { try context.save() }            // ✅ explicit, immediately after the mutation
    catch { /* surface / log — don't swallow silently */ }
}
// macOS: also save on ScenePhase change / window close, not only on a timer.
```

---

## Detection tells

Grep/scan signals that flag the mistakes above:

- **`let ` immediately before an `@Relationship`** (or before any property whose type is another `@Model` class) → mistake 1 (runtime cast crash).
- **`self.<relationship> =` inside an `init` body** of a `@Model` class → mistake 2 (FK saved `NULL`, empty on relaunch). `append(contentsOf:)` is fine; bare `=` is the tell.
- **A non-optional, `@Model`-class-typed to-one property** (e.g. `var owner: Person`, not `Person?`) → silent **implicitly-unwrapped** trap: SwiftData stores the relationship with a *nullable* foreign key, so the property is really `Person!`; any read while the FK is `NULL` (mid-construction, mid-migration, after the inverse is cleared) is a nil-unwrap crash with no compiler warning. Make to-one relationships **optional** (`Person?`) unless you can prove the FK is never null.
- **`@Model class` / `@Model final class` with stored properties but no `init(`** → mistake 3 (uninitializable Apple-doc copy).
- **`@Relationship(.cascade)`** (first positional arg) instead of `@Relationship(deleteRule: .cascade)` → mistake 3 (type error: `.cascade` is a `DeleteRule`, the slot wants a `Schema.Relationship.Option` — won't compile; still in Apple's live docs).
- **A `#Preview` that constructs a `@Model` value but contains no `ModelConfiguration(isStoredInMemoryOnly:` / `.modelContainer(`** → mistake 4 (preview crash).
- **`try ModelContainer(` followed by `catch { fatalError(`** in non-preview code → mistake 5 (recoverable errors crash-blind). `try!` outside a `#Preview` is the same smell.
- **Indexing a relationship array (`.floors[0]`) or a `ForEach`/`Table` over a relationship with no `@Query(sort:)` / `SortDescriptor`** → mistake 6 (assumes unpersisted order).
- **`Task` / `Task.detached` / `DispatchQueue` reading `@Environment(\.modelContext)` results and mutating them, with no `@ModelActor`** → mistake 7 (non-`Sendable` `@Model` across actors).
- **A mutation path with no `try modelContext.save()` anywhere** → mistake 8 (silent loss on Quit). On macOS, also look for the absence of a `ScenePhase`/window-close save.
- **macOS-only smell:** one container opened by the app *and* a widget/menu-bar helper with no lock-file serialization → triggers the concurrent-migration error class from mistake 5.

---

## Canonical pattern

Quote this block verbatim when prescribing the rules:

```swift
// CANONICAL @Model (macOS 14+): explicit init; relationships are `var` with a default.
@Model final class House {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Floor.house)
    var floors: [Floor] = []                  // var, defaulted — NEVER let

    init(name: String) {                      // explicit init — Apple omits this
        self.name = name
    }
    func add(_ floors: [Floor]) {             // append — NEVER assign a relationship in init
        self.floors.append(contentsOf: floors)
    }
}

// App: register only the root model(s) at the scene.
WindowGroup { ContentView() }
    .modelContainer(for: House.self)

// Ordered reads: @Query(sort:) — relationship-array order is NOT persisted.
@Query(sort: \House.name, order: .forward) private var houses: [House]

// Preview: in-memory container, sample data inserted (try! OK here only).
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // `for:configurations:` is macOS 15+; on macOS 14 use `for:migrationPlan:configurations:` (migrationPlan: nil)
    let container = try! ModelContainer(for: House.self, configurations: config)
    container.mainContext.insert(House(name: "Sample"))
    return ContentView().modelContainer(container)
}

// Production container: classify the error, NEVER blind fatalError.
do {
    container = try ModelContainer(for: House.self, configurations: ModelConfiguration())  // macOS 15+ init
} catch {
    // 134504 schema mismatch / no disk space / 134110 concurrent migration (common on macOS) →
    // recover or surface a real message; do NOT just fatalError(error).
}

// Background writes: @ModelActor owns its own context; hand off PersistentIdentifier (Sendable).
@ModelActor actor Importer {
    func add(_ name: String) throws {
        modelContext.insert(House(name: name))
        try modelContext.save()               // explicit save
    }
}
```

**Rules:** (1) relationship properties are **always `var`** with a default — `let` crashes at runtime. (2) **Never assign a relationship in `init`** — `append`, or assign outside `init`, or the FK saves `NULL` and data vanishes on relaunch. (3) Every `@Model` needs an **explicit `init`**; use named `@Relationship(deleteRule:)` — the bare `@Relationship(.cascade)` from Apple's docs is a type error. (4) **Previews need an in-memory container** (`isStoredInMemoryOnly: true`) with sample data inserted. (5) **Never `fatalError` on container creation** — classify and recover. (6) **Order explicitly** with `@Query(sort:)` / `SortDescriptor`; relationship-array order is not persisted. (7) **Mutate off-main only inside a `@ModelActor`**; hand off `PersistentIdentifier`, never the non-`Sendable` `@Model`. (8) **Call `try modelContext.save()` explicitly** — don't trust auto-save, especially before macOS window close / Quit.

**macOS addendum (not in the iOS version):** save on `ScenePhase` change / window close because Mac windows close independently and a fast Quit drops a pending auto-save (mistake 8). A sandboxed store lands in the app/group container (`…/Library/Application Support/default.store`); sharing it with a helper or widget needs a **group-container** entitlement, and those multi-process opens are exactly what triggers the concurrent-migration crash in mistake 5 — serialize container creation with a lock file.

---

## Sources

| URL | Type | Confidence | Key fact / verbatim |
|---|---|---|---|
| https://wadetregaskis.com/swiftdata-pitfalls/ | practitioner blog | high | *"All member variables (of `@Model` classes) that refer bidirectionally to other model classes must be variables (`var`), not constants (`let`). Irrespective of their actual intended semantics."*; the crash *"Could not cast value of type 'Swift.KeyPath<…>' … to 'Swift.ReferenceWritableKeyPath<…>'."*; *"never assign the relationship in `init`. You can append to it, and you can assign it outside of `init`."* / *"their foreign key back to `House` is `NULL`."*; *"Apple never show a complete example of a `@Model` class"* and *"`@Relationship(.cascade) …` That's not valid; it doesn't even compile."*; *"randomly reordering elements … it fails to record the order"*; *"those changes are silently lost!"* / *"you have to immediately call `context.save()` manually."* Accessed 2026-06-06. |
| https://scottdriggers.com/blog/swiftdata-modelcontainer-creation-crash/ | practitioner blog | high | *"creating a `ModelContainer` can throw an error, and in their code, they recommend crashing your app with `fatalError`"*; the three causes *"Error due to schema mismatch … no free space on disk … multiple migrators attempting to migrate the database concurrently."*; `Code=134504` *"Cannot use staged migration with an unknown model version"*; `SwiftDataError(…loadIssueModelContainer, _explanation: nil)`. Accessed 2026-06-06. |
| https://www.hackingwithswift.com/quick-start/swiftdata/how-to-use-swiftdata-in-swiftui-previews | practitioner tutorial (Paul Hudson, upd. Xcode 16.4) | high | *"you must create a custom `ModelConfiguration` that stores data in memory only, use that to create a `ModelContainer` …"* and *"If you attempt to create a model object without first having created a container for that object, your preview will crash."* Accessed 2026-06-06. |
| https://www.reddit.com/r/swift/comments/145e4p7/swiftdata_crashes_in_preview/ | forum | medium | Corroborates the preview-crash-without-container symptom. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftdata | primary-doc (index) | high | Core surface: `@Model`, `ModelContext`, `@Query`, `.modelContainer(for:)` are `macOS 14+`; `#Index` / `#Unique` and the history API (`HistoryDescriptor`, `fetchHistory(_:)`, `fetchLimit`) are `macOS 15+`; `HistoryDescriptor.sortBy` is `macOS 26+`. Confirmed 2026-06-07. |
| https://developer.apple.com/documentation/swiftdata/modelcontainer | primary-doc | high | `init(for:configurations:)` (variadic convenience) is **`macOS 15.0+`**; `init(for:migrationPlan:configurations:)` is **`macOS 14.0+`** — the correct init for a macOS-14 target (pass `migrationPlan: nil`). Confirmed 2026-06-07. |
| https://developer.apple.com/videos/play/wwdc2025/291/ | Apple WWDC25 (session 291, "SwiftData: Dive into inheritance and schema migration") | high | macOS 26 adds `@Model` class inheritance: subclasses need `@available(macOS 26, *)`; adding one is a schema change requiring a versioned schema + `MigrationStage`; register every type via `.modelContainer(for: [Base.self, SubA.self, …])`; filter by subclass with `#Predicate { $0 is SubType }`. Accessed 2026-06-07. |
| https://www.hackingwithswift.com/swift/6.0/concurrency | practitioner | high | Swift 6 language mode: *"complete concurrency checking is enabled by default"* — the non-`Sendable` `@Model` / off-context-mutation rule (mistake 7) becomes a hard error. Accessed 2026-06-06. |

**Availability (Apple SwiftData docs, confirmed 2026-06-07):**

- `@Model`, `ModelContext`, `ModelConfiguration(isStoredInMemoryOnly:)`, `@Relationship(deleteRule:inverse:)`, `@Attribute(.preserveValueOnDeletion)`, `@Query`, `.modelContainer(for:)` — **macOS 14.0+**.
- **`ModelContainer(for:configurations:)`** — the variadic convenience init — is **macOS 15.0+**. The macOS-14-compatible init is **`ModelContainer(for:migrationPlan:configurations:)`** (`macOS 14.0+`): pass `migrationPlan: nil` when you have no plan.
- **`@ModelActor`** (mistake 7) — **macOS 14.0+**; `PersistentIdentifier` is the `Sendable` hand-off type.
- **`#Index` / `#Unique`** — **macOS 15.0+** (confirmed). Compile-time index/uniqueness constraints on a `@Model`.
- **History API** — `HistoryDescriptor`, `ModelContext.fetchHistory(_:)`, and `HistoryDescriptor.fetchLimit` — **macOS 15.0+** (confirmed). `HistoryDescriptor.sortBy` (`[SortDescriptor]`, for sorted history fetches) — **macOS 26.0+**.

**macOS 26 — `@Model` class inheritance (the one new feature this cycle):**

WWDC25 session 291 ("SwiftData: Dive into inheritance and schema migration") adds subclassing of `@Model` classes. It is gated and migration-bound:

- Every `@Model` subclass needs `@available(macOS 26, *)`.
- Adding a subclass is a schema change: define a **versioned schema** and a `MigrationStage` for it.
- The container must register the base **and every subclass** type: `.modelContainer(for: [Base.self, SubA.self, SubB.self])`.
- Filter a query to one subclass with a type check in the predicate: `@Query(filter: #Predicate<Base> { $0 is SubType })`.
