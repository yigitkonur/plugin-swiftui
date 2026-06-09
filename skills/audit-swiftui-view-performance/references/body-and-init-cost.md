# Reference — Cost in `body` and `init` (vperf-01, vperf-05, vperf-06)

`body` runs on **every dependency change**; a `View`'s `init` runs **every time its parent re-evaluates
`body`**. Both are hot paths — work placed there is paid on every render. The ✅ shapes below come from
`swiftui-ctx lookup` (the consensus shape) + a permalinked real example; verify each fix target's floor
via Sosumi (`references/source-directory.md`) and `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain.**

---

## vperf-01 — a heavyweight built inside `body` (or a computed view prop)

Allocating a `DateFormatter`/`NumberFormatter`/`JSONDecoder`/`ISO8601DateFormatter`/`JSONEncoder`/`RelativeDateTimeFormatter` inside `body` builds
a fresh one on every render. (Why tier-2 ast-grep, not grep: a flat `DateFormatter(` cannot distinguish
a constructor *inside* `body` from a correctly *hoisted* `static let` at type scope — the latter is the
fix. The structural rule fires only on the in-`body` case.)

```swift
// ❌ WRONG — new DateFormatter every render
var body: some View {
    Text(DateFormatter().string(from: date))
}
// ✅ CORRECT (a) — hoist to a type-scope static let (built once, reused)
private static let df: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; return f }()
var body: some View { Text(Self.df.string(from: date)) }
// ✅ CORRECT (b) — let SwiftUI format it: Text(_:format:) (macOS 12.0+ for FormatOutput == String; no formatter object at all)
var body: some View { Text(date, format: .dateTime.month().day()) }
```

`Text(_:format:)` is the leaner fix — it requires **macOS 12.0+** for the `FormatOutput == String`
overload (e.g. `.dateTime.month().day()`) and **macOS 15.0+** for the `FormatOutput == AttributedString`
overload; confirm the correct floor against your deployment target (`floors-master.md`). The canonical shape +
a permalinked example: `swiftui-ctx lookup "Text(_:format:)" --json` then `file <recommended.id> --smart`.

## vperf-05 — `GeometryReader` wrapping a whole screen / large subtree

`GeometryReader` **greedily takes all offered space** and re-lays-out its subtree on **every size
change** — constant on a resizable Mac window. It is correct only when you truly need the *measured*
size of a region; reaching for it to arrange a layout is the smell.

```swift
// ❌ WRONG — GeometryReader wrapping the whole screen just to position children
GeometryReader { geo in
    VStack { header; content; footer }.frame(width: geo.size.width)   // arrangement, not measurement
}
// ✅ CORRECT — use layout primitives; no per-resize subtree re-layout
VStack { header; content; footer }                 // or: .frame / .alignmentGuide / a Layout / containerRelativeFrame
```

READ the file: a `GeometryReader` whose `geo` value is genuinely *consumed* (e.g. feeding a `Canvas`
draw, a parallax offset) may be correct — that case `cross_ref`s `audit-swiftui-drawing-canvas`
(drawing geometry) or `audit-swiftui-layout-and-tables` (layout arrangement); don't double-own.

## vperf-06 — real logic in a `View`'s `init`

A view's `init` runs on every parent `body` re-eval, so heavy work there runs constantly. (Why tier-2:
grep can't scope to an `init` body nor tell a trivial `self.x = x` from a `.sorted`/function call.)

```swift
// ❌ WRONG — sorting/transforming in init (runs every parent render)
init(items: [Item]) { self.rows = items.sorted { $0.name < $1.name } }
// ✅ CORRECT — keep init trivial; derive once upstream, or in the model / a .task
init(rows: [Item]) { self.rows = rows }            // caller/model supplies the already-derived rows
```

Move the work to an `@Observable` model method, a cached derived property computed once upstream, or
`.task` for async work. The principle is the same as vperf-07 (compute derived collections **once**, not
per render).

---

## Sources

- WWDC23 "Demystify SwiftUI performance" (session 10160) — update cost, expensive `body` work:
  https://developer.apple.com/videos/play/wwdc2023/10160/ (accessed 2026-06-07).
- WWDC21 "Demystify SwiftUI" (session 10022) — identity, lifetime, dependencies:
  https://developer.apple.com/videos/play/wwdc2021/10022/ (accessed 2026-06-07).
- Apple — `Text(_:format:)`: https://developer.apple.com/documentation/swiftui/text · `Layout`:
  https://developer.apple.com/documentation/swiftui/layout · `GeometryReader`:
  https://developer.apple.com/documentation/swiftui/geometryreader (fetch via Sosumi; accessed 2026-06-07).
