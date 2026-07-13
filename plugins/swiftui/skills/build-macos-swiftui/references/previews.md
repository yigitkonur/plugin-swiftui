# Previews & #Preview Macro (macOS)

A broken preview blocks the whole edit loop, and the preview *tooling* is exactly where AI goes stale: it emits the legacy `PreviewProvider` struct (which dominated 2019–2023 examples), forgets `@Previewable` when a `#Preview` body needs `@State`, hand-rolls `EnvironmentKey` boilerplate instead of `@Entry`, ignores `#Preview` *traits*, and ships previews that **crash the canvas** — because a preview instantiates the view for real, so an un-provided SwiftData container or `@Environment` dependency traps.

Every example here compiles on a **macOS target** (macOS 14+ unless noted). iOS appears only as a ❌ contrast — the macro semantics are platform-agnostic, and on macOS the plain `#Preview { }` previews a *view*. There is **no** `windowStyle:` preview overload on macOS: `Preview(_:windowStyle:traits:body:)` is **visionOS-only**, so don't reach for it here.

> **Availability floors (confirmed).** `@Entry` (the freestanding `#Preview` / `Preview(_:body:)` symbol too) is `macOS 10.15+` and back-deploys, but the *macro* needs the Xcode 15+ toolchain to expand — so the practical floor is **macOS 14**. `@Previewable` is `macOS 14.0+`. The modern `PreviewModifier` protocol and the `.modifier(_:)` trait are `macOS 15.0+`. All four are body-confirmed against the Apple docs (see Sources).

## Mistake 1 — `PreviewProvider` struct instead of the `#Preview` macro

The `struct …_Previews: PreviewProvider { static var previews }` form is the **legacy** path: verbose and superseded by the freestanding `#Preview` macro (Xcode 15+, `macOS 14.0+`). `PreviewProvider` still exists and is *not* deprecated, but new code should use the macro — multiple named previews are just multiple `#Preview` declarations.

```swift
// ❌ WRONG (legacy for new code, Xcode 15+) — PreviewProvider struct boilerplate
struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
```
```swift
// ✅ CORRECT — freestanding #Preview macro; one declaration per named preview (macOS 14+)
#Preview { ContentView() }
#Preview("Dark") { ContentView().preferredColorScheme(.dark) }
```

## Mistake 2 — Using `@State` directly inside a `#Preview` body (should be `@Previewable @State`)

`#Preview { }` is a *freestanding declaration macro*: it expands the body into a generated view where **tagged declarations become stored properties and the remaining statements form the `body`**. A bare `@State` can't live at that scope. The fix is `@Previewable @State` — *"It is an error to use `@Previewable` outside of a `#Preview` body closure,"* and inversely a dynamic property used inline must be tagged with it.

```swift
// ❌ WRONG — bare @State at #Preview body scope (compile error)
#Preview {
    @State var toggled = true            // ERROR — illegal at the expanded body scope
    Toggle("On", isOn: $toggled)
}
```
```swift
// ✅ CORRECT — tag the dynamic property with @Previewable (macOS 14.0+)
#Preview {
    @Previewable @State var toggled = true
    Toggle("On", isOn: $toggled)
}
```

This is the canonical way to drive a stateful preview — same for `@Previewable @State`-backed `@Binding` and `@Bindable` drivers.

## Mistake 3 — Hand-rolling `EnvironmentKey` + `EnvironmentValues` instead of `@Entry`

The legacy custom-environment-value recipe is a private `EnvironmentKey` *plus* an `EnvironmentValues` computed-property extension — three times the code for one value. The `@Entry` macro collapses it to a single annotated `var` with an inline default: *"Create `EnvironmentValues` entries by extending the `EnvironmentValues` structure with new properties and attaching the @Entry macro to the variable declarations."*

```swift
// ❌ WRONG — verbose legacy EnvironmentKey + computed-property boilerplate
private struct MyKey: EnvironmentKey { static let defaultValue = "Default value" }
extension EnvironmentValues {
    var myCustomValue: String { get { self[MyKey.self] } set { self[MyKey.self] = newValue } }
}
```
```swift
// ✅ CORRECT — one line with @Entry (macOS 10.15+, back-deploys; Xcode 15+ toolchain to expand)
extension EnvironmentValues {
    @Entry var myCustomValue: String = "Default value"
    @Entry var anotherCustomValue = true
}
```

