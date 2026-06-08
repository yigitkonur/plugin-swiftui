# `@Binding` vs `@Bindable` — projecting a non-owned `@Observable` (state-06)

An `@Observable` class held in a **plain property** (passed in, injected, or any non-owning reference) has
**no projected value**, so `$obj.prop` does not exist — `Cannot find '$obj' in scope`. `@Bindable` is the
wrapper that adds binding projection to an `@Observable` object the view does **not** own. This is distinct
from `@Binding`, which projects into a *value* owned by another view.

| You have | You want | Wrapper |
|---|---|---|
| a value owned by another view | a two-way binding `$value` | `@Binding` |
| a non-owned `@Observable` object | a binding to its property `$obj.prop` | `@Bindable` |
| an `@Observable` you own here | a binding to its property | `@State` (already projects `$model.prop`) |

## state-06 — `$obj.prop` with no `@Bindable` re-wrap

```swift
// ❌ WRONG — can't form $counter.count from a plain @Observable property
struct InspectorView: View {
    var counter: MyCounter = MyCounter()           // @Observable, but plain → not bindable
    var body: some View {
        Stepper("Count", value: $counter.count)    // error: Cannot find '$counter' in scope
    }
}
```

```swift
// ✅ CORRECT — non-owning view that needs two-way bindings → @Bindable (macOS 14+)
@available(macOS 14, *)
@Observable final class MyCounter { var count = 0 }

@available(macOS 14, *)
struct InspectorView: View {
    @Bindable var counter: MyCounter               // passed in, not owned here
    var body: some View { Stepper("Count", value: $counter.count) }   // now compiles
}
```

For an `@Observable` **injected by environment**, the re-wrap happens **locally inside `body`** (you can't
put `@Bindable` on an `@Environment` property) — see `environment-injection.md`:

```swift
var body: some View {
    @Bindable var book = book          // local re-wrap of an @Environment(Book.self) property
    TextField("Title", text: $book.title)
}
```

## The detection nuance (why the lint LOCATES, you DECIDE)

The tier-2 rule `state-06` anchors on `navigation_expression` whose base is a `$`-prefixed identifier — it
excludes the `$0`/`$1` closure shorthand a flat grep also matches. But it cannot tell, across scopes,
whether a `@Bindable var obj = obj` re-wrap already exists or whether `obj` is a legal `@State`/`@Binding`/
`@Bindable`. **READ the body** (SKILL.md step 3): report only when `obj` is a plain or `@Environment`
`@Observable` property with no nearby re-wrap. A `$obj.prop` where `obj` is `@State`/`@Binding`/`@Bindable`
is correct — not a finding.

## ✅ grounded in swiftui-ctx

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Bindable --json     # introduced_macos 14.0; 390 repos / 4548 uses
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart   # the real @Bindable call site, live
```

`lookup Bindable` (accessed 2026-06-07): `introduced_macos 14.0`, recommended `ex_ff2273b082`
(`sindresorhus/Gifski`), source `@Bindable var appState = appState` — exactly the local-re-wrap idiom.

## Severity & fix mode

state-06 → `warning`, `fix_mode: flag-only` (`failure_shape: compile-error` — the missing projection won't
compile; but whether the fix is `@Bindable var counter: MyCounter` vs a local re-wrap depends on how the
model arrives, a human-confirmed call). `model_kind: observable`.

## Sources

- **Apple — `Bindable`.** `macOS 14.0+`. *"A property wrapper type that supports creating bindings to the
  mutable properties of observable objects."* Overview carries the `@Environment(Book.self) private var
  book` + `@Bindable var book = book` re-wrap example.
  https://developer.apple.com/documentation/swiftui/bindable — accessed 2026-06-06 (via Sosumi).
- **Apple — `Binding`.** Two-way binding into a value owned elsewhere.
  https://developer.apple.com/documentation/swiftui/binding — accessed 2026-06-07 (via Sosumi).
- **Donny Wals — "What's the difference between @Binding and @Bindable," upd. 2024-04-23.** Own → `@State`;
  non-owned → `@Bindable`; `$counter` errors without `@Bindable`.
  https://www.donnywals.com/whats-the-difference-between-binding-and-bindable/ — accessed 2026-06-06.
