# Representable lifecycle — the two halves, the Coordinator, the protocol choice, cleanup

Covers **interop-01** (missing `updateNSView`), **interop-02** (dead Coordinator), **interop-04**
(controller flattened to a bare view), **interop-09** (missing `dismantleNSView`). All `fix_mode:
flag-only`. The ✅ shapes here are corroborated by `swiftui-ctx recipe nsview-bridge` (4,698 real bridges
across 957 repos) and `lookup NSViewRepresentable` (redirects to that recipe) — fetch a permalinked
example with `swiftui-ctx file <id> --smart` for `## Source`.

## interop-01 — `makeNSView` runs once; without `updateNSView` the view goes stale

`makeNSView(context:)` runs **once** at creation. SwiftUI calls `updateNSView(_:context:)` on every
relevant state change; omit it and later `@Binding`/state changes never reach the AppKit view, which
silently goes stale. `NSViewRepresentable` declares **both** as core members.

❌ set once, no update half:
```swift
struct MyField: NSViewRepresentable {
    @Binding var text: String
    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.stringValue = text          // set ONCE, never again
        return tf
    }
    // no updateNSView ❌ — later text changes never reach the view
}
```

✅ implement both halves, **guard the write**:
```swift
func updateNSView(_ nsView: NSTextField, context: Context) {
    if nsView.stringValue != text { nsView.stringValue = text }   // SwiftUI → AppKit
}
```
An unconditional `nsView.stringValue = text` every update resets the cursor, kills undo, and can re-enter
the change→update loop. The guard is mandatory.

## interop-02 — a `@Binding` with no Coordinator is a dead AppKit→SwiftUI direction

AppKit controls report changes through delegate protocols (`NSTextFieldDelegate.controlTextDidChange(_:)`,
`NSTextViewDelegate.textDidChange(_:)`). `makeCoordinator()` exists to own a delegate reachable as
`context.coordinator`. No Coordinator → typing shows on screen but the `@Binding` stays empty.

✅ Coordinator owns the delegate; write the bound value back from the callback:
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
        parent.text = (obj.object as! NSTextField).stringValue   // AppKit → SwiftUI
    }
}
```
Focus lifecycle maps cleanly: `controlTextDidBeginEditing` / `controlTextDidEndEditing`.

## interop-04 — controller-shaped AppKit needs `NSViewControllerRepresentable`

`NSView` and `NSViewController` are different bridge surfaces. When the AppKit thing is controller-shaped
(lifecycle, child-VC containment, `representedObject`, `viewDidAppear`) — `NSSplitViewController`, a
document editor, an `NSTextView` with its scroll/ruler machinery — wrapping `vc.view` as a bare `NSView`
deallocates the VC and loses all of that.

❌ flatten a controller to a bare view:
```swift
struct EditorBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { MyEditorVC().view }   // ❌ VC deallocated
    func updateNSView(_ nsView: NSView, context: Context) {}
}
```
✅ use the controller representable (`makeNSViewController` / `updateNSViewController`; `makeCoordinator`
available identically):
```swift
struct EditorBridge: NSViewControllerRepresentable {                    // macOS 10.15+
    func makeNSViewController(context: Context) -> MyEditorVC { MyEditorVC() }
    func updateNSViewController(_ vc: MyEditorVC, context: Context) { /* push state */ }
}
```

## interop-09 — observers added in `makeNSView` leak without `dismantleNSView`

`NotificationCenter` observers, KVO, and `Timer`/`CADisplayLink` set up in `makeNSView` outlive the view
when SwiftUI changes the view's identity, unless you tear them down in the optional `static func
dismantleNSView(_:coordinator:)`. Cleanup belongs there, not in `deinit` of a value type.

✅ canonical full shape (both halves · Coordinator · focus opt-in · dismantle):
```swift
struct AppKitField: NSViewRepresentable {
    @Binding var text: String
    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField(); tf.delegate = context.coordinator; return tf
    }
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    static func dismantleNSView(_ nsView: NSTextField, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)   // tear down here
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: AppKitField
        init(_ parent: AppKitField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            parent.text = (obj.object as! NSTextField).stringValue
        }
    }
}
```

The core representable types are `macOS 10.15+`. Floor values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/
floors-master.md` — read, never restate.

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/nsviewrepresentable | primary-doc | required `makeNSView(context:)` + `updateNSView(_:context:)`; optional `static func dismantleNSView(_:coordinator:)`; `macOS 10.15+`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nsviewcontrollerrepresentable | primary-doc | sibling protocol; required `makeNSViewController(context:)` / `updateNSViewController(_:context:)`; `macOS 10.15+`. Accessed 2026-06-07. |
| https://developer.apple.com/videos/play/wwdc2022/10075/ | primary-doc (WWDC22 "Use SwiftUI with AppKit") | representables are the sanctioned interop path: implement `updateNSView` + a `Coordinator` to feed state in and route delegate callbacks back. Accessed 2026-06-07. |
| https://github.com/onmyway133/blog/issues/589 | practitioner | full `FocusTextField: NSViewRepresentable` (`makeNSView`/`updateNSView`/`makeCoordinator`); `Coordinator: NSObject, NSTextFieldDelegate`. Accessed 2026-06-07. |
| https://msena.com/posts/three-column-swiftui-macos/ | practitioner | bridging `NSSplitViewController` via `NSViewControllerRepresentable` as the route to AppKit split behaviour SwiftUI lacks. Accessed 2026-06-07. |
