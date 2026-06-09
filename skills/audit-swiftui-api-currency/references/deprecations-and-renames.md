# Deprecations & Renames (macOS SwiftUI) — curr-01 … curr-12

The deprecated/renamed catalog this skill flags. Each entry is the ❌ stale form, the ✅ current idiom,
the deprecation/floor fact, and how to confirm it live. **Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read them there; the dates below are the
era labels for the `era` finding field, not a restated floor table.** The canonical ✅ shape is the
`swiftui-ctx` consensus, not the snippet below: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup
<api> --json` and `… deprecated <api>` (steps VERIFY/FIX).

> macOS-only. Every ✅ compiles against the macOS SDK; iOS appears solely as ❌ contrast. The unifying
> tell: the code reads idiomatic and usually compiles (deprecation *warning*, not error), so it survives
> casual review — until the window closes.

---

## curr-01 · `NavigationView` → `NavigationStack` / `NavigationSplitView`

```swift
NavigationView { List(items) { row($0) } }                 // ❌ deprecated macOS 10.15–26.5
NavigationStack { List(items) { row($0) } }                // ✅ push/stack IA
NavigationSplitView { Sidebar() } detail: { Detail() }     // ✅ macOS-idiomatic columns (the rare-but-right swap)
```

Apple: *"Use `NavigationStack` and `NavigationSplitView` instead."* On the Mac the *right* replacement
is usually the split view, not the stack. **api-currency flags the deprecation; the structural migration
is `cross_ref audit-swiftui-navigation-toolbars`.** `era: WWDC22/macOS-13`.

## curr-02 · `.foregroundColor(_:)` → `.foregroundStyle(_:)` *(fix_mode: auto)*

```swift
Text("Hi").foregroundColor(.red)        // ❌ deprecated macOS 10.15–26.5
Text("Hi").foregroundStyle(.red)        // ✅ same length; accepts ShapeStyle, hierarchical .secondary, glass vibrancy
```

Apple: *"Use `foregroundStyle(_:)` instead."* Mechanical single-answer rename → `fix_mode: auto`. Craft
(gradients, hierarchical styles) is `cross_ref audit-swiftui-appearance-color`. `era: rolling/≤26.5`.

## curr-03 · `.cornerRadius(_:)` → `.clipShape(.rect(cornerRadius:))` *(fix_mode: auto)*

```swift
view.cornerRadius(12)                              // ❌ deprecated
view.clipShape(.rect(cornerRadius: 12))            // ✅ universally safe — RoundedRectangle/.rect are macOS 10.15+
```

Apple: *"Use `clipShape(_:style:)` with `RoundedRectangle` instead."* No gating needed. `cross_ref
audit-swiftui-appearance-color`. `era: rolling/≤26.5`.

## curr-04 · single-param `onChange(of:perform:)` → two-/zero-param

```swift
.onChange(of: value) { newValue in handle(newValue) }                 // ❌ introduced macOS 11, deprecated macOS 14
.onChange(of: value, initial: false) { oldValue, newValue in … }      // ✅ two-param
.onChange(of: value) { recompute() }                                  // ✅ zero-param
```

Current signature `onChange<V>(of:initial:_:)` with `(V, V) -> Void`, macOS 14.0+. The 1-param closure
is the tell — caught structurally by `lint/ast-grep/curr-04-onchange-one-param.yml`. `cross_ref
audit-swiftui-state-observation`. `era: macOS-11-introduced/macOS-14-deprecated`.

## curr-05 · `.tabItem { … }` → `Tab("…", systemImage:) { }`

```swift
TabView { Home().tabItem { Label("Home", systemImage: "house") } }    // ❌ legacy builder
TabView { Tab("Home", systemImage: "house") { Home() } }              // ✅ type-safe, macOS 15.0+
```

Gate `Tab(...)` below macOS 15. On macOS also reach for `.tabViewStyle(.sidebarAdaptable)`. Structural
migration `cross_ref audit-swiftui-navigation-toolbars`. `era: macOS-15`.

## curr-06 · inline `NavigationLink(destination:)` in `List`/`ForEach` → value-based

```swift
List { NavigationLink("Detail", destination: DetailView()) }                 // ❌ eager build, breaks value nav
List(items) { NavigationLink($0.name, value: $0) }                           // ✅ value-based
    .navigationDestination(for: Item.self) { DetailView(item: $0) }
