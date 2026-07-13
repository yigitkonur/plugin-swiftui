# AppKit Liquid Glass (macOS 26)

As of macOS 26 (Tahoe), AppKit gets its own Liquid Glass surface — `NSGlassEffectView` and friends — parallel to SwiftUI's `.glassEffect()`. You reach for it when SwiftUI's glass modifiers don't give you enough control: custom corner radius/tint on a glass platter, rotated glass, a hand-built `NSToolbar`, or any app whose shell is AppKit. Everything here is **macOS-only** (these classes don't exist on iOS) and **macOS-26-only** — gate every symbol below behind `#available(macOS 26, *)` or the project won't compile against an earlier deployment target.

> macOS-only. There is no UIKit equivalent of `NSGlassEffectView`; iOS adopts Liquid Glass purely through the SwiftUI `.glassEffect()` surface. None of the AppKit classes below exist off the Mac.

Default: **stay in SwiftUI's `.glassEffect()`** and bridge only the one view that needs AppKit-level glass. Don't wrap a whole window in `NSGlassEffectView` because one control wants a custom tint.

---

## 1. The inactive/non-key-window opacity trap (HIGH — read this first)

`NSGlassEffectView` has **no `state` property** — there is no `NSVisualEffectView.state = .active` equivalent. When the host `NSWindow` is **not the key window**, the glass renders **significantly more opaque/solid**, and there is **no public API to force the active (translucent) appearance**. This is the single most damaging AppKit-glass gotcha: it breaks HUD-style floating windows, tool palettes, inspectors, and any overlay that intentionally never takes key focus — exactly the windows that most want glass. It is **unresolved as of macOS 26.4**.

❌ **WRONG** — assume there's a `state`-style switch (there isn't), or reach for the private override to "fix" it:
```swift
let glass = NSGlassEffectView()
glass.state = .active                    // ❌ does not compile — no such property on NSGlassEffectView

// ❌ The only known "workaround": overriding private NSWindow appearance methods.
final class AlwaysActiveWindow: NSWindow {
    override var _hasActiveAppearance: Bool { true }   // ❌ private API
    override var _hasKeyAppearance: Bool { true }      // ❌ private API — App Store REJECTION risk, breaks on future macOS
}
```

✅ **CORRECT** — accept the limitation; for a non-key overlay that must stay translucent, fall back to `NSVisualEffectView` (which *does* have `state = .active`) instead of forcing glass:
```swift
// HUD / floating palette that never becomes key → use NSVisualEffectView so it stays translucent.
let backing = NSVisualEffectView()
backing.material = .hudWindow
backing.blendingMode = .behindWindow
backing.state = .active                  // ✅ public API — stays vibrant on inactive windows
// File Feedback with Apple requesting a `state`-equivalent on NSGlassEffectView.
```

There is no full public fix. Setting `glass.style = .clear` (§2) makes the glass start from the Dock's more-transparent look and **partially** mitigates the heavier inactive appearance — but it does not eliminate it. Otherwise, either tolerate the heavier glass on inactive windows, or use `NSVisualEffectView` for the specific windows that must remain translucent without key focus. **Never** ship the `_hasActiveAppearance` / `_hasKeyAppearance` override — it is private API and is an App Store rejection (and future-breakage) risk.

---

## 2. `NSGlassEffectView` — the core glass surface

The AppKit equivalent of `.glassEffect()`: renders a Liquid Glass material as a view's background with a content view on top. It exposes **four** public properties.

| Property | Type | Notes |
|---|---|---|
| `contentView` | `NSView?` | The view drawn on top of the glass platter |
| `cornerRadius` | `CGFloat` | Per-view corner radius — **not** inherited from a container |
| `tintColor` | `NSColor?` | Optional color composited into the glass material |
| `style` | `NSGlassEffectView.Style` | `.regular` (default, more opaque) or `.clear` (the Dock / Control-Center look) |

There is no material enum, no `state`, and no blur-radius knob — the API is deliberately minimal.

```swift
if #available(macOS 26, *) {
    let glass = NSGlassEffectView()
    glass.contentView = myContentView          // drawn on top of the glass
    glass.cornerRadius = 12
    glass.tintColor = .controlAccentColor      // optional tint
    glass.style = .clear                       // .regular (default) or .clear — Dock-style transparency
}
```

**`style = .clear`** is how you match the Dock's transparency, and it *partially* mitigates the inactive-window opacity trap (§1) — but it does **not** fully fix it; even `.clear` glass renders heavier on a non-key window.

