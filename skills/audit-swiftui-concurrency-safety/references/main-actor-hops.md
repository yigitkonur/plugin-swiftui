# Reference — Main-Actor Hops & Task Lifecycle (conc-03/04/10)

How async code reaches the main actor and how view-bound async work is scoped. These are era-stable
mechanics (`@MainActor` / `MainActor.run` back-deploy to `macOS 10.15+`; `.task` is `macOS 12.0+`), but
strict checking is what turns the GCD cargo-cult from "works" into "unverifiable".

> Confirm the canonical `.task` shape against the corpus:
> `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup task --json` — the corpus consensus is **70%
> `.task { }`, 29% `.task(id:)`**, and the highest-authority current example is the `recommended`
> permalink (put it in the finding's `## Source`). Floors:
> `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

---

## conc-03 — `DispatchQueue.main.async` cargo-cult (the one auto-fix)

The pre-`async/await` habit of hopping to the UI thread with GCD. It **side-steps the compiler's
isolation checking** — the very checking Swift 6 turns on — is unstructured, and doesn't compose with
`async/await` cancellation.

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
**Why:** `@MainActor` / `await MainActor.run` are *checkable* — the compiler proves the access is on the
main actor; `DispatchQueue.main.async` proves nothing. **fix_mode: auto** — the single mechanical
rewrite. Batch multiple post-async writes into **one** `MainActor.run` block so SwiftUI never renders an
intermediate state (e.g. `isLoading = false` before `items` is set → flash of empty content).

---

## conc-04 — bare `Task` in `.onAppear` (lifecycle leak)

Kicking off async work with a bare unstructured `Task` in `.onAppear`. That `Task` is **not** cancelled
when the view disappears, so it leaks and races a re-appearing view. **SEAM: `async-data` owns the
lifecycle fix (`.task` / `.task(id:)`); this skill owns the verdict only when an isolation hazard is
present** (a non-`Sendable` capture, an off-actor mutation). Emit `cross_ref: audit-swiftui-async-data`.

❌ **WRONG** — unstructured `Task`, not tied to view lifetime:
```swift
.onAppear { Task { await viewModel.load() } }   // ❌ never cancelled on disappear
```
✅ **CORRECT** — `.task` binds the work to view identity and auto-cancels:
```swift
.task { await viewModel.load() }                            // cancelled when the view goes away
.task(id: selectedID) { await viewModel.load(selectedID) }  // restarts when id changes
```
**Why:** `.task` (`macOS 12.0+`; closure inherits the caller's isolation via `@isolated(any)` — from a
`@MainActor` context, view-state mutation needs no extra hop) scopes async work to the view's lifetime. `Task {}` still has a place — quick async
coordination on a `@MainActor` type — but it inherits the caller's actor and stalls the UI on
blocking/CPU work (use `@concurrent` + a `Sendable` return for that, see
`isolation-modes-and-execution.md`). The structural tell is `lint/ast-grep/conc-04-task-in-onappear.yml`.

---

## conc-10 — stale results overwrite fresh ones (read-only tell)

Rapidly-changing selections (`selectedID` flips fast): a cancelled-but-still-finishing task delivers an
older result on top of a newer one. **No lint tell can prove a *missing* guard — this is read-only;
inspect every rapid-trigger `await`-then-write site by hand.**

✅ **CORRECT** — hold the handle, cancel before relaunching, gate writes behind a generation counter:
```swift
@State private var loadTask: Task<Void, Never>?
@State private var generation = 0

func reload(_ id: ID) {
    loadTask?.cancel()
    let captured = generation &+ 1; generation = captured
    loadTask = Task {
        let result = await fetch(id)
        guard generation == captured else { return }   // an older load can't overwrite a newer one
        items = result
    }
}
```
**Why:** cancellation is cooperative — a task already past its last `Task.isCancelled` check still runs
to completion and writes. The generation guard makes the write idempotent to ordering. Prefer
`.task(id:)` when the trigger is a single value; reach for the manual handle when several inputs drive
the reload. The lifecycle ownership of this seam is `async-data` (cross_ref).

---

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/view/task(priority:_:) | primary-doc | `.task` is the lifecycle-bound async modifier, `macOS 12.0+`; the closure inherits the caller's isolation via `@isolated(any)`, cancelled on view disappearance. Fetch via Sosumi. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swift/mainactor/run(resulttype:body:) | primary-doc | `MainActor.run` runs a body on the main actor from a nonisolated async context; back-deploys to `macOS 10.15+`. Fetch via Sosumi. Accessed 2026-06-07. |
| https://www.hackingwithswift.com/quick-start/concurrency/how-to-use-a-task-to-perform-asynchronous-work | practitioner | `Task {}` inherits the caller's actor; unstructured tasks in `.onAppear` are not cancelled with the view; cancellation is cooperative. Accessed 2026-06-07. |
