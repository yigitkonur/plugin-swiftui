# Ownership wrappers — the two failure shapes (state-01, state-04)

The single most error-dense corner of AI-written SwiftUI: a view-owned model paired with the **wrong
ownership wrapper**. The root cause is always the same — **`@ObservedObject` does not own or persist its
object** — but it surfaces as one of two opposite shapes depending on the model's *kind*. Diagnose by
which one you're looking at; the shape *is* half the fix, and it also sets the severity.

## The ownership test (run this first)

Does **this view** create the model (`= Model()` on the declaration)? → it **owns** it → an **owning
wrapper**. Is the model **passed in / injected**? → a **non-owning wrapper**.

| Model kind | Own it (created here) | Pass it in (created elsewhere) |
|---|---|---|
| value type (`struct`, `enum`) | `@State` | `@Binding` |
| `@Observable` class (modern) | `@State` | `@Bindable` |
| `ObservableObject` class (legacy) | `@StateObject` | `@ObservedObject` |

**Never initialize a model inside `@ObservedObject` / `@Bindable`** — both are for objects owned
elsewhere and passed in. An `= Type()` after either is the state-01 tell.

## state-01 — initializer on a non-owning wrapper (TWO failure shapes)

The same tell (`@ObservedObject var x = Type()`) produces opposite results by model kind. **Read the
`class` declaration to classify `Type`** before reporting — it sets `failure_shape`, the fix, AND the
severity.

### Shape A — SILENT runtime reset (`failure_shape: silent-reset`, severity warning)

`Type` is a real `ObservableObject`. The wrapper *accepts* it and **compiles** — but `@ObservedObject`
does not own the instance, so when the parent re-renders SwiftUI rebuilds the struct, the initializer
runs again, and all accumulated state silently resets to defaults. No compile error, no crash — a
counter that "won't count." Fix: the owning wrapper — `@StateObject` (legacy) or `@State` (modern).

```swift
// ❌ WRONG (silent reset) — real ObservableObject, created + "owned" under @ObservedObject
struct CounterView: View {
    @ObservedObject var model = CounterModel()     // CounterModel: ObservableObject → compiles,
    var body: some View { Text("\(model.count)") } // but recreated on every parent re-render
}
```

### Shape B — likely compile error (`failure_shape: compile-error`, severity hard-fail)

`Type` is `@Observable`. Per Apple's `@ObservedObject` docs: *"Attempting to wrap an Observable object
with @ObservedObject **may** cause a compiler error, because it requires that its wrapped object conform to
the ObservableObject protocol."* Apple's language deliberately hedges with "may"; in practice the Swift
compiler does reject this — treat it as a build break — but note the spec's hedge when reporting.
Fix: `@State` (owned) or `@Bindable` (passed in).

```swift
// ❌ WRONG (compile error) — @Observable type cannot satisfy @ObservedObject's ObservableObject requirement
@available(macOS 14, *)
struct CounterView2: View {
    @ObservedObject var model = CounterModel()     // CounterModel is @Observable → does NOT compile
    var body: some View { Text("\(model.count)") }
}
```

## state-04 — `@StateObject` mismatched to the model kind

`@StateObject` is constrained to **reference types**. A `struct`/`enum` cannot be a `@StateObject` →
**hard compile error** (`failure_shape: compile-error`); use `@State`. It *accepts* a plain `@Observable`
class (Apple allows this for migration), but that leaves you on the legacy wrapper — a **migration
smell** (`failure_shape: migration-smell`, advisory), not the idiom; finish converting to `@State`.

```swift
// ❌ WRONG (compile error) — @StateObject needs a reference type; a struct is not one
struct V: View { @StateObject private var settings = SettingsStruct() }   // value type → error → @State
// ⚠️ SMELL (compiles) — @Observable accepted by @StateObject, but should be @State
struct W: View { @StateObject private var model = ModelObservable() }     // finish migrating → @State
```

## ✅ The correct shape — grounded in swiftui-ctx (do not hand-write the ✅)

The fix's ✅ is the **consensus shape + a permalinked real example**, not opinion. Get it live:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx recipe observable-model    # the canonical own-with-@State pattern
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup State --json        # @State consensus + recommended
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file ex_44cfa1bff8 --smart # the recommended @Observable model, live
```

The `observable-model` recipe's consensus (accessed 2026-06-07): own a modern model with `@State`, bind
with `$model.prop`:

```swift
// ✅ CORRECT — modern @Observable owned by the view → @State (macOS 14+). Consensus per swiftui-ctx
//    recipe observable-model; recommended example ex_44cfa1bff8 (Gremble-io/Detto, @Observable @MainActor).
@available(macOS 14, *)
@Observable final class CounterModel { var count = 0 }

@available(macOS 14, *)
struct CounterView: View {
    @State private var model = CounterModel()        // stable, SwiftUI-managed lifetime
    var body: some View { Stepper("\(model.count)", value: $model.count) }
}

// ✅ CORRECT — legacy ObservableObject owned by the view → @StateObject (still real, not deprecated)
struct LegacyCounterView: View {
    @StateObject private var model = LegacyCounterModel()   // LegacyCounterModel: ObservableObject
    var body: some View { Text("\(model.count)") }
}
```

`@StateObject` is **not deprecated** — `swiftui-ctx deprecated StateObject` returns `deprecated:false`,
no replacement (accessed 2026-06-07). The defect is the *wrong-kind pairing*, never a deprecation flag.

## Severity & fix mode

- state-01 shape A → `warning`, `fix_mode: flag-only` (the owner intent — `@State` vs hoist-and-inject —
  is a human call). Shape B → `hard-fail`, `flag-only`.
- state-04 value type → `hard-fail`, `flag-only`; plain-`@Observable` smell → `advisory`, `flag-only`.
- All are `flag-only`: a wrapper swap depends on ownership intent only a human confirms (per SKILL.md
  confidence gating). Set `model_kind` + `failure_shape` in the finding frontmatter.

## Sources

- **Apple — `ObservedObject`.** *"Attempting to wrap an Observable object with @ObservedObject may cause a
  compiler error, because it requires that its wrapped object conform to the ObservableObject protocol."*
  https://developer.apple.com/documentation/swiftui/observedobject — accessed 2026-06-07 (via Sosumi).
- **Apple — `StateObject`.** Reference-type owner; `macOS 11.0+`.
  https://developer.apple.com/documentation/swiftui/stateobject — accessed 2026-06-07 (via Sosumi).
- **Apple — `State` / `Bindable`.** `https://developer.apple.com/documentation/swiftui/state` ·
  `https://developer.apple.com/documentation/swiftui/bindable` — accessed 2026-06-07 (via Sosumi).
- **Jesse Squires — "SwiftUI's `@Observable` macro is not a drop-in replacement for `ObservableObject`,"
  2024-09-09.** *"Use the `@StateObject` property wrapper with `ObservableObject` and use the `@State`
  property wrapper with `@Observable`."* https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/
  — accessed 2026-06-06.
