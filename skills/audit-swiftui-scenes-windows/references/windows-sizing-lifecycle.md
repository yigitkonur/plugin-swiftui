# Reference — Auxiliary Windows, Sizing, Style & Lifecycle (sw-04 / 08 / 09 / 10 / 11 / 12 / 13)

Everything about *opening, sizing, styling, dismissing, and quitting* Mac windows. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; this file carries the mechanics, the
detection content, and the ❌→✅. The `MenuBarExtra` activation trap is its own file
(`menu-bar-activation-trap.md`); the scene-type vocabulary is `scene-types-and-settings.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## sw-04 — a second window faked with a sheet or a `@State` bool (warning; flag-only)

A sheet is **modal** and lives *inside* the current window — it can never be a separate,
independently-movable, independently-resizable Mac window. A `@State` boolean cannot create or own a
real window; the scene system owns window lifetime. The Mac idiom is a **registered scene + the
`openWindow` action**.

```swift
// ❌ fakes a second window with a sheet/flag — modal, trapped in this window
@State private var showInspector = false
// .sheet(isPresented: $showInspector) { InspectorView() }

// ✅ register a scene, open it via openWindow
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        Window("Inspector", id: "inspector") { InspectorView() }   // single unique window
        // or UtilityWindow("Inspector", id:) { … } for a floating panel; or
        // WindowGroup(id: "doc", for: Item.ID.self) { … } for typed multiple instances
    }
}
struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View { Button("Open Inspector") { openWindow(id: "inspector") } }
}
```

The **tell**: `.sheet(isPresented:` used for something the user would expect as a separate window
(inspector, second document). For a *floating* inspector prefer `UtilityWindow` (macOS 15+) over a plain
`Window`. The consensus open shape is `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup openWindow --json`.

---

## sw-08 — no scene sizing (advisory; flag-only)

iOS never makes you size a window — the screen *is* the size. On macOS, windows resize freely, so
without `.defaultSize` / `.windowResizability` the first-run window is the wrong size and a utility
window can be stretched to absurd dimensions.

```swift
// ❌ uncontrolled size and resize
WindowGroup { ContentView() }

// ✅ set default size and resizability
WindowGroup { ContentView() }
    .defaultSize(width: 800, height: 600)
    .windowResizability(.contentSize)   // clamp to the content's frame limits
Window("Inspector", id: "inspector") { InspectorView() }
    .windowResizability(.contentSize)
```

`.defaultSize(_:)` and `.windowResizability(_:)` are both macOS 13.0+. On **macOS 15+** you also get
`.windowIdealSize(_:)`, `.windowIdealPlacement(_:)`, and `.windowManagerRole(_:)` (principal vs.
auxiliary, so Stage Manager / tiling treats the scene correctly).

**Seam:** this is the **scene-modifier layer** of window sizing — **ours**. The **content-frame layer**
(`.frame(minWidth:idealWidth:maxWidth:…)` on the root view) is `audit-swiftui-layout-and-tables`; when
both apply, emit `cross_ref: audit-swiftui-layout-and-tables` (the window-sizing two-domain split,
`${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`). The consensus is
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx recipe window-scene` (real examples: `jordanbaird/Ice`,
`leetcode-mafia/cheetah`).

---

## sw-09 — `openWindow(id:)` typo → silent no-op (hard-fail; flag-only)

`openWindow(id:)` matches its argument against the `id` you gave a `Window(id:)`/`WindowGroup(id:)`
scene. If the string matches **no** registered scene (a typo, a renamed scene, a constant that drifted),
the call is a **silent no-op** — no crash, no error, no console warning, no window. The diff reads
correctly; nothing happens at runtime.

```swift
// ❌ the id passed doesn't match the registered scene; the button is dead
Window("Inspector", id: "inspector") { InspectorView() }
Button("Open Inspector") { openWindow(id: "Inspector") }   // capital I ≠ "inspector" → no-op

// ✅ share one constant so the id can't drift
enum WindowID { static let inspector = "inspector" }
Window("Inspector", id: WindowID.inspector) { InspectorView() }
Button("Open Inspector") { openWindow(id: WindowID.inspector) }
```

This is **deliberately not a lint rule** — confirming it needs the **project-wide** scene-id ↔
open-call cross-reference only the agent can build in READ (step 3): collect every
`Window(id:)`/`WindowGroup(id:)`/`UtilityWindow(id:)` literal, then check every `openWindow(id:)` /
`dismissWindow(id:)` string against that set. A finding is 100% only once you have confirmed **no** scene
registers that string anywhere. Because the failure is invisible to a code review, **test the open at
runtime**. (`dismissWindow(id:)` no-ops the same way.)

---

## sw-10 — auxiliary window opened but never dismissed (advisory; flag-only)

Opening a window via `openWindow` with no code path to close it — or flipping a `@State` flag that the
real window ignores. The window's lifetime is owned by the scene system; a boolean can't close it. Use
the `dismissWindow` environment action with the **same `id`**.

```swift
// ❌ a boolean the real window ignores
@State private var inspectorOpen = false
Button("Close Inspector") { inspectorOpen = false }   // window stays open

// ✅ dismissWindow(id:)
@Environment(\.dismissWindow) private var dismissWindow
Button("Close Inspector") { dismissWindow(id: "inspector") }
```

`dismissWindow` / `DismissWindowAction` is **macOS 14.0+** — NOT 13 (it trails `openWindow` by one
release; don't assume the pair shares a version). Its verbatim description is **UNVERIFIED — `verify
against Xcode 26 SDK`**. The **tell**: `@Environment(\.openWindow)` present, no
`@Environment(\.dismissWindow)` anywhere, despite an auxiliary window.

---

## sw-11 — `WindowGroup`-only `App`, expecting macOS lifecycle it can't deliver (warning; flag-only)

`WindowGroup` is a *scene*, not an app lifecycle. On its own it **cannot**: quit the app when the last
window closes, run global `NSApp`-level setup at launch, or hook `applicationWillTerminate` for
save-on-quit. AI assumes the iOS lifecycle (one window, app stays alive headless) and ships an `App`
with only scenes — then the Mac app keeps running with no windows, or never gets its launch/terminate
hooks. The fix is an `NSApplicationDelegate` wired via `@NSApplicationDelegateAdaptor`.

```swift
// ❌ only scenes; app won't quit when the last window closes, no launch/terminate hooks
@main struct MyApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

// ✅ bridge an AppDelegate for the lifecycle SwiftUI doesn't expose
@main struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { WindowGroup { ContentView() } }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) { /* global NSApp setup */ }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ n: Notification) { /* save-on-quit */ }
}
```

`@NSApplicationDelegateAdaptor` is macOS 11.0+. A **menu-bar-only** app deliberately returns `false`
(or omits the hook) so closing windows doesn't quit it — the ✅ answer depends on the app **type**
recorded in ORIENT, which is why this is flag-only, not auto. The **tell**: an `App` with scenes but no
`@NSApplicationDelegateAdaptor`, where the app needs quit-on-last-window / launch / terminate.

---

## sw-12 — wrong / absent `.windowStyle` for Mac chrome (advisory; flag-only)

A content-forward app keeps the default titled chrome when it wants `.hiddenTitleBar`; a utility wants a
plainer style. Mac window chrome is a deliberate design choice with no iOS equivalent.

```swift
// ❌ default titled bar even when the design wants it hidden
WindowGroup { ContentView() }

