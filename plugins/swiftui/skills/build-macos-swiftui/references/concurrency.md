# Swift 6 Concurrency (macOS)

Concurrency is the most version-sensitive area of AI-written Swift, because the rules **changed twice in twelve months** and most training data predates both changes. Two facts have to be kept apart or every fix is wrong:

- **Swift 6 (language mode, Sept 2024) makes _complete (strict) data-race-safety checking_ the default.** What used to be warnings — a non-`Sendable` type crossing an actor boundary, main-actor state read inside a `@Sendable` closure — are now **hard compile errors**. The default is *checking*, not isolation. **The Swift 6 language mode is opt-in _per target_** (`SWIFT_VERSION = 6` in Xcode build settings, or `swiftLanguageMode(.v6)` in a Package.swift target) — existing projects do **not** switch automatically when the toolchain updates; they stay on their declared mode (4 / 5) until you bump it.
- **Swift 6.2 (Sept 15 2025) adds an _opt-in_ "main actor by default" build mode** (`-default-isolation MainActor`, surfaced in Xcode as *Approachable Concurrency* + *Default Actor Isolation = Main Actor*). This is **a setting you turn on**, NOT the unconditional language default. AI conflates the two and produces either `@MainActor` spam or code that assumes single-threaded isolation it never enabled.

Every example here compiles on a **macOS target**. iOS appears only as a ❌ contrast — the isolation *rules* are platform-agnostic, but the friction lands harder on Mac: AppKit bridging (`NSViewRepresentable`, `Coordinator` callbacks, `loadTransferable` drag-drop) crosses isolation boundaries constantly, and a fresh Xcode 26 Mac template often ships with the opt-in mode enabled — so "is it on?" is a real per-project question.

> macOS-only. The compiler model is identical on iOS, but these examples target a Mac app; the boundary-crossing pain points (AppKit `Coordinator`, `NSViewRepresentable`, document/file decode) are macOS-shaped. Toolchain/flag-gated facts (`@concurrent`, `-default-isolation MainActor`, `nonisolated(nonsending)`, and the `NonisolatedNonsendingByDefault` upcoming-feature flag) carry an explicit verify note — they need **Swift 6.2+** and, where noted, an explicitly-enabled flag.

---

## The seven mistakes

### 1. Ignoring that strict data-race checking is the Swift 6 default

Passing a non-`Sendable` reference type (a model `class`, `ModelContext`, an `NSView`) out of a main-actor context to a background task — the old pre-6 leniency. Under the Swift 6 language mode this is an **error, not a warning**.

❌ **WRONG** — compiled pre-6, errors under the Swift 6 language mode:
```swift
@MainActor func reload() {
    let user = self.user                  // non-Sendable model class
    Task.detached { await save(user) }    // ❌ `user` escapes main-actor isolation
}
```

✅ **CORRECT** — make the crossing type `Sendable`, or keep the work on the same actor:
```swift
// Cross only Sendable value types; produce them, then hand them off.
struct UserSnapshot: Sendable { let id: UUID; let name: String }

@MainActor func reload() {
    let snap = UserSnapshot(id: user.id, name: user.name)   // Sendable value
    Task.detached { await save(snap) }                      // ✅ safe to cross
}
```
**Why:** the pre-6 form "*would throw up a warning: 'passing argument of non-sendable type … may introduce data races'*" — that warning is now an error. "*If Swift 6 throws up concurrency warnings and errors about your code, those problems were there beforehand too — they just weren't being diagnosed automatically.*" Make the type `Sendable` (a value type, or a `final class` with only immutable/`Sendable` stored properties), confine it to an actor, or don't cross.

### 2. "Main actor-isolated property can not be referenced from a Sendable closure"

Passing a closure that reads/writes `@MainActor` state into a `@Sendable`-typed parameter. The closure can run on any thread, so reading main-actor state synchronously inside it is a data race.

❌ **WRONG** — `@Sendable` closure body touches main-actor `count`:
```swift
@MainActor
final class Counter {
    var count = 0
    func use() { run { print(count) } }                 // ❌ Main actor-isolated property
    func run(_ c: @Sendable @escaping () -> Void) { /* may run off-main */ }
}                                                       //    'count' can not be referenced
```

