# Reference — MenuBarExtra & the Activation Trap (sw-05 / sw-06 / sw-07)

The headline of this domain. A `MenuBarExtra` app that opens a window or Settings can open it **behind
everything** or not at all — the diff reads correctly and the behavior silently fails. This is **not a
solved problem on macOS 26**. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; this file carries the trap mechanics, the
detection content, and the ❌→✅.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## sw-05 — a menu-bar app faked with AppKit `NSStatusItem` (warning; flag-only)

`MenuBarExtra` is macOS-only and post-dates most training data (macOS 13, 2022), so AI reaches for the
old `NSStatusItem` + `NSMenu` blob inside an `NSApplicationDelegate` — far more imperative code that
doesn't compose with the SwiftUI scene graph — or, worse, an in-window button row that isn't in the
menu bar at all.

```swift
// ❌ AppKit status item bolted onto an app delegate
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.menu = NSMenu()   // imperative, off to the side of the scene graph

// ✅ a MenuBarExtra scene
@main struct MyApp: App {
    var body: some Scene {
        MenuBarExtra("Status", systemImage: "star") {
            Button("Do Thing") { /* … */ }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)   // or .window for a popover panel; .automatic = system default
    }
}
```

`menuBarExtraStyle(_:)` takes `.menu` (pull-down), `.window` (popover-style panel), `.automatic`. The
exact case names are **UNVERIFIED — `verify against Xcode 26 SDK`**. *Whether* the AppKit bridge should
exist at all is `audit-swiftui-appkit-overuse`'s call — emit `cross_ref: audit-swiftui-appkit-overuse`.
The buttons/`Divider`s/shortcuts **inside** the closure are `audit-swiftui-menus-commands`' content,
not ours; emit `cross_ref: audit-swiftui-menus-commands` for any item-level issue.

**swiftui-ctx grounding** (lookup run during the build, 2026-06-07):
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup MenuBarExtra --json` →
`deprecated:false`, consensus shapes `{ }` (50%) / `(_, systemImage)` (29%) / `(isInserted)` (6%),
`co_occurs_with: [menuBarExtraStyle, SettingsLink, defaultLaunchBehavior, windowLevel, …]`. The
**recommended** real example is `us/mocker` —
`https://github.com/us/mocker/blob/b2d305c6273df7ab1ce88a20eb73815948ebd2b1/Sources/MockerApp/MockerApp.swift#L9`
(`MenuBarExtra("Mocker", systemImage: "shippingbox.fill")`, min_macos 13). The
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx recipe menubar-app` pattern pairs `MenuBarExtra` +
`menuBarExtraStyle` + `Settings` — use its permalinked examples (e.g. `kageroumado/phosphene`,
`mrkai77/Loop`) as the ✅ in `## Source`, fetched with `file <id> --smart`.

---

## sw-06 — the `MenuBarExtra → openWindow/openSettings` activation trap (hard-fail; flag-only)

**This is the headline trap of the domain — and it is *not* a solved problem.** When the app has no
visible regular window — typical for a menu-bar-only app, usually with `LSUIElement` / `.accessory`
activation policy — calling `openWindow` or `openSettings` may open the window **behind everything** or
fail to activate the app, so *nothing appears*. The diff looks correct; the behavior silently fails.
There was no clean first-party fix for years.

```swift
// ❌ from inside a MenuBarExtra with no front window — the window opens behind / app never comes forward
MenuBarExtra("Status", systemImage: "star") {
    Button("Settings…") { openSettings() }            // app not activated → invisible window
    Button("Inspector")  { openWindow(id: "inspector") }   // same trap
}
```

```swift
// ⚠️ macOS 15 pattern (works on 13–15, but FAILS on macOS 26 for .accessory apps) — activate first
@Environment(\.openSettings) private var openSettings   // macOS 14+
Button("Settings…") {
    NSApp.activate(ignoringOtherApps: true)   // bring the app forward FIRST
    openSettings()                            // ← silently shows nothing on macOS 26 for .accessory apps
}
```

On **macOS 14+** prefer plain `NSApp.activate()` — the `ignoringOtherApps:` form is **deprecated**; gate
with `if #available(macOS 14, *)`.

