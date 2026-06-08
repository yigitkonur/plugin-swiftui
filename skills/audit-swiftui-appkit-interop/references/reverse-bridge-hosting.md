# Reverse bridge — hosting SwiftUI inside AppKit (interop-05, interop-08)

`fix_mode: flag-only`. The reverse direction: dropping SwiftUI into an existing `NSWindow` /
`NSViewController` / popover / `MenuBarExtra` / toolbar item.

## interop-05 — the sanctioned host is `NSHostingController` / `NSHostingView`

In a mostly-AppKit app, AI tries to instantiate SwiftUI views by hand or claims SwiftUI "can't be
embedded." Both are wrong. The bridge is `NSHostingController` (an `NSViewController` whose content is a
SwiftUI `rootView`) or `NSHostingView` (an `NSView` host).

❌ claim it can't be done / hand-instantiate:
```swift
let v = MySwiftUIView()             // ❌ a View is not an NSView
window.contentView?.addSubview(v)   // ❌ does not compile / nothing renders
```
✅ host through the AppKit bridge type:
```swift
let host = NSHostingController(rootView: MySwiftUIView())    // macOS 10.15+
window.contentViewController = host
// or as a plain view:
let v = NSHostingView(rootView: MySwiftUIView())
```

**swiftui-ctx grounding (the canonical ✅):** `swiftui-ctx lookup NSHostingController --json` returns
`consensus: [{shape:"(rootView)", pct:100}]`, `introduced_macos:"10.15"`, and `recommended` =
`NSHostingController(rootView: contentView)` permalinked at
`https://github.com/jordanbaird/Ice/blob/11edd39115f3f43a83ae114b5348df6a0e1741cf/Ice/MenuBar/Appearance/MenuBarAppearanceEditor/MenuBarAppearanceEditorPanel.swift#L105`
(jordanbaird/Ice, 28k★, `min_macos:26`). Put `(rootView:)` in `## Correct`; that permalink + the Sosumi
`doc:` in `## Source`. Fetch the enclosing body live with `swiftui-ctx file ex_ff382027c2 --smart`.

## interop-08 — scene chrome under `NSHostingView`: split by OS and modifier

The reverse bridge gets you *pixels*. Whether it carries scene-level chrome (`.toolbar`,
`.navigationTitle`) depends on **scene bridging**, and AI gets it wrong in both directions.

`macOS 14` added `NSHostingView.sceneBridgingOptions` (`NSHostingSceneBridgingOptions`: `.toolbars`,
`.title`, `.all`, `[]`). When the hosting view is the window's `contentView`, it defaults to `.all`, so
`.toolbar` / `.navigationTitle` route automatically. If the host is **nested** (not the `contentView`),
the default is `[]` — set the options yourself. **`.searchable` has NO scene bridge — it never renders
under a bare `NSWindow` + `NSHostingView`, on any macOS version.**

macOS 14 release notes, verbatim: *"The toolbar and navigationTitle modifiers now work outside of the
SwiftUI App Lifecycle on macOS. Use `NSHostingView.sceneBridgingOptions` to enable or disable this
functionality."*

✅ WORKS on macOS 14+ — toolbar/title bridge:
```swift
let host = NSHostingView(rootView: root.toolbar { … }.navigationTitle("Items"))
window.contentView = host                 // as contentView → defaults to .all
host.sceneBridgingOptions = [.toolbars, .title]   // REQUIRED if host is nested ([] default)
```
❌ expect `.searchable` to bridge:
```swift
window.contentView = NSHostingView(rootView: ContentView().searchable(text: $query))  // ❌ never appears
```
✅ for search: own a SwiftUI scene (`WindowGroup { ContentView().searchable(…) }`) — searchable resolves
normally — or drive search via an `NSSearchField` in an `NSToolbar`. On macOS 13 and earlier there is no
scene bridge at all; `.toolbar` / `.navigationTitle` also do nothing under a hand-built `NSWindow`.

Floors (`sceneBridgingOptions` = macOS 14): `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/nshostingcontroller | primary-doc | *"An AppKit view controller that hosts SwiftUI view hierarchy."* (`init(rootView:)`); `macOS 10.15+`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nshostingview | primary-doc | *"An AppKit view that hosts a SwiftUI view hierarchy."*; `macOS 10.15+`; `sceneBridgingOptions` (macOS 14+). Accessed 2026-06-07. |
| https://developer.apple.com/documentation/macos-release-notes/macos-14-release-notes | primary-doc | verbatim: *"The toolbar and navigationTitle modifiers now work outside of the SwiftUI App Lifecycle on macOS. Use NSHostingView.sceneBridgingOptions to enable or disable this functionality."* Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nshostingscenebridgingoptions | primary-doc | option set (macOS 14+): `.toolbars`, `.title`, `.all`, `[]`; default `.all` when host is the window `contentView`, else `[]`. Accessed 2026-06-07. |