`@Entry` uses the same one-line form for `Transaction`, `ContainerValues`, and `FocusedValues` entries — so `@Entry var someAction: SomeAction?` is the modern way to declare the **focused values** that wire macOS main-menu commands to the active window, replacing legacy `FocusedValueKey` boilerplate.

## Mistake 4 — Ignoring `#Preview` traits (`.fixedLayout`, `.sizeThatFitsLayout`)

AI either never customizes the canvas or wraps the view in manual `.frame(...)` hacks to make it size correctly. `#Preview` takes **variadic traits** the macro applies — and *"The macro ignores traits that don't apply to the current context,"* so they're safe to pass. Use `.fixedLayout(width:height:)` for a pinned canvas, `.sizeThatFitsLayout` to size the canvas to the view's ideal size, and `.defaultLayout` for the standard device-style canvas (the implicit default) — all instead of hand-tuned frames.

```swift
// ❌ WRONG — manual sizing hack to make the canvas behave
#Preview {
    ContentView().frame(width: 100, height: 100)     // fighting the canvas by hand
}
```
```swift
// ✅ CORRECT — pass a trait the macro applies (macOS 14+)
#Preview("Content", traits: .fixedLayout(width: 100, height: 100)) {
    ContentView()
}
#Preview("Fits", traits: .sizeThatFitsLayout) { Badge() }
#Preview("Default", traits: .defaultLayout) { ContentView() }   // standard canvas (the implicit default)
```

Verbatim signature: `macro Preview(_ name: String? = nil, traits: PreviewTrait<Preview.ViewTraits>, _ additionalTraits: PreviewTrait<Preview.ViewTraits>..., @ViewBuilder body: @escaping @MainActor () -> any View)`. There is no `windowStyle:` overload on macOS — `Preview(_:windowStyle:traits:body:)` is **visionOS-only**. On macOS, `#Preview { }` previews a `View`; that is the only `#Preview` shape available.

## Mistake 5 — SwiftData preview that crashes (no in-memory container)

