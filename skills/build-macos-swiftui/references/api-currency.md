# macOS SwiftUI API Currency

Ground-truth, primary-source-verified snapshot of current vs. deprecated macOS SwiftUI APIs. Every other doc in this skill cross-checks symbol names, availability floors, and deprecation dates against this file.

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain** (verified Swift 6.2 introduced approachable concurrency; shipping toolchain at scrape time was the 6.3.x point line, which carries the same 6.2 concurrency model). All CONFIRMED facts scraped **2026-06-06** from `developer.apple.com`, `swift.org`, and WWDC25 session pages, with a **2026-06-07** correction pass against the `developer.apple.com` JSON availability endpoints. **macOS-only:** where Apple renders a multi-platform availability string, only the macOS arm is reproduced here.

---

## Current vs deprecated (dated)

Wrong = AI's stale training default. Right = current macOS idiom. Floor = lowest macOS the *right* API supports.

| Era boundary (date) | Wrong (stale) | Right (current) | macOS floor |
|---|---|---|---|
| **NavigationView deprecation** (WWDC22 / macOS 13, 2022; window closes 26.5) | `NavigationView { }` | `NavigationStack` (push) / `NavigationSplitView` (Mac sidebar/columns) | macOS 13.0+ |
| **`@Observable` macro** (WWDC23 / macOS 14, 2023) | `class VM: ObservableObject { @Published … }` + `@StateObject` | `@Observable class VM` + `@State` / `@Bindable` / `@Environment(Type.self)` | macOS 14.0+ |
| **Two-param `onChange`** (macOS 14, 2023) | `.onChange(of:) { newValue in }` | `.onChange(of:, initial:) { old, new in }` (or 0-param) | macOS 14.0+ |
| **`#Preview` / `@Previewable`** (Xcode 15, 2023 / Xcode 16, 2024) | `struct _Previews: PreviewProvider` | `#Preview { @Previewable @State … }` | macOS 14.0+ |
| **`@Entry` macro** (Xcode 16, 2024) | 3-part `EnvironmentKey` struct + `EnvironmentValues` extension | `@Entry var myKey: T = default` | macOS 10.15+ (back-deploys) |
| **Style deprecations** (rolling; deprecated through 26.5) | `.foregroundColor`, `.cornerRadius`, `tabItem`, inline-dest `NavigationLink` | `.foregroundStyle`, `.clipShape(.rect(cornerRadius:))`, `Tab(){}`, `.navigationDestination(for:)` | macOS 11–14+ |
| **`dropDestination(for:action:isTargeted:)` 3-arg deprecation** (macOS 26.5) | `dropDestination(for:action:isTargeted:)` (3-arg `Bool`-returning form) | `dropDestination(for:isEnabled:action:)` (macOS 26.0+ successor) | macOS 26.0+ |
| **Gesture renames** (macOS 26.5; successors macOS 14+) | `MagnificationGesture` · `RotationGesture` | `MagnifyGesture` · `RotateGesture` | macOS 14.0+ |
| **`Font.system(_:design:)` (design-only)** (macOS 26.5) | `Font.system(_:design:)` (design arg, no `weight:`) | `Font.system(_:design:weight:)` | same macOS floor as existing form |
| **`.accentColor(_:)` deprecation** (macOS 26.5; successor macOS 12+) | `.accentColor(_:)` | `.tint(_:)` | macOS 12.0+ |
| **Swift 6 strict concurrency default** (Swift 6.0, Sept 2024) | non-`Sendable` crossing actors; `DispatchQueue.main.async` | `Sendable`-correct types, `@MainActor` / `await MainActor.run`, `.task` | toolchain (all targets) |
| **Swift 6.2 "approachable concurrency"** (Sept 15, 2025) | assumes main-actor-by-default everywhere; invents `@concurrent` semantics | opt-in `-default-isolation MainActor` build mode; `@concurrent` is Swift 6.2+ only | toolchain 6.2+ |
| **Liquid Glass** (WWDC25 / macOS 26 Tahoe, 2025) | `.glassBackground()` / `.liquidGlass()` / `.material(.glass)` (hallucinated) | `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)` — `#available(macOS 26)`-gated | macOS 26.0+ |
| **`Settings {}` scene** (vs pre-13 hack) | `NSApp.sendAction(Selector(("showSettingsWindow:")))` / `Preferences {}` | `Settings {}` scene + `SettingsLink` | macOS 11.0+ |

---

## CONFIRMED APIs (primary-source verified)

