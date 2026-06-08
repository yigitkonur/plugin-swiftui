# Reference — The rendering model & profiling (vperf-12 + the workflow's render test)

Before reporting a perf finding, *prove* the re-render. SwiftUI gives two zero-to-low-setup tools that
attribute a `body` re-evaluation to its cause. This file backs the workflow's "render test" and the
vperf-12 leftover-debug strip, and describes the optional `_render-cost-map.md` artifact.

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain.**

---

## The identity / dependency model (one paragraph)

A SwiftUI view has an **identity** (which view it *is*, across renders) and a set of **dependencies**
(state it reads). When a dependency changes, SwiftUI re-evaluates that view's `body` and diffs the
result against the previous one, skipping unchanged subtrees. Performance defects come from three
failures: (1) doing expensive work *inside* the re-evaluated `body`/`init` (vperf-01/05/06); (2)
breaking identity so a subtree can't be skipped and is recreated (vperf-02/03); (3) widening or
mis-routing dependencies so too many views re-evaluate too often (vperf-04/08/09) or too many rows
build at once (vperf-07/10/11).

## `Self._printChanges()` — the fastest "why did this re-render?"

Drop it as the **first line of a suspect `body`**; it prints which dependency caused that `body` to
re-evaluate:

```swift
var body: some View {
    let _ = Self._printChanges()      // prints @self / a property name / @identity to the console
    …
}
```

Read the printed cause:
- **`@identity`** → the view's identity changed → an identity bug (vperf-02 `.id(UUID())` or vperf-03
  `AnyView`). The subtree is being recreated, not updated.
- **a specific property name** → that property is the dependency. If it's a property you didn't expect
  this view to read, that's **over-broad observation** (vperf-09) — narrow the read.
- **`@self`** → the whole value changed (e.g. a new struct instance from the parent) → look at what the
  parent passes (a fresh closure/array each render → vperf-04/07).

## vperf-12 — `Self._printChanges()` left in shipping code (fix_mode: auto)

`Self._printChanges()` is a **debug probe**, not production code — it runs on every render and prints to
the console. Strip it before shipping. This is the one mechanical, single-answer fix in the domain:
delete the `let _ = Self._printChanges()` line (and its lone-line whitespace). Auto-applied under the
fix-safety protocol; DOUBLE-CHECK re-greps the file to confirm the line is gone.

## The SwiftUI Instrument (Instruments 26) — the deeper tool

For attributing *cost* (not just cause), the **SwiftUI track** in Instruments 26 and its **Cause &
Effect graph** map update cost to the state change that triggered it — the canonical macOS-26 tool for
finding expensive `body` work and excessive updates (WWDC25 session 306). Use it when
`Self._printChanges()` shows *which* dependency but you need *how much* it costs.

## Optional artifact — `_render-cost-map.md`

A go-beyond deliverable: a table of each suspect view + the `Self._printChanges()` cause that drives its
re-render + which vperf-id it maps to. Written to
`swiftui-audits/view-performance/_render-cost-map.md`; lets a reviewer see the whole render-cost picture
at a glance, not just one finding at a time.

---

## Sources

- WWDC25 "Discover the new SwiftUI instrument." (session 306) — the SwiftUI Instrument in
  Instruments 26 and its Cause & Effect graph: https://developer.apple.com/videos/play/wwdc2025/306/
  (accessed 2026-06-07).
- WWDC21 "Demystify SwiftUI" (session 10022) — identity, lifetime, dependencies (the diffing model):
  https://developer.apple.com/videos/play/wwdc2021/10022/ (accessed 2026-06-07).
- `Self._printChanges()` is an Apple-provided SwiftUI debug API (see the session 10160/306 demos);
  Apple — `View`: https://developer.apple.com/documentation/swiftui/view (fetch via Sosumi; accessed 2026-06-07).
