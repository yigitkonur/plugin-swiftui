# Scenes & Windows (macOS)

> **macOS-only.** This domain is almost entirely macOS-divergent — that is the point. `MenuBarExtra` and `Settings` have **no iOS analog**; the `Window` (single unique) vs `WindowGroup` (user-duplicable) split barely matters on iOS (one window) but is fundamental on the Mac, where ⌘N spawns new `WindowGroup` instances and ⌘, opens Settings.

AI defaults to the **iOS one-window mental model**: it hard-codes a single `WindowGroup`, crams Preferences into the main window, fakes a menu-bar app with AppKit `NSStatusItem`, opens auxiliary windows by flipping a `@State` boolean, and omits the scene-sizing modifiers that make a Mac window behave like a Mac window. The scene-composition APIs live at **`App.body` level** — a spot iOS tutorials rarely exercise — so the model has thin priors there. Worst of all is the **menu-bar→`openWindow` activation trap**: code that reads correctly in a diff opens a window *behind everything* because the app was never activated.

## The five scene types

| Scene | What it is | When | Availability |
|---|---|---|---|
| `WindowGroup` | User-duplicable window (⌘N spawns more); `WindowGroup(id:for:content:)` / `WindowGroup(for:)` for typed multi-instance | The main window of most apps | macOS 11.0+ |
| `Window` | A **single unique** window — one instance, no ⌘N duplication | Console, "About"-style auxiliary windows | macOS 13.0+ |
| `UtilityWindow` | A **single unique** auxiliary/utility **panel** — floats above normal windows and auto-adds a show/hide item to the View menu; the modern inspector/utility type, distinct from `Window` | Inspectors, tool palettes, floating utility panels | macOS 15.0+ (macOS-only) |
| `Settings {}` | The standard Preferences window — adds the "Settings…" menu item, ⌘, shortcut, and a floating window automatically | App preferences. The **only** idiomatic mechanism | macOS 11.0+ (macOS-only) |
| `MenuBarExtra` | A persistent control in the system menu bar | Menu-bar / status-item apps | macOS 13.0+ (macOS-only) |

`UtilityWindow` (macOS 15) is what you reach for when you want a floating inspector/tool panel rather than a plain document-level `Window`: it stays above the main window and registers its own View-menu show/hide command for free.

Environment actions to drive them from a view: `\.openWindow` (`OpenWindowAction`, macOS 13.0+), `\.dismissWindow` (`DismissWindowAction`, **macOS 14.0+**), `\.openSettings` (`OpenSettingsAction`, macOS 14.0+), `\.pushWindow` (`PushWindowAction`, macOS 15.0+ — opens a window *and* hides the originator). `SettingsLink` (a view, macOS 14.0+) is the no-action way to open Settings from a button.

---

## The 9 mistakes

### 1 — Preferences crammed into the main window instead of the `Settings` scene

Mac users press **⌘, (Command-comma)** to open a standard, separate Preferences window from the app menu. A `NavigationLink` gives none of that — no menu item, no shortcut, no floating window. The `Settings {}` scene wires all three automatically.

❌ **WRONG** — a "Settings" link/sheet inside the main window; ⌘, does nothing:
```swift
WindowGroup {
    NavigationStack {
        NavigationLink("Settings") { SettingsView() }   // ⌘, dead, no menu item
    }
}
```