**Migration note:** `NSVisualEffectView` is **NOT deprecated** and keeps working — but it does **NOT** produce the Liquid Glass appearance. The two are not interchangeable: `NSVisualEffectView` is material-based vibrancy (blur); `NSGlassEffectView` is the new compositing pipeline with specular highlights and depth-aware tinting. To adopt the new design, replace `NSVisualEffectView` with `NSGlassEffectView` — but keep `NSVisualEffectView` as the pre-26 fallback (and as the only way to get a `state`-controlled translucent inactive window — see §1).

### NSViewRepresentable wrapper

Wrap it when you want a glass platter with a custom radius/tint inside an otherwise-SwiftUI view, and adapt for pre-Tahoe targets in the same wrapper:

```swift
struct AdaptiveGlassView: NSViewRepresentable {            // macOS 10.15+ wrapper; glass arm gated to 26
    var cornerRadius: CGFloat = 12
    var tintColor: NSColor? = nil

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.tintColor = tintColor
            return glass
        } else {
            let fallback = NSVisualEffectView()           // closest pre-26 look
            fallback.material = .sidebar
            fallback.blendingMode = .behindWindow
            fallback.state = .active
            return fallback
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if #available(macOS 26, *), let glass = nsView as? NSGlassEffectView {
            glass.cornerRadius = cornerRadius
            glass.tintColor = tintColor
        }
        // NSVisualEffectView needs no per-update work for basic usage.
    }
}
```

---

## 3. `NSGlassEffectContainerView` — grouping glass

Glass cannot sample other glass. When multiple `NSGlassEffectView`s sit near each other, group them in an `NSGlassEffectContainerView` so they composite against the same background snapshot (the AppKit equivalent of `GlassEffectContainer`). The container exposes two properties:

| Property | Type | Notes |
|---|---|---|
| `contentView` | `NSView?` | The view holding the child glass views |
| `spacing` | `CGFloat` | Proximity threshold at which neighboring child glass views visually merge; default `0` |

The container has **no `cornerRadius`** — each child `NSGlassEffectView` sets its own.

❌ **WRONG** — set a corner radius on the container (there is no such property — this is a **compile error**):
```swift
if #available(macOS 26, *) {
    let container = NSGlassEffectContainerView()
    container.cornerRadius = 16        // ❌ does NOT COMPILE — NSGlassEffectContainerView has no cornerRadius
    container.addSubview(NSGlassEffectView())
}
```

✅ **CORRECT** — tune merge distance via `spacing`; each child sets its own `cornerRadius`:
```swift
if #available(macOS 26, *) {
    let container = NSGlassEffectContainerView()
    container.spacing = 12                                  // children within 12pt merge into one glass shape
    let child1 = NSGlassEffectView(); child1.cornerRadius = 16
    let child2 = NSGlassEffectView(); child2.cornerRadius = 16
    container.addSubview(child1)
    container.addSubview(child2)
}
```

Corner radius is **per-child** — every `NSGlassEffectView` child must set `cornerRadius` itself, or it renders with the default radius and breaks visual consistency. Use `spacing` to control how close two glass views must be before they fuse into a single shape.

---

## 4. `NSBackgroundExtensionView` — bleed content under the chrome

The AppKit equivalent of SwiftUI's `.backgroundExtensionEffect()`. Extends a content view edge-to-edge **behind** the glass toolbar and title bar, producing the signature layered Liquid Glass depth (hero image or sidebar color showing through the toolbar glass).

```swift
if #available(macOS 26, *) {
    let extensionView = NSBackgroundExtensionView()
    extensionView.contentView = heroImageView          // bleeds under the toolbar glass
    extensionView.automaticallyPlacesContentView = true // default: view auto-positions the content within the safe area
    // install as the background of your content area
}
```

`automaticallyPlacesContentView` (default `true`) lets the view position and size its `contentView` against the safe area for you; set it `false` only when you need to lay the content view out manually. Use this view whenever content should appear to run under the toolbar on macOS — without it, content stops at the safe-area inset boundary.

---

## 5. `NSView.LayoutRegion` — avoid the larger window corners

macOS 26 windows have **larger corner radii** (roughly a 3-tier system: ~16pt inner controls / 20pt panels / 26pt window chrome) and there is **no public API to control them**. Content placed in corners gets clipped. The static factories `safeArea(cornerAdaptation:)` and `margins(cornerAdaptation:)` build a `LayoutRegion`; `layoutGuide(for:)` then returns a guide whose insets respect the rounded corners. The `cornerAdaptation` parameter is an optional `AdaptivityAxis?` (default `nil`) — its only cases are `.horizontal` and `.vertical`.

