# Canvas crashes: missing container, missing @Environment injection (prev-06/07)

A `#Preview` **instantiates the previewed view for real** — so any dependency the view reads but the
preview never provides traps **the canvas**, not the app. The two headline traps are a SwiftData view
with no in-memory `ModelContainer` (prev-06) and an `@Environment`-dependent view with no injection
(prev-07). Both are `hard-fail` (canvas crash / blank), both `fix_mode: flag-only` (the sample data and
the mock instance are the dev's call). Get the real injection shape from `swiftui-ctx`, below.

## The instantiation test

For every `#Preview`, ask: *does the previewed view read state or a dependency the preview never
provides?* Walk the view's stored properties: a `@Query`, an `@Environment(Model.self)`, a non-optional
`@Bindable` model — each must be supplied **in the preview body** (previews do **not** inherit your app's
scene environment). If READ confirms a required dependency is unprovided and nothing upstream injects it,
that is a 100%-confidence finding.

## prev-06 — SwiftData preview with no in-memory container

A `#Preview` of a view that uses `@Query` or expects a `modelContainer`, with no container injected,
**crashes the canvas on launch** — with no `ModelContainer` in the environment (or a production container
that can't initialize in the preview sandbox), it traps. Inject a dedicated **in-memory** container so the
preview is self-contained. (Seam: SwiftData *model design* is `audit-swiftui-swiftdata`'s —
`cross_ref: audit-swiftui-swiftdata`; the preview-construction angle is this skill's per the shared
cross-ref graph.)

```swift
// ❌ @Query view with no container → preview traps on launch
#Preview {
    ItemListView()                                   // reads @Query, no ModelContainer provided
}
```
```swift
// ✅ inject an in-memory container scoped to the preview (macOS 14+)
#Preview {
    ItemListView()
        .modelContainer(for: Item.self, inMemory: true)
}
```

**swiftui-ctx grounding (run during this build):** `swiftui-ctx lookup modelContainer --json` →
`consensus` carries the `(for, inMemory)` shape (the preview form) at **13%** of all real uses;
`co_occurs_with` lists `Query`, `Model`, `ModelContext`, `Schema` — i.e. wherever the corpus uses
`@Query` it pairs a `modelContainer`, corroborating prev-06's tell. `introduced_macos: 14.0`,
`doc: https://sosumi.ai/documentation/swiftui/view/modelcontainer`. The `recommended` permalink (a real
macOS app's body) is the canonical ✅ to cite in a finding's `## Source` — fetch its enclosing body with
`swiftui-ctx file <recommended.id> --smart`. For an **explicit** configured container:

```swift
// let container = try! ModelContainer(
//     for: Item.self,
//     configurations: ModelConfiguration(isStoredInMemoryOnly: true))   // ModelContainer.init(for:configurations:) is macOS 15.0+ — see floors-master
```

Seed sample rows into the container's `mainContext` when the view should render non-empty. On macOS 15+
prefer a shared `PreviewModifier` over rebuilding inline (prev-09 — `preview-modifier-shared.md`).

## prev-07 — environment-dependent view with no injected dependency

`#Preview { DetailView() }` where `DetailView` reads `@Environment(AppModel.self)` shows nothing or
crashes — previews do not inherit the app's scene environment, so any required `@Environment` / injected
`@Observable` must be supplied in the preview body. Provide a mock/sample. (Seam: the *sample factory* —
where `AppModel.preview` lives — is `audit-swiftui-state-observation`'s; `cross_ref` it.)

```swift
// ❌ required @Environment(AppModel.self) never provided
#Preview {
    DetailView()                                     // empty / crashes: no AppModel in environment
}
```
```swift
// ✅ inject a sample @Observable by type (macOS 14+)
#Preview {
    DetailView()
        .environment(AppModel.preview)               // sample/mock @Observable
}
```

This is the type-keyed `.environment(_:)` injection — **not** legacy `.environmentObject(_:)`, which only
takes an `ObservableObject` (that mismatch is prev-08 — see `entry-and-environment.md`).
**swiftui-ctx grounding:** `swiftui-ctx lookup environment --json` → `consensus` `(_)` 56% / `(_, _)` 44%;
the highest-authority `recommended` example is `.environment(appState)` at `min_macos: 26`
(`sindresorhus/Gifski`), confirming `.environment(_:)` as the live macOS injector.
`introduced_macos: 10.15`, `doc: https://sosumi.ai/documentation/swiftui/view/environment`.

## VERIFY / FIX

Run `swiftui-ctx lookup modelContainer --json` and `swiftui-ctx lookup environment --json` for the
consensus shape + `recommended` permalink; cross-check the floor on Sosumi
(`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`). The ✅ in `## Correct` is the consensus
shape backed by `swiftui-ctx file <recommended.id> --smart`; its GitHub permalink + the Sosumi `doc:` go
in `## Source`. Every fix is `flag-only` (per the fix-safety protocol).

## Sources

- **Apple — SwiftData / `.modelContainer(for:inMemory:)`.** `@Model`, `ModelContainer`, `ModelConfiguration`, `@Query`, `.modelContainer(for:inMemory:)` confirmed; SwiftData is `macOS 14.0+`. https://developer.apple.com/documentation/swiftdata — accessed 2026-06-07. View modifier: https://developer.apple.com/documentation/swiftui/view/modelcontainer(for:inmemory:onsetup:) — accessed 2026-06-07.
- **Apple — `environment(_:)` (type-keyed Observable injection).** The modern injector for an `@Observable`; supersedes `.environmentObject(_:)` for `Observable` types. https://developer.apple.com/documentation/swiftui/view/environment(_:) — accessed 2026-06-07.
- **swiftlang/swift issue #66537** — SwiftData preview crashes without an in-memory container; corroborates the canvas-trap symptom (also r/swift "SwiftData Crashes in Preview"). https://github.com/swiftlang/swift/issues/66537 — accessed 2026-06-07.
- **Real macOS example (swiftui-ctx `recommended`):** `.environment(appState)` in `sindresorhus/Gifski` — https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/App.swift#L15 — accessed 2026-06-07.
