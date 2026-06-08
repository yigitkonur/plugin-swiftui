# Reference — Window Sizing & the fixedSize Trap (lt-01 · lt-02 · lt-06)

The content-frame side of window sizing, the scene-modifier companion note, and the `.fixedSize()` /
`layoutPriority` confusion. These are *flag-only* defects (the ✅ shape is shown; the restructuring is the
dev's call). Floors live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never
restate. The canonical shape for any API is what shipping Mac apps write — fetch it with
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (VERIFY) and back the ✅ with a
`swiftui-ctx file <recommended.id> --smart` permalink (FIX).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2.

---

## Why this is a macOS-only problem

iOS has **one fixed canvas** — the screen *is* the size, so a window's min/ideal/max dimensions,
`.defaultSize`, and `.windowResizability` are load-bearing on the Mac and largely irrelevant on iOS. The
iOS-trained model has no notion that a window resizes freely, so AI ships an unconstrained root and no
scene sizing. The window then opens at an arbitrary system size and collapses when the user drags it small.

There are **two distinct layers** — use both:

| Layer | Where it lives | Owner |
|---|---|---|
| content `.frame(min/ideal/max…)` | on the **root content view** inside the scene's closure | **this skill** (lt-01) |
| scene `.defaultSize` / `.windowResizability` | chained on the **scene** at `App.body` | `scenes-windows` (lt-02 companion) |

---

## lt-01 — no min/ideal/max content frame (warning, flag-only)

Without an ideal or minimum size, a resizable Mac window opens too small (content clipped) or lets the
user drag it down until the layout collapses. Declare the frame on the **root content view**; those
constraints then feed `.windowResizability(.contentMinSize)`.

```swift
// ❌ WRONG — unconstrained root content on a free-resizing Mac window
WindowGroup {
    ContentView()
}
```
```swift
// ✅ CORRECT — declare min/ideal/max on the root content
WindowGroup {
    ContentView()
        .frame(minWidth: 480, idealWidth: 720, maxWidth: .infinity,
               minHeight: 320, idealHeight: 480, maxHeight: .infinity)
}
```

> *See also:* `.containerRelativeFrame(.horizontal) { w, _ in w * 0.4 }` (macOS 14.0+) sizes a view
> relative to its nearest container instead of a hard-coded CGFloat — use it when a pane should track the
> window rather than a fixed number. (Gate it if the deployment target is below macOS 14.)

## lt-02 — no scene `.defaultSize` / `.windowResizability` (warning, flag-only — **companion note**)

`scenes-windows` owns the scene-modifier layer; this skill flags only the obvious absence and emits
`cross_ref: scenes-windows`. Without them the first-run window opens at an arbitrary system size and a
utility window stretches to absurd dimensions.

```swift
// ❌ WRONG — no scene sizing
Window("Inspector", id: "inspector") { InspectorView() }
```
```swift
// ✅ CORRECT — scene .defaultSize + .windowResizability (distinct from the content frame; use both)
Window("Inspector", id: "inspector") { InspectorView() }
    .defaultSize(width: 320, height: 600)        // initial window size
    .windowResizability(.contentSize)            // clamp to content's frame limits
// .contentMinSize => window can't shrink below content's min, but can grow freely
```

## lt-06 — blanket `.fixedSize()` on a container (advisory, flag-only)

Wrapping a whole subtree in `.fixedSize()` to "stop truncation" forces the view to its ideal size in
*both* axes and can blow past the window, defeating the flexible layout a resizable window depends on. The
targeted fix for "which view gives up space first" is `layoutPriority`; to stop a single label wrapping
without freezing height, use single-axis `fixedSize(horizontal:vertical:)`.

```swift
// ❌ WRONG — blanket both-axis fixedSize on a container; ignores the proposed size, overflows the window
HStack { Text(longTitle); Spacer(); Text(subtitle) }
    .fixedSize()
```
```swift
// ✅ CORRECT — layoutPriority decides who keeps space; single-axis fixedSize stops wrap only
HStack {
    Text(longTitle).layoutPriority(1)            // this Text keeps its space
    Spacer()
    Text(subtitle)                               // this one truncates first
}
Text(label).fixedSize(horizontal: false, vertical: true)   // stop wrap, don't freeze height
```

---

## The canonical exemplar (steer fixes toward this)

The canonical resizable macOS window with a sortable data `Table` — both layers wired:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            PeopleTable()
                .frame(minWidth: 480, idealWidth: 720, maxWidth: .infinity,
                       minHeight: 320, idealHeight: 480, maxHeight: .infinity)   // lt-01: content frame
        }
        .defaultSize(width: 720, height: 480)            // lt-02 (scenes-windows): scene initial size
        .windowResizability(.contentMinSize)             // lt-02 (scenes-windows): can't shrink below min
    }
}
```

**Rules:** (1) min/ideal/max `.frame` on the **root content**. (2) scene `.defaultSize` +
`.windowResizability` — distinct from the content frame; use both. (3) prefer `layoutPriority` /
single-axis `fixedSize(horizontal:vertical:)` / `containerRelativeFrame` before a blanket `.fixedSize()`.

VERIFY a floor or signature with `swiftui-ctx lookup <api> --json` + Sosumi; the `defaultSize`/
`windowResizability` depth (and their ✅ permalinks) is `scenes-windows`' to own.

---

## Sources

- Apple — `frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)`:
  `https://developer.apple.com/documentation/swiftui/view/frame(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:alignment:)`
  (via Sosumi, accessed 2026-06-07).
- Apple — `windowResizability(_:)`: *"Sets the resizability of windows created by this scene."* — macOS
  13.0+; cases `.automatic`/`.contentSize`/`.contentMinSize`.
  `https://developer.apple.com/documentation/swiftui/scene/windowresizability(_:)` (via Sosumi, accessed
  2026-06-07).
- Apple — `defaultSize(_:)`: *"Sets a default size for a scene."* — macOS 13.0+.
  `https://developer.apple.com/documentation/swiftui/scene/defaultsize(_:)` (via Sosumi, accessed
  2026-06-07; exact iOS/visionOS badge not re-scraped — verify against your Xcode 26 SDK).
- Apple — `containerRelativeFrame(_:alignment:)`: *"Positions this view within an invisible frame with a
  size relative to the nearest container."* — macOS 14.0+.
  `https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:)` (via
  Sosumi, accessed 2026-06-07).
- Apple — `fixedSize()` / `layoutPriority(_:)`: macOS 10.15+ (signatures long-stable).
  `https://developer.apple.com/documentation/swiftui/view/fixedsize()` ·
  `https://developer.apple.com/documentation/swiftui/view/layoutpriority(_:)` (via Sosumi, accessed
  2026-06-07).
- createwithswift.com — "Understanding scenes for your macOS app" (scene/window sizing modifiers).
  `https://www.createwithswift.com/understanding-scenes-for-your-macos-app/` (accessed 2026-06-07).