Eight clusters, each with the exact macOS availability string and a verbatim signature scraped 2026-06-06.

### 1. Navigation — `NavigationView` is DEPRECATED
- macOS availability: **`macOS 10.15–26.5 Deprecated`** (deprecation window closes at OS 26.5)
- Signature: `struct NavigationView<Content> where Content : View`
- Apple guidance (verbatim): *"Use `NavigationStack` and `NavigationSplitView` instead. For more information, see Migrating to new navigation types."*
- Also deprecated on the same page: `NavigationViewStyle`, `navigationViewStyle(_:)`.
- Current: `NavigationStack` (push/stack IA) and `NavigationSplitView` (2–3-column sidebar IA — the macOS-idiomatic default, not a fallback).
- **`Tab`** — macOS availability: **`macOS 15.0+`**. `struct Tab` is the current value-based `TabView` content primitive (`Tab("Label", systemImage:) { … }`); it replaces the deprecated `.tabItem` builder on `TabView`.

### 2. Observation — `@Observable` macro
- macOS availability: **`macOS 14.0+`**
- Signature: `@attached(member, names: named(_$observationRegistrar), named(access), named(withMutation), named(shouldNotifyObservers)) @attached(memberAttribute) @attached(extension, conformances: Observable) macro Observable()`
- Verbatim: *"Defines and implements conformance of the Observable protocol."*
- `ObservableObject` / `@StateObject` / `@ObservedObject` / `@EnvironmentObject` are **NOT** marked deprecated (no `@available(deprecated)` annotation) — valid for back-deployment, but `@Observable` is the current default. Own with `@State`, bind with `@Bindable`, inject with `.environment(_)` + `@Environment(Type.self)`. No `@Published` and no `: ObservableObject` inside an `@Observable` class.

### 3. `onChange` — two-parameter `(oldValue, newValue)`
- macOS availability: **`macOS 14.0+`**
- Signature:
  ```swift
  nonisolated
  func onChange<V>(
      of value: V,
      initial: Bool = false,
      _ action: @escaping (V, V) -> Void
  ) -> some View where V : Equatable
  ```
- Verbatim example: `.onChange(of: playState) { oldState, newState in ... }`
- The single-param `onChange(of:perform:)` (zero/one-arg closure) is the deprecated form AI emits.

### 4. Liquid Glass — VERIFIED names (macOS 26)
All `macOS 26.0+`. Gate every use with `if #available(macOS 26.0, *)` when the deployment target is below 26.

- **`glassEffect(_:in:)`** — macOS availability: `macOS 26.0+`
  ```swift
  nonisolated
  func glassEffect(
      _ glass: Glass = .regular,
      in shape: some Shape = DefaultGlassEffectShape()
  ) -> some View
  ```
  Verbatim: *"Applies the Liquid Glass effect to a view."*
- **`GlassEffectContainer`** — macOS availability: `macOS 26.0+`
  - Signature: `@MainActor @preconcurrency struct GlassEffectContainer<Content> where Content : View`
  - Verbatim: *"A view that combines multiple Liquid Glass shapes into a single shape that can morph individual shapes into one another."* Glass cannot sample glass — group adjacent glass here.
- **`GlassButtonStyle`** + **`.buttonStyle(.glass)`** — macOS availability: `macOS 26.0+`
  - `struct GlassButtonStyle`; *"A button style that applies glass border artwork based on the button's context."*
  - Shorthand: `@MainActor @preconcurrency static func glass(_ glass: Glass) -> Self` — so `.buttonStyle(.glass)` and `.buttonStyle(.glass(.clear))` are real.
- **`GlassProminentButtonStyle`** + **`.buttonStyle(.glassProminent)`** — macOS availability: `macOS 26.0+` *(upgraded UNVERIFIED→CONFIRMED; corroborated by the Liquid Glass macOS-26 availability table — `.glassProminent` = Yes on macOS)*. Accent-tinted glass platter; the macOS-26 replacement for `.borderedProminent` on primary actions.
- **`Glass` statics** (all `macOS 26.0+`): `Glass.regular`, `Glass.clear`, and **`Glass.identity`** (opts a view out of the Liquid Glass effect while keeping the `glassEffect` modifier in place — the no-op variant). Configure with `Glass.tint(_:)`.
- **`Glass.interactive(_:)`** — macOS availability: **`macOS 26.0+`** (NOT iOS-only). It IS available on macOS 26; on the Mac it is pointer-driven (no continuous touch), so the elastic / springy response differs from the touch-driven iOS effect, but the API is present and functional.
- **`scrollEdgeEffectStyle(_:for:)`** — macOS availability: **`macOS 26.0+`**
  ```swift
  func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View
  ```
  Sibling toggle: **`scrollEdgeEffectHidden(_:for:)`** (`macOS 26.0+`) — hides the scroll-edge effect for the given edges.
