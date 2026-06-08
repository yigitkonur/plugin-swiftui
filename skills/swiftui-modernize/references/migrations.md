# Common deprecated → modern macOS SwiftUI migrations

Confirm each against the live tool: `swiftui-ctx deprecated <api>` (gives the replacement + a note), then
`swiftui-ctx lookup <replacement>` for the real, current call shape. This table is the fast path; the CLI is truth.

| Deprecated | Use instead | Notes |
|---|---|---|
| `.foregroundColor(_:)` | `.foregroundStyle(_:)` | takes any `ShapeStyle` (colors, gradients, hierarchical) |
| `NavigationView` | `NavigationStack` / `NavigationSplitView` | Stack = single column; SplitView = sidebar+detail (the macOS standard) |
| `.navigationBarTitle(_:)` | `.navigationTitle(_:)` | — |
| `.navigationBarItems(...)` | `.toolbar { ... }` | use `ToolbarItem`/`ToolbarItemGroup` with placements |
| `.tabItem { ... }` | `Tab(_:systemImage:)` | inside `TabView(selection:)` (newer API) |
| `Alert(...)` / `.alert(isPresented:content:)` | `.alert(_:isPresented:)` | message/actions builder form |
| `.actionSheet(...)` | `.confirmationDialog(_:isPresented:)` | — |
| `.edgesIgnoringSafeArea(_:)` | `.ignoresSafeArea(_:edges:)` | — |
| `.disableAutocorrection(_:)` | `.autocorrectionDisabled(_:)` | — |
| `.accentColor(_:)` | `.tint(_:)` | — |
| `presentationMode` (`@Environment`) | `@Environment(\.dismiss)` + `\.isPresented` | call `dismiss()` |
| `.autocapitalization(_:)` | `.textInputAutocapitalization(_:)` | iOS-side; rare on macOS |

State-management modernization (not "deprecated" but stale):
- `class VM: ObservableObject { @Published … }` + `@StateObject`/`@ObservedObject` → `@Observable final class VM { … }`
  + `@State private var vm = VM()` (pass with `@Bindable` where a binding is needed). See `macos-app-patterns` recipe `observable-model`.

Always verify the replacement is available on the project's deployment target (the `doc:` sosumi link shows availability).