// ✅ pick the chrome
WindowGroup { ContentView() }.windowStyle(.hiddenTitleBar)   // content-forward look
```

`windowStyle(_:)` / `WindowStyle` (cases `.hiddenTitleBar`, `.titleBar`, `.plain`) are macOS 11.0+. The
exact case strings are **UNVERIFIED — `verify against Xcode 26 SDK`**; treat the names as
canonical-but-verify. This is a judgment flag — only raise it when the design clearly wants different chrome.

---

## sw-13 — `navigationTitle` inside a `Window` scene replaces the titlebar (advisory; flag-only)

A `navigationTitle(_:)` placed **inside a `Window` scene** *replaces* the window's titlebar text rather
than adding a navigation title, which surprises code expecting the `Window("…", id:)` label to win. Owned
here as the scene-side gotcha; the broader `navigationTitle`/toolbar migration is
`audit-swiftui-navigation-toolbars` — emit `cross_ref: audit-swiftui-navigation-toolbars`.

---

## Go-beyond artifact — the scene-graph map

Optionally write `swiftui-audits/scenes-windows/_scene-graph.md`: a table of every scene the `App`
declares (`type · id · sizing · style · gate`) plus every `openWindow`/`dismissWindow` call mapped to
its scene, **red where an `id` is unmatched** (the sw-09 evidence in one view). It also makes sw-08
(unsized scenes) and sw-10 (no dismiss path) visible at a glance.

---

## Sources

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/openwindowaction | `openWindow` / `OpenWindowAction` — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/environmentvalues/dismisswindow | `dismissWindow` / `DismissWindowAction` — **macOS 14.0+ (NOT 13)** | high (desc UNVERIFIED) |
| https://developer.apple.com/documentation/swiftui/scene/defaultsize(_:) | `defaultSize(_:)` — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/scene/windowresizability(_:) | `windowResizability(_:)` — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/scene/windowidealsize(_:) | `windowIdealSize(_:)` / `windowIdealPlacement(_:)` — macOS 15.0+ | high |
| https://developer.apple.com/documentation/swiftui/scene/windowmanagerrole(_:) | `windowManagerRole(_:)` — principal vs. auxiliary role — macOS 15.0+ | high |
| https://developer.apple.com/documentation/swiftui/windowstyle | `windowStyle(_:)` / `WindowStyle` cases — macOS 11.0+ | high (case strings UNVERIFIED) |
| https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldterminateafterlastwindowclosed(_:) | quit-on-last-window AppKit hook bridged via `@NSApplicationDelegateAdaptor` (macOS 11.0+) | high |

Apple availability strings cross-checked against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
and fetched via Sosumi (access 2026-06-07). UNVERIFIED strings flagged inline.