- **`GlassEffectTransition.materialize`** — macOS availability: **`macOS 26.0+`** (real). `GlassEffectTransition`'s three cases are **`.identity`**, **`.matchedGeometry`**, and **`.materialize`**.
- **`ToolbarSpacer`** — macOS availability: **`macOS 26.0+`**. `struct ToolbarSpacer`; the no-arg `ToolbarSpacer()` defaults to flexible. Sizing is `SpacerSizing` with cases **`.fixed`** and **`.flexible`** (e.g. `ToolbarSpacer(.fixed)` / `ToolbarSpacer(.flexible)`).
- **`searchToolbarBehavior(_:)`** — macOS availability: **`macOS 26.0+`**. The correct case is **`.minimize`** (not `.minimized`): `.searchToolbarBehavior(.minimize)` collapses the search field into the toolbar until invoked.
- Verified sibling symbols (names confirmed in topic lists; bodies not individually scraped): `glassEffectID(_:in:)`, `glassEffectUnion(id:namespace:)`, `glassEffectTransition(_:)`, `DefaultGlassEffectShape`, `.backgroundExtensionEffect()`.

### 5. Scene APIs — `MenuBarExtra` / `Settings` / `Window`
- **`MenuBarExtra`** — macOS availability: **`macOS 13.0+`** (macOS-only)
  - `struct MenuBarExtra<Label, Content> where Label : View, Content : View`
  - Verbatim: *"A scene that renders itself as a persistent control in the system menu bar."* Styled via `menuBarExtraStyle(_:)` — `MenuBarExtraStyle` cases **`.automatic`**, **`.menu`**, and **`.window`** are all **`macOS 13.0+`** (`.window` gives a panel-style popover; `.menu` the classic pull-down).
- **`Settings`** — macOS availability: **`macOS 11.0+`** (macOS-only)
  - `struct Settings<Content> where Content : View`
  - Verbatim: *"A scene that presents an interface for viewing and modifying an app's settings."* Companion `SettingsLink` opens it. Replaces the `NSApp.sendAction(Selector(("showSettingsWindow:")))` hack and the old `Preferences {}` scene.
- **`Window`** — single-instance scene (vs `WindowGroup` for multi-window); present in the Scenes index. macOS 13.0+ floor is from WWDC22 — **verify against your Xcode 26 SDK** (not body-scraped this round).

### 6. `Table` — macOS-first multi-column data view
- macOS availability: **`macOS 12.0+`**
- Signature: `struct Table<Value, Rows, Columns> where Value == Rows.TableRowValue, Rows : TableRowContent, Columns : TableColumnContent, Rows.TableRowValue == Columns.TableRowValue`
- Verbatim: *"A container that presents rows of data arranged in one or more columns, optionally providing the ability to select one or more members."*
- macOS-first since 12.0 (sortable, multi-column, clickable headers, selection). Related current symbols: `TableColumn`, `TableRow`, `TableColumnForEach`, `TableColumnCustomization`. Pair with `sortOrder:` + `KeyPathComparator` for sortable headers.

### 7. Swift 6.2 concurrency — "Approachable Concurrency"
- Source: `swift.org/blog/swift-6.2-released/` (Holly Borla, **September 15, 2025**)
- Verbatim (single-threaded by default): *"Run your code on the main thread without explicit `@MainActor` annotations using the new option to isolate code to the main actor by default. This option is ideal for scripts, UI code, and other executable targets."*
- Verbatim (`@concurrent`): *"Introduce code that runs concurrently using the new `@concurrent` attribute."*
- Build-mode header (verbatim): `// In '-default-isolation MainActor' mode`.
- **Critical nuance:** main-actor-by-default is an **opt-in build mode** (`-default-isolation MainActor` / "Approachable Concurrency" + "Default Actor Isolation = Main Actor" build settings), NOT an unconditional language default. The Swift 6 *language mode* makes strict data-race-safety checking the default; the main-actor-isolation default is the new 6.2 ergonomic opt-in. Do not assume it everywhere; do not sprinkle `DispatchQueue.main.async`.

