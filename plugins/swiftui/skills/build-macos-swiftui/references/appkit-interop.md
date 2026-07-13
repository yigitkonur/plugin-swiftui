# AppKit Interop & First Responder (macOS)

When SwiftUI has no native equal of a real `NSTextView` (rich text), `NSOutlineView`, `NSTableView`-grade control, or when you need fine first-responder/focus control, you bridge to AppKit. macOS-only: the protocols are `NSViewRepresentable` / `NSViewControllerRepresentable`, and the first-responder model is the AppKit window responder chain — *not* iOS's `becomeFirstResponder()` / `@FocusState`-covers-everything model.

AI fails this three ways: (a) pretends a SwiftUI-only solution exists; (b) writes a representable that compiles but never reflects state because it omits `updateNSView` or mismanages the `Coordinator`; (c) misunderstands the macOS responder chain (an `NSView` is not focusable unless it returns `true` from `acceptsFirstResponder`; you drive focus through `window.makeFirstResponder(_:)`). It also bridges the wrong direction and forgets `NSHostingController` / `NSHostingView` exist for the reverse.

Default: **stay in SwiftUI.** Bridge only the one control/subsystem that needs it. Never wrap a whole window in `NSViewRepresentable` when one control needs AppKit.

> macOS-only. iOS uses `UIViewRepresentable` / `UIHostingController` and a different focus model — none of the responder-chain rules below transfer.

---

## The eight mistakes

### 1. Omitting `updateNSView` — state never propagates (most common)

`makeNSView(context:)` runs **once** at creation. SwiftUI calls `updateNSView(_:context:)` on every relevant state change; without it, later changes to bound state never reach the AppKit view, which silently goes stale. `NSViewRepresentable` declares **both** as core members.

❌ **WRONG** — set once, bridge is one-shot:
```swift
struct MyField: NSViewRepresentable {
    @Binding var text: String
    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.stringValue = text          // set ONCE, never again
        return tf
    }
    // no updateNSView  ❌  later text changes never reach the view
}
```

✅ **CORRECT** — implement both halves:
```swift
struct MyField: NSViewRepresentable {                // macOS 10.15+
    @Binding var text: String
    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.delegate = context.coordinator
        return tf
    }
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }   // push SwiftUI -> AppKit
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: MyField
        init(_ parent: MyField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {              // push AppKit -> SwiftUI
            parent.text = (obj.object as! NSTextField).stringValue
        }
    }
}
```
Guard the write (`if nsView.stringValue != text`): an unconditional `nsView.stringValue = text` every update resets the cursor, kills undo, and can re-enter the change->update loop.

### 2. Forgetting the Coordinator / delegate round-trip

AppKit controls report changes through delegate protocols (`NSTextFieldDelegate.controlTextDidChange(_:)`, `NSTextViewDelegate.textDidChange(_:)`). SwiftUI gives you `makeCoordinator()` precisely to own a delegate reachable as `context.coordinator`. No Coordinator → the AppKit→SwiftUI direction is dead: typing shows on screen but the `@Binding` stays empty.

❌ **WRONG** — `@Binding` with no Coordinator, no delegate:
```swift
struct MyField: NSViewRepresentable {
    @Binding var text: String
    func makeNSView(context: Context) -> NSTextField { NSTextField() }   // delegate never set
    func updateNSView(_ nsView: NSTextField, context: Context) { nsView.stringValue = text }
    // no makeCoordinator()  ❌  edits never flow back to `text`
}
```

✅ **CORRECT** — Coordinator owns the delegate; bound value written back from the callback:
```swift
func makeNSView(context: Context) -> NSTextField {
    let tf = NSTextField()
    tf.delegate = context.coordinator                 // wire the delegate
    return tf
}
func makeCoordinator() -> Coordinator { Coordinator(self) }
final class Coordinator: NSObject, NSTextFieldDelegate {
    let parent: MyField
    init(_ parent: MyField) { self.parent = parent }
    func controlTextDidChange(_ obj: Notification) {
        parent.text = (obj.object as! NSTextField).stringValue   // AppKit -> SwiftUI
    }
    // focus lifecycle maps cleanly: controlTextDidBeginEditing / controlTextDidEndEditing
}
```

### 3. Assuming a SwiftUI view can be made first responder directly

