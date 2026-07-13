# Reference — Isolation Modes & Execution Context (conc-05/06/07/08)

The Swift 6.2 era: the **opt-in "main actor by default" build mode** and the **per-function execution
spellings**. Everything here is **Swift 6.2+** and verified against **swift.org / Swift Evolution**
(SE-0338, SE-0461), **not swiftui-ctx** — the corpus shows usage, not toolchain semantics. Carry every
6.2 fact as `advisory` with `source: verify against Xcode 26 SDK` unless the target toolchain is
confirmed 6.2+ in ORIENT.

> The opt-in mode is `-default-isolation MainActor` (Xcode: *Default Actor Isolation = Main Actor* /
> *Approachable Concurrency*). It is a **setting you turn on**, never the unconditional language
> default. The unconditional Swift 6 default is **data-race-safety checking**, not isolation.

---

## conc-05 — `@MainActor` spam on value logic

`@MainActor` sprinkled on pure value types and free functions "to be safe". Pure logic forced onto the
main actor for no reason.

❌ **WRONG** — value logic needlessly isolated:
```swift
@MainActor struct Math { @MainActor static func add(_ a: Int, _ b: Int) -> Int { a + b } }
```
✅ **CORRECT** — isolate only what touches UI; leave value logic free:
```swift
enum Math { static func add(_ a: Int, _ b: Int) -> Int { a + b } }   // no isolation needed
```
**Why:** if the mode is ON, UI types are *already* isolated — the `@MainActor` is redundant; mark
genuinely-parallel code `nonisolated`. If the mode is OFF, isolate UI-touching types explicitly but
never pure computation. Know the mode before adding or removing the annotation.

## conc-06 — `@Observable` UI type with no isolation, assuming "6.2 does it"

The opposite extreme of the same misread: dropping `@MainActor` from a UI-touching `@Observable`
"because Swift 6.2 makes everything main-actor-by-default" — but the mode is **OFF**. **SEAM:
`state-observation` owns model-correctness; this skill owns the isolation angle (cross_ref).**

❌ **WRONG** — assumed isolated, mode is off:
```swift
@Observable final class ViewModel { var items: [Item] = [] }   // ❌ touches UI, no @MainActor, mode OFF
```
✅ **CORRECT** — annotate explicitly when the mode is off (the common case):
```swift
@MainActor @Observable final class ViewModel { var items: [Item] = [] }
// Mode ON (a fresh Xcode 26 Mac app may enable it): the @MainActor is redundant — drop it.
```
**Why:** "main actor by default" is the **new option** to isolate code to the main actor
(`-default-isolation MainActor`), not the unconditional default. Check the build setting; a fresh Xcode
26 Mac template frequently enables it, an existing or library target usually does not.

## conc-07 / conc-08 — execution context: `@concurrent` vs `nonisolated(nonsending)` vs plain `nonisolated async`

The common AI error (conc-08): claiming a **`nonisolated async` function runs in the caller's context by
default on Swift 6.2**. It does **not**. Caller-context execution is the `NonisolatedNonsendingByDefault`
**upcoming-feature flag** (SE-0461); without it — even on 6.2 — a plain `nonisolated async` function
still **hops to the global (concurrent) executor** (SE-0338), as before. Three states, not two.

❌ **WRONG** — assert caller-context as the plain 6.2 default:
```swift
nonisolated func decode(_ url: URL) async -> Image { heavyDecode(url) }
// ❌ "on 6.2 this stays on the caller's actor" — FALSE without the flag; it hops to the global executor.
```
✅ **CORRECT** — pick the spelling, don't rely on a default:
```swift
// (a) OFF the main actor (heavy work): @concurrent ALWAYS runs on the global executor.   [conc-07]
@concurrent static func decodeLargeImage(_ url: URL) async throws -> Image { /* on the pool */ }
// call: .task { self.image = try? await Loader.decodeLargeImage(url) }

// (b) CALLER's context per function (no global flag): nonisolated(nonsending).            [conc-08]
//     Ideal at an AppKit Coordinator / NSViewRepresentable boundary that's already main-actor.
nonisolated(nonsending) func validate(_ text: String) async -> Bool { /* stays on the caller */ }

// (c) Module-wide caller-context default: enable the flag, then @concurrent marks exceptions.
//     SPM:   .enableUpcomingFeature("NonisolatedNonsendingByDefault")
//     swiftc: -enable-upcoming-feature NonisolatedNonsendingByDefault
```
**Why:** `@concurrent` (always global executor) and `nonisolated(nonsending)` (always caller's context)
are explicit opposites — they behave the same with or without the flag. The flag only changes the
**default** for *unannotated* `nonisolated async` functions. All three need **Swift 6.2+** — gate them;
never emit them for a 6.0/6.1 target. On Mac, reach for `nonisolated(nonsending)` at AppKit
`Coordinator`/`NSViewRepresentable` async callbacks (cross_ref `appkit-interop`), and `@concurrent` for
heavy image/document decode that must stay off the main actor — never GCD.

---

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://swift.org/blog/swift-6.2-released/ | primary-doc | "main actor by default" is "*the new option to isolate code to the main actor by default*" (OPT-IN, `-default-isolation MainActor`), not the unconditional default; sample headed `// In '-default-isolation MainActor' mode`; `@concurrent` makes parallel intent explicit. The caller's-context behavior it describes is the `NonisolatedNonsendingByDefault` upcoming feature. Holly Borla, Sept 15 2025. Accessed 2026-06-07. |
| https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md | primary (Swift Evolution) | SE-0461 — `nonisolated(nonsending)` runs on the caller's execution context; `@concurrent` always the global executor; the module-wide flip is gated behind the `NonisolatedNonsendingByDefault` upcoming-feature flag, so plain `nonisolated async` still hops to the global executor without it. Accessed 2026-06-07. |
| https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md | primary (Swift Evolution) | SE-0338 — the pre-existing rule that a `nonisolated async` function hops to the global concurrent executor; this is what the flag replaces. Accessed 2026-06-07. |