✅ **CORRECT** — the fix depends on whether you own the receiving function:
```swift
// (a) You OWN the API → isolate the closure to the main actor:
func run(_ c: @Sendable @MainActor @escaping () -> Void) { c() }
// "Because the closure is now both @Sendable and isolated to the main actor, we're free
//  to run it and access any other main actor isolated state inside."

// (b) You DON'T own it, READ-ONLY → capture the value in the capture list:
func use() { run { [count] in print(count) } }
// "Capturing the value of count when the closure is created, rather than trying to read
//  it from inside of our sendable closure."
```
**Why:** capture-by-value reads a *copy* taken at closure-creation, so no isolated access happens inside the `@Sendable` body. It works for **reads only** — *mutating* main-actor state triggers "*can not be mutated from a Sendable closure*" and needs an `await` / `MainActor.run` hop onto the main actor instead. On Mac this is exactly where AppKit `Coordinator` delegate callbacks bite.

### 3. `DispatchQueue.main.async` cargo-cult inside async code

The pre-`async/await` habit: hop to the UI thread with GCD. It **side-steps the compiler's isolation checking** — the very checking Swift 6 turns on — is unstructured, and doesn't compose with `async/await` cancellation.

❌ **WRONG** — GCD hop to dodge the checker:
```swift
func didFinish(_ data: Data) {
    DispatchQueue.main.async { self.items = decode(data) }   // ❌ unchecked, unstructured
}
```

✅ **CORRECT** — annotate the hop with an actor the compiler can verify:
```swift
@MainActor func didFinish(_ data: Data) { items = decode(data) }   // isolated by annotation
// …or, from a nonisolated async context:
func didFinish(_ data: Data) async { await MainActor.run { items = decode(data) } }
```
**Why:** `@MainActor` / `await MainActor.run` are *checkable* — the compiler proves the access is on the main actor. `DispatchQueue.main.async` proves nothing and is the #1 concurrency cargo-cult AI emits. Batch multiple post-async writes into **one** `MainActor.run` block so SwiftUI never renders an intermediate state (e.g. `isLoading = false` before `items` is set → flash of empty content).

### 4. `Task {}` vs `.task {}` in views — lifecycle & cancellation

Kicking off async work in `.onAppear` with a bare unstructured `Task`. That `Task` is **not** cancelled when the view disappears, so it leaks and races a re-appearing view.

❌ **WRONG** — unstructured `Task`, not tied to view lifetime:
```swift
.onAppear { Task { await viewModel.load() } }   // ❌ never cancelled on disappear
```

✅ **CORRECT** — `.task` binds the work to view identity and auto-cancels:
```swift
.task { await viewModel.load() }                       // cancelled when the view goes away
.task(id: selectedID) { await viewModel.load(selectedID) }   // restarts when id changes
```
**Why:** SwiftUI's `.task` modifier (`macOS 12.0+`; closure is `@MainActor`-isolated, so view-state mutation inside it needs no extra hop) exists precisely to scope async work to the view's lifetime. For rapidly-changing selections, also guard against a cancelled-but-still-finishing task delivering stale results: hold the handle (`@State private var loadTask: Task<Void, Never>?`), `loadTask?.cancel()` before relaunching, and gate writes behind a **generation counter** (`guard generation == captured else { return }`) so an older load can't overwrite a newer one. `Task {}` still has a place — quick async coordination on a `@MainActor` type — but it inherits the caller's actor and stalls the UI if it does blocking/CPU work (use `Task.detached` + a `Sendable` return for that).

### 5. Over-applying `@MainActor` after misreading Swift 6.2 (the opt-in confusion)

`@MainActor` sprinkled on every type and free function "to be safe," OR the opposite — omitting needed annotations because "Swift 6.2 is main-actor-by-default." Both come from conflating the two eras.

❌ **WRONG** — either extreme, both from the same misread:
```swift
@MainActor struct Math { @MainActor static func add(_ a: Int, _ b: Int) -> Int { a + b } }
// ❌ pure value logic forced onto the main actor for no reason — spurious @MainActor spam

@Observable final class ViewModel { var items: [Item] = [] }   // touches UI state
// ❌ assumed main-actor-isolated "because 6.2 does that automatically" — but the mode is OFF
```

