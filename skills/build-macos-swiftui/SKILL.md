---
name: build-macos-swiftui
description: Use skill if you are writing, reviewing, or refactoring SwiftUI for macOS — @Observable state, scenes/windows/menu bar (Settings, MenuBarExtra, .commands), NavigationSplitView sidebars, AppKit (NSViewRepresentable) bridging, Swift 6 concurrency, SwiftData, App Sandbox file access, or macOS-gated Liquid Glass. Triggers include "write a SwiftUI view for Mac", "macOS menu bar app", "Settings window", "Mac sidebar app", "bridge NSTextView/NSView", "state isn't updating", "sandbox file access", "SwiftData crash", "Liquid Glass on macOS". NOT for iOS/iPadOS SwiftUI, visual-only HIG snapshot auditing, codesigning/notarization, a single-API lookup (use swiftui-examples), recipe/template scaffolding (use macos-app-patterns), or a whole-codebase audit (use audit-macos-swiftui-full).
---

# Build macOS SwiftUI

Write correct, current, idiomatic **macOS** SwiftUI. This catalog encodes the mistakes AI makes on the
Mac and the current rule for each. The target is **always macOS**; iOS appears only as a ❌ contrast.
Depth for any topic is one hop away in `references/`.

> **Write-time vs. audit.** This skill (+ its `swiftui-reviewer` agent and the quick
> `scripts/macos-swiftui-lint.sh` — a 67-rule write-time quick-lint) is the **write-time** authoring +
> review path. For a **deep, whole-codebase audit** of a finished project, use the
> **`audit-macos-swiftui-full`** orchestrator and the 28 `audit-swiftui-*` skills (the separate, shared
> 334-rule audit engine `scripts/swiftui-lint.sh` — 282 grep tells + 52 ast-grep — Sosumi + `swiftui-ctx`
> verification, findings written to `swiftui-audits/`). The two are complementary, not rivals.
>
> **Verify APIs against the live catalog.** Before emitting any non-trivial API, run `swiftui-ctx lookup <api>`
> (the `swiftui-examples` skill) for the real consensus shape — `references/api-currency.md` is a curated summary,
> not a substitute for the live corpus.

## When to use / not use

**Use** for SwiftUI *code correctness* on macOS: state & data flow, scenes/windows/menu bar,
navigation/sidebars/toolbars, AppKit bridging, concurrency, layout & tables, controls & pointer
interaction, Liquid Glass, SwiftData, sandbox & file access, previews.

