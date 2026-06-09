# Pointer affordances — hover, cursor, continuous position, right-click (pg-01 … pg-06)

The Mac is pointer-driven: it has a cursor, a hover state, and a right mouse button. iOS has none of
these, so iOS-trained corpora carry almost no `.onHover`, `pointerStyle`, `onContinuousHover`, or
right-click `.contextMenu` code. The result compiles and looks plausible but reads as "an iPad app in a
window." This reference covers the **affordance** half (pg-01 … pg-06); gesture currency, live state, and
composition are in `gestures-and-state.md`; gating depth is in `gesture-availability.md`.

Floor values are NOT restated here — read them from
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The invented/stale case names are in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`. The canonical ✅ shape is the
swiftui-ctx **consensus** + a permalinked example, not the snippet below — `lookup` before you cite.

---

## The affordance test (how to judge pg-02/03/05)

Remove the pointer modifier and ask: did the view lose a *cursor signal* or *hover feedback* a Mac user
expects? If the view is **interactive** (reacts to click, drag, selection) the answer is yes and the
absence is a defect. A **static** label/decoration is not a defect for lacking hover — that is the
load-bearing distinction the agent must make at READ. pg-02/03/05 are warnings, not hard-fails, precisely
because only the agent (not grep) can tell interactive from static.

---

## pg-01 — `PointerStyle.grabbing` (invented case, hard-fail)

There is no `.grabbing` case. The real cases are `.grabActive` (a grab in progress) and `.grabIdle` (a
grabbable affordance at rest), both macOS 15.0+. This is a mechanical rename — `fix_mode: auto`.

```swift
// ❌ WRONG — .grabbing is not a PointerStyle case (macOS)
.pointerStyle(.grabbing)
```
```swift
// ✅ CORRECT — real cases (macOS 15+); confirm with: swiftui-ctx lookup pointerStyle
if #available(macOS 15, *) { handle.pointerStyle(.grabActive) }   // .grabIdle at rest
```

## pg-02 — custom interactive view with no `.onHover`

`.onHover(perform:)` (macOS 10.15+) fires a `Bool` on pointer enter/exit. A custom row/card/handle that
reacts to the pointer but never highlights or changes feels dead on the Mac. The swiftui-ctx **consensus
shape is `.onHover { … }` (96% of real uses)** — back the ✅ with `swiftui-ctx lookup onHover` and its
`recommended` permalink.

```swift
// ❌ WRONG — custom row, zero pointer feedback (fine on touch, dead on Mac)
Text("Open").padding(6)
```
```swift
// ✅ CORRECT — pointer-driven highlight (macOS has a cursor to answer)
@State private var hovering = false
Text("Open").padding(6)
    .background(hovering ? Color.accentColor.opacity(0.15) : .clear)
    .onHover { hovering = $0 }
