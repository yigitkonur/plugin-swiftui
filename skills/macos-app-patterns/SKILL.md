---
name: macos-app-patterns
description: Use when asked to "build", "add", "scaffold", or "set up" a whole macOS SwiftUI feature — menu-bar apps, settings/preferences screens, sidebar master-detail, NSView/AppKit bridges, Swift Charts, command palettes, drag-to-reorder, cached async images — or when you need the multi-API recipe (not a single call). Scaffolds these from real production patterns via the swiftui-ctx CLI (recipe + file). Do NOT use for a single API lookup (use swiftui-examples), fixing deprecated code (use swiftui-modernize), or auditing a finished codebase (use audit-macos-swiftui-full).
license: MIT
---

# macos-app-patterns — scaffold from real recipes

For **building a whole feature**, not one call. Each recipe is a canonical template plus real examples from shipping
macOS apps, served by `swiftui-ctx`. (One API → `swiftui-examples`. Deprecated cleanup → `swiftui-modernize`.)

`swiftui-ctx` = `${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx` (or `swiftui-ctx` on PATH). It self-builds + self-locates the catalog.

## The rule
Don't reconstruct a macOS pattern from memory (menu-bar lifecycle, Settings scene, NSViewRepresentable wiring are
exactly where memory fails). Pull the recipe, then open a real example. Announce: *"Using macos-app-patterns."*

## Workflow
1. `swiftui-ctx recipes` — list the patterns (or go straight to the one you need).
2. `swiftui-ctx recipe <name>` — the template skeleton + the APIs + real examples.
3. `swiftui-ctx file <example.id> --smart` (or the printed `file <permalink>`) — read the real, compilable code.
4. Adapt the template to the task; verify each API's current shape with `swiftui-ctx lookup <api>` if unsure.

## Recipes (and when to use each)
| Recipe | Use for |
|---|---|
| `menubar-app` | a status-bar/menu-bar app with a Settings window (`MenuBarExtra` + `Settings`) |
| `settings-screen` / `settings-form` | a preferences window (TabView of panes) / a grouped `Form` of controls |
| `master-detail` | sidebar + detail (`NavigationSplitView`) — the macOS standard |
| `window-scene` | custom window config (hidden title bar, fixed size, level) |
| `observable-model` | modern state: `@Observable` model owned by a view |
| `nsview-bridge` | wrap an AppKit `NSView`/`NSViewController` (the hardest thing to get right) |
| `charts-bar` | a Swift Charts bar chart with axes |
| `searchable-list` | a list with a search field (+ scopes) |
| `command-palette` | a ⌘K quick-open/command overlay |
| `draggable-reorder` | reorderable rows (`onMove` / `draggable`+`dropDestination(for:isEnabled:action:)`) |
| `cached-async-image` | remote image with placeholder (+ caching note) |

Full index with the APIs each pulls in → `references/recipes.md`.

## Errors → actions
`3` not-found (bad recipe name) → `swiftui-ctx recipes` to list them. `5` no catalog → STOP, tell the user, don't fabricate.

## References
| File | Read when |
|---|---|
| `references/recipes.md` | You want the recipe index with the APIs each one composes. |
