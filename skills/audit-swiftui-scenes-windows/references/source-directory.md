# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
scenes/windows claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the
curl/CLI commands and the JSON-404 caveat is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the scenes-specific *map* of
which pages to fetch. Floor *values* live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Cross-check against `floors-master.md` and, in practice, `swiftui-ctx lookup <api>`'s
   `introduced_macos`. Absence from the SwiftUI index = treat as hallucinated until proven.
2. **Need the precise per-platform array?** The raw `…/tutorials/data/documentation/swiftui/<symbol>.json`
   `introducedAt` works when it resolves; it **404s** on parenthesized-symbol families (`defaultsize(_:)`,
   the state-restoration/document-model parenthesized symbols) — fall back to Sosumi (never 404s on a
   valid human URL). Never `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess.
3. **Platform-arm gotchas:** both `pushWindow` (`PushWindowAction`) and `DocumentGroupLaunchScene` are
   **macOS ABSENT** (verified 2026-06-08): `pushWindow` is visionOS 2.0+ only; `DocumentGroupLaunchScene`
   is iOS 18 / iPadOS 18 / Mac Catalyst 18 / visionOS 2 only. Using either on a Mac target is a compile error.

---

## A. SwiftUI scene / window symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`). Floors
below are per `floors-master.md` (re-confirmed 2026-06-07).

| Symbol | Path | macOS |
|---|---|---|
| `WindowGroup` | `windowgroup` | 11.0+ |
| `Window` (single) | `window` | 13.0+ |
| `UtilityWindow` | `utilitywindow` | 15.0+ (macOS-only) |
| `Settings` scene | `settings` | 11.0+ (macOS-only) |
| `MenuBarExtra` | `menubarextra` | 13.0+ (macOS-only) |
| `menuBarExtraStyle(_:)` / `MenuBarExtraStyle` | `scene/menubarextrastyle(_:)` · `menubarextrastyle` | 13.0+ (case names UNVERIFIED) |
| `SettingsLink` | `settingslink` | 14.0+ (macOS-only) |
| `openWindow` / `OpenWindowAction` | `openwindowaction` · `environmentvalues/openwindow` | 13.0+ |
| `dismissWindow` / `DismissWindowAction` | `dismisswindowaction` · `environmentvalues/dismisswindow` | **14.0+ (NOT 13)** |
| `openSettings` / `OpenSettingsAction` | `opensettingsaction` · `environmentvalues/opensettings` | 14.0+ (macOS-only) |
| `pushWindow` / `PushWindowAction` | `pushwindowaction` | **UNVERIFIED — visionOS 2.0+ shown; macOS unconfirmed** |
| `defaultSize(_:)` | `scene/defaultsize(_:)` | 13.0+ |
| `windowResizability(_:)` | `scene/windowresizability(_:)` | 13.0+ |
| `windowStyle(_:)` / `WindowStyle` | `windowstyle` · `scene/windowstyle(_:)` | 11.0+ (case strings UNVERIFIED) |
| `windowIdealSize(_:)` / `windowIdealPlacement(_:)` | `scene/windowidealsize(_:)` · `scene/windowidealplacement(_:)` | 15.0+ |
| `windowManagerRole(_:)` | `scene/windowmanagerrole(_:)` | 15.0+ |
| `defaultLaunchBehavior(_:)` / `SceneLaunchBehavior` | `scene/defaultlaunchbehavior(_:)` | 15.0+ |
| `@NSApplicationDelegateAdaptor` | `nsapplicationdelegateadaptor` | 11.0+ |

**Stale / absent → never emit (sw-01):** `Preferences {}` scene, `showSettingsWindow:` /
`showPreferencesWindow:` selectors, `@FocusedDocument` (use a custom `FocusedValues` key — see the
shared hallucination-blacklist). `DocumentGroupLaunchScene` is **macOS ABSENT** (iOS 18 / iPadOS 18 / Mac Catalyst 18 / visionOS 2 only).

## B. AppKit lifecycle / activation paths

| Symbol | Path (`developer.apple.com/documentation/appkit/<…>`) | Note |
|---|---|---|
| `NSApplication.activate()` | `nsapplication/activate()` | macOS 14+; replaces deprecated `activate(ignoringOtherApps:)` |
| `applicationShouldTerminateAfterLastWindowClosed(_:)` | `nsapplicationdelegate/applicationshouldterminateafterlastwindowclosed(_:)` | quit-on-last-window hook bridged via the adaptor |
| `applicationWillTerminate(_:)` | `nsapplicationdelegate/applicationwillterminate(_:)` | save-on-quit hook |
| `NSApplication.setActivationPolicy(_:)` / `NSApplication.ActivationPolicy` | `nsapplication/setactivationpolicy(_:)` · `nsapplication/activationpolicy` | `.accessory`/`.regular` toggled in the sw-06 workaround |

## C. HIG

| Page | Path | Anchors |
|---|---|---|
| Settings | `design/human-interface-guidelines/settings` (verify exact path against current HIG) | modeless, immediate-apply, no Save/Cancel, dimmed minimize/maximize, persist last tab (sw-03) |
| The menu bar | `design/human-interface-guidelines/the-menu-bar` | menu-bar app conventions (sw-05) |
| Windows | `design/human-interface-guidelines/windows` | chrome / sizing intent (sw-08, sw-12) |

## D. swiftui-ctx recipes (the practice patterns for this domain)

| Recipe | APIs | Use for |
|---|---|---|
| `menubar-app` | `MenuBarExtra` + `menuBarExtraStyle` + `Settings` | sw-05/06 ✅ — real `phosphene`/`mocker`/`Loop` permalinks |
| `window-scene` | `WindowGroup` + `windowStyle` + `windowResizability` + `defaultSize` | sw-08/12 ✅ — real `Ice`/`cheetah` permalinks |
| `settings-form` / `settings-screen` | `Settings` + `Form` + `Toggle` | sw-02/03 ✅ — the modeless settings shape |

## E. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Peter Steinberger | `steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items` | the macOS 26 menu-bar→Settings activation regression + hidden-`Window` workaround (sw-06/07) | high |
| Michael Tsai | `mjtsai.com/blog/2025/06/18/showing-settings-from-macos-menu-bar-items/` | confirms the macOS 26 (Tahoe) regression | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07); floors reconciled
  against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.
- swiftui-ctx recipes from the bundled CLI (`recipe menubar-app` / `window-scene` / `settings-form`).
- Practitioner URLs as listed (trust labelled; corroboration only).