macOS first-responder is a window-level, AppKit responder-chain concept. A custom `NSView`/`NSControl` is **not focusable at all** unless it returns `true` from `acceptsFirstResponder`, and you make it active via `window.makeFirstResponder(_:)`. `@FocusState` (macOS 12+) covers SwiftUI-native controls but **not** arbitrary first-responder behaviour (custom field editors, insertion-point color, focus rings). There is no public "make this arbitrary SwiftUI view first responder" call.

❌ **WRONG** — call `becomeFirstResponder()` on a value / expect `@FocusState` to drive AppKit:
```swift
someView.becomeFirstResponder()           // ❌ not a thing on a SwiftUI value
// custom NSView subclass with no acceptsFirstResponder override, expected to take focus  ❌
```

✅ **CORRECT** — opt in on the AppKit subclass; focus through the window:
```swift
final class FocusAwareTextField: NSTextField {
    var onFocusChange: (Bool) -> Void = { _ in }
    override var acceptsFirstResponder: Bool { true }       // opt in to focus
    override func becomeFirstResponder() -> Bool {
        onFocusChange(true)
        return super.becomeFirstResponder()
    }
}
// focus programmatically (e.g. from updateNSView, guarded by a flag):
nsView.window?.makeFirstResponder(nsView)
```

### 4. Reaching for `NSViewRepresentable` when you need `NSViewControllerRepresentable`

`NSView` and `NSViewController` are different bridge surfaces. When the AppKit thing is controller-shaped (lifecycle, child-VC containment, `representedObject`, `viewDidAppear`) — an `NSSplitViewController`, a document editor, an `NSTextView` with its scroll/ruler machinery — wrapping it as a bare `NSView` loses all of that. The right protocol is `NSViewControllerRepresentable`, whose required members are `makeNSViewController(context:)` / `updateNSViewController(_:context:)` (`makeCoordinator()` available identically).

❌ **WRONG** — flatten a controller-shaped component to a bare view:
```swift
struct EditorBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        MyEditorVC().view          // ❌ VC deallocated / lifecycle & containment lost
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
```

✅ **CORRECT** — use the controller representable:
```swift
struct EditorBridge: NSViewControllerRepresentable {        // macOS 10.15+
    func makeNSViewController(context: Context) -> MyEditorVC { MyEditorVC() }
    func updateNSViewController(_ vc: MyEditorVC, context: Context) { /* push state */ }
}
```

### 5. Forgetting the reverse bridge: hosting SwiftUI inside AppKit

In a mostly-AppKit app, AI tries to instantiate SwiftUI views by hand or claims SwiftUI "can't be embedded" in an existing `NSWindow` / `NSViewController`. The sanctioned bridge is `NSHostingController` (an `NSViewController` whose content is a SwiftUI `rootView`) or `NSHostingView` (an `NSView` host) — that's how you drop SwiftUI into an AppKit window, a popover, a `MenuBarExtra` window, or a toolbar item.

❌ **WRONG** — claim it can't be done / hand-instantiate:
```swift
// "SwiftUI can't go in an NSWindow" — false.
let v = MySwiftUIView()           // ❌ a View is not an NSView; nothing to add as a subview
window.contentView?.addSubview(v) // ❌ does not compile / nothing renders
```

✅ **CORRECT** — host through the AppKit bridge type:
```swift
let host = NSHostingController(rootView: MySwiftUIView())    // macOS 10.15+
window.contentViewController = host
// or as a plain view:
let v = NSHostingView(rootView: MySwiftUIView())
```

### 6. Swift-6 bridge-concurrency: a `@Sendable` Coordinator callback touching main-actor state

The Coordinator boundary is exactly where Swift 6's strict data-race checking bites on Mac. `NSViewRepresentable.updateNSView`, Coordinator delegate callbacks, and `NSView` action targets are `@MainActor` AppKit surfaces. Feed SwiftUI state in or route a callback out through a closure typed `@Sendable` and the compiler errors: a `@Sendable` closure can run on any thread, so synchronously reading/writing main-actor state inside it is a data race — *"Main actor-isolated property '…' can not be referenced from a Sendable closure."* This is a hard **error** under the Swift 6 language mode, not a warning. (Note: a fresh Xcode 26 macOS target often ships *Default Actor Isolation = Main Actor*, which can pre-isolate the closure and mask this — but never assume that mode is on; it is an opt-in build setting, `-default-isolation MainActor`, not the unconditional language default — verify against your Xcode 26 SDK.)