✅ **CORRECT** — know which mode the *target* is in, don't assume:
```swift
// Mode is OFF (the common case, and any pre-6.2 target): annotate UI-touching types explicitly.
@MainActor @Observable final class ViewModel { var items: [Item] = [] }
enum Math { static func add(_ a: Int, _ b: Int) -> Int { a + b } }   // no isolation needed

// Mode is ON (`-default-isolation MainActor`, e.g. a fresh Xcode 26 Mac app): UI types are
// ALREADY isolated — drop the now-redundant @MainActor; mark genuinely-parallel code nonisolated.
```
**Why — the exact nuance:** "main actor by default" is the **new _option_** to isolate code to the main actor (`-default-isolation MainActor`), not the unconditional language default. The swift.org 6.2 post frames it as "*the new option to isolate code to the main actor by default*" and heads its sample `// In '-default-isolation MainActor' mode`. The unconditional Swift 6 default is **data-race-safety checking**, not main-actor isolation. So: check the build setting before relying on either behavior — verify against your Xcode 26 SDK / Swift 6.2 toolchain. A fresh Xcode 26 Mac template frequently enables it; an existing or library target usually does not.

### 6. Misreading where `nonisolated async` runs — the flag-gated detail AI gets wrong

The common AI error: claiming that on **Swift 6.2 a `nonisolated async` function runs in the _caller's_ context by default**. It does **not**. Caller-context execution for `nonisolated async` is the `NonisolatedNonsendingByDefault` **upcoming-feature flag** (SE-0338's behavior is what it replaces). **Without that flag enabled — even on Swift 6.2 — a `nonisolated async` function still hops to the global (concurrent) executor**, exactly as it did before. So you have *three* states to keep straight, not two.

❌ **WRONG** — assert the caller-context behavior is the plain 6.2 default:
```swift
nonisolated func decode(_ url: URL) async -> Image { heavyDecode(url) }
// ❌ "on Swift 6.2 this stays on the caller's actor" — FALSE without the flag.
//    With the default (flag OFF) it hops to the global executor (SE-0338), as in 6.0/6.1.
//    It only stays on the caller's context if NonisolatedNonsendingByDefault is enabled.
```

✅ **CORRECT** — be explicit about each state; pick the spelling, don't rely on a default:
```swift
// (a) Want it OFF the main actor (heavy work): @concurrent ALWAYS runs on the global executor.
@concurrent
static func decodeLargeImage(_ url: URL) async throws -> Image { /* on the pool */ }
// call: .task { self.image = try? await Loader.decodeLargeImage(url) }

// (b) Want THIS one async fn to run in the CALLER's context (no global flag): nonisolated(nonsending).
//     Ideal at an AppKit Coordinator / NSViewRepresentable boundary that's already main-actor.
nonisolated(nonsending)
func validate(_ text: String) async -> Bool { /* stays on the caller's actor */ }

// (c) Want caller-context to be the MODULE-WIDE default for every nonisolated async:
//     enable the upcoming-feature flag, then @concurrent marks the exceptions.
//     SPM:   .enableUpcomingFeature("NonisolatedNonsendingByDefault")
//     swiftc: -enable-upcoming-feature NonisolatedNonsendingByDefault
```
**Why:** `@concurrent` and `nonisolated(nonsending)` are opposites — `@concurrent` *always* runs on the global executor; `nonisolated(nonsending)` *always* runs in the caller's execution context. Both are explicit per-function spellings, so they behave the same whether or not the `NonisolatedNonsendingByDefault` flag is set. The flag only changes the **default** for *unannotated* `nonisolated async` functions (from "hop to the global executor" to "stay on the caller"). All three need **Swift 6.2+**; the flag must be turned on deliberately. On Mac this matters at AppKit `Coordinator`/`NSViewRepresentable` async callbacks (reach for `nonisolated(nonsending)`) and for heavy image/document decode that must stay off the main actor (reach for `@concurrent`). Verify against your Xcode 26 SDK / Swift 6.2 toolchain; don't emit any of them for projects on Swift 6.0/6.1.

### 7. Non-`Sendable` transfer types tripping `loadTransferable` / drag-drop under Swift 6

`Transferable` / `loadTransferable` drag-drop code that compiled pre-6 but now errors because the transfer representation — or the closure crossing the transfer boundary — isn't `Sendable`-correct. Strict concurrency now checks those closures and types.

❌ **WRONG** — a transfer item carrying a non-`Sendable` type across the boundary:
```swift
struct DroppedModel: Transferable {                       // wraps a non-Sendable class
    let node: ReferenceNode                               // ❌ not Sendable
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)         // ❌ closures cross with non-Sendable state
    }
}
```

