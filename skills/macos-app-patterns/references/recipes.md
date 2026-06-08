# Recipe index

Each recipe = a canonical template + the real APIs it composes + ranked real examples (with permalinks).
Run `swiftui-ctx recipe <name>` for the template + examples; `swiftui-ctx file <id> --smart` to read real code.

| Recipe | Composes (APIs) | What you get |
|---|---|---|
| `menubar-app` | `MenuBarExtra`, `menuBarExtraStyle`, `Settings` | a menu-bar app shell with a Settings window |
| `master-detail` | `NavigationSplitView`, `List`, `navigationDestination` | sidebar + detail navigation (macOS standard) |
| `settings-screen` | `Settings`, `TabView`, `Section` | a multi-pane preferences window |
| `settings-form` | `Form`, `Section`, `Toggle`, `Picker`, `LabeledContent` | a grouped settings form |
| `observable-model` | `Observable`, `State`, `Bindable` | modern Observation state ownership |
| `window-scene` | `WindowGroup`, `windowStyle`, `windowResizability`, `defaultSize` | custom window config |
| `charts-bar` | `Chart`, `BarMark`, `chartXAxis(content:)` | a bar chart with axis config |
| `searchable-list` | `searchable`, `searchScopes` | a searchable list |
| `nsview-bridge` | `NSViewRepresentable` | wrap an AppKit view (Coordinator + make/update) |
| `command-palette` | `searchable`, `keyboardShortcut`, `onKeyPress`, `focused` | a ⌘K command overlay |
| `draggable-reorder` | `onMove`, `draggable`, `dropDestination(for:isEnabled:action:)`, `Transferable` | reorderable rows |
| `cached-async-image` | `AsyncImage` | remote image with placeholder (+ caching note) |

Tips:
- For **nsview-bridge**, read the example with `--full` — bridges (Coordinator + `makeNSView` + `updateNSView`) are
  best understood whole, not as a fragment.
- Recipe examples are filtered to ones that actually use the recipe's APIs (a `charts-bar` example uses `BarMark`).
- After scaffolding, confirm any individual API's current argument shape with `swiftui-ctx lookup <api>`.
