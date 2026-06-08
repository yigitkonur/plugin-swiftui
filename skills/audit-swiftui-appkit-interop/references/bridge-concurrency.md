# Bridge concurrency — the Swift-6 race at the Coordinator boundary (interop-06)

`fix_mode: flag-only`. **hard-fail** under the Swift 6 language mode. `cross_ref: concurrency-safety` (that
skill owns the isolation model in depth — use `swift_era` + `isolation_kind` on the finding).

The Coordinator boundary is exactly where Swift 6's strict data-race checking bites on Mac.
`updateNSView`, Coordinator delegate callbacks, and `NSView` action targets are `@MainActor` AppKit
surfaces. Route a callback out (or feed state in) through a closure typed `@Sendable` and the compiler
errors: a `@Sendable` closure can run on any thread, so synchronously reading/writing main-actor state
inside it is a data race — *"Main actor-isolated property '…' can not be referenced from a Sendable
closure."* This is a hard **error** under the Swift 6 language mode, not a warning.

❌ read main-actor state inside a `@Sendable` closure, or GCD-hop to dodge the checker:
```swift
func controlTextDidChange(_ obj: Notification) {
    runOffMain { self.parent.text = "x" }        // ❌ Sendable closure can't touch main-actor parent
}
// also wrong: DispatchQueue.main.async { self.parent.text = ... }  // ❌ side-steps the very check Swift 6 enables
```

✅ isolate the closure to the main actor (you own the API), capture-by-value for reads, or hop with an
annotation (not GCD):
```swift
// You own the receiving function: mark the closure @MainActor so reading main-actor state is legal.
func runOnMain(_ work: @Sendable @MainActor @escaping () -> Void) { /* ... */ }

// You don't own it but only READ a value: capture by value in the capture list.
runOffMain { [text = parent.text] in print(text) }   // captures the value, not the isolated property

// Hopping back to the main actor from a nonisolated context — annotation, not GCD:
await MainActor.run { parent.text = newValue }
```
Capture-by-value works for **reads only**; mutating main-actor state from a `@Sendable` closure needs an
`await` / `MainActor.run` hop.

**UNVERIFIED — carry as `verify against Xcode 26 SDK`, never assert:**
- A fresh Xcode 26 macOS target often ships *Default Actor Isolation = Main Actor*
  (`-default-isolation MainActor`), which pre-isolates the closure and **masks** this error. interop-06
  fires only when that mode is **off** — it is an opt-in build setting, not the unconditional language
  default. Read `SWIFT_STRICT_CONCURRENCY` / the isolation setting in ORIENT before flagging.
- `@concurrent` (for deliberately running heavy decode off-main) and `-default-isolation MainActor` are
  **Swift 6.2+** toolchain-gated — gate any use behind that toolchain.

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://www.donnywals.com/solving-main-actor-isolated-property-can-not-be-referenced-from-a-sendable-closure-in-swift/ | practitioner | the error text; fix depends on ownership — `@Sendable @MainActor` closure when you own the API; `[count]` capture-list for reads; mutation needs an `await`/`Task` hop. Accessed 2026-06-07. |
| https://www.hackingwithswift.com/swift/6.0/concurrency | practitioner | *"complete concurrency checking is enabled by default"* in the Swift 6 language mode — main-actor warnings become hard errors. Accessed 2026-06-07. |
| https://swift.org/blog/swift-6.2-released/ | primary-doc | "main actor by default" is *"the new option to isolate code to the main actor"* (opt-in, `-default-isolation MainActor`), not the unconditional default; `@concurrent` is new in Swift 6.2 (Sept 15 2025). Accessed 2026-06-07. |