❌ **WRONG** — read main-actor state inside a `@Sendable` closure, or GCD-hop to dodge the checker:
```swift
final class Coordinator: NSObject, NSTextFieldDelegate {
    let parent: AppKitField
    init(_ parent: AppKitField) { self.parent = parent }
    func controlTextDidChange(_ obj: Notification) {
        runOffMain { self.parent.text = "x" }        // ❌ Sendable closure can't touch main-actor `parent`
    }
    func runOffMain(_ work: @Sendable @escaping () -> Void) { /* ... */ }
}
// also wrong: DispatchQueue.main.async { self.parent.text = ... }  // ❌ side-steps the very checking Swift 6 enables
```

✅ **CORRECT** — isolate the closure to the main actor (you own the API) or hop with a checkable annotation:
```swift
// You own the receiving function: mark the closure @MainActor so reading main-actor state is legal.
func runOnMain(_ work: @Sendable @MainActor @escaping () -> Void) { /* ... */ }

// You don't own it but only READ a value: capture by value in the capture list.
runOffMain { [text = parent.text] in print(text) }   // captures the value, not the isolated property

// Hopping back to the main actor from a nonisolated context — annotation, not GCD:
await MainActor.run { parent.text = newValue }
```
Capture-by-value works for **reads only**; mutating main-actor state from a `@Sendable` closure needs an `await` / `MainActor.run` hop. `@concurrent` (for deliberately running heavy decode off-main) is **Swift 6.2+** — gate any use behind that toolchain — verify against your Xcode 26 SDK.

### 7. Expecting SwiftUI `.ultraThinMaterial` to match a native sidebar — it composites *inside* the window

SwiftUI's materials blend against the **window's own content**, not the desktop and windows *behind* the window. A real macOS sidebar/panel uses **behind-window** vibrancy. So `.ultraThinMaterial` on a sidebar renders flat — it never picks up what's actually behind the window — while a native sidebar built on `NSVisualEffectView(material: .sidebar, blendingMode: .behindWindow)` samples the desktop and is visibly deeper. `.ultraThinMaterial` is the strongest SwiftUI vibrancy and still looks noticeably flatter side-by-side. The Mac-correct material is `NSVisualEffectView` bridged through `NSViewRepresentable`.

❌ **WRONG** — SwiftUI material as a "native" sidebar background (composites inside the window → flat):
```swift
List { /* … */ }
    .background(.ultraThinMaterial)   // ❌ blends against window content, not behind-window; flat sidebar
```

✅ **CORRECT** — wrap `NSVisualEffectView` with behind-window blending:
```swift
struct VisualEffectView: NSViewRepresentable {                       // macOS 10.15+
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active                                         // keep vibrancy on inactive windows too
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Use it as the background of the sidebar:
List { /* … */ }
    .background(VisualEffectView(material: .sidebar))
```
`.sidebar` + `.behindWindow` is the genuine sidebar look; set `state = .active` so the vibrancy survives when the window isn't key. (This is `NSVisualEffectView` — the established AppKit material; not the macOS-26 Liquid Glass `NSGlassEffectView`.)

### 8. Mishandling scene-level chrome under `NSHostingView` — `.toolbar` / `.navigationTitle` bridge on macOS 14+, `.searchable` does not

The reverse bridge (mistake 5) gets you *pixels*. Whether it also carries scene-level chrome (`.toolbar`, `.navigationTitle`) depends on **scene bridging** — and AI gets this wrong in *both* directions: it either assumes none of it works (stale pre-macOS-14 lore) or assumes all of it works (over-optimism). The truth is split by OS and modifier.

`macOS 14` added `NSHostingView.sceneBridgingOptions` (an `NSHostingSceneBridgingOptions` set: `.toolbars`, `.title`, `.all`, `[]`). When the hosting view is the window's `contentView`, it defaults to `.all`, so `.toolbar` and `.navigationTitle` route to the window automatically. macOS 14 release notes, verbatim: *"The toolbar and navigationTitle modifiers now work outside of the SwiftUI App Lifecycle on macOS. Use `NSHostingView.sceneBridgingOptions` to enable or disable this functionality."* If the hosting view is **not** the `contentView` (nested in some other AppKit view), the default is `[]` — you must set the options yourself. `.searchable` has **no** scene bridge: it never renders under a bare `NSWindow` + `NSHostingView`, on any macOS version.

✅ **WORKS on macOS 14+** — `.toolbar` / `.navigationTitle` bridge through `sceneBridgingOptions`:
```swift
let root = ContentView()
    .toolbar { ToolbarItem { Button("Add", systemImage: "plus") {} } }  // ✅ bridges on macOS 14+
    .navigationTitle("Items")                                           // ✅ bridges on macOS 14+
let window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .resizable],
                      backing: .buffered, defer: false)
let host = NSHostingView(rootView: root)
window.contentView = host                       // as contentView → defaults to .all (toolbars + title)
// If host is NOT the contentView (nested deeper), the default is [] — opt in explicitly:
host.sceneBridgingOptions = [.toolbars, .title]
```

