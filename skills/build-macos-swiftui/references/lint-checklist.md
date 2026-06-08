# Detection Lint Checklist (macOS SwiftUI)

67 grep/scan tells: **WRONG pattern → correct macOS replacement**. Run before proposing code (agent
self-check) or wire as a `PreToolUse`/CI scan. The runnable version is
`${CLAUDE_PLUGIN_ROOT}/scripts/macos-swiftui-lint.sh`; this file is the human-readable source of truth.
Each rule maps to its deep reference doc.

## Version drift / deprecation → `version-and-hallucination.md`, `navigation-and-toolbars.md`
1. `NavigationView {` → `NavigationStack` / `NavigationSplitView` (Mac sidebar). **[hard-fail]**
2. `.foregroundColor(` → `.foregroundStyle(` (note: `.foregroundStyle` is macOS 12+ — gate or keep `.foregroundColor` for macOS-11 targets).
3. `.cornerRadius(` → `.clipShape(RoundedRectangle(cornerRadius: N))` (Apple-canonical; `.clipShape(.rect(cornerRadius: N))` is an equivalent shorthand; floor macOS 10.15+).
4. `.onChange(of:` with single-ident closure `{ newValue in }` / `{ value in }` → two-param `{ old, new in }`.
5. `.tabItem {` → `Tab(...) { }` (note: `Tab {}` requires macOS 15.0+ — for macOS-14 targets keep `.tabItem` with gating).
6. `Text("a") + Text("b")` (the `Text` `+` operator) → **deprecated macOS 26.0**; use string interpolation `Text("a \(b)")`.
7. `NavigationLink(` with `destination:` inside a `List`/`ForEach` → `.navigationDestination(for:)`.
8. `.navigationBarTitle(` / `.navigationBarTitleDisplayMode(` → `.navigationTitle` (iOS-only on Mac).
9. `placement: .navigationBarLeading` / `.navigationBarTrailing` → `.primaryAction`/`.principal`/`.navigation`.

