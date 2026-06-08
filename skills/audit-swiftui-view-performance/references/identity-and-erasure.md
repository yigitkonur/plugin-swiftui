# Reference — Identity churn & type-erasure (vperf-02, vperf-03)

SwiftUI diffs by **identity**: a stable id lets it *skip* an unchanged subtree; a concrete type lets it
*compare* the subtree across renders. Both defects below throw that away, forcing recreation. Neither
symbol is hallucinated — `.id(_:)` and `AnyView` are **real APIs misused** (confirmed:
`swiftui-ctx deprecated AnyView` → not deprecated, no replacement); findings are `warning`, not
`hard-fail`.

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain.**

---

## vperf-02 — `.id(UUID())` forces full recreation every render (fix_mode: auto)

A fresh `UUID()` on every `body` evaluation is a brand-new identity each time → SwiftUI discards the old
view, recreates it, loses its `@State`, and cannot diff.

```swift
// ❌ WRONG — new identity each render → recreated, state lost, no diffing
RowView(item: item).id(UUID())
// ✅ CORRECT — a stable identity tied to the data
RowView(item: item).id(item.id)
```

**Auto-fix** only when the stable id is unambiguous (the row's `item.id`/`element.id` is in scope). If
the id is supposed to force a deliberate reset on a *specific* state change, the intent is a value that
changes only then — not `UUID()`; READ before auto-applying. A `ForEach` already keys on its `id:`, so
an extra `.id(UUID())` on a row inside it is pure churn.

## vperf-03 — `AnyView` erases the type SwiftUI needs to diff

Type-erasure defeats structural diffing — once a subtree is an `AnyView`, SwiftUI can't compare it
against the previous render, so it can't skip it. The fix keeps the concrete type with `@ViewBuilder`
(returns `some View`), confirmed via `swiftui-ctx lookup "@ViewBuilder"`.

```swift
// ❌ WRONG — type erased; subtree can't be diffed/skipped
func cell() -> AnyView { AnyView(Text("hi")) }
// ✅ CORRECT — @ViewBuilder preserves the concrete type
@ViewBuilder func cell() -> some View { Text("hi") }
```

When two branches return *different* concrete types (the usual reason people reach for `AnyView`),
`@ViewBuilder` handles it via SwiftUI's built-in `_ConditionalContent` — you do **not** need `AnyView`
for an `if/else`. READ to confirm it's view code: a deliberate `[AnyView]` heterogeneous collection in a
data layer is a different (rarer) case — flag it, don't blind-auto-fix; this stays `flag-only`.

---

## Sources

- WWDC21 "Demystify SwiftUI" (session 10022) — identity, lifetime, the structural-diffing model:
  https://developer.apple.com/videos/play/wwdc2021/10022/ (accessed 2026-06-07).
- Apple — `View.id(_:)`: https://developer.apple.com/documentation/swiftui/view/id(_:) · `AnyView`:
  https://developer.apple.com/documentation/swiftui/anyview · `ViewBuilder`:
  https://developer.apple.com/documentation/swiftui/viewbuilder (fetch via Sosumi; accessed 2026-06-07).