✅ **CORRECT** — the `Settings {}` scene adds the menu item + ⌘, + window:
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        #if os(macOS)
        Settings { SettingsView() }   // "Settings…" menu item + ⌘, + window
        #endif
    }
}
```
To reach it from a button without the menu, use `SettingsLink` (a view) or the `openSettings` environment action (macOS 14+).

**Settings-window hard rules (Apple HIG).** A proper macOS Settings window is not a generic dialog — it must:
- Be **modeless** — changes apply *immediately*, with **no Save / Cancel / Apply buttons** (the save-or-cancel modal is a Windows convention and reads as non-native on the Mac).
- Have its **minimize and maximize (yellow/green) buttons dimmed** — a Settings window is fixed-purpose, not a resizable document window.
- **Persist the last-selected tab across reopens**, so ⌘, returns the user to where they were.
- Use **checkboxes (`Toggle`)** for simple on/off settings, not iOS-style switches.

❌ **WRONG** — a modal Settings sheet with Save/Cancel; changes don't apply until "Save":
```swift
.sheet(isPresented: $showSettings) {
    Form { /* … */ }
    HStack { Button("Cancel") {…}; Button("Save") { commit() } }   // Windows-style modal
}
```

✅ **CORRECT** — the `Settings {}` scene, changes bound to live values, no Save/Cancel:
```swift
Settings {
    Form {
        Toggle("Launch at login", isOn: $launchAtLogin)   // applies immediately, no Save button
    }
}
```

### 2 — Single hard-coded `WindowGroup`; auxiliary windows faked with a boolean / sheet

A sheet is **modal** and lives *inside* the current window — it can never be a separate, independently-movable, independently-resizable Mac window. The Mac idiom is a registered scene plus the `openWindow` action. A `@State` boolean cannot create or own a real window; the scene system owns window lifetime.

❌ **WRONG** — fakes a second window with a sheet/flag:
```swift
@State private var showInspector = false
// .sheet(isPresented: $showInspector) { InspectorView() }   // modal, trapped in this window
```

✅ **CORRECT** — register a scene, open it via `openWindow`:
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        Window("Inspector", id: "inspector") { InspectorView() }   // single unique window
        // or WindowGroup(id: "doc", for: Item.ID.self) { … } for typed multiple instances
    }
}

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Open Inspector") { openWindow(id: "inspector") }
    }
}
```
Prefer the **value-based** `WindowGroup(id:for:content:)` / `WindowGroup(_:id:for:content:)` family for multi-instance windows. The older **string-`title`-label** inits (e.g. `WindowGroup("Doc", id:)` used purely to label, without `for:`) are deprecated in favor of the id/value forms — pass an explicit `id:` (and a `for:` presented type when each instance carries data) rather than relying on the title string as the identifier.

### 3 — No `MenuBarExtra`; a menu-bar app faked with AppKit `NSStatusItem` (or an in-window panel)

`MenuBarExtra` is macOS-only and post-dates most training data (macOS 13, 2022), so AI reaches for the old `NSStatusItem` + `NSMenu` blob inside an `NSApplicationDelegate` — far more code that doesn't compose with the SwiftUI scene graph — or, worse, an in-window button row that isn't in the menu bar at all.

❌ **WRONG** — AppKit status item bolted onto an app delegate:
```swift
// In NSApplicationDelegate:
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.menu = NSMenu()   // imperative, off to the side of the scene graph
```

✅ **CORRECT** — a `MenuBarExtra` scene:
```swift
@main
struct MyApp: App {
    var body: some Scene {
        MenuBarExtra("Status", systemImage: "star") {
            Button("Do Thing") { /* … */ }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)   // or .window for a popover-style panel; .automatic = system default
    }
}
```
`menuBarExtraStyle(_:)` takes three styles: `.menu` (a pull-down menu), `.window` (a popover-style panel), and `.automatic` (let the system pick). Exact case names are **UNVERIFIED — verify against your Xcode 26 SDK** (named in the doc index, page body not scraped).

### 4 — The `MenuBarExtra` → `openWindow`/`openSettings` activation trap (the multi-hour bug, **still unsolved on macOS 26**)

**This is the headline trap of the domain — and it is *not* a solved problem.** When the app has no visible regular window — typical for a menu-bar-only app, usually with `LSUIElement` / `.accessory` activation policy — calling `openWindow` or `openSettings` may open the window **behind everything** or fail to activate the app, so *nothing appears*. The diff looks correct; the behavior silently fails. There was no clean first-party fix for years (the corresponding Apple Feedback was open for the whole span).

The **macOS 15 pattern** below (activate first, *then* open) was the working workaround on macOS 13–15. **On macOS 26 (Tahoe) it regressed: for an `.accessory`-policy menu-bar app the same `NSApp.activate()` + `openSettings()` silently shows no front window again** (Peter Steinberger, 2025-06-17; confirmed by Michael Tsai). Treat this as an **open, unresolved platform gap**, not a closed bug.

❌ **WRONG** — from inside a `MenuBarExtra` with no front window, the window opens behind / app never comes forward:
```swift
MenuBarExtra("Status", systemImage: "star") {
    Button("Settings…") { openSettings() }   // app not activated → invisible window
    Button("Inspector")  { openWindow(id: "inspector") }   // same trap
}
```

⚠️ **macOS 15 pattern (works on 13–15, but FAILS on macOS 26)** — activate first, then open:
```swift
@Environment(\.openSettings) private var openSettings   // macOS 14+
@Environment(\.openWindow)   private var openWindow

Button("Settings…") {
    NSApp.activate(ignoringOtherApps: true)   // bring the app forward FIRST
    openSettings()                            // ← silently shows nothing on macOS 26 for .accessory apps
}
```
On **macOS 14+** prefer plain `NSApp.activate()` — the `ignoringOtherApps:` form is deprecated; gate with `if #available(macOS 14, *)`.