❌ **WRONG** — expect `.searchable` to work under a plain `NSWindow` + `NSHostingView`:
```swift
let root = ContentView()
    .searchable(text: $query)                    // ❌ no scene bridge exists; never appears (any macOS)
window.contentView = NSHostingView(rootView: root)
```

✅ **CORRECT** for search — own a SwiftUI scene, or drive search in AppKit:
```swift
// Preferred: let a SwiftUI scene own the window — searchable resolves normally.
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .searchable(text: $query)                                           // ✅ works
        }
    }
}
// If you MUST keep a hand-built NSWindow, drive the search via NSSearchField in an NSToolbar —
// don't expect the SwiftUI .searchable modifier to fire.
```

> `sceneBridgingOptions` exists on both `NSHostingView` and `NSHostingController` (macOS 14). On macOS 13 and earlier there is no scene bridge at all — `.toolbar` / `.navigationTitle` also do nothing under a hand-built `NSWindow`; target macOS 14+ to rely on this.

---

## Detection tells

- A `: NSViewRepresentable` / `: NSViewControllerRepresentable` type with **no** `func updateNSView` / `func updateNSViewController` → state-staleness bug (mistake 1).
- `makeNSView` that sets `.stringValue` / `.state` / data once, and a body with no `updateNSView` writing the same property back.
- A representable with a `@Binding` but **no** `makeCoordinator()` and no `.delegate = context.coordinator` → broken AppKit→SwiftUI direction (mistake 2).
- A call to `becomeFirstResponder()` on a SwiftUI value, or a custom `NSView` subclass without `override var acceptsFirstResponder: Bool { true }` that is expected to take focus (mistake 3).
- An `NSViewController`-backed component (`NSSplitViewController`, editor, scroll/ruler `NSTextView`) wrapped as a bare `NSView` via `vc.view` → wrong protocol (mistake 4).
- Hand-instantiated SwiftUI views in AppKit code with no `NSHostingController` / `NSHostingView` (mistake 5).
- A `@Sendable` closure parameter (or `Task.detached`, `DispatchQueue.main.async`) in/around a Coordinator whose body reads `self.parent.…` / a `@MainActor` property → the Swift-6 "can not be referenced from a Sendable closure" error class (mistake 6).
- `.searchable(...)` on a view installed via `NSHostingView`/`NSHostingController` under a hand-built `NSWindow` → no scene bridge exists for search; it never renders (mistake 8). Same for `.toolbar` / `.navigationTitle` when the target is **< macOS 14**, or when the hosting view is nested (not the window's `contentView`) and `sceneBridgingOptions` is left at its `[]` default.
- Observers / KVO / timers added in `makeNSView` with no `static func dismantleNSView(_:coordinator:)` → leaks across view-identity changes (cleanup belongs in `dismantleNSView`).

---

## Newer bridging surfaces (macOS 13 / 14)

The classic four (`NSViewRepresentable`, `NSViewControllerRepresentable`, `NSHostingController`, `NSHostingView`) are `macOS 10.15+`. Later releases added bridges that solve the long-standing rough edges — reach for these instead of hand-rolling Auto Layout glue, hidden toolbars, or `CABasicAnimation`:

| API | macOS | What it bridges | Use when |
|---|---|---|---|
| `NSHostingSizingOptions` (`NSHostingController.sizingOptions` / `NSHostingView.sizingOptions`) | 13.0 | Feeds the SwiftUI view's measured size into Auto Layout — `.intrinsicContentSize`, `.minSize`, `.maxSize` | Hosted SwiftUI content must drive an AppKit layout (constraints, split-view min thickness) instead of being a fixed frame. |
| `sizeThatFits(_:nsView:context:)` (optional `NSViewRepresentable` member) | 13.0 | The *forward* direction: a representable proposes its own size to SwiftUI's layout | An AppKit-backed control needs to report an intrinsic/ideal size to the SwiftUI parent. **Targeting macOS 12 cannot use this** — fall back to `.frame`/intrinsic content size. |
| `NSHostingSceneBridgingOptions` (`.sceneBridgingOptions` on `NSHostingView` / `NSHostingController`) | 14.0 | Routes scene-level chrome (`.toolbars`, `.title`, `.all`, `[]`) from hosted SwiftUI up to the `NSWindow` | Hosting SwiftUI in a hand-built `NSWindow` and you want its `.toolbar` / `.navigationTitle` to appear (see mistake 8). |
| `NSHostingMenu(rootView:)` | 14.4 | Hosts a SwiftUI `Menu` body as an `NSMenu` | Building a dock menu / context menu / status-item menu in AppKit but composing it in SwiftUI. |
| `NSAnimationContext.animate(_:changes:completion:)` | 15.0 | Drives AppKit view changes with a SwiftUI `Animation` (timing curves, springs) | Animating AppKit views to match SwiftUI motion without dropping to `CAAnimation`. |

> All five are macOS-only and have no UIKit equivalent by these names. None replace the core `make…`/`update…` lifecycle — they extend it.

---

## Canonical pattern

```swift
// macOS AppKit -> SwiftUI bridge — the canonical shape (macOS 10.15+)
struct AppKitField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeNSView(context: Context) -> FocusAwareTextField {
        let tf = FocusAwareTextField()
        tf.delegate = context.coordinator
        tf.onFocusChange = { context.coordinator.parent.isFocused = $0 }
        return tf
    }
    func updateNSView(_ nsView: FocusAwareTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }       // SwiftUI -> AppKit
        if isFocused, nsView.window?.firstResponder !== nsView {
            nsView.window?.makeFirstResponder(nsView)                     // explicit focus
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    static func dismantleNSView(_ nsView: FocusAwareTextField, coordinator: Coordinator) { }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: AppKitField
        init(_ parent: AppKitField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {                  // AppKit -> SwiftUI
            parent.text = (obj.object as! NSTextField).stringValue
        }
    }
}

final class FocusAwareTextField: NSTextField {
    var onFocusChange: (Bool) -> Void = { _ in }
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { onFocusChange(true); return super.becomeFirstResponder() }
}

// Reverse bridge: SwiftUI inside AppKit
window.contentViewController = NSHostingController(rootView: MySwiftUIView())
```

**Rules:** (1) implement BOTH `makeNSView` and `updateNSView` (guard the write). (2) Use `makeCoordinator()` + `context.coordinator` as the delegate for the AppKit→SwiftUI direction. (3) Custom focusable AppKit views must return `true` from `acceptsFirstResponder`; focus via `window.makeFirstResponder(_:)` — `@FocusState` only covers SwiftUI-native controls. (4) Controller-shaped AppKit → `NSViewControllerRepresentable`. (5) SwiftUI-in-AppKit → `NSHostingController` / `NSHostingView`. (6) At the Coordinator boundary, a closure that touches main-actor state must be `@MainActor`-isolated (or capture-by-value for reads, or `await MainActor.run` to hop) — never `DispatchQueue.main.async` to dodge the Swift-6 checker.

macOS-specific: First-responder is explicit and window-scoped. Text controls share a single per-window `NSText` field editor (`window?.fieldEditor(true, for:)`) — customizing insertion-point color/selection means reaching it inside `becomeFirstResponder()`, with no iOS analog. Controls report via delegates, not target/action closures — the Coordinator is their home. Recurring reasons to bridge at all on macOS: real rich-text `NSTextView`, hierarchical `NSOutlineView`, `NSSplitViewController` collapse/min-thickness behaviour, and precise focus-ring/insertion-point control.

---

## Sources

| URL | Type | Confidence | Key fact / verbatim |
|---|---|---|---|
| https://developer.apple.com/documentation/swiftui/nsviewrepresentable | primary-doc | high | *"A wrapper that you use to integrate an AppKit view into your SwiftUI view hierarchy."*; required `func makeNSView(context:) -> NSViewType` + `func updateNSView(_:context:)`; `static func dismantleNSView(_:coordinator:)`; `macOS 10.15+`. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftui/nsviewcontrollerrepresentable | primary-doc | high | Sibling protocol; required `makeNSViewController(context:)` / `updateNSViewController(_:context:)`; `macOS 10.15+`. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftui/nshostingcontroller | primary-doc | high | *"An AppKit view controller that hosts SwiftUI view hierarchy."* (`init(rootView:)`); `macOS 10.15+`. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftui/nshostingview | primary-doc | high | *"An AppKit view that hosts a SwiftUI view hierarchy."*; `macOS 10.15+`; `sceneBridgingOptions` (`macOS 14+`); `sizingOptions: NSHostingSizingOptions` (`macOS 13+`). Accessed 2026-06-07. |
| https://developer.apple.com/documentation/macos-release-notes/macos-14-release-notes | primary-doc (macOS 14 release notes) | high | Verbatim: *"The toolbar and navigationTitle modifiers now work outside of the SwiftUI App Lifecycle on macOS. Use NSHostingView.sceneBridgingOptions to enable or disable this functionality."* Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nshostingscenebridgingoptions | primary-doc | high | Option set (`macOS 14+`): `.toolbars`, `.title`, `.all`, `[]`; on `NSHostingView` and `NSHostingController`; default `.all` when the host is the window `contentView`, else `[]`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nshostingsizingoptions | primary-doc | high | Option set (`macOS 13+`): `.intrinsicContentSize`, `.minSize`, `.maxSize`; feeds SwiftUI measured size into Auto Layout. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nsviewrepresentable/sizethatfits(_:nsview:context:) | primary-doc | high | Optional representable member (`macOS 13+`): a representable proposes its own size to SwiftUI layout. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nshostingmenu | primary-doc | high | *"An AppKit menu with custom content provided by a SwiftUI view hierarchy."* `init(rootView:)`; `macOS 14.4+`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsanimationcontext/animate(_:changes:completion:) | primary-doc | high | `macOS 15.0+`: drives AppKit view changes with a SwiftUI `Animation`. Accessed 2026-06-07. |
| https://developer.apple.com/videos/play/wwdc2022/10075/ | primary-doc (WWDC22 "Use SwiftUI with AppKit") | high | Representables are the sanctioned interop path: implement `updateNSView` + a `Coordinator` to feed SwiftUI state into AppKit and route delegate callbacks back. Accessed 2026-06-07. |
| https://github.com/onmyway133/blog/issues/589 | practitioner | high | Full `FocusTextField: NSViewRepresentable` (`makeNSView`/`updateNSView`/`makeCoordinator`); `Coordinator: NSObject, NSTextFieldDelegate` (`controlTextDidBeginEditing`/`controlTextDidEndEditing`/`controlTextDidChange`); `FocusAwareTextField` overriding `becomeFirstResponder()`. Accessed 2026-06-06. |
| https://forums.swift.org/t/swiftui-textfield-focus-firstresponder-macos/35018 | forum | medium | `@FocusState` (macOS 12+) for SwiftUI controls vs `NSViewRepresentable` bridge for finer first-responder control. Accessed 2026-06-06. |
| https://msena.com/posts/three-column-swiftui-macos/ | practitioner | high | Bridging `NSSplitViewController` via `NSViewControllerRepresentable` as the route to AppKit split behaviour SwiftUI lacks. Accessed 2026-06-06. |
| https://www.donnywals.com/solving-main-actor-isolated-property-can-not-be-referenced-from-a-sendable-closure-in-swift/ | practitioner | high | The error text; fix depends on ownership: `@Sendable @MainActor` closure when you own the API; `[count]` capture-list for reads; mutation needs an `await`/`Task` hop. Accessed 2026-06-06. |
| https://swift.org/blog/swift-6.2-released/ | primary-doc | high | "main actor by default" is *"the new option to isolate code to the main actor"* (opt-in, `-default-isolation MainActor`), not the unconditional default; `@concurrent` is new in Swift 6.2 (Sept 15 2025). Accessed 2026-06-06. |
| https://www.hackingwithswift.com/swift/6.0/concurrency | practitioner | high | *"complete concurrency checking is enabled by default"* in the Swift 6 language mode — non-Sendable / main-actor warnings become hard errors. Accessed 2026-06-06. |

**Availability note (Apple docs, 2026-06-07):** the core representable/hosting types (`NSViewRepresentable`, `NSViewControllerRepresentable`, `NSHostingController`, `NSHostingView`) are `macOS 10.15+`. `@FocusState` is `macOS 12.0+` (SwiftUI controls only). `NSHostingSizingOptions` and the optional `sizeThatFits(_:nsView:context:)` member are `macOS 13.0+` — a target on macOS 12 cannot use either. `NSHostingSceneBridgingOptions` and `NSAnimationContext.animate(_:changes:completion:)` are `macOS 15.0+`; `NSHostingMenu` is `macOS 14.4+`. `@concurrent` and `-default-isolation MainActor` are toolchain-gated to **Swift 6.2+** (latest snapshot toolchain Swift 6.3.2). Verify the OS deployment target and toolchain/build settings against your Xcode 26 SDK before relying on any of these.