```swift
if #available(macOS 26, *) {
    // cornerAdaptation: .horizontal | .vertical | nil (default)
    let guide = view.layoutGuide(for: .safeArea(cornerAdaptation: .horizontal))
    let child = childView
    child.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        child.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
        child.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
        child.topAnchor.constraint(equalTo: guide.topAnchor),
        child.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
    ])
}
```

| `cornerAdaptation` | Behavior |
|---|---|
| `.horizontal` | Insets leading/trailing edges to clear the corners |
| `.vertical` | Insets top/bottom edges to clear the corners |
| `nil` (omit) | No axis-specific corner adaptation |

There is **no `.all` case** — passing `.all` is a compile error. To clear corners on both axes, build the region with the axis your layout actually needs, or omit the argument. This guide is primarily needed when you host raw `NSView` subclasses managing their own Auto Layout; pure-SwiftUI content uses `.safeAreaPadding()` instead.

---

## 6. `prefersCompactControlSizeMetrics` — revert macOS-26 control enlargement

macOS 26 **enlarges** many controls (buttons, text fields) to match the Liquid Glass language. If a dense layout needs the pre-Tahoe (macOS 15 and earlier) sizing, opt out per view-hierarchy:

```swift
if #available(macOS 26, *) {
    view.prefersCompactControlSizeMetrics = true   // back to macOS-15-era compact control sizes
}
```

Use it sparingly — the larger sizes are the intended Tahoe experience; this is for utility/inspector layouts that genuinely can't absorb the extra height.

---

## 7. Toolbar & button glass

Existing `NSToolbarItem` and `NSButton` gain glass-related properties on macOS 26.

### NSToolbarItem glass props

```swift
if #available(macOS 26, *) {
    let item = NSToolbarItem(itemIdentifier: .init("inbox"))
    item.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "Inbox")
    item.isBordered = false                          // remove the default glass platter background
    item.style = .prominent                          // accent-tinted glass (like .glassProminent) — macOS 26.0+
    // item.style = .plain                           // reset to the default, non-prominent glass
    item.backgroundTintColor = NSColor.systemBlue    // custom glass tint
    item.badge = .count(12)                          // NSItemBadge: .count(_) / .text(_) / .indicator
}
```

- **`isBordered = false`** — strips the default glass background from the item.
- **`style`** — `NSToolbarItem.Style`: `.prominent` for accent-tinted glass, `.plain` to reset to the default non-prominent appearance.
- **`backgroundTintColor`** — a custom tint for the item's glass.
- **`NSItemBadge`** via `item.badge` — `.count(Int)`, `.text(String)`, or `.indicator` (dot).

### NSButton glass bezel

```swift
if #available(macOS 26, *) {
    let button = NSButton(title: "Submit", target: self, action: #selector(submit))
    button.bezelStyle = .glass                       // Liquid Glass bezel
    button.bezelColor = .controlAccentColor          // accent-tinted glass (primary action)
    // button.bezelColor = .clear                    // neutral glass (secondary action)
    button.tintProminence = .secondary               // hierarchy hint among similar buttons
}
```

- **`bezelColor`** — the path for glass-button tint control.
- **`tintProminence`** (`NSTintProminence`, macOS 26+) — suggests a button's prominence in a hierarchy of similar buttons. It **complements** `bezelColor` (it does not replace it): use `bezelColor` for the tint, `tintProminence` to rank related buttons.

---

## 8. `NSSplitView` — glass sidebar layouts

Split-view items gain glass-aware conveniences for sidebar layouts. The accessory methods take an `NSSplitViewItemAccessoryViewController` (a distinct subclass — **not** a plain `NSViewController`):

```swift
if #available(macOS 26, *) {
    let headerVC: NSSplitViewItemAccessoryViewController = makeHeaderAccessory()
    let footerVC: NSSplitViewItemAccessoryViewController = makeFooterAccessory()

    splitViewItem.automaticallyAdjustsSafeAreaInsets = true       // auto-inset for the glass toolbar/chrome
    splitViewItem.addTopAlignedAccessoryViewController(headerVC)   // sidebar header
    splitViewItem.addBottomAlignedAccessoryViewController(footerVC) // sidebar footer
}
```