✅ **macOS 26 workaround (current best, still a hack)** — declare a **hidden `Window` scene *before* the `Settings` scene** in `App.body`, and flip the activation policy to `.regular` *around* the call:
```swift
@main
struct MyApp: App {
    var body: some Scene {
        // Scene ORDER matters: this hidden Window must come BEFORE Settings.
        Window("", id: "hidden-anchor") { EmptyView() }   // forces a real SwiftUI render tree
            .defaultLaunchBehavior(.suppressed)            // keep it off-screen/closed at launch
                                                           // (macOS 15+; verify the exact modifier/case vs. your SDK)

        Settings { SettingsView() }                        // declared AFTER the anchor
        MenuBarExtra("Status", systemImage: "star") { MenuBarContent() }
    }
}

// In the menu-bar button:
Button("Settings…") {
    NSApp.setActivationPolicy(.regular)   // leave .accessory temporarily
    NSApp.activate()
    openSettings()
    // restore .accessory after the window is up so the Dock icon disappears again:
    DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
}
```
Caveats that make this fragile: (a) it is **scene-order-dependent** — the hidden `Window` must be declared **before** `Settings` in `body` or the trick stops working; (b) a `SettingsLink` placed **directly inside a `MenuBarExtra`** *also* fails to surface the window on macOS 26, so the manual `openSettings()` path above is required; (c) toggling activation policy makes the Dock icon flicker. **Test it at runtime on the actual target OS — reading the diff is not enough**, and a fix verified on macOS 15 says nothing about macOS 26.

### 5 — No scene sizing: window opens at an awkward default and resizes wrongly

iOS never makes you size a window — the screen *is* the size. On macOS, windows resize freely, so without `.defaultSize` / `.windowResizability` the first-run window is the wrong size and a utility window can be stretched to absurd dimensions.

❌ **WRONG** — uncontrolled size and resize:
```swift
WindowGroup { ContentView() }   // opens too small/large; resizes without bound
```

✅ **CORRECT** — set default size and resizability:
```swift
WindowGroup { ContentView() }
    .defaultSize(width: 800, height: 600)
    .windowResizability(.contentSize)   // clamp to the content's frame limits

Window("Inspector", id: "inspector") { InspectorView() }
    .windowResizability(.contentSize)
```
Pair with content `.frame(minWidth:idealWidth:maxWidth:…)`. `.defaultSize(_:)` and `.windowResizability(_:)` are both macOS 13.0+. On **macOS 15+** you also get finer control: `.windowIdealSize(_:)` (the size the window adopts when "zoomed"/fit-to-ideal) and `.windowIdealPlacement(_:)` (where a freshly-opened window lands on screen), plus `.windowManagerRole(_:)` to declare a scene as principal vs. auxiliary so the window manager (Stage Manager, tiling) treats it correctly.

### 6 — Never dismissing an auxiliary window programmatically

Opening a window via `openWindow` but providing no code path to close it — or flipping a `@State` flag that doesn't control the real window. The window's lifetime is owned by the scene system, not by view state; a boolean can't close it. Use the `dismissWindow` environment action with the same `id`.

❌ **WRONG** — a boolean that the real window ignores:
```swift
@State private var inspectorOpen = false
Button("Close Inspector") { inspectorOpen = false }   // window stays open
```

