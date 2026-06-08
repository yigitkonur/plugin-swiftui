# First responder & focus — the macOS responder chain (interop-03)

`fix_mode: flag-only`. macOS first-responder is a **window-level, AppKit responder-chain** concept — *not*
iOS's `becomeFirstResponder()` / `@FocusState`-covers-everything model. None of the iOS focus rules
transfer.

Two true facts the audit enforces:
1. A custom `NSView`/`NSControl` is **not focusable at all** unless it returns `true` from
   `acceptsFirstResponder`.
2. You make it active through `window.makeFirstResponder(_:)`. There is **no public "make this arbitrary
   SwiftUI view first responder" call.** `@FocusState` (macOS 12+) covers SwiftUI-native controls but
   **not** arbitrary first-responder behaviour (custom field editors, insertion-point color, focus rings).

❌ call `becomeFirstResponder()` on a SwiftUI value / expect `@FocusState` to drive AppKit:
```swift
someView.becomeFirstResponder()        // ❌ not a thing on a SwiftUI value
// a custom NSView subclass with no acceptsFirstResponder override, expected to take focus ❌
```

✅ opt in on the AppKit subclass; drive focus through the window:
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
if isFocused, nsView.window?.firstResponder !== nsView {
    nsView.window?.makeFirstResponder(nsView)
}
```

macOS detail: text controls share a single per-window `NSText` field editor
(`window?.fieldEditor(true, for:)`); customizing insertion-point color / selection means reaching it inside
`becomeFirstResponder()`, with no iOS analog. Verify the `@FocusState` floor (macOS 12) against
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://forums.swift.org/t/swiftui-textfield-focus-firstresponder-macos/35018 | forum | `@FocusState` (macOS 12+) for SwiftUI controls vs an `NSViewRepresentable` bridge for finer first-responder control. Accessed 2026-06-07. |
| https://github.com/onmyway133/blog/issues/589 | practitioner | `FocusAwareTextField` overriding `acceptsFirstResponder` + `becomeFirstResponder()`; focus driven via the window. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsresponder/acceptsfirstresponder | primary-doc | a view returns `true` from `acceptsFirstResponder` to become first responder; default `false`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nswindow/makefirstresponder(_:) | primary-doc | window-level call that promotes a responder; the macOS focus entry point. Accessed 2026-06-07. |
