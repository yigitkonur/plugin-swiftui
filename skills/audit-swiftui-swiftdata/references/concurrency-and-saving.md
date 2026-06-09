# Reference — Off-Actor Mutation & Explicit Saving (sd-09, sd-10)

The two run-time-correctness defects: mutating a `@Model` off its owning context (a data race), and
trusting auto-save (silent loss on a fast Quit). Floor *values* live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The isolation race itself is owned by
`audit-swiftui-concurrency-safety` — this skill prescribes the **`@ModelActor` fix shape** and
cross_refs concurrency.

**As of:** 2026-06-07 · macOS 14+ (`@ModelActor` is macOS 14.0+) · Xcode 26 SDK.

---

## sd-09 — off-actor `@Model` mutation → data race (should be a `@ModelActor`)

A view's `@Environment(\.modelContext)` is the `mainContext`, which is **`@MainActor`-isolated**.
`@Model` objects are **not `Sendable`** and are bound to the `ModelContext` that created them. Fetching
on `mainContext` and then mutating those objects (or passing them) inside a background `Task` is a data
race that the **Swift 6 language mode flags as a hard error**, or that crashes at runtime. Do background
SwiftData work inside a `@ModelActor` (which owns its own `ModelContext`) and hand off
`PersistentIdentifier` — which *is* `Sendable` — across the boundary, never the model object.

❌ main-context objects mutated off-main in a detached task:
```swift
@Environment(\.modelContext) private var context        // mainContext, @MainActor
func importAll(_ raw: [RawTrip]) {
    Task.detached {
        for r in raw { context.insert(Trip(name: r.name)) }   // ❌ off-main use of @MainActor context
        try? context.save()                                   // ❌ non-Sendable @Model across actors
    }
}
```
✅ a `@ModelActor` owns its own context; hand off `PersistentIdentifier`:
```swift
@ModelActor                                             // macro (macOS 14+): generates conformance to `protocol ModelActor`, giving this actor its own ModelContext
actor DataImporter {
    func importTrips(_ raw: [RawTrip]) throws {
        for r in raw { modelContext.insert(Trip(name: r.name)) }
        try modelContext.save()          // ✅ save on the actor's own context
    }
}
let id: PersistentIdentifier = trip.persistentModelID   // hand a Sendable id across the boundary
```
**Detection:** grep `sd-09` (`Task.detached` / `Task {` / `DispatchQueue`); the agent READS to confirm
it reads `@Environment(\.modelContext)` results and mutates `@Model` objects with **no `@ModelActor`**.
Severity **hard-fail**, `fix_mode: flag-only`. **Seam:** `audit-swiftui-concurrency-safety` flags the
race (isolation angle) and is **primary**; this skill prescribes the fix shape — emit
`cross_ref: concurrency-safety`.

> **Corpus note:** `swiftui-ctx lookup ModelActor` returns **not-found** — but `@ModelActor` is real
> (**macOS 14.0+** per `floors-master.md`); the not-found is `low_corpus` (the macOS-26-era app corpus
> rarely declares a custom actor), **NOT** a hallucination. Verify the fix shape against **Sosumi**
> (`/documentation/swiftdata/modelactor`), not against the corpus.

## sd-10 — relying on auto-save → silent loss on Quit / window close

The docs promise periodic implicit saves, but in practice the auto-save period is *tens of seconds*,
and changes made shortly before window close / app Quit are frequently **lost** — there are no
deinit/window-close/app-exit hooks. This bites *harder on macOS*: Mac windows are free-floating and
independently closable, and users expect state to persist when they close one. Call
`try modelContext.save()` explicitly after meaningful mutations (and on `ScenePhase` change / window
close), handling the thrown error.

❌ mutate and trust auto-save:
```swift
func rename(_ trip: Trip, to name: String) {
    trip.name = name
    // ❌ no save() — auto-save may not fire before window close / Quit → change lost
}
```
✅ explicit `try modelContext.save()`, error handled:
```swift
@Environment(\.modelContext) private var context
func rename(_ trip: Trip, to name: String) {
    trip.name = name
    do { try context.save() }            // ✅ explicit, immediately after the mutation
    catch { /* surface / log — don't swallow silently */ }
}
// macOS: also save on ScenePhase change / window close, not only on a timer.
```
**Detection:** grep `sd-10` locates `modelContext` / `.mainContext` use; the agent READS to confirm a
mutation path with **no `try …save()` anywhere** (and no `ScenePhase`/window-close save). Severity
**advisory**, `fix_mode: flag-only`. The "auto-save drops a fast-Quit save" behavior is observed
practitioner experience, not a documented guarantee — carry it as `advisory` with `source: verify
against Xcode 26 SDK` unless Sosumi confirms a `save()` requirement for the window-close path.

---

## Get the ✅ shape from swiftui-ctx + Sosumi

`@ModelActor` is `low_corpus`, so lean on **Sosumi** for sd-09's fix
(`/documentation/swiftdata/modelactor`, `/documentation/swiftdata/persistentidentifier`). For
`modelContext.save()` use `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup ModelContext --json` —
its consensus + `co_occurs_with` (`Model`, `Query`, `FetchDescriptor`) show the real save/fetch idiom;
back the ✅ with `swiftui-ctx file <recommended.id> --smart` and the Sosumi `doc:`.

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://wadetregaskis.com/swiftdata-pitfalls/ | practitioner blog | high | "those changes are silently lost!" / "you have to immediately call `context.save()` manually." Accessed 2026-06-06. |
| https://www.hackingwithswift.com/swift/6.0/concurrency | practitioner | high | Swift 6 language mode: "complete concurrency checking is enabled by default" — the non-`Sendable` `@Model` / off-context-mutation rule becomes a hard error. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftdata/modelactor | primary-doc | high | `@ModelActor` macro is macOS 14.0+; generates an actor owning its own `ModelContext`; `PersistentIdentifier` is the `Sendable` hand-off type. Confirmed 2026-06-07. |
