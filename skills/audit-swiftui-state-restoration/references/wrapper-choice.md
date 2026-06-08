# Reference — Wrapper choice: @AppStorage vs @SceneStorage vs UserDefaults (sr-02/03/04/07/08)

The semantic core of this skill. `@AppStorage`, `@SceneStorage`, and hand-rolled `UserDefaults` all
**compile interchangeably for primitive values** — so the defect is never a build error, it is a *meaning*
error. READ the value's purpose before reporting. Get the canonical shape from
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup AppStorage --json` /
`... lookup SceneStorage --json` rather than pasting a static snippet; the `recommended` permalink is the ✅.

## The wrapper test (decision rule)

> Would *two open windows of this app* legitimately hold **different** values for this property?

- **Yes** → it is **per-window UI state** (selected tab, sidebar selection, current detail item, scroll
  target, inspector visibility) → **`@SceneStorage`**. The system restores it per scene on relaunch.
- **No, there is one app-wide truth** (theme, default font size, "confirm before delete", API base URL) →
  **`@AppStorage`** (or a typed preferences store). Shared across every window, backed by `UserDefaults`.

`@AppStorage` (macOS 11), `@SceneStorage` (macOS 11) — floors confirmed via swiftui-ctx `introduced_macos`
and `floors-master.md`.

## sr-02 — @SceneStorage holding an app-wide preference (warning, flag-only)

A preference that *every* window must agree on, stored per-scene. Symptom: a setting changes in one window
but not another; a fresh window shows a stale default. The value fails the wrapper test (two windows should
NOT disagree).

```swift
// ❌ a global preference parked in per-window storage
@SceneStorage("showLineNumbers") private var showLineNumbers = true
// ✅ app-wide → @AppStorage (one truth for all scenes)
@AppStorage("showLineNumbers") private var showLineNumbers = true
```

## sr-03 — @AppStorage holding per-window UI state (warning, flag-only)

Per-window UI parked in app-wide storage: opening a second window clobbers the first window's selection;
the system also cannot restore each scene independently. Most common on `selectedTab`, sidebar selection,
and the current detail item.

```swift
// ❌ per-window selection in app-wide storage → leaks across windows, no per-scene restore
@AppStorage("selectedTab") private var selectedTab = Tab.inbox
// ✅ per-window UI state → @SceneStorage
@SceneStorage("selectedTab") private var selectedTab = Tab.inbox
```

## sr-04 — hand-rolled UserDefaults where @AppStorage fits (warning, flag-only)

Manual `UserDefaults.standard.set(_:forKey:)` / `.object(forKey:)` for a simple app-wide pref reimplements
`@AppStorage` without its automatic view invalidation. Flag only when the value is a plain pref. **Do not
flag** a deliberate non-view use: a custom suite (`UserDefaults(suiteName:)`), a migration, KVO/observer
plumbing, or a value read outside a `View`.

```swift
// ❌ manual UserDefaults for a view-bound pref (no auto-refresh)
var theme: String { UserDefaults.standard.string(forKey: "theme") ?? "system" }
// ✅ @AppStorage — view re-renders on change
@AppStorage("theme") private var theme = "system"
```

## sr-07 — custom type without RawRepresentable / Codable (hard-fail, flag-only)

`@AppStorage`/`@SceneStorage` persist only property-list-compatible primitives (`Bool`, `Int`, `Double`,
`String`, `URL`, `Data`) **or** a type that is `RawRepresentable` whose `RawValue` is one of those (the
standard pattern for an enum), or a `Codable` type encoded to `Data` yourself. A bare `struct`/`class`, or
an enum with no `RawValue`, will not compile (or silently will not persist).

```swift
// ❌ enum with no RawValue in storage — does not satisfy the wrapper's constraint
enum ViewMode { case grid, list }
@SceneStorage("viewMode") private var viewMode = ViewMode.grid
// ✅ give it a primitive RawValue (RawRepresentable)
enum ViewMode: String { case grid, list }
@SceneStorage("viewMode") private var viewMode = ViewMode.grid
```

> Detection limit: neither grep nor ast-grep can confirm a type's protocol conformance across files. The
> tell LOCATES a custom-type annotation; **READ the type's declaration** to confirm it lacks
> `RawRepresentable`/`Codable` before reporting.

## sr-08 — oversized data in size-limited storage (warning, flag-only)

`@SceneStorage` is explicitly documented for *small* values and `@AppStorage`/`UserDefaults` degrade past a
few hundred KB. A `Data` blob, a large array, or an encoded image does not belong there. Move structured
records to **SwiftData** (`cross_ref: audit-swiftui-swiftdata`) and binaries to a file in Application
Support / a security-scoped bookmark.

```swift
// ❌ a blob in key-value storage
@AppStorage("cachedThumbnail") private var thumbnail = Data()
// ✅ persist the record in SwiftData / the file in Application Support; store only a small key/URL here
@AppStorage("lastThumbnailID") private var lastThumbnailID = ""
```

## Sources

- Apple — `AppStorage`, macOS 11.0+: `https://developer.apple.com/documentation/swiftui/appstorage`
  (via Sosumi, accessed 2026-06-07).
- Apple — `SceneStorage` ("use for *small* amounts of data… per-scene state restoration"), macOS 11.0+:
  `https://developer.apple.com/documentation/swiftui/scenestorage` (via Sosumi, accessed 2026-06-07).
- swiftui-ctx practice corpus — `lookup SceneStorage` (introduced_macos 11.0; consensus key shapes like
  `("selectedTab")`, `("viewMode")`; `recommended`:
  `https://github.com/TableProApp/TablePro/blob/e3afc6457cd819eca5226c3874a9b4d7ad318a67/TableProMobile/TableProMobile/Views/TableListView.swift#L12`)
  and `lookup AppStorage` (introduced_macos 11.0; `recommended`:
  `https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/CompletedScreen.swift#L8`),
  run 2026-06-07.