**Not for** (say so and stop — these are other concerns, not this skill's job):
- iOS / iPadOS / visionOS / watchOS SwiftUI.
- Visual HIG judgement or snapshot auditing (typography/spacing/color review).
- Liquid Glass *aesthetic* design choices; app packaging, codesigning, notarization.
- SwiftLint / SwiftFormat configuration.

## Operating contract (non-negotiable)

1. **macOS is the target.** Every snippet must compile on a Mac target. Never emit a UIKit symbol,
   `horizontalSizeClass`, or an iOS-only toolbar placement as the answer.
2. **Trust `references/api-currency.md`, not your prior.** If an API is not there or in Apple docs,
   **say so and offer a safe alternative — do not invent it.** The most *probable* token for an unknown
   API is a plausible hallucination (`.glassBackground()` does not exist).
3. **Gate on the macOS arm.** Above-floor APIs need `#available(macOS 26, *)` / `@available(macOS 14, *)`
   — never gate only on the iOS arm (the single mistake even good artifacts make).
4. **Run the lint before proposing code** (see Detection). Fix every hard-fail.
5. **Output Contract.** Claim only the verification rung you reached:
   (1) read · (2) lint/types · (3) unit · (4) integration · (5) ran/observed · (6) user-confirmed.
   The compile hook (below) is how you legitimately reach rung 2+. Don't imply a higher rung.
6. **No architecture mandate.** Teach plain `@Observable final class` owned at the App level. Do not
   force MVVM/VIPER.

## The Core Catalog — 52 ranked failure modes

Ordered by frequency × impact × macOS-uniqueness. `Sev`: **C**=critical (broken/net-negative),
**H**=high (wrong-but-compiles / non-idiomatic), **M**=med (stale-but-works). `→` is the deep doc.

| # | Symptom (what AI emits) | Correct macOS rule | Sev | → |
|---|---|---|---|---|
| 1 | `NavigationView { … }` for new code | `NavigationStack`, or for a sidebar app `NavigationSplitView` (deprecated through OS 26.5) | C | navigation-and-toolbars.md |
| 2 | Invents `.glassBackground()` / `.liquidGlass()` / `.material(.glass)` / `LiquidGlassView` | Real API: `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` — the rest don't exist | C | liquid-glass.md |
| 3 | macOS-26/14-only API with no `#available`/`@available` gate | Gate every above-floor API on the **macOS arm** (`#available(macOS 26, *)`) | C | version-and-hallucination.md |
| 4 | `@ObservedObject var x = Model()` — view creates what it doesn't own | Owner uses `@State` (`@Observable`) or `@StateObject` (`ObservableObject`); else silent state reset | C | state-and-observation.md |
| 5 | `@Observable` kept as `: ObservableObject` + `@Published` + `@StateObject` | Under `@Observable`: no `@Published`, no conformance, own with `@State` | C | state-and-observation.md |
| 6 | No `Settings {}` scene / no `MenuBarExtra`; menu-bar app faked with `NSStatusItem` | Use the `Settings {}` scene (+ `SettingsLink`) and `MenuBarExtra` — Mac-only primitives | C | scenes-and-windows.md |
| 7 | No `.commands {}`; menu actions faked as in-window buttons | Declare main-menu actions via `.commands { CommandGroup / CommandMenu }` | C | menus-and-commands.md |
| 8 | SwiftData `let` on a bidirectional relationship | Use `var`; `let` compiles but crashes at runtime | C | swiftdata.md |
| 9 | Non-`Sendable` class crossing a `@MainActor`→background `Task` boundary | Swift 6 = strict data-race checking by default (error): make it `Sendable` / actor-isolate / stay on-actor | C | concurrency.md |
| 10 | `NSViewRepresentable` with no `updateNSView` | Implement `updateNSView` or SwiftUI state never reaches the AppKit view | C | appkit-interop.md |
| 11 | Sidebar/document app wrapped in `NavigationStack` | macOS sidebar IA wants `NavigationSplitView` (2–3 columns) | H | navigation-and-toolbars.md |
| 12 | `.foregroundColor(_:)` | Deprecated → `.foregroundStyle(_:)` | H | version-and-hallucination.md |
| 13 | Single-param `.onChange(of:) { newValue in }` | Two-param `{ old, new in }` (+ optional `initial:`) | H | version-and-hallucination.md |
| 14 | `DispatchQueue.main.async` in async/SwiftUI code | `@MainActor` / `await MainActor.run` — GCD bypasses isolation checking | H | concurrency.md |
| 15 | `$obs.prop` on a non-owned `@Observable` with no `@Bindable` | Re-wrap with `@Bindable` to project `$` | H | state-and-observation.md |
| 16 | Arbitrary file paths in a sandboxed Mac app (no consent) | `fileImporter`/`NSOpenPanel` grant; raw paths silently fail | C | sandbox-and-files.md |
| 17 | Re-opening a user-picked file next launch with no bookmark | Persist `bookmarkData(.withSecurityScope)` + `start/stopAccessingSecurityScopedResource()` | H | sandbox-and-files.md |
| 18 | Single-column `List` of struct fields where macOS wants a `Table` | `Table` + `TableColumn` + `sortOrder:` (sortable clickable headers) | H | layout-and-tables.md |
| 19 | Menu command can't reach the active window's state | Route via `@FocusedValue`; `.disabled(focusedValue == nil)` | H | menus-and-commands.md |
| 20 | Glass effect on content (lists/cards/backgrounds) | Liquid Glass is **navigation-layer-only** — never on content | H | liquid-glass.md |
| 21 | bare `Task {}` in `.onAppear` for view-lifecycle async | `.task {}` / `.task(id:)` — auto-cancelled on disappear | H | concurrency.md |
| 22 | `WindowGroup`/`Window` with no `.defaultSize`/`.windowResizability`/root `minWidth` | Size scenes explicitly | H | scenes-and-windows.md |
| 23 | `openWindow`/`openSettings` from a `MenuBarExtra` with no `NSApp.activate` | Activate the app or the window opens with no front window (the multi-hour trap) | H | scenes-and-windows.md |
| 24 | `@Sendable` closure body touches `self.`/a main-actor property | Isolate the closure `@MainActor` or capture-by-value for reads | H | concurrency.md |
| 25 | Custom interactive Mac view with no `.onHover` / no `.help` | Add pointer affordances — Mac is not touch | H | controls-and-pointer.md |
| 26 | Row/item views with no right-click `.contextMenu` | Mac users expect right-click menus | H | controls-and-pointer.md |
| 27 | SwiftData relationship assigned inside `init` | Assign after inserting into the context, not in `init` (data vanishes on relaunch) | H | swiftdata.md |
| 28 | `#Preview` of a SwiftData/`@Query` view with no in-memory container | `.modelContainer(for: …, inMemory: true)` or the canvas crashes | H | previews.md |
| 29 | Splitting an `@Observable`-reading view into computed `var x: some View` | Extract into separate `View` **types** — computed props lose per-property invalidation | H | state-and-observation.md |
| 30 | `placement: .navigationBarLeading/.navigationBarTrailing` on macOS | iOS-only → `.primaryAction`/`.principal`/`.navigation` | H | navigation-and-toolbars.md |
| 31 | `.navigationBarTitle` / `navigationBarTitleDisplayMode` | iOS-only → `.navigationTitle` | M | navigation-and-toolbars.md |
| 32 | `@EnvironmentObject` for an injected `@Observable` dependency | `.environment(instance)` + `@Environment(Type.self)` | H | state-and-observation.md |
| 33 | `.cornerRadius(_:)` | Deprecated → `.clipShape(.rect(cornerRadius:))` | M | version-and-hallucination.md |
| 34 | Old `tabItem {}` / inline-destination `NavigationLink` in lists | `Tab(...) {}` and value-based `.navigationDestination(for:)` | M | version-and-hallucination.md |
| 35 | Copying Apple's `fatalError`-on-`ModelContainer` / `@Model` with no `init` | Handle container failure gracefully; supply a real initializer | H | swiftdata.md |
| 36 | `loadTransferable`/drag-drop that compiled pre-Swift-6 now errors | Make `Transferable` conformances/closures `Sendable`-correct; `.draggable`/`.dropDestination` | H | sandbox-and-files.md |
| 37 | App Sandbox on but file/network entitlements off | Declare matching `.entitlements` keys; sandbox-on + capability-off silently denies | H | sandbox-and-files.md |
| 38 | `PreviewProvider` struct + hand-rolled `EnvironmentKey` boilerplate | `#Preview { }`, `@Previewable @State`, one-line `@Entry var` | M | previews.md |
| 39 | Blanket `@MainActor` spam OR assuming main-actor-by-default is automatic | It's an **opt-in** Swift 6.2 build mode (`-default-isolation MainActor`), not the language default | M | concurrency.md |
| 40 | `Form {}` with no `.formStyle(.grouped)`; wrong `listStyle`/`controlSize` density | `.formStyle(.grouped)`, `.listStyle(.sidebar)`, `.controlSize` for Mac density | M | controls-and-pointer.md |
| 41 | `becomeFirstResponder()` on a SwiftUI value / `NSView` missing `acceptsFirstResponder` | First-responder goes through AppKit, or SwiftUI `@FocusState`/`.focusable()` | H | appkit-interop.md |
| 42 | `@Model` relationship arrays treated as ordered; off-thread mutation | Sort explicitly (`@Query(sort:)`/`SortDescriptor`); mutate on the context's actor (`@ModelActor`) | H | swiftdata.md |
| 43 | Glass-on-glass / sibling glass with no `GlassEffectContainer` | Never nest glass; group siblings in a `GlassEffectContainer` (glass can't sample glass) | M | liquid-glass.md |
| 44 | Representable with `@Binding` but no `makeCoordinator()`/delegate wiring | Add a `Coordinator` + `delegate = context.coordinator` | H | appkit-interop.md |
| 45 | Mutating SwiftData but never saving; relying on auto-save | `try modelContext.save()` at meaningful boundaries — auto-save is unreliable | H | swiftdata.md |
| 46 | `NSGlassEffectView` glass turns opaque when its window isn't key (no `.state` fix) | AppKit glass has no active-state API; for translucent non-key/HUD overlays fall back to `NSVisualEffectView` | C | appkit-liquid-glass.md |
| 47 | `@main App` with only `WindowGroup` — won't quit on last window close, no global `NSApp` setup | Add `@NSApplicationDelegateAdaptor`; `applicationShouldTerminateAfterLastWindowClosed { true }` | H | scenes-and-windows.md |
| 48 | `.ultraThinMaterial` sidebar looks flat (no real vibrancy) | Window-scoped material ≠ behind-window vibrancy; wrap `NSVisualEffectView(material: .sidebar, blendingMode: .behindWindow)` | H | appkit-interop.md |
| 49 | Heavy work in `body`/`init`, `.id(UUID())`, `AnyView`, filter-in-`ForEach` | Hoist formatters; stable ids; `@ViewBuilder` not `AnyView`; derive collections upstream | H | view-performance.md |
| 50 | `openWindow(id:)` silently does nothing | The `id` must match a `Window(id:)`/`WindowGroup(id:)` exactly (shared constant); test at runtime | M | scenes-and-windows.md |
| 51 | MenuBarExtra→`openSettings`/`openWindow` one-liner shows no window on **macOS 26** | The `NSApp.activate()`+`openSettings()` fix regressed on Tahoe — needs a hidden `Window` scene + `setActivationPolicy(.regular)` toggle | H | scenes-and-windows.md |
| 52 | `Text("a") + Text("b")` (the `Text` `+` operator) | Deprecated macOS 26.0 → string interpolation `Text("a \(b)")` | M | version-and-hallucination.md |

## Currency cliffs (dated wrong → right)

The era-boundaries where a pre-2024 prior is stale. Full detail + availability strings in
`references/api-currency.md`.

| Era boundary | Wrong (stale default) | Right (current) | macOS floor |
|---|---|---|---|
| NavigationView deprecation (2022) | `NavigationView {}` | `NavigationStack` / `NavigationSplitView` | macOS 13 |
| `@Observable` macro (2023) | `class VM: ObservableObject { @Published }` + `@StateObject` | `@Observable class VM` + `@State`/`@Bindable`/`@Environment(Type.self)` | macOS 14 |
| Two-param `onChange` (2023) | `.onChange(of:) { newValue in }` | `.onChange(of:, initial:) { old, new in }` | macOS 14 |
| `#Preview`/`@Previewable`/`@Entry` (2023–24) | `PreviewProvider` + manual `EnvironmentKey` | `#Preview { @Previewable @State }`, `@Entry var` | macOS 14 |
| Style deprecations (rolling) | `.foregroundColor`, `.cornerRadius`, `tabItem` | `.foregroundStyle`, `.clipShape(.rect(cornerRadius:))` | macOS 12 |
| `tabItem` → `Tab(){}` | `tabItem {}` / `TabView` without `Tab` | `Tab("Label", systemImage:) {}` inside `TabView` | macOS 15 |
| Swift 6 strict concurrency (2024) | non-`Sendable` across actors; `DispatchQueue.main.async` | `Sendable`-correct, `@MainActor`, `.task` | toolchain |
| Swift 6.2 approachable concurrency (2025) | assume main-actor-by-default everywhere | opt-in `-default-isolation MainActor` build mode | toolchain 6.2 |
| Liquid Glass (2025) | `.glassBackground()` / `.liquidGlass()` (invented) | `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` — `#available(macOS 26)` | macOS 26 |
| `Settings {}` scene | `NSApp.sendAction(showSettingsWindow:)` / `Preferences {}` | `Settings {}` scene | macOS 11 |
| `SettingsLink` | manual `NSApp.sendAction(showSettingsWindow:)` | `SettingsLink` (requires `Settings {}` scene) | macOS 14 |

## macOS-only primitives AI forgets exist

These have **no iOS analogue**, so an iOS-trained model never reaches for them (it doesn't get them
wrong — it omits them). Reaching for these is what makes code feel native.

- **Scenes & windows** — `Settings {}` + `SettingsLink`; `MenuBarExtra`; `Window` (single-instance) vs
  `WindowGroup`; `.defaultSize`/`.windowResizability`/`.windowStyle`; `openWindow`/`openSettings`/`dismissWindow`. → scenes-and-windows.md
- **Menu bar & commands** — `.commands {}`, `CommandGroup(replacing:/after:)`, `CommandMenu`,
  `SidebarCommands()`, app-global `.keyboardShortcut` on menu items, `@FocusedValue` routing. → menus-and-commands.md
- **Pointer affordances** — `.onHover`, right-click `.contextMenu`, `.help()` tooltips. → controls-and-pointer.md
- **First responder & focus** — AppKit `acceptsFirstResponder`/`makeFirstResponder`, SwiftUI
  `.focusable()`/`@FocusState`. → appkit-interop.md
- **AppKit interop** — `NSViewRepresentable`/`NSViewControllerRepresentable` (+ `updateNSView`/
  `Coordinator`/`dismantleNSView`), the `NSHostingController`/`NSHostingView` reverse bridge. → appkit-interop.md
- **Data-dense controls** — `Table`/`TableColumn` with sortable, multi-column, clickable headers;
  `.formStyle(.grouped)`, `.controlSize`, `HSplitView`. → layout-and-tables.md
- **Navigation IA** — `NavigationSplitView` 2–3-column sidebar (the *default* Mac shell); `columnVisibility`. → navigation-and-toolbars.md
- **App Sandbox & file access** — entitlements; security-scoped bookmarks; `fileImporter`/`NSOpenPanel` consent. → sandbox-and-files.md
- **Liquid Glass (macOS 26)** — `glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass/.glassProminent)`,
  `glassEffectID`/`glassEffectUnion`. → liquid-glass.md
- **AppKit Liquid Glass** — `NSGlassEffectView`/`NSGlassEffectContainerView`/`NSBackgroundExtensionView`/
  `NSView.LayoutRegion`/`prefersCompactControlSizeMetrics`; the inactive-window opacity trap. → appkit-liquid-glass.md

## Per-domain rules + router

Load the named reference when you touch that area. Each block lists the always-true rules; the doc has
the ❌/✅ code.

**State & observation** — `@Observable final class` for reference models; **own** with `@State`, bind a
non-owned one with `@Bindable`, inject by type via `.environment(x)` + `@Environment(T.self)`. No
`@Published`/`ObservableObject`/`@StateObject` for new code. Never `@ObservedObject var x = T()`. Split
big views into `View` **types**, not computed `var`s. → `references/state-and-observation.md`

**Version drift & hallucination** — Cross-check every API against `references/api-currency.md`. Bans:
`NavigationView`, `.foregroundColor`, `.cornerRadius`, single-param `onChange`, `tabItem`. Never emit
an API you can't cite; gate new APIs on the **macOS** arm. → `references/version-and-hallucination.md`

**Scenes & windows** — `WindowGroup`/`Window`/`Settings {}`/`MenuBarExtra` are the scene vocabulary.
Open via `openWindow`/`openSettings`; from a `MenuBarExtra`, also `NSApp.activate`. Always set
`.defaultSize`/`.windowResizability`. → `references/scenes-and-windows.md`

**Menus & commands** — Real Mac chrome uses `.commands {}` with `CommandMenu`/`CommandGroup(replacing:/
after:/before:)`; wire actions to the focused window via `@FocusedValue`; `.keyboardShortcut` belongs on
menu items. → `references/menus-and-commands.md`

**AppKit interop** — `NSViewRepresentable` needs `makeNSView`/`updateNSView`/`makeCoordinator` and
`dismantleNSView` for teardown; delegates round-trip through the `Coordinator`; first responder is
window-scoped. Watch the Swift-6 Sendable-closure boundary. → `references/appkit-interop.md`

**Navigation, sidebars & toolbars** — `NavigationSplitView` (2-col `init(sidebar:detail:)` / 3-col
`init(sidebar:content:detail:)`), `columnVisibility`, sidebar `.listStyle(.sidebar)`. Toolbar
placements `.primaryAction`/`.principal`/`.navigation`; `.navigationTitle`. → `references/navigation-and-toolbars.md`

**Concurrency** — Swift 6 default = strict data-race **checking**; main-actor-by-default is an **opt-in**
6.2 build mode. `.task`/`.task(id:)` not `Task {}` in lifecycle; no `DispatchQueue.main.async`; make
cross-actor types `Sendable`. → `references/concurrency.md`

**Layout & tables** — Resizable windows: `.frame(minWidth:idealWidth:maxWidth:…)` + scene
`.defaultSize`/`.windowResizability`. Multi-field rows → `Table` + `TableColumn` + `sortOrder:`.
`.controlSize` for density. → `references/layout-and-tables.md`

**Controls & pointer** — `.formStyle(.grouped)`; `.onHover`; right-click `.contextMenu`; `.focusable()`
+ `@FocusState`; `.help()` tooltips. Mac is pointer-driven, not touch. → `references/controls-and-pointer.md`

**Liquid Glass (macOS 26)** — Real names only (`glassEffect(_:in:)`, `GlassEffectContainer`,
`.buttonStyle(.glass/.glassProminent)`). Glass on the **navigation layer only**, never content, never
glass-on-glass; group siblings in `GlassEffectContainer`; gate `#available(macOS 26, *)` with an
`.ultraThinMaterial` fallback. `Glass.interactive()` is macOS 26 too (pointer-driven, not iOS-only). → `references/liquid-glass.md`

**SwiftData** — `var` (never `let`) relationships; assign relationships after insert, not in `init`;
in-memory container for previews; handle `ModelContainer` errors (no `fatalError`); explicit
`try modelContext.save()`. → `references/swiftdata.md`

**App Sandbox & files** — Holding a URL ≠ being allowed to open it. `fileImporter`/`NSOpenPanel`
consent; security-scoped bookmarks for re-access; declare entitlements; `Transferable`/`.dropDestination`
(Sendable-correct) for drag-drop; no `UIPasteboard`. → `references/sandbox-and-files.md`

**Previews** — `#Preview {}` not `PreviewProvider`; `@Previewable @State` inside previews; `@Entry`
for environment values; in-memory container for SwiftData previews; inject `@Environment` models.
→ `references/previews.md`

**AppKit Liquid Glass (macOS 26)** — the AppKit glass surface: `NSGlassEffectView` (+ the
inactive/non-key-window opacity trap — no `.state` fix), `NSGlassEffectContainerView` (children set
their own `cornerRadius`), `NSBackgroundExtensionView`, `NSView.LayoutRegion` corner-avoidance,
`prefersCompactControlSizeMetrics`. → `references/appkit-liquid-glass.md`

**View rendering performance** — avoid heavy work in `body`/`init`, `.id(UUID())`, `AnyView`, and
filter/sort inside `ForEach`; know the SwiftUI `Table` large-dataset ceiling (fall back to
`NSTableView`); Intel-Mac glass cost. → `references/view-performance.md`

## Detection

Before proposing code, run the grep lint and fix every hard-fail:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/macos-swiftui-lint.sh <files-or-dir>`. The full 67-rule list
(WRONG → correct, mapped to each doc) is `references/lint-checklist.md`.

## Verification & enforcement

This skill ships a closed loop — use it to legitimately claim rung 2+ of the Output Contract:
- **Lint** (`scripts/macos-swiftui-lint.sh`) — fast grep self-check; hard-fails exit non-zero.
- **Compile hook** — a `PostToolUse` hook (`hooks/hooks.json` → `swiftui-build-check.sh`) builds the
  enclosing project for the **macOS** destination after each Swift edit and **blocks on compile errors**.
  It needs Xcode + the macOS 26 SDK and a real Xcode/SwiftPM project; it no-ops elsewhere.
- **Reviewer** — the `swiftui-reviewer` subagent audits a diff against this catalog and reports
  `FILE / RULE / LINE / VIOLATION / FIX`. Invoke it before declaring a change done.

State the verification rung you actually reached. "Compiles" requires the hook/build to have run green.

## Guardrails / non-goals

- macOS only. If the user wants iOS/iPadOS, say this skill is macOS-scoped and stop.
- Don't invent APIs. Unverified → mark "verify against your Xcode 26 SDK" (see `api-currency.md`).
- Don't enforce an app architecture. Teach data flow, not layering.
- Out of scope: visual HIG auditing, Liquid Glass aesthetics, packaging/codesigning/notarization,
  lint/format config. Don't attempt them — say so.

## Reference index

| File | Read when |
|---|---|
| `references/api-currency.md` | Any concrete API — the real-vs-deprecated-vs-hallucinated ground truth |
| `references/state-and-observation.md` | @Observable / @State / @Bindable / @Environment, ownership, re-render bugs |
| `references/version-and-hallucination.md` | Deprecations, hallucinated modifiers, `#available(macOS)` gating |
| `references/scenes-and-windows.md` | WindowGroup / Window / Settings / MenuBarExtra, openWindow, activation trap |
| `references/menus-and-commands.md` | `.commands`, CommandGroup/CommandMenu, @FocusedValue, keyboard shortcuts |
| `references/appkit-interop.md` | NSViewRepresentable, Coordinator, first responder, NSHostingController |
| `references/navigation-and-toolbars.md` | NavigationSplitView sidebars, columnVisibility, toolbar placements |
| `references/concurrency.md` | Swift 6 / 6.2, @MainActor, Sendable, `.task` vs Task |
| `references/layout-and-tables.md` | Resizable-window sizing, List vs Table, controlSize |
| `references/controls-and-pointer.md` | formStyle, hover, right-click, focusable, help tooltips |
| `references/liquid-glass.md` | macOS 26 glass: real APIs, navigation-layer rule, gating |
| `references/swiftdata.md` | @Model relationships, container, previews, save |
| `references/sandbox-and-files.md` | App Sandbox, entitlements, security-scoped bookmarks, drag-drop |
| `references/previews.md` | #Preview / @Previewable / @Entry, SwiftData/env preview crashes |
| `references/appkit-liquid-glass.md` | The AppKit glass surface (NSGlassEffectView…) + the inactive-window trap |
| `references/view-performance.md` | Rendering anti-patterns, Table large-dataset ceiling, Intel-Mac glass cost |
| `references/lint-checklist.md` | The 67 grep tells (mirrors the lint script) |