✅ **CORRECT** — `dismissWindow(id:)`:
```swift
@Environment(\.dismissWindow) private var dismissWindow
Button("Close Inspector") { dismissWindow(id: "inspector") }
```
`dismissWindow` / `DismissWindowAction` is **macOS 14.0+** (note: `openWindow` is macOS 13, but the matching *dismiss* action only arrived in macOS 14 — don't assume the pair shares a version). Its exact verbatim Apple description is **UNVERIFIED — verify against your Xcode 26 SDK** (description string not body-scraped).

### 7 — Wrong / absent `.windowStyle` for Mac-appropriate chrome

A content-forward app keeps the default titled chrome when it wants `.hiddenTitleBar`; a utility wants a plainer style. Mac window chrome is a deliberate design choice with no iOS equivalent, and the default isn't always right.

❌ **WRONG** — default chrome on a content-forward window:
```swift
WindowGroup { ContentView() }   // titled bar even when the design wants it hidden
```

✅ **CORRECT** — pick the chrome:
```swift
WindowGroup { ContentView() }
    .windowStyle(.hiddenTitleBar)   // content-forward look
```
`windowStyle(_:)` and `WindowStyle` (cases `.hiddenTitleBar`, `.titleBar`, `.plain`) are listed in the SwiftUI Windows topic group, availability macOS 11.0+. Exact availability/description strings are **UNVERIFIED — verify against your Xcode 26 SDK**; treat the case names as canonical-but-verify.

### 8 — `WindowGroup` alone, expecting macOS lifecycle behavior it can't deliver (no app delegate)

`WindowGroup` is a *scene*, not an app lifecycle. On its own it **cannot**: quit the app when the last window closes, run global `NSApp`-level setup at launch, or hook `applicationWillTerminate` for save-on-quit. AI assumes the iOS lifecycle (one window, app stays alive headless) and ships an `App` with only scenes — then the Mac app keeps running with no windows, or never gets its launch/terminate hooks. The macOS fix is an `NSApplicationDelegate` wired in via `@NSApplicationDelegateAdaptor`; `applicationShouldTerminateAfterLastWindowClosed(_:)` is the canonical quit-on-last-window switch.

❌ **WRONG** — only scenes; app won't quit when the last window closes, no launch/terminate hooks:
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }   // closing every window leaves the app running, headless
    }                                    // no applicationWillTerminate, no global NSApp setup
}
```

✅ **CORRECT** — bridge an `AppDelegate` for the lifecycle SwiftUI doesn't expose:
```swift
@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // global NSApp-level setup that has no SwiftUI scene equivalent
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true   // quit when the last window closes — the Mac default for single-window apps
    }
    func applicationWillTerminate(_ notification: Notification) {
        // save-on-quit / teardown hook
    }
}
```
`@NSApplicationDelegateAdaptor` is macOS 11.0+; `applicationShouldTerminateAfterLastWindowClosed(_:)` is the long-standing AppKit hook it exposes. A menu-bar-only app deliberately returns `false` (or omits this) so closing windows doesn't quit it — pick the answer that matches the app type.

### 9 — `Window`/`WindowGroup` scene `id` typo → `openWindow(id:)` silently does nothing

`openWindow(id:)` matches its argument against the `id` you gave a `Window(id:)` / `WindowGroup(id:)` scene. If the string doesn't match **any** registered scene (a typo, a renamed scene, a constant that drifted), the call is a **silent no-op** — no crash, no error, no console warning, no window. The diff reads correctly; nothing happens at runtime. Related titlebar gotcha: a `navigationTitle(_:)` placed inside a `Window` scene **replaces the window's titlebar text** rather than adding a navigation title, which surprises code expecting the `Window("…", id:)` label to win.

❌ **WRONG** — the id passed doesn't match the registered scene; the button is dead:
```swift
Window("Inspector", id: "inspector") { InspectorView() }
// elsewhere:
Button("Open Inspector") { openWindow(id: "Inspector") }   // capital I ≠ "inspector" → no-op, no warning
```

✅ **CORRECT** — share one constant so the id can't drift:
```swift
enum WindowID { static let inspector = "inspector" }