```

## pg-03 — draggable/resizable affordance with no `pointerStyle`

`pointerStyle(_:)` (macOS 15.0+, **no iOS arm**) sets the cursor *shape* declaratively — no
`NSCursor.push()/pop()` bookkeeping. A column divider wants `.columnResize`; a frame handle wants
`.frameResize(position:directions:)`; a grabbable handle wants `.grabIdle`/`.grabActive`; a clickable
glyph wants `.link`. Omitting it leaves the system arrow over an affordance that should signal resize/grab.
Gate it — see `gesture-availability.md` (pg-07).

```swift
// ✅ CORRECT — resize cursor over a draggable divider (macOS 15+). consensus shape is .pointerStyle(_)
if #available(macOS 15, *) {
    Divider().frame(width: 8).pointerStyle(.columnResize(directions: .all))
}
```

## pg-04 — binary `.onHover` where `onContinuousHover` is needed (advisory, UNVERIFIED judgment)

`.onHover` is binary (enter/exit) — it never reports *where* the pointer is. `onContinuousHover(coordinateSpace:perform:)`
(macOS 14.0+) streams `.active(CGPoint)` while the pointer moves and `.ended` when it leaves — needed for
a hover crosshair, a value readout under the cursor in a chart, or a tooltip that tracks the pointer. This
is a **judgment** call: only flag when the site visibly needs the coordinate. Carry as `advisory` /
`source: verify against Xcode 26 SDK`.

```swift
// ❌ WRONG — .onHover knows only enter/exit; you can never read the cursor position
.onHover { inside in /* `inside` is a Bool — no CGPoint */ }
```
```swift
// ✅ CORRECT — live pointer position inside the frame (macOS 14+)
@State private var point: CGPoint?
SomeChart().onContinuousHover(coordinateSpace: .local) { phase in
    switch phase { case .active(let p): point = p; case .ended: point = nil }
}
```

## pg-05 — row/item with actions but no right-click `.contextMenu`

Right-click contextual menus are a **primary** Mac interaction. Touch-trained code surfaces actions only
as on-screen buttons or swipe gestures, so right-clicking a row does nothing. The same `.contextMenu`
modifier fires via long-press on iOS — the right-click *idiom* is the Mac's. Mark destructive items
`role: .destructive`.

```swift
// ✅ CORRECT — right-click menu, the Mac idiom (also long-press on iOS)
// Uses contextMenu(menuItems:preview:) (macOS 13.0+) — the non-deprecated overload
Text(item.title).contextMenu(menuItems: {
    Button("Rename") { rename(item) }
    Button("Delete", role: .destructive) { delete(item) }
})
```
If the menu items deserve `keyboardShortcut`s or mirror a `CommandMenu`, `cross_ref: menus-commands`.

## pg-06 — `.swipeActions` as the only way to act (advisory)

Swipe-to-act is the touch idiom. On the Mac a `.swipeActions` row that has **no** right-click `.contextMenu`
leaves the primary Mac affordance missing. Keep the swipe (it still works) and *add* the context menu —
don't remove it.

---

## Detection tells (what LOCATE surfaces; you READ and judge)

- A `struct …Row/Cell/Item/Card/Handle: View` that is interactive but has no `.onHover` → pg-02.
- A `Divider()` / resize handle / fixed-width drag handle with no `.pointerStyle` → pg-03 (macOS 15).
- A `.onHover {` whose body wants a coordinate (crosshair / value-under-cursor) → pg-04.
- A `List`/`ForEach`/`Table` row with action `Button`s but no `.contextMenu` → pg-05.
- `.swipeActions` as the only action path → pg-06.

---

## Sources

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/view/onhover(perform:) | `onHover(perform:)` — *"action to perform when the user moves the pointer over or away from the view's frame"*; macOS 10.15+, pointer-only | high |
| https://developer.apple.com/documentation/swiftui/view/oncontinuoushover(coordinatespace:perform:) | `onContinuousHover` — phases `.active(CGPoint)` / `.ended`; macOS 14.0+ | high |
| https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:) | `pointerStyle(_:)` — *"sets the pointer style to display when the pointer is over the view"*; macOS 15.0+, macOS-only; cases `.grabActive`/`.grabIdle`/`.link`/`.columnResize`/`.frameResize(position:directions:)` | high |
| https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:) | `contextMenu(menuItems:)` — macOS 10.15+, **deprecated**; prefer `contextMenu(menuItems:preview:)` (macOS 13.0+); right-click on Mac, long-press on iOS | high |
| swiftui-ctx `lookup onHover` (732 repos, 5,694 uses) · `doc: sosumi.ai/documentation/swiftui/view/onhover` | consensus `{ }` 96%; recommended permalink `github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Components/TrimmingAVPlayer.swift#L729` (8.4k★) | high |
| swiftui-ctx `lookup pointerStyle` | consensus `(_)` 100%; recommended `sindresorhus/Gifski` `CropOverlayView.swift#L49` permalink (macOS 15) | high |

Apple availability strings cross-checked against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
and fetched via Sosumi (access 2026-06-07). pg-04 (does a site truly need the continuous coordinate) is a
judgment call — carry as `verify against Xcode 26 SDK`. The ✅ shapes above are confirmed by the
swiftui-ctx consensus rows; cite the permalink in each finding's `## Source`, not the static snippet.
