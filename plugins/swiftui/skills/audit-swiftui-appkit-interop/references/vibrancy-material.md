# Vibrancy — behind-window material vs in-window SwiftUI material (interop-07)

`fix_mode: flag-only`, **advisory**. `cross_ref: appearance-color` (that skill owns broader
color/material craft; this flags the specific in-window-flat sidebar at the bridge seam).

SwiftUI's materials blend against the **window's own content**, not the desktop and windows *behind* the
window. A real macOS sidebar/panel uses **behind-window** vibrancy. So `.ultraThinMaterial` on a sidebar
renders flat — it never picks up what's actually behind the window — while a native sidebar built on
`NSVisualEffectView(material: .sidebar, blendingMode: .behindWindow)` samples the desktop and is visibly
deeper. `.ultraThinMaterial` is the strongest SwiftUI vibrancy and still looks noticeably flatter
side-by-side. The Mac-correct material is `NSVisualEffectView` bridged through `NSViewRepresentable`.

❌ SwiftUI material as a "native" sidebar background (composites in-window → flat):
```swift
List { /* … */ }
    .background(.ultraThinMaterial)   // ❌ blends against window content, not behind-window
```

✅ wrap `NSVisualEffectView` with behind-window blending:
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
        nsView.material = material; nsView.blendingMode = blendingMode
    }
}
List { /* … */ }.background(VisualEffectView(material: .sidebar))
```
`.sidebar` + `.behindWindow` is the genuine sidebar look; set `state = .active` so vibrancy survives when
the window isn't key. This is `NSVisualEffectView` (the established AppKit material) — **not** the macOS-26
Liquid Glass `NSGlassEffectView`, which is out of scope here.

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://developer.apple.com/documentation/appkit/nsvisualeffectview | primary-doc | `material` + `blendingMode` (`.behindWindow` / `.withinWindow`) + `state`; behind-window samples desktop content. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode | primary-doc | `.behindWindow` blends with content behind the window; `.withinWindow` blends with content within it. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/material | primary-doc | SwiftUI `Material` (`.ultraThinMaterial` … `.thickMaterial`) composites against the view's own backdrop within the window. Accessed 2026-06-07. |
