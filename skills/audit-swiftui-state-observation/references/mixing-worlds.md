# Mixing the two Observation worlds (state-02, state-03, state-08)

The migration from `ObservableObject` to `@Observable` is **not a mechanical rename**. AI defaults to the
legacy world (it predates the macro) and produces hybrids that compile but are semantically wrong, or are
redundant/contradictory. The pivot for every finding here is the model's `class` declaration.

## The two worlds (pick ONE per model)

| | Modern — `@Observable` (default, macOS 14+) | Legacy — `ObservableObject` (Combine / pre-14) |
|---|---|---|
| Declaration | `@Observable final class` — no `@Published`, no conformance | `class: ObservableObject` + `@Published` per field |
| Granularity | field-level (read-only-what-changed) | whole-object `objectWillChange` (over-renders) |
| Own | `@State` | `@StateObject` |
| Bind | `@Bindable` | `@ObservedObject`'s `$`, `@Binding` |
| Inject | `.environment(_:)` + `@Environment(Type.self)` | `.environmentObject(_:)` + `@EnvironmentObject` |

Legacy is **not deprecated** (`swiftui-ctx deprecated StateObject`/`ObservedObject` →
`deprecated:false`, accessed 2026-06-07) — but it is not the new-Mac-code idiom.

## state-02 — redundant `: ObservableObject` on an `@Observable` class (fix_mode: auto)

The `@Observable` macro replaces `ObservableObject`; keeping the conformance is contradictory. Drop it.

## state-03 — `@Published` inside an `@Observable` class (fix_mode: auto)

`@Observable` tracks every stored property automatically; `@Published` is meaningless under it. Remove it.
(Confirm the enclosing class is `@Observable` first — `@Published` in a real `ObservableObject` is correct.)

```swift
// ❌ WRONG — @Observable class but still ObservableObject-era machinery
@Observable class ViewModel: ObservableObject {    // state-02: redundant/contradictory conformance
    @Published var items: [Item] = []              // state-03: @Published meaningless under @Observable
}
struct ListView: View {
    @StateObject private var vm = ViewModel()       // state-08: wrong owner wrapper for @Observable
}
```

## state-08 — legacy wrappers kept after an `@Observable` migration (the not-a-drop-in smell)

Once the class is `@Observable`, the surrounding wrappers must follow: `@StateObject` → `@State`,
passed-in `@ObservedObject` → `@Bindable`. **Transitional note (don't over-flag):** Apple deliberately
lets `@StateObject`/`@EnvironmentObject` accept a *plain* `@Observable` type so a codebase can migrate
incrementally — `@StateObject var x: SomePlainObservable` is a `failure_shape: migration-smell` to finish
converting, **not** a hard error. The genuinely wrong part is the redundant `: ObservableObject` +
`@Published` (state-02/03), which *contradicts* the macro.

## ✅ The correct shape — grounded in swiftui-ctx

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Observable --json   # introduced_macos 14.0, recommended ex_44cfa1bff8
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file ex_44cfa1bff8 --smart # @Observable @MainActor final class, live from GitHub
```

The recommended example (`ex_44cfa1bff8`, `Gremble-io/Detto`, accessed 2026-06-07) is a plain
`@Observable @MainActor final class` — no `: ObservableObject`, no `@Published`:

```swift
// ✅ CORRECT — one world: @Observable, owned with @State (macOS 14+). Consensus per swiftui-ctx lookup
//    Observable (434 repos / 2485 uses); recommended ex_44cfa1bff8.
@available(macOS 14, *)
@Observable final class ViewModel {                 // no ObservableObject, no @Published
    var items: [Item] = []
}
@available(macOS 14, *)
struct ListView: View {
    @State private var vm = ViewModel()
    var body: some View { Table(vm.items) { /* columns … */ } }   // macOS-rich multi-column
}
```

## The world-map artifact (optional go-beyond)

`swiftui-audits/state-observation/_world-map.md`: one row per model `class` — its kind
(`modern`/`legacy`/`mixed`), owner wrapper, and ownership verdict. A `mixed` row (`@Observable` +
`@Published`/`: ObservableObject`) is the state-02/03 finding set; a `legacy` row under a macOS-14+ floor
is a migration candidate (state-08), not a defect on its own.

## Severity & fix mode

- state-02, state-03 → `warning`, **`fix_mode: auto`** (mechanical single-answer deletions; gated by the
  fix-safety protocol — confirm `@Observable` is on the class, drop the redundant token, re-read).
- state-08 → `warning`, `fix_mode: flag-only` (`@StateObject`→`@State` is mechanical, but
  `@ObservedObject`→`@Bindable`-vs-`@State` depends on whether the view owns it — a human call).

## Sources

- **Apple — Migrating from the Observable Object protocol to the Observable macro.** The `@State`/
  `@Bindable`/`@Environment` mapping; `@Published`/conformance are dropped under `@Observable`.
  https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
  — accessed 2026-06-06 (via Sosumi).
- **Apple — `Observable()` macro.** `macOS 14.0+`. https://developer.apple.com/documentation/observation/observable()
  — accessed 2026-06-06 (via Sosumi).
- **Paul Hudson — "What to fix in AI-generated Swift code," 2025-12-09.** Replace `ObservableObject` →
  `@Observable`. https://www.hackingwithswift.com/articles/281/what-to-fix-in-ai-generated-swift-code
  — accessed 2026-06-06.
- **Jesse Squires — "@Observable is not a drop-in replacement," 2024-09-09.**
  https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/ — accessed 2026-06-06.
