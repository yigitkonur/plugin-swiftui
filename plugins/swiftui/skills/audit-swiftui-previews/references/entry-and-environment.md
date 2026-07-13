# @Entry vs EnvironmentKey boilerplate, and the wrong injector (prev-03/08)

Custom environment values and their injection are where AI emits three-part legacy boilerplate (prev-03)
and the wrong injector for an `@Observable` (prev-08). Both are `warning`, `fix_mode: flag-only`. Floor
values: `<swiftui-plugin-root>/references/_shared/floors-master.md` (`@Entry` macOS 10.15+, back-deploys;
Xcode 15+ to expand → practical floor macOS 14).

## prev-03 — hand-rolling `EnvironmentKey` + `EnvironmentValues` instead of `@Entry`

The legacy custom-environment-value recipe is a private `EnvironmentKey` *plus* an `EnvironmentValues`
computed-property extension — three times the code for one value. The `@Entry` macro collapses it to a
single annotated `var` with an inline default: *"Create EnvironmentValues entries by extending the
EnvironmentValues structure with new properties and attaching the @Entry macro to the variable
declarations."*

```swift
// ❌ verbose legacy EnvironmentKey + computed-property boilerplate
private struct MyKey: EnvironmentKey { static let defaultValue = "Default value" }
extension EnvironmentValues {
    var myCustomValue: String { get { self[MyKey.self] } set { self[MyKey.self] = newValue } }
}
```
```swift
// ✅ one line with @Entry (macOS 10.15+, back-deploys; Xcode 15+ toolchain to expand)
extension EnvironmentValues {
    @Entry var myCustomValue: String = "Default value"
    @Entry var anotherCustomValue = true
}
```

`@Entry` uses the same one-line form for `Transaction`, `ContainerValues`, and `FocusedValues` entries —
so `@Entry var someAction: SomeAction?` is the modern way to declare the **focused values** that wire
macOS main-menu commands to the active window, replacing legacy `FocusedValueKey` boilerplate
(`FocusedValueKey` is macOS 11.0+).

**Context-conditional seam (per `<swiftui-plugin-root>/references/_shared/cross-ref-graph.md`):** if the
`@Entry`/`FocusedValueKey` pattern is **co-located with a `CommandMenu`/`CommandGroup`** →
`audit-swiftui-menus-commands` owns it (emit `cross_ref: audit-swiftui-menus-commands`). If it is in a
**preview / general environment setup** → this skill owns it. Decide by reading the surrounding scope.

## prev-08 — `.environmentObject(…)` for an `@Observable` (wrong injector)

`.environmentObject(_:)` takes only an `ObservableObject` (the legacy Combine protocol). An `@Observable`
(the macro, macOS 14+) is injected by **type** with `.environment(_:)` and read with
`@Environment(Model.self)`. Mixing them is a silent mismatch: the `@Observable` never lands in the
environment, so a `@Environment(Model.self)` read crashes (the prev-07 path). READ to confirm the injected
type is `@Observable` before flagging — a real `ObservableObject` with `.environmentObject` is correct.

```swift
// ❌ wrong injector — model is @Observable but injected as if ObservableObject
#Preview { DetailView().environmentObject(AppModel.preview) }   // AppModel is @Observable
```
```swift
// ✅ type-keyed .environment(_:) for an @Observable (macOS 14+)
#Preview { DetailView().environment(AppModel.preview) }
```

## VERIFY / FIX

Confirm `@Entry` / `.environment(_:)` existence + floor with `swiftui-ctx lookup <api> --json` + Sosumi
(`<swiftui-plugin-root>/references/_shared/swiftui-ctx-reference.md`, `sosumi-reference.md`). The ✅ in
`## Correct` is the swiftui-ctx consensus shape backed by `swiftui-ctx file <recommended.id> --smart`;
permalink + Sosumi `doc:` go in `## Source`. Both fixes are `flag-only`.

## Sources

- **Apple — `Entry()` macro.** `iOS 13.0+ … macOS 10.15+` (back-deploys; the macro needs the Xcode 15+ toolchain to expand — practical floor macOS 14). *"Create EnvironmentValues entries by extending the EnvironmentValues structure with new properties and attaching the @Entry macro to the variable declarations."*; one-line `@Entry var` examples for Environment / Transaction / Container / Focused values. https://developer.apple.com/documentation/SwiftUI/Entry() — accessed 2026-06-07.
- **Apple — `environment(_:)` vs `environmentObject(_:)`.** `.environment(_:)` injects an `@Observable` by type (macOS 14+); `.environmentObject(_:)` takes an `ObservableObject`. https://developer.apple.com/documentation/swiftui/view/environment(_:) — accessed 2026-06-07. https://developer.apple.com/documentation/swiftui/view/environmentobject(_:) — accessed 2026-06-07.
- **Apple — `FocusedValueKey` / focused values.** macOS 11.0+; `@Entry var … : Action?` is the modern declaration form. https://developer.apple.com/documentation/swiftui/focusedvaluekey — accessed 2026-06-07.
- **WWDC23 — "Discover Observation in SwiftUI" (session 10149).** `@Observable` + `.environment(_:)` injection. https://developer.apple.com/videos/play/wwdc2023/10149 — accessed 2026-06-07.
