# Shared Reference — Cross-Ref Graph & Seam-Ownership Verdicts

The single source for cross-skill seams: the 129-seam directed `cross_ref` graph (which skill names
which sibling, and why) plus the seam-ownership verdicts that decide, when two skills detect the same
`file:line`, who keeps the primary finding and who is demoted to a `cross_ref`. **Both** the
orchestrator's dedup pass **and** each skill's `cross_ref` emission derive from this one file, so the
two cannot drift. Do not restate seam ownership inside a skill's own `references/`.

**As of:** 2026-06-07. Slugs below are the `audit-swiftui-<suffix>` skills (suffix shown).

---

## 1. Seam-ownership resolution table (who is primary on a collision)

When the same site is detected by two domains, the **primary** keeps a top-level finding; the
**sibling** is demoted (`status: duplicate-of <primary rule_id>`, excluded from `_SUMMARY.md`'s master
table, kept on disk). `keep-both` = an intentional double-detection; both stay, cross-linked.

| Collision site | Primary (kept) | Sibling (demoted → cross_ref) | Rule |
|---|---|---|---|
| `Task` in `.onAppear` capturing non-Sendable state | `async-data` (lifecycle fix) | `concurrency-safety` (isolation angle) | async-data owns lifecycle; concurrency only if an isolation hazard is present. |
| `.foregroundColor(_:)` deprecated | `api-currency` (the flag) | `appearance-color` (positive craft) | currency owns the deprecation flag; appearance owns the replacement craft. |
| `Text + Text` (`+`) deprecated | `api-currency` (the flag) | `typography-text` (`AttributedString` craft) | currency flags; typography owns positive craft. |
| `Font.system(_:design:)` deprecated | `api-currency` (the flag) | `typography-text` (craft) | same three-way split. |
| `MagnificationGesture` / `RotationGesture` deprecated | `api-currency` (the flag) | `pointer-gestures` (replacement mechanics) | currency flags; pointer-gestures owns the mechanics. |
| `NavigationView` | `api-currency` (the flag) | `navigation-toolbars` (structural migration) | currency flags currency; nav owns the structural fix. |
| glass gating (`#available(macOS 26`) | `liquid-glass` (deep glass gating) | `availability-gating` (blanket net) | liquid-glass owns glass gating in depth; gating is the catch-all. |
| any domain's missed gate | the domain skill (owns its gating in depth) | `availability-gating` (blanket net) | each domain owns its gating; availability-gating catches the misses. |
| `controlSize` sizing axis | `layout-and-tables` | `controls-forms` (only inside a `Table`/inspector) | sizing axis = layout; style variants = controls-forms. |
| `.buttonStyle`/`.pickerStyle`/`.formStyle(.grouped)` density | `controls-forms` | `layout-and-tables` (only inside a `Table`/inspector) | style variants = controls-forms. |
| window sizing — content frame (`.frame(min/ideal/max)`) | `layout-and-tables` | `scenes-windows` (companion note) | two-layer split; content-frame layer = layout. |
| window sizing — scene (`.defaultSize`/`.windowResizability`) | `scenes-windows` | `layout-and-tables` (companion note) | scene-modifier layer = scenes-windows. |
| SwiftData off-context `@Model` mutation | `swiftdata` (prescribes `@ModelActor`) | `concurrency-safety` (flags + routes) | concurrency flags the race; swiftdata prescribes the fix shape. |
| `loadTransferable` Sendable race | `concurrency-safety` (isolation) | `sandbox-files` (consent/bookmark) | sendable correctness = concurrency; file consent = sandbox-files. |
| `NSOpenPanel`/`NSSavePanel` | `appkit-overuse` (whether to bridge) | `sandbox-files` (consent once `fileImporter`) | whether = overuse; bookmark correctness = sandbox-files. |
| any AppKit bridge | `appkit-overuse` (WHETHER it should exist) | `appkit-interop` (HOW it's implemented) | bidirectional handshake; overuse=whether, interop=how. |
| SwiftData preview container injection | `previews` (preview mechanics) | `swiftdata` (model design routes) | preview-construction = previews; model design = swiftdata. |
| `.drawingGroup()` perf | `drawing-canvas` (usage decision) | `view-performance` (cost measurement) | usage = drawing-canvas; cost = view-performance. |
| over-broad `@Observable` observation | `view-performance` (render cost) | `state-observation` (granularity note) | render cost = perf; state-correctness = state-observation. |
| `GeometryReader` wrapping a `Canvas` | `drawing-canvas` (feeds drawing geometry) | `layout-and-tables` (only if doing layout) | drawing geometry = drawing-canvas; layout arrangement = layout. |
| `.repeatForever` motion | `animation-motion` (UX restraint) | `view-performance` (render cost) | UX = animation; cost = perf. |
| Reduce-Motion path | `accessibility` (ignores flag entirely) | `animation-motion` (motion-specific reduced path) | "ignores flag" = a11y; "motion is wrong" = animation. |
| `@FocusState` vs `AccessibilityFocusState` | `controls-forms` (`@FocusState`, keyboard) | `accessibility` (`AccessibilityFocusState`, VoiceOver) | different wrappers; keyboard=controls, VoiceOver=a11y. |
| icon-only control: no `.help` AND no `.accessibilityLabel` | **keep-both**, cross-linked | — | controls-forms files `.help`; accessibility files the label; a11y reuses controls-forms' `.help` text. |
| `Chart`/`Canvas` no a11y descriptor | **keep-both** (`a11y` + `charts`/`drawing-canvas`) | — | intentional double-detection per both plans; cross-link, don't collapse. |
| `Text(verbatim:)` / markdown rendering | `typography-text` (rendering) | `localization` (catalog angle) | type detects+renders; loc is the catalog implication. |

---

## 2. Two context-conditional tiebreakers

- **`@Entry` / `FocusedValueKey`** (previews ↔ menus-commands): if the `FocusedValueKey`/`@Entry`
  pattern is **co-located with a `CommandMenu`/`CommandGroup`** → **menus-commands** owns; if it is in a
  **preview / general environment setup** → **previews** owns.
- **`MenuBarExtra` scene vs contents** (scenes-windows ↔ menus-commands): **item-level** issues *inside*
  a `MenuBarExtra` closure → **menus-commands**; the **scene + activation trap** → **scenes-windows**.

---

## 3. The cross_ref graph (129 directed seams, one row per skill, outgoing)

| Skill | cross_ref targets (seam reason) |
|---|---|
| **accessibility** | controls-forms (`.help`↔`.accessibilityLabel`; `@FocusState`↔`AccessibilityFocusState`) · animation-motion (Reduce-Motion: motion construction theirs, "ignores flag" ours) · appearance-color (Differentiate-Without-Color / contrast) · charts (chart descriptor) · drawing-canvas (Canvas a11y) · liquid-glass (Reduce Transparency) |
| **animation-motion** | accessibility (Reduce-Motion seam) · view-performance (render cost of motion) · pointer-gestures (gesture-driven animation coupling) · liquid-glass (glass morph vs generic `matchedGeometryEffect`) · drawing-canvas (`TimelineView`-as-clock theirs) |
| **api-currency** | availability-gating (floor facts; "is it gated" theirs) · appearance-color (`.foregroundColor`/`.accentColor`/`.cornerRadius` craft) · typography-text (`Text + Text`/`Font.system` craft) · navigation-toolbars (`NavigationView`/`tabItem`/inline `NavigationLink`) · state-observation (1-param `onChange`, `ObservableObject` default) · async-data (`DispatchQueue.main.async`) · pointer-gestures (gesture renames) · sandbox-files (`dropDestination` deprecation) · liquid-glass (hallucinated glass names) |
| **appearance-color** | liquid-glass (glass materials/tint) · api-currency (`.foregroundColor`/`.accentColor` flag shared) · accessibility (Differentiate-Without-Color, WCAG ratios) · drawing-canvas (`.cornerRadius` deprecation) |
| **appkit-interop** | appkit-overuse (HOW↔WHETHER; every finding cross_refs) · concurrency-safety (`@Sendable` race at bridge) · appearance-color (`NSVisualEffectView` material decision) |
| **appkit-overuse** | appkit-interop (the HOW for justified bridges) · scenes-windows (`MenuBarExtra` scene) · sandbox-files (`NSOpenPanel`/`NSItemProvider`) · liquid-glass (`NSGlassEffectView`) · appearance-color (`NSVisualEffectView` vibrancy) · view-performance (`NSOutlineView`/`NSTableView` ceiling) |
| **async-data** | concurrency-safety (isolation of captured loading state) · state-observation (where the model lives) · swiftdata (`@Query` fetches) · controls-forms (`.redacted` on controls) |
| **availability-gating** | api-currency (floor facts) · liquid-glass (deep glass gating theirs) · state-observation, navigation-toolbars, scenes-windows, swiftdata, previews (each owns its gating in depth; this is the net) |
| **charts** | accessibility (chart descriptor) · appearance-color (per-series colors) · drawing-canvas (hand-rolled non-`Chart` drawings) · view-performance (large-dataset scrolling) |
| **concurrency-safety** | async-data (lifecycle `.task` fix) · swiftdata (`@ModelActor` fix shape) · sandbox-files (`Transferable` Sendable seam) · appkit-overuse (Coordinator/`NSViewRepresentable` boundary) · state-observation (`@MainActor` on `@Observable`) |
| **controls-forms** | pointer-gestures (hover/cursor/right-click/drag) · appearance-color (color/material crossover) · accessibility (`.help`↔label) |
| **document-model** | sandbox-files (file IO + security-scoped bookmarks) · appkit-interop (`NSDocument`/`NSDocumentController` bridge) · state-restoration (document window state) · scenes-windows (`DocumentGroup` scene) · api-currency (`FileDocument`/`ReferenceFileDocument` currency) |
| **drawing-canvas** | layout-and-tables (`GeometryReader`-vs-`Layout`) · accessibility (Canvas a11y) · animation-motion (`withAnimation` timing) · charts (Canvas-drawn charts theirs) · view-performance (`.drawingGroup()` rationale) |
| **layout-and-tables** | view-performance (large-Table ceiling) · controls-forms (control styling/density) · navigation-toolbars (`NavigationSplitView` columns theirs) · scenes-windows (scene-modifier side of window sizing) |
| **liquid-glass** | appearance-color (materials, Dark-Mode contrast) · availability-gating (blanket sweep) · animation-motion (glass morph vs generic) |
| **localization** | typography-text (`AttributedString` styling vs loc init) · async-data (date/number `FormatStyle`) · previews (`\.locale`/`\.layoutDirection`) · api-currency (broad deprecated sweep) · layout-and-tables (RTL mirroring) |
| **macos-nativeness** | pointer-gestures · controls-forms · layout-and-tables · navigation-toolbars · menus-commands · scenes-windows · liquid-glass (each: a routed nativeness smell → the owner skill) |
| **menus-commands** | scenes-windows (`MenuBarExtra` scene) · controls-forms (`@FocusState` keyboard focus) · availability-gating (generic gating auto-fix) · navigation-toolbars (toolbar button vs menu action) |
| **navigation-toolbars** | scenes-windows (window sizing/resizability) · menus-commands (`@FocusedValue` routing) · controls-forms (sidebar `List` styling) · liquid-glass (`ToolbarSpacer` glass era) |
| **pointer-gestures** | controls-forms (`.help`/`.focusable`/density) · sandbox-files (`Transferable` drag payloads) · animation-motion (gesture-driven animation) · menus-commands (context-menu semantics, `keyboardShortcut`) · appearance-color (color/material crossover) |
| **previews** | swiftdata (SwiftData model design) · state-observation (`@Observable` sample factory) · menus-commands (`@Entry`-focused-values wiring) · api-currency (macro modernity) |
| **sandbox-files** | concurrency-safety (`loadTransferable` Sendable) · swiftdata (store location, group-container) · appkit-overuse (`NSOpenPanel`/`NSItemProvider` over-bridging) |
| **scenes-windows** | menus-commands (menu contents) · navigation-toolbars (`navigationTitle`-in-`Window` titlebar) |
| **state-observation** | swiftdata (`@Query`) · concurrency-safety (`@Observable` isolation) · view-performance (over-broad observation) · previews (preview injection) · async-data (`onChange` lifecycle) |
| **state-restoration** | state-observation (`@SceneStorage`/`@AppStorage` vs `@State`) · scenes-windows (`NavigationPath`/window restoration) · sandbox-files (security-scoped bookmark persistence) · async-data (`onOpenURL`/`onContinueUserActivity` lifecycle) · document-model (document state restore) |
| **swiftdata** | concurrency-safety (`@ModelActor`/Sendable depth) · previews (preview-construction mechanics) · sandbox-files (store location + group-container) |
| **typography-text** | localization (string externalization, `String(localized:)`) · api-currency (`Text + Text`/`Font.system` flag) · accessibility (Dynamic-Type as a11y) · appkit-interop (rich-text `NSTextView` bridge) |
| **view-performance** | state-observation (over-broad observation) · layout-and-tables (Table/List structure) · animation-motion (animation cost) · liquid-glass (glass API correctness) · appkit-interop (`NSTableView`/`NSTextView` render cost) |

**Total directed cross_ref seams: 129, across all 28 domain skills** (every `audit-swiftui-*` has a row).

> `@FocusedDocument` is **not** a real Apple symbol — use a custom `FocusedValues` key (see
> `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`).

---

## 4. Reciprocity & valid-slug notes

- A `cross_ref` MUST name one of the valid `audit-swiftui-<suffix>` slugs. There is **no**
  `audit-swiftui-version-hallucination` and **no** `audit-swiftui-state-and-data-flow` — the
  availability sweep is `audit-swiftui-availability-gating`; the state skill is
  `audit-swiftui-state-observation`.
- Seams are **directional by design**: `A → B` means "A's finding may overlap B's domain," and reciprocity
  is common but not required (a downstream domain need not point back). Roughly half the 129 seams are
  one-directional; that is expected, not a gap. When a new reciprocal seam is genuinely useful, add the
  one-line note to the owning skill's row — no structural change.

---

## Sources

Internal seam graph derived from the 28 skills' own boundary/seam declarations; cites no external API.
Floor facts, the finding schema, and the Apple-doc fetch path live in sibling `_shared/` files.
