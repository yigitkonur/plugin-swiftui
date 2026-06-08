# Reference — Skippability & observation fan-out (vperf-04, vperf-08, vperf-09)

SwiftUI skips re-rendering a child only when it can *prove* the child's inputs are unchanged. A closure
prop it can't value-compare, a fast-changing `@Environment` value read by many views, or an over-broad
`@Observable` read each defeats that proof. These are **judgment** defects — READ before reporting; the
fix shapes below are confirmed via `swiftui-ctx lookup`.

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain.**

---

## vperf-04 — a closure passed as a child view's stored prop

A closure stored in a child **can't be value-compared**, so SwiftUI can't skip the child on a parent
re-render. Two fixes, in order of preference:

1. **Prefer**: let the child read shared `@Observable`/`@Environment` state instead of receiving a
   callback — then there's no closure to compare.
2. **When the child must keep the closure**: make the child `Equatable` (or wrap it in `EquatableView`,
   real since macOS 10.15 — `swiftui-ctx lookup EquatableView` → 100% consensus `(content)`) so SwiftUI
   compares the child's **other** props and skips re-render. Keeping the closure *stable* alone is **not
   enough** — SwiftUI still can't compare a function value, so without `Equatable` the child is never
   skipped.

```swift
// ❌ WRONG — child stores a closure; can't be compared → re-renders with the parent every time
struct Row: View { let onTap: () -> Void; let title: String; var body: some View { … } }
// ✅ CORRECT — make the child Equatable on its comparable data; SwiftUI skips when `title` is unchanged
struct Row: View, Equatable {
    let onTap: () -> Void; let title: String
    static func == (a: Row, b: Row) -> Bool { a.title == b.title }   // compare the data, ignore the closure
    var body: some View { … }
}
```

## vperf-08 — a fast-changing value stored in `@Environment`

`@Environment` **fans out widely**: every view reading a given key is re-checked when that value changes.
A fast-changing value there — a timer tick, drag/scroll geometry, anything updating many times a second —
re-evaluates the **whole subtree of subscribers on every tick** (WWDC25 session 306 warns against
exactly this).

```swift
// ❌ WRONG — a timer tick pushed through the environment; every reader's subtree re-evaluates per tick
.environment(\.tickTime, now)        // many views read \.tickTime → broad fan-out
// ✅ CORRECT — keep fast state in a narrowly-scoped @State/@Observable read only by the view that needs it
@State private var tickTime = Date() // local; reserve @Environment for slow-changing, broadly-shared config
```

## vperf-09 — over-broad `@Observable` observation (render cost)

A view that reads a *whole* broad `@Observable` model re-evaluates its `body` when **any** field it
touches changes. The render-cost angle is **ours**; the **state-correctness / granularity** angle (the
computed-`some View` smell, extract-to-a-child-type) is owned by `audit-swiftui-state-observation`
(state-07). Emit `cross_ref: audit-swiftui-state-observation/state-07` on this seam — don't restate the
granularity rule or double-own the perf number.

```swift
// ❌ WRONG — the view reads the broad model; any tracked-field change re-runs this body
struct Header: View { let model: AppModel; var body: some View { Text(model.title) } }  // re-renders on model.anyField
// ✅ CORRECT — pass only the field the view needs; the parent's per-field observation does the gating
struct Header: View { let title: String; var body: some View { Text(title) } }
```

Confirm *which* property drives a re-render with `Self._printChanges()`
(`references/rendering-model-and-profiling.md`) before reporting — an unexpected property name is the
signature of over-broad observation.

---

## Sources

- WWDC25 "Discover the new SwiftUI instrument." (session 306) — the `@Environment`
  high-frequency fan-out warning; the Cause & Effect graph:
  https://developer.apple.com/videos/play/wwdc2025/306/ (accessed 2026-06-07).
- Apple — `EquatableView`: https://developer.apple.com/documentation/swiftui/equatableview ·
  `View.equatable()`: https://developer.apple.com/documentation/swiftui/view/equatable() ·
  `Environment`: https://developer.apple.com/documentation/swiftui/environment ·
  `Observable` (macro): https://developer.apple.com/documentation/observation/observable()
  (fetch via Sosumi; accessed 2026-06-07).