```swift
// ✅ macOS 26 workaround (current best, STILL A HACK — runtime-test on the target OS)
@main struct MyApp: App {
    var body: some Scene {
        // Scene ORDER matters: this hidden Window must come BEFORE Settings.
        Window("", id: "hidden-anchor") { EmptyView() }    // forces a real SwiftUI render tree
            .defaultLaunchBehavior(.suppressed)            // keep it closed at launch (macOS 15+; verify exact case vs SDK)
        Settings { SettingsView() }                        // declared AFTER the anchor
        MenuBarExtra("Status", systemImage: "star") { MenuBarContent() }
    }
}
// In the menu-bar button:
Button("Settings…") {
    NSApp.setActivationPolicy(.regular)   // leave .accessory temporarily
    NSApp.activate()
    openSettings()
    DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }  // restore so the Dock icon disappears
}
```

Caveats that make this fragile: (a) it is **scene-order-dependent** — the hidden `Window` must come
**before** `Settings` in `body`; (b) a `SettingsLink` directly inside a `MenuBarExtra` *also* fails on
macOS 26 (sw-07); (c) toggling activation policy makes the Dock icon flicker.

**Report it as an *open, unresolved platform gap*, not a closed bug.** The ✅ above carries
`source: verify against Xcode 26 SDK` plus the practitioner citations; **never write "this is fixed."**

**The tell:** `openWindow(`/`openSettings(` called inside a `MenuBarExtra { … }` closure with **no
adjacent `NSApp.activate`** → the silent no-front-window bug — the highest-value tell in this domain.
And even *with* `NSApp.activate()`, a lone `NSApp.activate()` + `openSettings()` for an `.accessory` app
is a tell the code was verified only on macOS 15. `defaultLaunchBehavior` co-occurs with `MenuBarExtra`
in the corpus (confirmed via the build-time `lookup`), which is the hidden-anchor signal.

---

## sw-07 — `SettingsLink` directly inside a `MenuBarExtra` (warning; flag-only)

A `SettingsLink` placed **directly inside** a `MenuBarExtra { … }` closure *also* fails to surface the
Settings window on macOS 26 — same activation gap as sw-06. Route through the manual `openSettings()`
path with the activation-policy workaround above.

```swift
// ❌ SettingsLink inside MenuBarExtra → no window on macOS 26
MenuBarExtra("Status", systemImage: "star") { SettingsLink { Text("Settings…") } }

// ✅ a Button that runs the manual activation workaround (sw-06 ✅)
MenuBarExtra("Status", systemImage: "star") {
    Button("Settings…") { /* setActivationPolicy(.regular) → activate() → openSettings() … */ }
}
```

`SettingsLink` is **macOS 14.0+** (macOS-only). Outside a `MenuBarExtra` it is the
correct no-action way to open Settings from a button; the failure is specific to the menu-bar closure.

---

## Sources

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/menubarextra | `MenuBarExtra` scene — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/opensettingsaction | `openSettings` / `OpenSettingsAction` — macOS 14.0+ | high |
| https://developer.apple.com/documentation/swiftui/settingslink | `SettingsLink` — macOS 14.0+; fails inside `MenuBarExtra` on macOS 26 | high (failure UNVERIFIED) |
| https://developer.apple.com/documentation/appkit/nsapplication/activate() | `NSApplication.activate()` (macOS 14+) replaces deprecated `activate(ignoringOtherApps:)` | high |
| https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items | Peter Steinberger, "Showing Settings from macOS Menu Bar Items: A 5-Hour Journey" (2025-06-17) — the macOS-15 activate-then-open fix **breaks on macOS 26**; current workaround is a hidden `Window` before `Settings` + toggling `.regular`/`.accessory` around `openSettings()`; `SettingsLink` inside a `MenuBarExtra` also fails | high |
| https://mjtsai.com/blog/2025/06/18/showing-settings-from-macos-menu-bar-items/ | Michael Tsai — confirms the menu-bar→Settings activation gap and the macOS 26 (Tahoe) regression | high |
| swiftui-ctx `lookup MenuBarExtra` + `recipe menubar-app` (corpus of 1,857 macOS apps) | consensus shapes, `co_occurs_with` incl. `SettingsLink`/`defaultLaunchBehavior`, recommended `us/mocker` permalink | high |

Apple availability strings cross-checked against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
and fetched via Sosumi (access 2026-06-07). The macOS 26 activation regression is a first-party
practitioner report (steipete.me / mjtsai.com); treat it as an open gap.