`automaticallyAdjustsSafeAreaInsets` replaces manual inset math against the glass toolbar; the top/bottom accessory view controllers — each an `NSSplitViewItemAccessoryViewController`, not a bare `NSViewController` — align header/footer content within a pane, outside its scroll region.

---

## 9. Never use the private `set_variant(_:)`

Integers 0–19 exist as undocumented glass variants behind the private `set_variant(_:)` selector. **Never call it** — it is private API, will break on future macOS releases, and gets apps rejected in App Store review.

```swift
// ❌ NEVER — private API, breaks/rejection
glassView.perform(Selector(("set_variant:")), with: 5)

// ✅ Public surface only
glassView.cornerRadius = 12
glassView.tintColor = .clear
```

---

## Pre-26 fallback (the whole-file rule, restated)

Every symbol above is macOS-26-only and AppKit-only. If the deployment target dips below macOS 26, the compiler emits an availability error (and bypassing it via weak-linking yields a missing-symbol crash at launch, not graceful degradation). Always gate:

```swift
if #available(macOS 26, *) {
    let glass = NSGlassEffectView()
    glass.cornerRadius = 12
    // …
} else {
    let fallback = NSVisualEffectView()   // material-based vibrancy — closest pre-26 look
    fallback.material = .sidebar
    fallback.blendingMode = .behindWindow
    fallback.state = .active
}
```

---

## Sources

| URL / Reference | Type | Key fact |
|---|---|---|
| https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass | primary-doc | "Adopting Liquid Glass" — adoption guidance and the new design language across AppKit/SwiftUI. Accessed 2026-06-07. |
| https://developer.apple.com/videos/play/wwdc2025/310/ | WWDC25 Session 310 — "Build an AppKit app with the new design" | The canonical AppKit Liquid Glass session: `NSGlassEffectView`, `NSBackgroundExtensionView`, `NSView.LayoutRegion`, toolbar-item and split-view changes. Accessed 2026-06-07. |
| https://developer.apple.com/videos/play/wwdc2025/219/ | WWDC25 Session 219 — "Meet Liquid Glass" | Design principles, philosophy, and the visual language behind Liquid Glass. Accessed 2026-06-07. |
| https://developer.apple.com/videos/play/wwdc2025/323/ | WWDC25 Session 323 — "Build a SwiftUI app with the new design" | SwiftUI glass surface (`.glassEffect()`, `GlassEffectContainer`) that the AppKit classes here parallel. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsglasseffectview | primary-doc | `NSGlassEffectView` reference — four properties `contentView` / `cornerRadius` / `tintColor` / `style` (`NSGlassEffectView.Style`: `.regular` / `.clear`); macOS 26+. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsglasseffectcontainerview | primary-doc | `NSGlassEffectContainerView` reference — `contentView` / `spacing`; **no `cornerRadius`**. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsbackgroundextensionview | primary-doc | `NSBackgroundExtensionView` reference — `contentView` / `automaticallyPlacesContentView`; macOS 26+. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsview/layoutregion | primary-doc | `NSView.LayoutRegion` — `safeArea(cornerAdaptation:)` / `margins(cornerAdaptation:)`; `AdaptivityAxis` is `.horizontal` / `.vertical` only (optional, default `nil`). Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nstoolbaritem | primary-doc | `NSToolbarItem` — `style` (`NSToolbarItem.Style`: `.plain` / `.prominent`), `isBordered`, `backgroundTintColor`, `badge`; macOS 26+. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsbutton/tintprominence | primary-doc | `NSButton.tintProminence` (`NSTintProminence`) — confirmed macOS 26+; suggests hierarchy among similar buttons, complements `bezelColor`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nssplitviewitem | primary-doc | `NSSplitViewItem` — `automaticallyAdjustsSafeAreaInsets`; accessory methods take `NSSplitViewItemAccessoryViewController`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsvisualeffectview | primary-doc | `NSVisualEffectView` (not deprecated) — `material` / `blendingMode` / `state`; the pre-26 vibrancy fallback. Accessed 2026-06-07. |
| https://www.swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/ | practitioner (Majid Jabrayilov) | Liquid Glass migration is not backward-compatible; macOS-26 APIs need `#available` guards. Accessed 2026-06-07. |
| https://github.com/feedback-assistant (Apple Feedback Assistant) | practitioner threads | Community reports of the `NSGlassEffectView` inactive/non-key-window opacity behavior (no `state` equivalent) and the private `_hasActiveAppearance` / `_hasKeyAppearance` override; unresolved as of macOS 26.4. Accessed 2026-06-07. |
