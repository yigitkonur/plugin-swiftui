# Reference — Strict Data-Race Checking & Sendable Crossings (conc-01/02/09/11)

The Swift 6 language-mode era: **complete (strict) data-race-safety checking is the default**. What
were warnings pre-6 — a non-`Sendable` reference crossing an actor, main-actor state read inside a
`@Sendable` closure, a non-`Sendable` `Transferable` payload — are now **hard compile errors**. The
default is *checking*, not isolation. This era is **opt-in per target** (`SWIFT_VERSION = 6` /
`swiftLanguageMode(.v6)`); a project stays on its declared mode until bumped, so confirm the mode in
ORIENT before calling any of these an error rather than a latent race.

> All ✅ shapes here are confirmed against the live corpus — run
> `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` and take the `consensus` shape +
> the `recommended` permalink rather than pasting a snippet (the FIX step requires the permalinked
> example). Floor values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

---

## conc-01 — non-`Sendable` type crossing an actor boundary

Passing a model `class`, `ModelContext`, or an `NSView` out of a main-actor context into a background
task. Pre-6 leniency; an **error** under the Swift 6 language mode.

❌ **WRONG** — non-`Sendable` `user` escapes main-actor isolation:
```swift
@MainActor func reload() {
    let user = self.user                  // non-Sendable model class
    Task.detached { await save(user) }    // ❌ `user` crosses into a detached task
}
```
✅ **CORRECT** — cross only a `Sendable` value snapshot, or keep the work on the same actor:
```swift
struct UserSnapshot: Sendable { let id: UUID; let name: String }

@MainActor func reload() {
    let snap = UserSnapshot(id: user.id, name: user.name)   // Sendable value
    Task.detached { await save(snap) }                      // ✅ safe to cross
}
```
**Why:** make the crossing type `Sendable` (a value type, or a `final class` with only
immutable/`Sendable` stored properties), confine it to an actor, or don't cross. For a one-shot payload
that can't easily be `Sendable` end-to-end, mark the parameter `sending` — it transfers ownership (the
compiler proves the sender no longer touches it) instead of requiring full conformance.

---

## conc-02 — `@Sendable` closure touching main-actor state

A closure passed into a `@Sendable`-typed parameter reads/writes `@MainActor` state. The closure can
run on any thread → "*Main actor-isolated property … can not be referenced from a Sendable closure*".

❌ **WRONG** — `@Sendable` body reads main-actor `count`:
```swift
@MainActor final class Counter {
    var count = 0
    func use() { run { print(count) } }                  // ❌ can not be referenced
    func run(_ c: @Sendable @escaping () -> Void) { /* may run off-main */ }
}
```
✅ **CORRECT** — the fix depends on whether you own the receiving function:
```swift
// (a) You OWN the API → isolate the closure to the main actor:
func run(_ c: @Sendable @MainActor @escaping () -> Void) { c() }

// (b) You DON'T own it, READ-ONLY → capture the value in the capture list:
func use() { run { [count] in print(count) } }
```
**Why:** capture-by-value reads a *copy* taken at closure creation, so no isolated access happens inside
the `@Sendable` body. Reads only — *mutating* main-actor state triggers "*can not be mutated from a
Sendable closure*" and needs an `await` / `MainActor.run` hop (see `main-actor-hops.md`). On Mac this
bites at AppKit `Coordinator` delegate callbacks — flag the isolation hazard; the *how* of the bridge
belongs to `appkit-interop` (cross_ref).

---

## conc-09 — non-`Sendable` `Transferable` / `loadTransferable` payload

`Transferable` / `loadTransferable` drag-drop that compiled pre-6 but errors because the transfer
payload — or the closure crossing the transfer boundary — isn't `Sendable`-correct. **This skill owns
Sendable correctness (primary); `sandbox-files` owns consent/bookmark (cross_ref).**

❌ **WRONG** — a transfer item wrapping a non-`Sendable` class:
```swift
struct DroppedModel: Transferable {
    let node: ReferenceNode                               // ❌ not Sendable
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)         // ❌ closures cross with non-Sendable state
    }
}
```
✅ **CORRECT** — `Sendable` value end-to-end; rebuild the model on the receiving side:
```swift
struct DroppedItem: Transferable, Sendable {
    let id: UUID
    let title: String
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)    // Codable value, no captured class
    }
}
// usage stays declarative: .draggable(item) / .dropDestination(for: DroppedItem.self) { … }
```
**Why:** drag/drop data can be handled off the main actor, so Swift 6 requires the payload and its
representation closures to be data-race safe. Transfer plain `Sendable` value types, not reference
types or main-actor-bound objects.

---

## conc-11 — `@Model` mutation off-context

A SwiftData `modelContext` mutation (`.insert` / `.delete` / `.save`) reached from inside a
`Task.detached`. `ModelContext` is **not `Sendable`**, so touching it off its actor is a data race —
an error under the Swift 6 language mode. **This skill flags the race; `swiftdata` prescribes the
`@ModelActor` fix shape (cross_ref).** The structural tell is `lint/ast-grep/conc-11-…yml` (the
`Task.detached`-contains-`modelContext` co-occurrence). The ✅ shape (a `@ModelActor`-confined writer)
is owned by `audit-swiftui-swiftdata`; confirm the consensus via
`swiftui-ctx lookup ModelContext --json` and route.

---

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://www.hackingwithswift.com/swift/6.0/concurrency | practitioner | "*complete concurrency checking is enabled by default*"; the non-Sendable warning string is now a hard error under the Swift 6 language mode; "*those problems were there beforehand too*". Accessed 2026-06-07. |
| https://www.donnywals.com/solving-main-actor-isolated-property-can-not-be-referenced-from-a-sendable-closure-in-swift/ | practitioner | the error text + the ownership-dependent fix: `@Sendable @MainActor` closure when you own the API; `[count]` capture-list for reads; mutation needs an `await`/`MainActor.run` hop. Accessed 2026-06-07. |
| https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md | primary (Swift Evolution) | `sending` transfers ownership across an isolation boundary as a lighter alternative to full `Sendable` conformance. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/coretransferable/transferable | primary-doc | `Transferable` conformance + `transferRepresentation`; strict checking requires the payload and its closures to be data-race safe. Fetch via Sosumi. Accessed 2026-06-07. |