✅ **CORRECT** — make the conformance and its transfer closures `Sendable`-correct:
```swift
struct DroppedItem: Transferable, Sendable {              // value type, Sendable end-to-end
    let id: UUID
    let title: String
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)    // Codable value, no captured class
    }
}
// usage stays declarative: .draggable(item)  /  .dropDestination(for: DroppedItem.self) { … }
```
**Why:** the data that crosses a drag/drop boundary can be handled off the main actor, so Swift 6 requires the `Transferable` payload and its representation closures to be data-race safe. Transfer plain `Sendable` value types (an `id` + `Codable` fields), not reference types or main-actor-bound objects; rebuild the model on the receiving side from those values. For a value that *must* cross a boundary but can't easily be `Sendable` end-to-end, mark the parameter `sending` — it transfers ownership across the boundary (the compiler proves the sender no longer touches it) instead of requiring full `Sendable` conformance, a lighter fit for one-shot drag/drop payloads.

---

## Detection tells

Grep/scan signals that flag the mistakes above:

- **`DispatchQueue.main.async`** anywhere in `async`/SwiftUI code → almost always should be `@MainActor` / `await MainActor.run` (mistake 3).
- **`Task {`** inside `.onAppear` / `.onChange` → suspect; prefer `.task {}` / `.task(id:)` for lifecycle-bound work (mistake 4).
- **`@Sendable` closure parameter + a body reading `self.` / a `@MainActor` property** → the "can not be referenced from a Sendable closure" error class (mistake 2).
- **`Task.detached { … someClass … }`** where `someClass` (or `ModelContext`, an `NSView`) isn't `Sendable` → boundary violation (mistake 1).
- **`@concurrent` present** → confirm the project toolchain is **Swift 6.2+**; flag it on 6.0/6.1 (mistake 6).
- **Blanket `@MainActor` on every type**, OR UI types with **no** isolation annotation *plus* a claim that "6.2 makes it main-actor by default" → verify the `-default-isolation MainActor` build setting actually exists; don't assume (mistake 5).
- **`nonisolated async`** method assumed to run in the caller's context "because Swift 6.2" → FALSE unless `NonisolatedNonsendingByDefault` is enabled; the plain default still hops to the global executor. Use `@concurrent` to force off-main, `nonisolated(nonsending)` to force caller-context per function (mistake 6).
- **`Transferable` conformance wrapping a reference type**, or a transfer representation with a non-`Sendable` closure → the `loadTransferable` Swift-6 error class (mistake 7).
- **Rapid-trigger writes after `await`** (selection/refresh) with no cancelled-task guard or generation counter → stale results overwrite fresh ones (mistake 4).

---

## Canonical pattern

Quote this block verbatim when prescribing the rules:

```
SWIFT 6 CONCURRENCY — CANONICAL RULES (macOS)

0. Two eras, kept apart:
   • Swift 6 (language mode) DEFAULT = strict DATA-RACE-SAFETY CHECKING (errors, not warnings).
   • Swift 6.2 "main actor by default" = an OPT-IN build mode (-default-isolation MainActor),
     NOT the unconditional default. Check the build setting; never assume it is on.

1. Hop to the main actor with a CHECKABLE annotation, never GCD:
   @MainActor func apply(_ d: Data) { self.items = decode(d) }
   // nonisolated context:  await MainActor.run { self.items = decode(d) }
   // (batch related post-async writes into ONE MainActor.run block.)

2. View-lifecycle async work → .task, NOT a bare Task in onAppear:
   .task(id: selectedID) { await model.load(selectedID) }   // auto-cancelled on disappear
   // rapid triggers: cancel the prior task + guard writes with a generation counter.

3. Sendable closure needing main-actor state:
   • You own the API → isolate it:        func run(_ c: @Sendable @MainActor () -> Void)
   • You don't, read-only → capture value: run { [count] in print(count) }
   • Mutation → hop:                       await MainActor.run { count += 1 }

4. Only Sendable types cross actor boundaries (value types, or final classes with
   immutable/Sendable stored props). Produce a Sendable snapshot; don't pass the class.

5. Swift 6.2 ONLY (verify the toolchain) — pick the execution spelling, don't trust a default:
   @concurrent              → ALWAYS the global executor (heavy/off-main work):
                              @concurrent static func decodeLargeImage(_ u: URL) async throws -> Image
   nonisolated(nonsending)  → ALWAYS the caller's context (per-fn; AppKit boundary): SE-0461
   PLAIN nonisolated async  → still hops to the global executor by DEFAULT — it only stays on
                              the caller if the NonisolatedNonsendingByDefault flag is enabled.
```

