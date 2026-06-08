# Preview macro, @Previewable state, traits & the windowStyle trap (prev-01/02/04/05)

The `#Preview` macro era (Xcode 15+, macOS 14+) superseded the `PreviewProvider` struct, and the macro's
*expanded-view-scope* semantics are where AI trained on 2019–2023 code goes wrong. Get the real macOS
shape from `swiftui-ctx lookup Preview --json` (`introduced_macos: 10.15`, `doc:` the Sosumi page), never
from memory. Floor values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

## prev-01 — `PreviewProvider` struct instead of the `#Preview` macro

The `struct …_Previews: PreviewProvider { static var previews }` form is **legacy** for new code: verbose
and superseded by the freestanding macro. `PreviewProvider` still exists and is **not deprecated** — flag
it as stale-for-new-code (a `warning`, `fix_mode: flag-only`), never call it invented. Multiple named
previews are just multiple `#Preview` declarations. (Seam: macro-modernity shares the `api-currency`
deprecation flag — `cross_ref: audit-swiftui-api-currency`.)

```swift
// ❌ legacy for new code (Xcode 15+) — PreviewProvider struct boilerplate
struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
```
```swift
// ✅ freestanding #Preview macro; one declaration per named preview (macOS 14+)
#Preview { ContentView() }
#Preview("Dark") { ContentView().preferredColorScheme(.dark) }
```

## prev-02 — bare `@State` / `@Binding` / `@Bindable` in a `#Preview` body (compile error)

`#Preview { }` is a *freestanding declaration macro*: the body expands into a generated view where
**tagged declarations become stored properties and the remaining statements form the `body`**. A bare
`@State` can't live at that scope — *"It is an error to use `@Previewable` outside of a `#Preview` body
closure,"* and inversely a dynamic property used inline must be tagged. This is `hard-fail` (it does not
compile), but `fix_mode: flag-only` — the tag is mechanical, but the *initial value* is the dev's call.

```swift
// ❌ bare @State at #Preview body scope — compile error
#Preview {
    @State var toggled = true            // illegal at the expanded body scope
    Toggle("On", isOn: $toggled)
}
```
```swift
// ✅ tag the dynamic property with @Previewable (macOS 14.0+)
#Preview {
    @Previewable @State var toggled = true
    Toggle("On", isOn: $toggled)
}
```

Same for a `@Previewable @State`-backed `@Binding` and a `@Bindable` driver. This is the canonical
stateful-preview shape — located structurally by `lint/ast-grep/prev-02-bare-state-in-preview.yml`.

## prev-04 — manual `.frame` sizing instead of a trait

AI wraps the view in a manual `.frame(...)` to make the canvas behave. `#Preview` takes **variadic
traits** the macro applies — and *"The macro ignores traits that don't apply to the current context,"* so
they're safe. Use `.fixedLayout(width:height:)` for a pinned canvas, `.sizeThatFitsLayout` to size to the
view's ideal size, `.defaultLayout` for the standard canvas (the implicit default) — instead of hand
frames. `advisory` (the `.frame` compiles; it's just not idiomatic), `fix_mode: flag-only`.

```swift
// ❌ manual sizing hack to make the canvas behave
#Preview { ContentView().frame(width: 100, height: 100) }
```
```swift
// ✅ pass a trait the macro applies (macOS 14+)
#Preview("Content", traits: .fixedLayout(width: 100, height: 100)) { ContentView() }
#Preview("Fits", traits: .sizeThatFitsLayout) { Badge() }
```

Verbatim signature: `macro Preview(_ name: String? = nil, traits: PreviewTrait<Preview.ViewTraits>, _ additionalTraits: PreviewTrait<Preview.ViewTraits>..., @ViewBuilder body: @escaping @MainActor () -> any View)`.

## prev-05 — `Preview(…, windowStyle:)` on a Mac target (visionOS-only)

There is **no** `windowStyle:` `#Preview` overload on macOS: `Preview(_:windowStyle:traits:body:)` is
**visionOS-only** — a `macOS ABSENT` symbol. On macOS, `#Preview { }` previews a `View`; that is the only
`#Preview` shape. **Never** wrap it in `#available(macOS …)` (it has no Mac arm — see
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` §3); replace it with the plain macro.
`hard-fail` (won't compile on a Mac target), `fix_mode: flag-only`.

```swift
// ❌ windowStyle: overload on a macOS target — visionOS-only, won't compile here
#Preview(windowStyle: .plain) { ContentView() }
```
```swift
// ✅ plain #Preview on macOS
#Preview { ContentView() }
```

## VERIFY / FIX

Confirm any floor or existence question with `swiftui-ctx lookup <api> --json` + Sosumi (protocol:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` and `sosumi-reference.md`). The ✅ in a
finding's `## Correct` is the swiftui-ctx **consensus shape**, backed by a real example fetched with
`swiftui-ctx file <recommended.id> --smart` (its GitHub permalink + the Sosumi `doc:` go in `## Source`).

## Sources

- **Apple — `Previewable()` macro.** `iOS 17.0+ … macOS 14.0+`. *"The #Preview macro will generate an embedded SwiftUI view; tagged declarations become properties on the view, and all remaining statements form the view's body."* / *"It is an error to use @Previewable outside of a #Preview body closure."* https://developer.apple.com/documentation/SwiftUI/Previewable() — accessed 2026-06-07.
- **Apple — `Preview(_:traits:_:body:)` macro.** `iOS 17.0+ … macOS 14.0+`; verbatim variadic-`PreviewTrait` + `@MainActor` signature; *"you can display a preview at a fixed size using the fixedLayout(width:height:) trait"* / *"The macro ignores traits that don't apply to the current context."* The `Preview(_:windowStyle:traits:body:)` overload is **visionOS-only**. https://developer.apple.com/documentation/SwiftUI/Preview(_:traits:_:body:) — accessed 2026-06-07.
- **Apple — `PreviewProvider` protocol.** Still present, not deprecated; the macro is the modern path. https://developer.apple.com/documentation/SwiftUI/PreviewProvider — accessed 2026-06-07.
- **WWDC23 — "Build programmatic UI with Xcode Previews" (session 10252).** The `#Preview` macro introduction (Xcode 15). `@Previewable` is NOT in this session. https://developer.apple.com/videos/play/wwdc2023/10252 — accessed 2026-06-07.
- **WWDC24 — "What's new in SwiftUI" (session 10144).** `@Previewable` macro announced as new at Xcode 16 / WWDC24; the `@Previewable @State` preview body shape originates here. https://developer.apple.com/videos/play/wwdc2024/10144 — accessed 2026-06-08.