## Hallucination / gating → `liquid-glass.md`, `api-currency.md`
10. `.glassBackground(` · `.liquidGlass(` · `.material(.glass` · `.background(.glass)` · `LiquidGlassView` → **hard-fail** (don't exist); real = `.glassEffect()`.
11. `.glassBackgroundEffect(` on a macOS target → visionOS-only; flag.
12. `glassEffect`/`GlassEffectContainer`/`.buttonStyle(.glass`/`glassEffectID`/`glassEffectUnion`/`backgroundExtensionEffect`/`scrollEdgeEffectStyle` with no enclosing `#available(macOS 26` (deployment < 26) → add macOS-arm gate.
13. `@Observable`/`@Bindable`/two-param `onChange` below macOS 14 with no `@available`/`#available` → gate. (Note: `#Preview { }` itself back-deploys to macOS 10.15 and needs no gate; only `@Previewable` inside its body needs a macOS-14 gate.)
14. `#available(iOS …` / `@available(iOS …` used as the gate in macOS-target code → wrong arm (the `*` wildcard already covers macOS, so the branch always fires); use `#available(macOS …)`.
15. `.focusable(` / `.focused(` below macOS 12 with no gate → `.focusable`/`.focused` are macOS 12.0+; gate or raise the floor.
16. Any unfamiliar modifier that "reads right" but isn't in `api-currency.md`/Apple docs → treat as hallucinated until verified.

## State & observation → `state-and-observation.md`
17. `@ObservedObject var <name> = <Type>(` (initializer present) → `@StateObject`/`@State`. **[hard-fail]**
18. `@ObservedObject var <x>: <T>` where `<T>` is an `@Observable` type → compile error (`@ObservedObject` needs `ObservableObject`); use a plain stored property.
19. `@Observable` class `… : ObservableObject` → remove the conformance. **[hard-fail]**
20. `@Published` inside an `@Observable` class → remove. **[hard-fail]**
21. `@StateObject` on a type that is not `: ObservableObject` (struct or `@Observable`) → wrong owner wrapper.
22. `@EnvironmentObject` where the model is `@Observable` → `@Environment(Type.self)`.
23. `$someObservable.prop` where the var is plain/`@Environment(Type.self)` with no nearby `@Bindable` → add `@Bindable`.
24. `private var <name>: some View {` computed prop reading an `@Observable` model → extract to a child `View` type.

## Concurrency → `concurrency.md`
25. `DispatchQueue.main.async` in async/SwiftUI code → `@MainActor` / `await MainActor.run`.
26. `Task {` inside `.onAppear`/`onChange` → `.task {}` / `.task(id:)`. **[advisory]** (Exceptions: intentionally long-lived tasks — background upload/analytics — and macOS-11 targets, where `.task` is unavailable; `.task` is macOS 12+.)
27. `@Sendable` closure whose body reads `self.`/a `@MainActor` property → isolate the closure or capture-by-value.
28. `Task.detached {` capturing a non-`Sendable` class → boundary violation.
29. `@concurrent` present → confirm toolchain is Swift 6.2+.

## Scenes / menus → `scenes-and-windows.md`, `menus-and-commands.md`
30. `WindowGroup` once **and** a `*Settings*`/`*Preferences*` view reached via `NavigationLink`/`.sheet` → missing `Settings {}` scene.
31. `NSStatusItem` / `NSMenu` in a SwiftUI-first app → `MenuBarExtra`.
32. `openWindow(`/`openSettings(` inside a `MenuBarExtra { }` closure with no adjacent `NSApp.activate` → no-front-window bug.
33. `WindowGroup`/`Window(` with no `.defaultSize`/`.windowResizability`/root `minWidth` → unsized window.
34. A scene with no `.commands { }` anywhere → menu bar faked as buttons.
35. `CommandMenu("File"|"Edit"|"View"|"Window"|"Help")` (standard-menu title) → `CommandGroup(... .placement)`.
36. A `CommandMenu`/`CommandGroup` closure referencing concrete `@State`/model → use `@FocusedValue` + `.disabled(focusedValue == nil)`.
37. `Preferences {}` scene or `NSApp.sendAction(Selector(("showSettingsWindow:"))` → stale pre-`Settings`-scene pattern.

## AppKit interop → `appkit-interop.md`
38. `: NSViewRepresentable`/`: NSViewControllerRepresentable` with no `updateNSView`/`updateNSViewController` → state staleness. **[hard-fail]**
39. Representable with a `@Binding` but no `makeCoordinator()`/`delegate = context.coordinator` → broken AppKit→SwiftUI direction.
40. `becomeFirstResponder()` on a SwiftUI value, or custom `NSView` lacking `override var acceptsFirstResponder { true }` → focus won't work.
41. Observers/KVO added in `makeNSView` with no `dismantleNSView` → teardown leak.

## Layout / controls → `layout-and-tables.md`, `controls-and-pointer.md`
42. `List(` wrapping `HStack { Text … Spacer() Text … }` of struct fields → `Table` + `TableColumn`.
43. `Table(` with no `sortOrder:`/`KeyPathComparator` → non-sortable table (Mac expects clickable headers).
44. `Form {` with no `.formStyle(` in a Mac settings/pane → ungrouped non-native form.
45. Custom interactive view with no `.onHover` and no `.help(` → missing pointer affordances.
46. Row/item view with no `.contextMenu` → missing right-click menu.
47. Custom focus-taking view with no `.focusable()`/`@FocusState` → not keyboard-reachable.
48. `NavigationSplitView` sidebar `List` with no `.listStyle(.sidebar)` → wrong sidebar look.

## SwiftData → `swiftdata.md`
49. `let ` immediately before an `@Relationship`/another-`@Model`-typed property → runtime crash. **[hard-fail]**
50. `self.<relationship> =` inside a `@Model` `init` body → data vanishes on relaunch.
51. `try ModelContainer(` followed by `catch { fatalError(` in non-preview code → handle gracefully.
52. `@Model class` with stored props but no `init(` → incomplete Apple-doc copy.
53. `@Relationship(.cascade)` → **compile-time type error**: `.cascade` is a `DeleteRule`, but the macro's first positional param is `Schema.Relationship.Option` (whose only case is `.unique`). Use `@Relationship(deleteRule: .cascade)`.
54. Indexing a relationship array (`.items[0]`) with no `SortDescriptor`/`@Query(sort:)` → unordered.
55. Background `Task {}` mutating `@Environment(\.modelContext)` results with no `@ModelActor` → off-thread mutation.
56. A mutation path with no `try modelContext.save()` anywhere → silent data loss.

## Sandbox / file access → `sandbox-and-files.md`
57. `URL(fileURLWithPath:`/`Data(contentsOf:`/`FileManager` against a literal/typed path with no preceding `fileImporter`/`NSOpenPanel` → consent violation. **[hard-fail]** (Exception: does NOT apply to URLs from `Bundle.main.url(forResource:)`/`Bundle.main` resource reads or paths inside the app's own container — those need no consent.)
58. Picked `URL` saved to `UserDefaults`/disk without `bookmarkData(options: .withSecurityScope)` → no re-access next launch.
59. Resolved/picked URL used with no surrounding `start/stopAccessingSecurityScopedResource()`.
60. File/network/bookmark APIs used with no `.entitlements` keys / missing `com.apple.security.app-sandbox`.
61. `NSItemProvider` `loadObject`/`loadDataRepresentation` or `UIPasteboard` in macOS code → use `Transferable` + `.dropDestination`.

## Previews → `previews.md`
62. `struct *_Previews: PreviewProvider` → `#Preview { }`.
63. `@State`/`@Binding`/`@Bindable` directly inside a `#Preview { }` body without `@Previewable` → compile error.
64. `struct *Key: EnvironmentKey` + `extension EnvironmentValues` computed prop → single `@Entry var`.
65. `#Preview` of a `@Query`/SwiftData view with no `.modelContainer(... inMemory: true)` → preview crash.
66. `try ModelContainer(` inside a `#Preview` body WITHOUT `inMemory:`/`isStoredInMemoryOnly: true` → preview crash / corrupts the dev store.
67. `#Preview` of a view reading `@Environment(SomeModel.self)` with no `.environment(...)` injection → crash/empty.

## Positive checks (a macOS app SHOULD contain these — absence is a smell)
- `Settings {}` / `MenuBarExtra` / `.commands {}` somewhere in an app target.
- `#available(macOS …` gating wherever a macOS-14+/26+ API is used.

## Sources
Consolidated macOS-SwiftUI detection rules. Each rule's deep treatment (with ❌/✅ code and Apple-doc
citations) is in the reference doc named in its group header above; this list mirrors
`scripts/macos-swiftui-lint.sh`.