```

`.navigationDestination(for:)` is macOS 13.0+. Containment (the link is *inside* a `List`/`ForEach`) is
proven by `lint/ast-grep/curr-06-inline-navlink-in-list.yml` — a standalone `NavigationLink(destination:)`
is fine. `cross_ref audit-swiftui-navigation-toolbars`. `era: WWDC22/macOS-13`.

## curr-07 · `Text + Text` → interpolation / `AttributedString`

```swift
Text("Hello ") + Text(name).bold()                  // ❌ the + operator is deprecated (macOS 10.15–26.0 — closes EARLY)
Text("Hello \(name)").bold()                         // ✅ uniformly-styled run
Text(AttributedString(makeStyledGreeting(name)))     // ✅ per-run styling
```

The window closes at **macOS 26.0**, ahead of the 26.5 cutoff most deprecations carry — it warns sooner.
Craft (`AttributedString`) is `cross_ref audit-swiftui-typography-text`. `era: macOS-26`.

## curr-08 · `DispatchQueue.main.async` cargo-cult → `@MainActor` / structured concurrency

```swift
DispatchQueue.main.async { self.items = newItems }   // ❌ pre-async GCD hop, overused under modern concurrency
@MainActor func update(_ newItems: [Item]) { items = newItems }   // ✅ isolation, not GCD
await MainActor.run { items = newItems }                          // ✅ hopping in from a Sendable context
```

A **smell, not a hard error** (`advisory`): only flag when the file otherwise uses `async`/`await`. Note:
main-actor-by-default is the *opt-in* Swift 6.2 build mode, not a free default everywhere. Isolation fix
is `cross_ref audit-swiftui-async-data` / concurrency-safety. `era: Swift-6`.

## curr-09 · 3-arg `dropDestination(for:action:isTargeted:)` → `dropDestination(for:isEnabled:action:)`

```swift
.dropDestination(for: URL.self) { items, location in handle(items) } isTargeted: { hovering = $0 }   // ❌ deprecated macOS 26.5
.dropDestination(for: URL.self, isEnabled: canDrop) { items, session in handle(items) }               // ✅ macOS 26.0+ successor (2nd param is DropSession, not CGPoint)
```

The `Bool`-returning 3-arg form (with `isTargeted:`) is deprecated at 26.5. **VERIFY the exact successor
signature** with `swiftui-ctx lookup dropDestination` + Sosumi before asserting; else `source: verify
against Xcode 26 SDK`. `cross_ref audit-swiftui-sandbox-files`. `era: macOS-26.5`.

## curr-10 · `MagnificationGesture` / `RotationGesture` → `MagnifyGesture` / `RotateGesture` *(fix_mode: auto)*

```swift
MagnificationGesture()    RotationGesture()          // ❌ renamed macOS 26.5
MagnifyGesture()          RotateGesture()            // ✅ successors are macOS 14.0+
```

Pure name swap → `fix_mode: auto`. The successors back-deploy to macOS 14, so the rename is safe down to
that floor. Mechanics `cross_ref audit-swiftui-pointer-gestures`. `era: macOS-26.5`.

## curr-11 · design-only `Font.system(_:design:)` → `Font.system(_:design:weight:)`

```swift
Font.system(.body, design: .rounded)                 // ❌ design-only form deprecated macOS 26.5 (if no weight:)
Font.system(.body, design: .rounded, weight: .regular)   // ✅ pass weight explicitly
```

**Only fires when there is no `weight:` argument** — READ to confirm (advisory). `cross_ref
audit-swiftui-typography-text`. `era: macOS-26.5`.

## curr-12 · `.accentColor(_:)` → `.tint(_:)` *(fix_mode: auto)*

```swift
SomeControl().accentColor(.blue)     // ❌ deprecated macOS 26.5
SomeControl().tint(.blue)            // ✅ .tint is macOS 12.0+
```

Mechanical rename → `fix_mode: auto`. `cross_ref audit-swiftui-appearance-color`. `era: macOS-26.5`.

---

## The gating arm (route depth to `availability-gating`)

Every ✅ replacement carries its own macOS floor (`.foregroundStyle` = 12, `Tab` = 15,
`.navigationDestination(for:)` = 13). Using one **below the deployment target** is a build break, not a
warning. This skill *notes* the gating need on the macOS arm — `if #available(macOS 12.0, *) { … } else {
… }`, never the iOS arm — and routes the depth to **`audit-swiftui-availability-gating`** (the blanket
net). The wrong-arm rule is `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`.

## Sources

- Paul Hudson, "What to fix in AI-generated Swift code," 2025-12-09 — https://www.hackingwithswift.com/articles/281/what-to-fix-in-ai-generated-swift-code (accessed 2026-06-06).
- Apple — `NavigationView` (deprecated `macOS 10.15–26.5`): https://developer.apple.com/documentation/swiftui/navigationview (scraped 2026-06-06).
- Apple — `foregroundColor(_:)` (deprecated, "Use foregroundStyle(_:) instead"): https://developer.apple.com/documentation/SwiftUI/View/foregroundColor(_:) (scraped 2026-06-06).
- Apple — `onChange(of:initial:_:)` (current 2-param, `macOS 14.0+`): https://developer.apple.com/documentation/SwiftUI/View/onChange(of:initial:_:)-4psgg (scraped 2026-06-06); deprecation text via Use Your Loaf — https://useyourloaf.com/blog/swiftui-onchange-deprecation/ (accessed 2026-06-06).
- Apple — `clipShape(_:style:)` (`macOS 10.15+`) and `RoundedRectangle`: https://developer.apple.com/documentation/swiftui/view/clipshape(_:style:) (confirmed 2026-06-07).
- Apple — `Tab` struct (`macOS 15.0+`): https://developer.apple.com/documentation/swiftui/tab (confirmed 2026-06-07).
- Apple — `Text` `+` operator (deprecated `macOS 10.15–26.0`, "Use Text interpolation instead"): https://developer.apple.com/documentation/swiftui/text/+(_:_:) (confirmed 2026-06-07).
- Apple — `navigationDestination(for:destination:)` (`macOS 13.0+`): https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:) (scraped 2026-06-06).
- Apple — `tint(_:)` (`macOS 12.0+`): https://developer.apple.com/documentation/swiftui/view/tint(_:) (scraped 2026-06-06).
- Apple — `MagnifyGesture` / `RotateGesture` (`macOS 14.0+`): https://developer.apple.com/documentation/swiftui/magnifygesture and https://developer.apple.com/documentation/swiftui/rotategesture (scraped 2026-06-06).
- Swift 6.2 release (main-actor-by-default is an opt-in `-default-isolation MainActor` build mode), 2025-09-15 — https://swift.org/blog/swift-6.2-released/ (scraped 2026-06-06).