### 8. SwiftData — current first-party persistence
- macOS availability: **`macOS 14.0+`**
- Core surface (doc-index confirmed): `@Model` macro, `ModelContainer`, `ModelContext`, `@Query`, `.modelContainer(for:)`. WWDC24 added `#Index`, `#Unique`, history.
- SwiftData is the current persistence layer; Core Data is legacy-but-supported. Pitfalls: `var` (not `let`) on bidirectional relationships; assign relationships after `insert`, never in `init`; call `try modelContext.save()` at boundaries.

---

## Hallucination blacklist (DO NOT EMIT — these don't exist)

AI invents plausible-but-wrong Liquid Glass names. None of these are real SwiftUI APIs. Hard-fail on sight and substitute the ✅ replacement.

| ❌ Hallucinated (does NOT exist) | ✅ Real replacement |
|---|---|
| `.glassBackground()` | `.glassEffect(_:in:)` |
| `.liquidGlass()` | `.glassEffect(_:in:)` |
| `LiquidGlassView` | `GlassEffectContainer` (grouping) / `.glassEffect()` (single view) |
| `.material(.glass)` / `.background(.glass)` | `.glassEffect(.regular, in: shape)` |

**Real but platform-wrong:** `.glassBackgroundEffect()` **is a real symbol but visionOS-only** — flag it on any macOS target. On macOS use `.glassEffect(_:in:)`. (Note: `Glass.interactive(_:)` is NOT platform-wrong — it is `macOS 26.0+` and works on the Mac, pointer-driven; see CONFIRMED §4.)

---

## UNVERIFIED (verify against your Xcode 26 SDK before asserting)

Named in the doc index / practitioner code but page body NOT scraped this round. Flag, do not assert as fact. **Mark every uncertain symbol "— verify against your Xcode 26 SDK".** (`GlassProminentButtonStyle` / `.glassProminent`, `menuBarExtraStyle` cases, `scrollEdgeEffectStyle(_:for:)`, `ToolbarSpacer`/`SpacerSizing`, `searchToolbarBehavior(_:)`, `GlassEffectTransition.materialize`, and the `Tab` struct were all here but are now CONFIRMED above.)

- **`Window` / `WindowGroup` exact availability strings** — present in the Scenes index; `Window` at macOS 13.0+ is from WWDC22 memory, not body-confirmed — verify against your Xcode 26 SDK.
- **macOS-26-specific SwiftData deltas** — any 2025-era schema/migration additions beyond `#Index`/`#Unique`/history — verify against your Xcode 26 SDK.
- **Scroll-edge effect DEFAULT style** (behavior, not the API): the API `scrollEdgeEffectStyle(_:for:)` is CONFIRMED above, but the claim that macOS defaults to `.hard` while iOS defaults to `.soft` is observed behavior, not a scraped fact — verify against your Xcode 26 SDK.

---

## Sources

All scraped 2026-06-06 unless dated otherwise.

- NavigationView (deprecation): https://developer.apple.com/documentation/swiftui/navigationview
- Migrating to new navigation types: https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types
- `@Observable` macro: https://developer.apple.com/documentation/observation/observable()
- Observation migration: https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro
- `onChange(of:initial:_:)`: https://developer.apple.com/documentation/SwiftUI/View/onChange(of:initial:_:)-4psgg
- `glassEffect(_:in:)`: https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- `GlassEffectContainer`: https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- `GlassButtonStyle`: https://developer.apple.com/documentation/swiftui/glassbuttonstyle
- `.glass(_:)` shorthand: https://developer.apple.com/documentation/SwiftUI/PrimitiveButtonStyle/glass(_:)
- `GlassProminentButtonStyle`: https://developer.apple.com/documentation/swiftui/glassprominentbuttonstyle
- Adopting Liquid Glass: https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- Applying Liquid Glass to custom views: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- `MenuBarExtra`: https://developer.apple.com/documentation/swiftui/menubarextra
- `Settings` scene: https://developer.apple.com/documentation/swiftui/settings
- Scenes index: https://developer.apple.com/documentation/swiftui/scenes
- `Table`: https://developer.apple.com/documentation/swiftui/table
- Swift 6.2 released (2025-09-15): https://swift.org/blog/swift-6.2-released/
- SwiftData: https://developer.apple.com/documentation/swiftdata · `@Model`: https://developer.apple.com/documentation/swiftdata/model()
- WWDC: "Meet Liquid Glass" (219), "Build a SwiftUI app with the new design" (323, 2025-06-09), "What's new in SwiftUI" (256), "Discover Observation in SwiftUI" (wwdc2023/10149), "What's new in SwiftData" (wwdc2024/10137)
