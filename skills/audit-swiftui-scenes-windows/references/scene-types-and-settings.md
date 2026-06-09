# Reference — The Five Scene Types & the Settings Scene (sw-01 / sw-02 / sw-03)

The scene-composition vocabulary at `App.body` level and the `Settings {}` scene with its HIG hard
rules. Per-platform floor *values* are not restated here — they live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the invented-name list lives in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`. This file carries the type
choices, the stale/invented detection content, and the ❌→✅ rewrites.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## Why AI gets this wrong

AI defaults to the **iOS one-window mental model**: the screen *is* the window, ⌘N and ⌘, don't exist,
and Preferences are "just another screen." So the model hard-codes a single `WindowGroup`, crams
Preferences inside it, and never reaches for `Settings {}` / `MenuBarExtra` / `Window` — all of which
are **macOS-only** (or Mac-meaningful) and post-date much training data (`MenuBarExtra` = macOS 13,
2022). The scene APIs live at `App.body` level, a spot iOS tutorials rarely exercise, so the priors are thin.

---

## The five scene types (pick the right one)

| Scene | What it is | Reach for it when | macOS floor |
|---|---|---|---|
| `WindowGroup` | user-duplicable window (⌘N spawns more); value-based `WindowGroup(id:for:content:)` for typed multi-instance | the main window of most apps | 11.0+ |
| `Window` | a **single unique** window — one instance, no ⌘N | console, a single "About"-style auxiliary | 13.0+ |
| `UtilityWindow` | a single unique **floating panel** above normal windows; auto-adds a View-menu show/hide item | inspectors, tool palettes | **15.0+ (macOS-only)** |
| `Settings {}` | the standard Preferences window — adds "Settings…" + ⌘, + a floating window | app preferences — the **only** idiomatic mechanism | **11.0+ (macOS-only)** |
| `MenuBarExtra` | a persistent control in the system menu bar | menu-bar / status-item apps | **13.0+ (macOS-only)** |

`UtilityWindow` (15.0+) is what you reach for when you want a floating inspector/tool panel rather than
a plain document-level `Window`: it stays above the main window and registers its own View-menu
show/hide command for free. The activation/dismiss/sizing of these scenes is in
`windows-sizing-lifecycle.md`; the `MenuBarExtra` activation trap is in `menu-bar-activation-trap.md`.

**Prefer the value-based `WindowGroup` family.** The string-`title`-label inits (e.g.
`WindowGroup("Doc", id:)` used purely to label, without `for:`) are **deprecated** in favor of the
id/value forms — pass an explicit `id:` (and a `for:` presented type when each instance carries data)
rather than relying on the title string as the identifier. Confirm via
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated WindowGroup --json`.

---

## sw-01 — stale / invented scene API (hard-fail; flag-only)

These do not exist or are stale on a macOS target. The canonical shared list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`; the scene-specific ❌→✅ below.

| ❌ Stale / invented | Why wrong | ✅ Correct (macOS 26) |
|---|---|---|
| `Preferences {}` scene | **stale** — never the SwiftUI scene name | `Settings {}` |
| `NSApp.sendAction(Selector(("showSettingsWindow:")), …)` / `showPreferencesWindow:` | stale selector hacks pre-`Settings`-scene | `Settings {}` scene + `SettingsLink` / `openSettings` |
| `@FocusedDocument` | **not a real Apple symbol** | a custom `FocusedValues` key: `@Entry var focusedDocument: …` on `FocusedValues` + `@FocusedValue(\.focusedDocument)` |
| `DocumentGroupLaunchScene` on a Mac arm | **macOS ABSENT** — iOS 18 / iPadOS 18 / Mac Catalyst 18 / visionOS 2 only (no native macOS arm; compile error on a Mac target) | a plain `WindowGroup`/`DocumentGroup` |
| `pushWindow` assumed macOS 15 | Apple pages show **visionOS 2.0+ only; macOS unconfirmed** | do *not* assert macOS 15 — `verify against Xcode 26 SDK`; use `openWindow` + `dismissWindow` for the same effect |

A `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a stale/invented
finding — no shipping Mac app uses the symbol.

