# Reference — Relaunch amnesia: selection + NavigationPath restoration (sr-05/06)

The most-reported symptom of this domain: "the app forgets where I was." Two distinct defects — UI
*selection* not bound to scene storage, and a `NavigationPath` that is never serialized. Get the ✅ shape
from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup SceneStorage --json` and
`... lookup NavigationPath --json` (the `recommended` permalink is a real call site), not a hand-written
snippet.

## sr-05 — selection on plain @State (warning, flag-only)

`TabView(selection:)`, `NavigationSplitView` column visibility, and `List(selection:)` bound to a plain
`@State` are dropped on relaunch — the system has no per-scene value to restore. Bind the selection to
`@SceneStorage` (per-window) so each window restores its own.

```swift
// ❌ selection forgotten on relaunch
@State private var selectedTab = Tab.inbox
TabView(selection: $selectedTab) { … }

// ✅ per-window restoration via @SceneStorage (enum is RawRepresentable: String)
@SceneStorage("selectedTab") private var selectedTab = Tab.inbox
TabView(selection: $selectedTab) { … }
```

Sidebar / column visibility follows the same shape:

```swift
// ✅ restore which columns were showing
@SceneStorage("columns") private var columns = NavigationSplitViewVisibility.automatic
NavigationSplitView(columnVisibility: $columns) { … }
```

> Seam: the *structure* of `NavigationSplitView`/`TabView` is `audit-swiftui-navigation-toolbars`; this
> skill owns only the **restoration binding**. Emit `cross_ref: audit-swiftui-navigation-toolbars`.

## sr-06 — NavigationPath not persisted (advisory, flag-only)

A deep `NavigationStack(path:)` driven by a `NavigationPath` that lives in plain `@State` loses the whole
drill-down on relaunch. `NavigationPath` is **macOS 13.0+** (confirmed via swiftui-ctx `introduced_macos`
13.0 + Sosumi). When every pushed value is `Codable & Hashable`, persist the path via its `codable`
representation, encode to `Data`, and round-trip through `@SceneStorage`.

```swift
// ❌ path lost on relaunch
@State private var path = NavigationPath()
NavigationStack(path: $path) { … }

// ✅ serialize the path through @SceneStorage (all pushed values Codable & Hashable)
@SceneStorage("navState") private var navData: Data?
@State private var path = NavigationPath()
// on change: if let repr = path.codable { navData = try? JSONEncoder().encode(repr) }
// on launch: if let d = navData, let r = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: d) { path = NavigationPath(r) }
```

If any pushed value is **not** `Codable`, `path.codable` is `nil` — note that the path cannot be persisted
as-is and the fix is to make the destination values `Codable` (or restore a shallower key). Carry as
advisory; confirm the `codable`/`CodableRepresentation` API via swiftui-ctx + Sosumi before asserting.

## Sources

- Apple — `NavigationPath` + `NavigationPath.CodableRepresentation` / `codable`, macOS 13.0+:
  `https://developer.apple.com/documentation/swiftui/navigationpath` (via Sosumi, accessed 2026-06-07).
- Apple — `SceneStorage` per-scene restoration, macOS 11.0+:
  `https://developer.apple.com/documentation/swiftui/scenestorage` (via Sosumi, accessed 2026-06-07).
- swiftui-ctx practice corpus — `lookup NavigationPath` (introduced_macos 13.0; `recommended`:
  `https://github.com/TableProApp/TablePro/blob/e3afc6457cd819eca5226c3874a9b4d7ad318a67/TableProMobile/TableProMobile/Coordinators/ConnectionCoordinator.swift#L31`)
  and `lookup SceneStorage`, run 2026-06-07.