**Rules:** Swift 6 default = strict *data-race-safety checking* (errors, not warnings), opt-in per target (`SWIFT_VERSION = 6` / `swiftLanguageMode(.v6)`). "Main actor by default" is an **opt-in** Swift 6.2 build mode (`-default-isolation MainActor`) — never assume it's on; verify against your Xcode 26 SDK / Swift 6.2 toolchain. `@concurrent` (always global executor) and `nonisolated(nonsending)` (always caller's context, SE-0461) require **Swift 6.2+** — gate them; plain `nonisolated async` still hops to the global executor *unless* `NonisolatedNonsendingByDefault` is enabled. macOS addendum: the boundary pain concentrates at AppKit `Coordinator`/`NSViewRepresentable` surfaces and heavy document/image decode — keep crossing types `Sendable`, reach for `nonisolated(nonsending)` at main-actor boundaries, and push CPU work off-main with `@concurrent`, not GCD.

---

## Sources

| URL | Type | Confidence | Key fact / verbatim |
|---|---|---|---|
| https://swift.org/blog/swift-6.2-released/ | primary-doc | high | "main actor by default" is "*the new option to isolate code to the main actor by default*" (OPT-IN, `-default-isolation MainActor`), not the unconditional default; sample headed `// In '-default-isolation MainActor' mode`; `@concurrent` "*makes it clear when you want code to remain serialized on actor, and when code may run in parallel*". The "*nonisolated async functions run in the caller's execution context*" behavior it describes is the `NonisolatedNonsendingByDefault` upcoming feature (SE-0461) — gated behind that flag, NOT on by default. Holly Borla, Sept 15 2025. Accessed 2026-06-07. |
| https://www.hackingwithswift.com/swift/6.0/concurrency | practitioner | high | "*By far the biggest change is that complete concurrency checking is enabled by default.*"; the non-Sendable `User` warning string; "*those problems were there beforehand too — they just weren't being diagnosed automatically.*" Warnings become hard errors under the Swift 6 language mode. Accessed 2026-06-06. |
| https://www.donnywals.com/solving-main-actor-isolated-property-can-not-be-referenced-from-a-sendable-closure-in-swift/ | practitioner | high | The error text; fix depends on ownership — `@Sendable @MainActor` closure when you own the API ("*free to run it and access any other main actor isolated state inside*"); `[count]` capture-list for reads ("*capturing the value of count when the closure is created*"); mutation triggers "*can not be mutated from a Sendable closure*" and needs an `await`/`Task` hop. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftui/view/task(priority:_:) | primary-doc | medium | `.task` is the lifecycle-bound async modifier, `macOS 12.0+`; the closure is `@MainActor`-isolated, cancelled on view disappearance. Accessed 2026-06-06. |
| https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md | primary-doc (Swift Evolution) | high | SE-0461 "Run nonisolated async functions on the caller's actor by default" — defines `nonisolated(nonsending)` (per-function: run on the caller's execution context) and its inverse `@concurrent` (always the global executor); the module-wide default flip is gated behind the `NonisolatedNonsendingByDefault` upcoming-feature flag, so plain `nonisolated async` still hops to the global executor without it. Accessed 2026-06-07. |

**Availability note:** strict data-race-safety checking is the default in the **Swift 6 language mode** (Sept 2024, compiler-level), but opt-in *per target* (`SWIFT_VERSION = 6` / `swiftLanguageMode(.v6)`) — existing projects stay on their declared mode until bumped. `@MainActor` / `Sendable` / `MainActor.run` / `sending` back-deploy to `macOS 10.15+`; `.task` is `macOS 12.0+`. `@concurrent`, `nonisolated(nonsending)`, `-default-isolation MainActor`, the `NonisolatedNonsendingByDefault` flag, and named tasks (`Task(name:)`) are gated to **Swift 6.2+** — verify against your Xcode 26 SDK / Swift 6.2 toolchain before relying on any of them.

**Staged adoption (Mac AppKit/ObjC):** when a still-non-`Sendable` framework or ObjC header trips strict checking before its types are audited, `@preconcurrency import AppKit` (or the offending module) silences the not-yet-`Sendable` diagnostics at that import so you can adopt the language mode incrementally rather than all at once; drop it once the dependency ships proper `Sendable` annotations. For profiling concurrency in Instruments, give long-lived work a name — `Task(name: "image-decode") { … }` (Swift 6.2) — so tasks are identifiable in the Swift Concurrency instrument instead of anonymous.