---

## sw-02 — Preferences crammed into the main window (warning; flag-only)

Mac users press **⌘, (Command-comma)** to open a standard, separate Preferences window from the app
menu. A `NavigationLink`/`.sheet` gives **none** of that — no menu item, no shortcut, no floating
window. The `Settings {}` scene wires all three automatically.

```swift
// ❌ a "Settings" link/sheet inside the main window; ⌘, does nothing, no menu item
WindowGroup {
    NavigationStack { NavigationLink("Settings") { SettingsView() } }
}

// ✅ the Settings {} scene — "Settings…" menu item + ⌘, + window
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        #if os(macOS)
        Settings { SettingsView() }
        #endif
    }
}
```

The **tell**: `WindowGroup` appears exactly once AND a view named `*Settings*`/`*Preferences*` is
reached via `NavigationLink`/`.sheet`, with no `Settings {}` scene anywhere. To reach Settings from a
button *without* the menu, use `SettingsLink` (a view) or the `openSettings` environment action — see
`menu-bar-activation-trap.md` for the menu-bar caveat.

---

## sw-03 — a modal Settings window with Save / Cancel (warning; flag-only)

**Settings-window HIG hard rules.** A proper macOS Settings window is **not** a generic dialog — it must:

- Be **modeless** — changes apply *immediately*, with **no Save / Cancel / Apply buttons** (the
  save-or-cancel modal is a Windows convention and reads as non-native on the Mac).
- Have its **minimize and maximize (yellow/green) buttons dimmed** — a Settings window is
  fixed-purpose, not a resizable document window.
- **Persist the last-selected tab across reopens**, so ⌘, returns the user where they were.
- Use **checkboxes (`Toggle`)** for simple on/off settings, not iOS-style switches.

```swift
// ❌ a modal Settings sheet with Save/Cancel; changes don't apply until "Save"
.sheet(isPresented: $showSettings) {
    Form { /* … */ }
    HStack { Button("Cancel") {…}; Button("Save") { commit() } }   // Windows-style modal
}

// ✅ the Settings {} scene, changes bound to live values, no Save/Cancel
Settings {
    Form {
        Toggle("Launch at login", isOn: $launchAtLogin)   // applies immediately
    }
}
```

The **tell**: a `Settings`/`Preferences` `Form` co-located with `Button("Save")` / `Button("Apply")` /
`Button("Cancel")`. The consensus settings shape is `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
recipe settings-form` (and `recipe settings-screen`) — back the ✅ with that permalinked example.

---

## Sources

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/settings | `Settings` scene — *"presents an interface for viewing and modifying an app's settings"* — macOS 11.0+ | high |
| https://developer.apple.com/documentation/swiftui/menubarextra | `MenuBarExtra` — *"renders itself as a persistent control in the system menu bar"* — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/utilitywindow | `UtilityWindow` — floating utility/inspector panel — macOS 15.0+ | high |
| https://developer.apple.com/documentation/swiftui/window | `Window` — single unique window — macOS 13.0+ | high |
| https://developer.apple.com/documentation/swiftui/scenes | Scenes index — `Window`/`WindowGroup`; value-based `WindowGroup(id:for:content:)`, string-`title`-label inits deprecated | medium |
| https://developer.apple.com/design/human-interface-guidelines/settings | macOS Settings HIG — modeless, immediate-apply, no Save/Cancel, dimmed minimize/maximize, persist last tab | high |

All Apple-doc availability strings cross-checked against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
(the reconciled truth) and fetched via Sosumi (access 2026-06-07). `pushWindow` and
`DocumentGroupLaunchScene` is **macOS ABSENT** (iOS 18 / iPadOS 18 / Mac Catalyst 18 / visionOS 2 only — verified 2026-06-08, sosumi.ai/developer.apple.com); using it on a Mac target is a compile error, not a gating problem.