Window("Inspector", id: WindowID.inspector) { InspectorView() }
// elsewhere:
Button("Open Inspector") { openWindow(id: WindowID.inspector) }   // guaranteed to match
```
Because the failure is invisible to a code review, **test the open at runtime** — an unmatched `id` looks identical to working code in a diff.

---

## Detection tells

Grep-able signals that catch these in review:

- **`WindowGroup` appears exactly once AND a view named `*Settings*` / `*Preferences*` is reached via `NavigationLink` or `.sheet`** → missing `Settings {}` scene (mistake 1).
- **`NSStatusItem` or `NSMenu` in a SwiftUI-first app** → should be `MenuBarExtra` (mistake 3).
- **`.sheet(isPresented:` used for something the user would expect as a separate window** (inspector, second document) → should be a scene + `openWindow` (mistake 2).
- **`openWindow(` / `openSettings(` called inside a `MenuBarExtra { … }` closure with no adjacent `NSApp.activate`** → the silent no-front-window activation bug (mistake 4) — the highest-value tell in this domain. And even *with* `NSApp.activate()`, on **macOS 26** an `.accessory`-policy app needs the hidden-`Window` + `.regular`-policy workaround; a lone `NSApp.activate()` + `openSettings()` is a tell that the code was verified only on macOS 15.
- **`SettingsLink` placed directly inside a `MenuBarExtra { … }`** → fails to surface Settings on macOS 26; route through a manual `openSettings()` call with the activation-policy workaround (mistake 4).
- **A `WindowGroup` / `Window` declaration with no `.defaultSize` and no `.windowResizability`** → uncontrolled sizing (mistake 5).
- **`@Environment(\.openWindow)` present but no `@Environment(\.dismissWindow)` anywhere despite auxiliary windows** → no programmatic close path (mistake 6).
- **Any `Preferences {}` scene, `NSApp.sendAction(Selector(("showSettingsWindow:")), …)`, or `showPreferencesWindow:`** → stale pre-`Settings`-scene pattern; `Settings {}` + `SettingsLink` are current.
- **An `openWindow(id: "…")` whose literal string matches no `Window(id:)` / `WindowGroup(id:)` declaration** (typo, casing, renamed/removed scene, drifted constant) → silent no-op, no warning (mistake 9). Cross-check every `openWindow(id:)` against a registered scene `id`; prefer a shared constant so they can't diverge.
- **An `App` with scenes but **no** `@NSApplicationDelegateAdaptor`, where the app needs quit-on-last-window, launch setup, or save-on-terminate** → missing lifecycle bridge (mistake 8); `WindowGroup` alone can't provide `applicationShouldTerminateAfterLastWindowClosed` / `applicationWillTerminate`.

---

## Canonical pattern

The macOS `App` skeleton to quote verbatim:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        // 1. Main, user-duplicable window
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)

        // 2. Single auxiliary window, opened via openWindow(id:)
        Window("Inspector", id: "inspector") {
            InspectorView()
        }
        .windowResizability(.contentSize)

        // 3. Standard Preferences (⌘, + "Settings…" menu item)
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif

        // 4. Menu-bar control
        MenuBarExtra("Status", systemImage: "star") {
            MenuBarContent()
        }
        .menuBarExtraStyle(.menu)
    }
}

// Opening / dismissing from a view:
struct MenuBarContent: View {
    @Environment(\.openWindow)   private var openWindow
    @Environment(\.openSettings) private var openSettings   // macOS 14+
    var body: some View {
        Button("Open Inspector") { openWindow(id: "inspector") }
        Button("Settings…") {
            NSApp.activate()        // plain form, macOS 14+ (ignoringOtherApps: deprecated)
            openSettings()          // ⚠️ still unreliable for .accessory apps on macOS 26 — see Mistake 4
        }
    }
}
```

**Rules:** (a) Preferences → `Settings {}`, never an in-window link. (b) Second window → a scene + `openWindow` (`UtilityWindow` for a floating inspector), never a sheet/flag. (c) Menu-bar UI → `MenuBarExtra`, never `NSStatusItem`. (d) Opening anything *from* a `MenuBarExtra` requires explicit `NSApp.activate` — plain `NSApp.activate()` on macOS 14+ (`ignoringOtherApps:` is deprecated) — and even that **fails for `.accessory` apps on macOS 26**, so use the hidden-`Window` + `.regular`-policy workaround from Mistake 4. (e) Always set `.defaultSize` + `.windowResizability` on Mac scenes.

---

## Availability table

| API | Min macOS | Note |
|---|---|---|
| `WindowGroup` | macOS 11.0+ | iOS has it but single-window in practice; prefer `WindowGroup(id:for:content:)` — string-`title`-label inits deprecated |
| `Window` (single) | macOS 13.0+ | Meaningful only on Mac/visionOS |
| `UtilityWindow` (single) | macOS 15.0+ | **macOS-only** — floating inspector/utility panel; auto-adds a View-menu show/hide; distinct from `Window` |
| `Settings {}` scene | macOS 11.0+ | **macOS-only — no iOS analog** |
| `SettingsLink` | macOS 14.0+ | macOS-only; **fails to surface Settings when placed directly in a `MenuBarExtra` on macOS 26** |
| `MenuBarExtra` | macOS 13.0+ | **macOS-only — no iOS analog** |
| `menuBarExtraStyle(_:)` | macOS 13.0+ | macOS-only; `.menu` / `.window` / `.automatic` case names **UNVERIFIED** |
| `openWindow` (`OpenWindowAction`) | macOS 13.0+ (iOS 16.0+) | cross-platform symbol; Mac-meaningful |
| `dismissWindow` (`DismissWindowAction`) | **macOS 14.0+** | **NOT 13** — trails `openWindow` by one release; desc **UNVERIFIED** |
| `pushWindow` (`PushWindowAction`) | macOS 15.0+ | **macOS-only** — opens a window and hides the requesting one |
| `openSettings` (`OpenSettingsAction`) | macOS 14.0+ | **macOS-only — new in macOS 14**; activation workaround broken on macOS 26 (Mistake 4) |
| `.defaultSize(_:)` | macOS 13.0+ (iOS 17.0+) | inert/irrelevant on iPhone |
| `.windowResizability(_:)` | macOS 13.0+ (iOS 16.0+) | Mac-meaningful |
| `.windowIdealSize(_:)` / `.windowIdealPlacement(_:)` | macOS 15.0+ | **macOS-only** — zoom/fit size and on-open placement |
| `.windowManagerRole(_:)` | macOS 15.0+ | **macOS-only** — principal vs. auxiliary role for the window manager |
| `.windowStyle(_:)` | macOS 11.0+ | macOS-only; exact string **UNVERIFIED** |
| `@NSApplicationDelegateAdaptor` | macOS 11.0+ | bridges an `NSApplicationDelegate` for lifecycle SwiftUI scenes don't expose |
| `NSApp.activate(ignoringOtherApps:)` | deprecated macOS 10.0–26.5 | use `NSApp.activate()` (macOS 14+) instead |
| `Preferences {}` / `showSettingsWindow:` selector | — | **stale** — replaced by `Settings {}` |

UNVERIFIED items: verify against your Xcode 26 SDK before asserting the exact string/case names.

---

## Sources

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/settings | *"A scene that presents an interface for viewing and modifying an app's settings."* — macOS 11.0+ | high |
| https://developer.apple.com/documentation/swiftui/menubarextra | *"A scene that renders itself as a persistent control in the system menu bar."* — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/openwindowaction | *"An action that opens a window."* — iOS 16.0+ … macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/opensettingsaction | *"An action that presents the settings scene for an app."* — macOS 14.0+ | high |
| https://developer.apple.com/documentation/swiftui/scene/defaultsize(_:) | *"Sets a default size for a scene."* — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/scene/windowresizability(_:) | *"Sets the resizability of windows created by this scene."* — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/environmentvalues/dismisswindow | `dismissWindow` / `DismissWindowAction` — **macOS 14.0+** (NOT 13) | high (desc UNVERIFIED) |
| https://developer.apple.com/documentation/swiftui/pushwindowaction | `pushWindow` / `PushWindowAction` — opens a window and hides the originator, macOS 15.0+ | high |
| https://developer.apple.com/documentation/swiftui/utilitywindow | `UtilityWindow` scene — floating utility/inspector panel, macOS 15.0+ | high |
| https://developer.apple.com/documentation/swiftui/scene/windowmanagerrole(_:) | `windowManagerRole(_:)` — principal vs. auxiliary scene role, macOS 15.0+ | high |
| https://developer.apple.com/documentation/swiftui/scene/windowidealsize(_:) | `windowIdealSize(_:)` (and `windowIdealPlacement(_:)`) — macOS 15.0+ | high |
| https://developer.apple.com/documentation/appkit/nsapplication/activate() | `NSApplication.activate()` (macOS 14+) replaces deprecated `activate(ignoringOtherApps:)` (deprecated macOS 10.0–26.5) | high |
| https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldterminateafterlastwindowclosed(_:) | quit-on-last-window AppKit hook bridged via `@NSApplicationDelegateAdaptor` (macOS 11.0+) | high |
| https://developer.apple.com/documentation/swiftui/scenes | Scenes index — `Window` / `WindowGroup` primitives; value-based `WindowGroup(id:for:content:)`, string-`title`-label inits deprecated | medium |
| https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items | Peter Steinberger, "Showing Settings from macOS Menu Bar Items: A 5-Hour Journey" (2025-06-17) — the macOS-15 activate-then-open fix **breaks on macOS 26**; current workaround is a hidden `Window` declared before `Settings` + toggling `.regular`/`.accessory` activation policy around `openSettings()`; `SettingsLink` inside a `MenuBarExtra` also fails | high |
| https://mjtsai.com/blog/2025/06/18/showing-settings-from-macos-menu-bar-items/ | Michael Tsai — confirms the menu-bar→Settings activation gap and the macOS 26 (Tahoe) regression | high |

All Apple-doc availability strings cross-checked against the SwiftUI/AppKit reference docs (access date 2026-06-07). Items are primary-source-cited (Apple) or first-party practitioner reports (steipete.me / mjtsai.com); UNVERIFIED strings are flagged inline and in the availability table.
