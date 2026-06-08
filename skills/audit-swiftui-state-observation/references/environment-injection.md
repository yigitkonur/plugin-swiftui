# Environment injection — type-keyed vs legacy (state-05)

`@EnvironmentObject` / `.environmentObject(_:)` belong to the **legacy** `ObservableObject` world. The
`@Observable` world injects through the **type-keyed** environment: `.environment(instance)` to inject,
`@Environment(Type.self)` to retrieve. Using `@EnvironmentObject` with an `@Observable` model is a
type mismatch (the modifier expects an `ObservableObject`).

## state-05 — `@EnvironmentObject` for an `@Observable` model

```swift
// ❌ WRONG — @EnvironmentObject only works with ObservableObject
@Observable class Library { var books: [Book] = [] }
struct RootView: View {
    var body: some View { LibraryView().environmentObject(Library()) }  // mismatch under @Observable
}
struct LibraryView: View { @EnvironmentObject var library: Library }     // wrong wrapper
```

```swift
// ✅ CORRECT — inject by type at SCENE level, retrieve by type, bind locally (macOS 14+)
@available(macOS 14, *)
@Observable final class Book { var title = "Sample Book Title" }

@available(macOS 14, *)
@main struct MacApp: App {
    @State private var book = Book()               // owned once, @State at App scope
    var body: some Scene {
        WindowGroup { TitleEditView() }
            .environment(book)                     // every window of the WindowGroup sees it
    }
}
@available(macOS 14, *)
struct TitleEditView: View {
    @Environment(Book.self) private var book       // read-only by type
    var body: some View {
        @Bindable var book = book                  // local re-wrap to project $book.title (see binding-and-bindable.md)
        TextField("Title", text: $book.title)
    }
}
```

## The macOS angle (load-bearing)

On macOS, type-keyed injection is typically at the **scene** level (on `WindowGroup`/the `Scene`) so every
window of a `WindowGroup` sees the **shared** model — this is the multi-window reason the type-keyed
environment matters more on Mac than iOS. Inject only **genuinely shared** models at scene level; per-window
concerns stay as `@State` in the window's root view (see `model-lifecycle.md`, state-10). Reading back an
injected `@Observable` is read-only; to get a binding, re-wrap locally with `@Bindable var x = x`.

## The detection nuance

The grep tell `@EnvironmentObject` LOCATES; **READ** the file (SKILL.md step 3) to confirm the injected
model's kind. `@EnvironmentObject` with a **real `ObservableObject`** is correct legacy code, not a finding
— report only when the model is `@Observable` (or the codebase has otherwise moved to the modern world).
Apple lets `@EnvironmentObject` accept a *plain* `@Observable` for incremental migration → that is a
`failure_shape: migration-smell`, not a hard mismatch.

## ✅ grounded in swiftui-ctx

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Environment --json        # @Environment(Type.self) consensus
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx recipe observable-model          # the own-once-inject-by-type pattern
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart    # the real `.environment(_:)` site, live
```

Cite the `lookup Environment` recommended permalink + Sosumi `doc:` as the ✅ `## Source`; put the consensus
`.environment(_:)` + `@Environment(Type.self)` shape in `## Correct`.

## Severity & fix mode

state-05 → `warning`, `fix_mode: flag-only` (`model_kind: observable`, `failure_shape: compile-error` when
the model is `@Observable`). The swap touches both the injection site (`.environmentObject` → `.environment`)
and the read site (`@EnvironmentObject` → `@Environment(Type.self)`), often across files — a human-confirmed
multi-site change, never auto.

## Sources

- **Apple — `EnvironmentObject`.** Legacy; requires `ObservableObject`.
  https://developer.apple.com/documentation/swiftui/environmentobject — accessed 2026-06-07 (via Sosumi).
- **Apple — `Environment` (type-based) / `environment(_:)`.** `@Environment(Type.self)` retrieval +
  `.environment(_:)` injection for `@Observable`.
  https://developer.apple.com/documentation/swiftui/environment — accessed 2026-06-07 (via Sosumi).
- **Apple — Migrating from the Observable Object protocol to the Observable macro.** The injection-by-type
  mapping. https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
  — accessed 2026-06-06 (via Sosumi).