A `#Preview` of a view that uses `@Query` or expects a `modelContainer`, with no container injected, **crashes the canvas on launch** — the preview instantiates the view for real, and with no `ModelContainer` in the environment (or a production container that can't initialize in the preview sandbox) it traps. Inject a dedicated **in-memory** container so the preview is self-contained.

```swift
// ❌ WRONG — @Query view with no container → preview traps on launch
#Preview {
    ItemListView()                                   // reads @Query, no ModelContainer provided
}
```
```swift
// ✅ CORRECT — inject an in-memory container scoped to the preview (macOS 14+)
#Preview {
    ItemListView()
        .modelContainer(for: Item.self, inMemory: true)
}
// Or build a configured container explicitly:
// let container = try! ModelContainer(
//     for: Item.self,
//     configurations: ModelConfiguration(isStoredInMemoryOnly: true))
```

Pair with `@Previewable @State` if the view also needs local state, and seed sample rows into the container's `mainContext` when the view should render non-empty. This inline in-memory container is the right pattern on **macOS 14**; on macOS 15+ prefer a `PreviewModifier` so the container is built once and shared (Mistake 6).

## Mistake 6 — Rebuilding the SwiftData container per preview instead of a shared `PreviewModifier` (macOS 15+)

The inline `.modelContainer(for:inMemory:true)` from Mistake 5 builds a **fresh** container — and re-seeds sample data — for *every* `#Preview`, which is wasteful when many previews share the same fixture. On **macOS 15.0+**, `PreviewModifier` is the modern fix: build the `ModelContainer` **once** in `makeSharedContext()` (Preview caches it by the modifier type and reuses it across previews), then attach it as a trait with `.modifier(_:)`. It also wraps any reusable preview environment, not just SwiftData.

```swift
// ❌ WRONG (macOS 15+) — every preview rebuilds + re-seeds its own container
#Preview { ItemListView().modelContainer(for: Item.self, inMemory: true) /* seed… */ }
#Preview("Filtered") { FilteredView().modelContainer(for: Item.self, inMemory: true) /* seed again… */ }
```
```swift
// ✅ CORRECT — define the fixture once, share it via .modifier (macOS 15.0+)
struct SampleData: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let container = try ModelContainer(
            for: Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(Item(name: "Sample"))   // seeded ONCE, cached & reused
        return container
    }
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

#Preview(traits: .modifier(SampleData())) { ItemListView() }
#Preview("Filtered", traits: .modifier(SampleData())) { FilteredView() }
```

`@Previewable @Query` inside a `#Preview` body also needs **macOS 15**. Keep the Mistake 5 inline in-memory container as the macOS-14 fallback when you can't require macOS 15.

## Mistake 7 — Environment-dependent view with no injected dependency

`#Preview { DetailView() }` where `DetailView` reads `@Environment(AppModel.self)` shows nothing or crashes — previews do **not** inherit your app's scene environment, so any required `@Environment` / injected `@Observable` must be supplied in the preview body. Provide a mock/sample instance.

```swift
// ❌ WRONG — required @Environment(AppModel.self) never provided
#Preview {
    DetailView()                                     // empty / crashes: no AppModel in environment
}
```
```swift
// ✅ CORRECT — inject a sample @Observable by type (macOS 14+)
#Preview {
    DetailView()
        .environment(AppModel.preview)               // sample/mock @Observable
}
```

This is the type-keyed `.environment(_:)` injection — not legacy `.environmentObject(_:)`, which only takes an `ObservableObject`.

## Detection tells

Grep/scan signals that flag the mistakes above:

- **`struct *_Previews: PreviewProvider`** — legacy preview struct; replace with one or more `#Preview { }` declarations.
- **`@State` / `@Binding` / `@Bindable` directly inside a `#Preview { }` body with no `@Previewable`** — compile error; tag the declaration `@Previewable`.
- **`struct *Key: EnvironmentKey`** alongside an **`extension EnvironmentValues`** computed property — collapse to a single `@Entry var`.
- **`#Preview` of a `@Query` / SwiftData view with no `.modelContainer(... inMemory: true)`** — the canvas will crash on launch.
- **Repeated `.modelContainer(for:inMemory:true)` + re-seeding across many `#Preview`s** (macOS 15+) — collapse to one `PreviewModifier` shared via `traits: .modifier(...)`.
- **`#Preview` of a view that reads `@Environment(SomeModel.self)` with no `.environment(...)` injection** — preview crashes or renders empty.
- **`.frame(width:height:)` (or other manual sizing) inside a `#Preview` body** where `traits: .fixedLayout(...)` / `.sizeThatFitsLayout` / `.defaultLayout` is the idiomatic replacement.
- **`.environmentObject(...)` in a preview whose model is `@Observable`** — wrong injector; use `.environment(...)`.
- **`Preview(_:windowStyle:traits:body:)` in a macOS target** — that overload is visionOS-only; on macOS use the plain `#Preview { }`.

## Canonical pattern

Quote this block verbatim when prescribing the rules:

```
PREVIEWS — CANONICAL RULES (Xcode 15/16+, macOS 14+/iOS 17+ era)

1. Use the #Preview macro, NOT `struct …_Previews: PreviewProvider`.
   One #Preview declaration per named preview.

2. Stateful preview → tag dynamic properties @Previewable inside the body:
       #Preview { @Previewable @State var on = true; Toggle("On", isOn: $on) }
   (@State/@Binding/@Bindable bare in a #Preview body is a compile error.)

3. Custom environment value → ONE line with @Entry, not the 3-part
   EnvironmentKey + EnvironmentValues boilerplate:
       extension EnvironmentValues { @Entry var myValue: String = "Default" }
   (Same form for Transaction / ContainerValues / FocusedValues entries.)

4. Size the canvas with TRAITS, not manual .frame hacks:
       #Preview("X", traits: .fixedLayout(width: 100, height: 100)) { View() }
       #Preview("Fits", traits: .sizeThatFitsLayout) { View() }
       #Preview("Default", traits: .defaultLayout) { View() }
   There is NO windowStyle: #Preview overload on macOS —
   Preview(_:windowStyle:traits:body:) is visionOS-only.

5. Previews run real code — INJECT every dependency the view needs:
       #Preview {
           ContentView()
               .modelContainer(for: Item.self, inMemory: true)  // SwiftData (macOS 14 fallback)
               .environment(AppModel.preview)                    // @Observable
       }
   No injected ModelContainer / @Environment object → the CANVAS crashes,
   not the app.

6. Reusable / cached preview environment → PreviewModifier (macOS 15+):
   build the ModelContainer ONCE in makeSharedContext(), share via
   traits: .modifier(...) — supersedes per-preview inline in-memory
   containers; @Previewable @Query also needs macOS 15.

FLOORS (confirmed): @Entry macOS 10.15+ (back-deploys; Xcode 15+ to
expand; practical floor macOS 14) · @Previewable macOS 14.0+ ·
PreviewModifier / .modifier(_:) macOS 15.0+.
```

## Sources

API/availability claims carry verbatim quotes from the Apple docs below (developer.apple.com JSON, confirmed 2026-06-07). `@Entry`, `@Previewable`, `#Preview` / `Preview(_:traits:_:body:)`, and `PreviewModifier` are all body-confirmed against the Apple docs — floors stated below are confirmed, not provisional.

- **Apple — `Previewable()` macro.** Availability `iOS 17.0+ … macOS 14.0+` (**confirmed**). *"The #Preview macro will generate an embedded SwiftUI view; tagged declarations become properties on the view, and all remaining statements form the view's body."* / *"It is an error to use @Previewable outside of a #Preview body closure."*; carries the `@Previewable @State var toggled = true` example. https://developer.apple.com/documentation/SwiftUI/Previewable() — accessed 2026-06-07.
- **Apple — `Entry()` macro.** Availability `iOS 13.0+ … macOS 10.15+` (**confirmed**; back-deploys, but the macro needs the Xcode 15+ toolchain to expand — practical floor macOS 14). *"Create EnvironmentValues entries by extending the EnvironmentValues structure with new properties and attaching the @Entry macro to the variable declarations."*; one-line `@Entry var` examples for Environment / Transaction / Container / Focused values. https://developer.apple.com/documentation/SwiftUI/Entry() — accessed 2026-06-07.
- **Apple — `Preview(_:traits:_:body:)` macro.** Availability `iOS 17.0+ … macOS 14.0+`; verbatim signature with variadic `PreviewTrait` + `@MainActor` body. *"you can display a preview at a fixed size using the fixedLayout(width:height:) trait"* / *"The macro ignores traits that don't apply to the current context."*; `#Preview("Content", traits: .fixedLayout(width: 100, height: 100))` example. The `Preview(_:windowStyle:traits:body:)` overload is **visionOS-only** — there is no `windowStyle:` `#Preview` on macOS. https://developer.apple.com/documentation/SwiftUI/Preview(_:traits:_:body:) — accessed 2026-06-07.
- **Apple — `PreviewModifier` protocol + `.modifier(_:)` trait.** Availability `macOS 15.0+` (**confirmed**). Build a shared environment once in `makeSharedContext()` (Preview caches it by modifier type) and apply via `body(content:context:)`; attach with `#Preview(traits: .modifier(SampleData()))`. https://developer.apple.com/documentation/SwiftUI/PreviewModifier — accessed 2026-06-07.
- **Apple — SwiftData.** `@Model`, `ModelContainer`, `ModelConfiguration`, `@Query`, `.modelContainer(for:inMemory:)` confirmed in the doc index; SwiftData is `macOS 14.0+`. https://developer.apple.com/documentation/swiftdata — accessed 2026-06-07.
- **swiftlang/swift issue #66537** — SwiftData preview crashes without an in-memory container; corroborates the canvas-trap symptom (also r/swift "SwiftData Crashes in Preview"). https://github.com/swiftlang/swift/issues/66537 — accessed 2026-06-06.
