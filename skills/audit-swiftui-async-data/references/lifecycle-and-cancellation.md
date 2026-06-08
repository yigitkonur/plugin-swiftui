# Reference — Lifecycle & Cancellation (async-01, async-09)

How view-lifecycle async loading should be bound, cancelled, and guarded against stale results. The
canonical concurrency facts (`.task` is `@MainActor`, `Sendable` crossing) live in
`${CLAUDE_PLUGIN_ROOT}/skills/build-macos-swiftui/references/concurrency.md` mistake 4; this file is the
audit framing. **Get the ✅ shapes from `swiftui-ctx`, not from memory** —
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup task --json` returns the consensus shape and a
permalinked macOS-26 example (do not paste a static snippet as the canonical one).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## async-01 — bare `Task {}` in `.onAppear` (LIFECYCLE)

The pre-`.task` habit: kick off the load in `.onAppear { Task { … } }`. That `Task` is **unstructured** —
it is not tied to view identity, so it is **not cancelled when the view disappears**. It leaks, and a
re-appearing view launches a second one that races the first.

❌ **WRONG** — not bound to view lifetime:
```swift
.onAppear { Task { await model.load() } }            // never cancelled on disappear
```

✅ **CORRECT** — `.task` binds the work to view identity and auto-cancels; `.task(id:)` restarts on change.
The consensus shape (`swiftui-ctx lookup task`: 70% `{ }`, 29% `(id)`) and a real macOS-26 site:
```swift
.task { await model.load() }                          // cancelled when the view goes away
.task(id: selectedID) { await model.load(selectedID) }   // restarts when id changes
```
The `.task` closure **inherits the actor context of its call site** — in a SwiftUI `View.body` (itself `@MainActor`) that means the closure runs on the main actor, so view-state mutation inside needs no extra hop in normal use. This is inherited context via `@_inheritActorContext`, not an explicit `@MainActor` annotation; a `.task` applied from a non-`@MainActor` call site would not inherit it.

**Seam (own the lifecycle, not the isolation).** This skill fixes only the lifecycle move. If the captured
loading state is **non-`Sendable`** (a model `class`, `ModelContext`, an `NSView`), the isolation verdict
is `concurrency-safety`'s — emit `cross_ref: concurrency-safety` and keep the fix to `.task`. When the
state is already `Sendable`/`@MainActor`-safe, the `Task{}`→`.task` rewrite is mechanical (`fix_mode: auto`).

`Task {}` still has a legitimate home: a one-shot button action or fire-and-forget side effect — that is
**not** async-01. Only a *view-lifecycle load* in `.onAppear` fires this.

---

## async-09 — no stale-result / generation guard

With `.task(id:)` on a rapidly-changing selection (or a manual relaunch), an older load that is mid-flight
when the id changes can still deliver and **overwrite the newer result**. Cancellation alone does not stop
an already-suspended task from resuming once and writing.

❌ **WRONG** — last writer wins, regardless of order:
```swift
.task(id: selectedID) { items = await fetch(selectedID) }   // a slow old fetch clobbers the new one
```

✅ **CORRECT** — gate the write behind a generation counter (or check `Task.isCancelled` before writing):
```swift
@State private var generation = 0
.task(id: selectedID) {
    let mine = generation + 1; generation = mine
    let result = await fetch(selectedID)
    guard mine == generation, !Task.isCancelled else { return }   // newer load won → drop
    items = result
}
```
Hold an explicit handle (`@State private var loadTask: Task<Void, Never>?`) and `loadTask?.cancel()` before
relaunching when you trigger loads manually rather than via `.task(id:)`.

**Detection.** async-09 is hard to grep (it is the *absence* of a guard around a write that follows an
`await` inside `.task(id:)`). Locate `.task(id:` sites in READ; flag any whose post-`await` write has no
generation/`isCancelled`/cancel-prior guard. Carry as `warning`, `flag-only`, `cross_ref:
concurrency-safety` when a `Sendable` boundary is also involved.

---

## Sources

- Apple — `https://developer.apple.com/documentation/swiftui/view/task(priority:_:)` and
  `/documentation/swiftui/view/task(id:priority:_:)` (the lifecycle-bound async modifiers; closure
  inherits caller's actor context — `@MainActor` in normal `View.body` use via `@_inheritActorContext`;
  cancelled on disappear), fetched via Sosumi. Accessed 2026-06-07.
- Apple — `https://developer.apple.com/documentation/swift/task/iscancelled` and
  `/documentation/swift/task/cancel()` (cooperative cancellation), via Sosumi. Accessed 2026-06-07.
- swiftui-ctx corpus — `lookup task` consensus `{ }` 70% / `(id)` 29%; recommended macOS-26 example
  `https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Utilities.swift#L5590`
  (`.task(id:)`). Accessed 2026-06-07.
