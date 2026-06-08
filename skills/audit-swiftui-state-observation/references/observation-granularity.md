# Observation granularity (state-07, state-11)

Two model-/view-shape issues that are correct in output but waste invalidation work specific to
`@Observable`. Both are `advisory`, `flag-only`.

## state-07 — `@Observable` reads hidden in a computed `some View` property (perf)

Not a correctness bug — a **performance regression** specific to `@Observable`. Observation tracks
per-property access at the granularity of a `View`'s `body`. A computed `some View` property folds into the
**parent's** body, so a change to **any** tracked property the parent reads re-evaluates the whole parent —
including the computed sub-view. Extract into a real child `View` **type** (its own `body`), passing only
the data it needs, so it gets its own per-property invalidation.

```swift
// ❌ WRONG (perf) — AI splits the view into a computed property to "tidy" it
@available(macOS 14, *)
struct DashboardView: View {
    @State private var vm = DashboardModel()
    var body: some View { header; list }
    private var list: some View { /* reads vm.items */ Text("…") }  // computed, folds into parent body
    private var header: some View { Text("…") }
}
```

```swift
// ✅ CORRECT — extract into a real child View TYPE (macOS 14+)
@available(macOS 14, *)
struct DashboardView: View {
    @State private var vm = DashboardModel()
    var body: some View { Header(); ItemList(items: vm.items) }
}
@available(macOS 14, *)
struct ItemList: View { let items: [Item]; var body: some View { /* … */ } }
```

**Detection nuance:** the tier-2 rule `state-07` anchors on a `property_declaration` with an `opaque_type`
of `View` + a `computed_value: computed_property`, excluding `body` by name (grep can't separate a computed
view property from a stored one, nor exclude the required `body`). **READ** the property: report only when
it actually reads an `@Observable` model — a computed `some View` that reads only `let`/passed-in data is
fine. **Seam:** this owns the **state-correctness / granularity** angle; the render-cost *number* is
`audit-swiftui-view-performance` — emit `cross_ref: audit-swiftui-view-performance` per the cross-ref graph.

## state-11 — missing `@ObservationIgnored` on non-UI stored state (model hygiene)

The `@Observable` macro tracks **every** stored property by default. A mutable cache, back-pointer, or
non-UI bookkeeping field that mutates frequently will invalidate views for changes nothing displays. Mark
such fields `@ObservationIgnored` so mutating them never triggers invalidation.

```swift
// ✅ CORRECT — UI-relevant fields tracked; a private cache opts out (macOS 14+)
@available(macOS 14, *)
@Observable final class SearchModel {
    var query = ""                                                  // tracked: typing redraws results
    @ObservationIgnored private var cache: [String: [Result]] = [:] // never triggers invalidation
}
```

**Detection nuance:** the grep tell only flags that an `@Observable` class is present — **READ** it to
judge whether a stored property is genuinely non-UI bookkeeping (cache/back-ref/coordinator handle) that
should opt out. A tracked-but-displayed property must stay tracked; over-flagging here is wrong.

## ✅ grounded in swiftui-ctx

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup ObservationIgnored --json  # introduced_macos 14.0, real call sites
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart     # a real @ObservationIgnored model, live
```

Cite the recommended permalink as the ✅ `## Source`.

## Severity & fix mode

- state-07 → `advisory`, `fix_mode: flag-only` (`failure_shape: over-render`; the extraction is a design
  change). `cross_ref: audit-swiftui-view-performance`.
- state-11 → `advisory`, `fix_mode: flag-only` (`failure_shape: over-render`; which fields opt out is a
  judgment a human confirms). `model_kind: observable`.

## Sources

- **Apple — `ObservationIgnored()` macro.** `macOS 14.0+`. Disables observation tracking for a stored
  property of an `@Observable` type.
  https://developer.apple.com/documentation/observation/observationignored() — accessed 2026-06-07 (via Sosumi).
- **Apple — `Observable()` macro.** Tracks every stored property by default; `macOS 14.0+`.
  https://developer.apple.com/documentation/observation/observable() — accessed 2026-06-06 (via Sosumi).
- **Paul Hudson — "What to fix in AI-generated Swift code," 2025-12-09.** Computed-property views defeat
  `@Observable` invalidation. https://www.hackingwithswift.com/articles/281/what-to-fix-in-ai-generated-swift-code
  — accessed 2026-06-06.
