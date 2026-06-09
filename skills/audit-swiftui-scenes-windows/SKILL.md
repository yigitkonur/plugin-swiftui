---
name: audit-swiftui-scenes-windows
description: Audits a finished or in-progress macOS SwiftUI codebase for scene-composition and window defects at App.body level and writes per-finding Markdown to swiftui-audits/. Use when a menu-bar Settings or window opens behind everything or not at all, when Preferences live in the main window instead of the Settings scene, when a second window is faked with a sheet or a State boolean, when a menu-bar app uses NSStatusItem instead of MenuBarExtra, when openWindow(id:) silently does nothing, when an app never quits after the last window closes, or when asked to verify MenuBarExtra, Settings, WindowGroup, Window, UtilityWindow, openWindow, openSettings, dismissWindow, SettingsLink, windowResizability, or NSApplicationDelegateAdaptor on a Mac target. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for menu/command CONTENTS inside a MenuBarExtra closure (audit-swiftui-menus-commands), not for content-frame window sizing (audit-swiftui-layout-and-tables), not for DocumentGroup modeling, not for writing new scenes from scratch.
---

# Audit SwiftUI Scenes & Windows

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, flag — every way the **scene graph at `App.body` level** goes
wrong on the Mac: the iOS one-window mental model, Preferences crammed into the main window instead of
the `Settings {}` scene, auxiliary windows faked with a sheet or a `@State` bool, a menu-bar app faked
with AppKit `NSStatusItem`, the headline `MenuBarExtra → openWindow/openSettings` **activation trap**,
`openWindow(id:)` typos that no-op silently, and a `WindowGroup`-only `App` with no lifecycle bridge.
Findings are written to disk in the toolkit's unified schema. This is never a from-scratch scene generator.

This domain is **almost entirely macOS-divergent** — `MenuBarExtra` and `Settings {}` have *no iOS
analog*; the `Window` (single, unique) vs `WindowGroup` (user-duplicable, ⌘N) split barely matters on
iOS but is fundamental on the Mac. The scene-composition APIs live at **`App.body` level**, a spot iOS
tutorials rarely exercise, so the model has thin priors there. Be suspicious wherever AI wrote scenes.

## Boundary / seam note (stay in lane)

- **Menu/command CONTENTS inside a `MenuBarExtra { … }` closure** (the buttons, `Divider`s, item
  shortcuts) belong to `audit-swiftui-menus-commands`. **This skill owns the scene + the activation
  trap**; an item-level issue inside the closure is `cross_ref: audit-swiftui-menus-commands`. (Tiebreaker:
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` §2.)
- **Window sizing is a two-layer split.** The **scene-modifier layer** (`.defaultSize`,
  `.windowResizability`, `.windowIdealSize`, `.windowManagerRole`) is **ours** (sw-08). The **content
  frame** (`.frame(min/ideal/max…)` on the root view) is `audit-swiftui-layout-and-tables`; emit a
  companion `cross_ref` when both apply.
- **`navigationTitle` *inside a `Window` scene*** replacing the titlebar (sw-13) is owned here as the
  scene-side gotcha; the structural `navigationTitle`/toolbar migration is `audit-swiftui-navigation-toolbars`.
- **`DocumentGroup` document modeling** (`FileDocument`, `ReferenceFileDocument`, conflict handling) is
  the future `audit-swiftui-document-model`. This skill audits document **scenes** only, not the model.
- **Whether an AppKit bridge should exist at all** is `audit-swiftui-appkit-overuse`; this skill flags
  `NSStatusItem`-instead-of-`MenuBarExtra` (sw-05) as the scene-shaped symptom and cross_refs there.

## The non-negotiable Mac scene rules

1. **Preferences → `Settings {}`, never an in-window link.** Only the `Settings {}` scene wires the
   "Settings…" menu item, the **⌘,** shortcut, and a floating modeless window. A `NavigationLink`/`.sheet`
   gives none of those.
2. **A real second window is a registered *scene* + `openWindow`, never a sheet or a `@State` bool.** The
   scene system owns window lifetime; a boolean cannot create, own, or close a real window.
3. **Menu-bar UI is `MenuBarExtra`, never `NSStatusItem` + `NSMenu`.** The AppKit blob doesn't compose
   with the SwiftUI scene graph.
4. **Opening anything *from* a `MenuBarExtra` requires explicit activation** — and even
   `NSApp.activate()` + `openSettings()` **fails for `.accessory` apps on macOS 26** (the headline trap, sw-06).
5. **Set `.defaultSize` + `.windowResizability` on every Mac scene**, and bridge an
   `@NSApplicationDelegateAdaptor` when the app needs quit-on-last-window / launch / terminate hooks.

The five scene types + the activation trap in full: `references/scene-types-and-settings.md` and
`references/menu-bar-activation-trap.md`.

## Defect index (sw-01 … sw-13)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (silent runtime failure /
never-correct), **warning** (compiles but non-native), **advisory** (judgment / polish). `auto` =
mechanical single-answer; `flag` = show the ✅, dev applies. **Every defect here is `flag-only`** — each
fix depends on the app's *type* (a menu-bar-only app's quit/dismiss/style answers differ from a
document app's), so none is mechanically auto-fixable.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| sw-01 | stale/invented scene API — `Preferences {}`, `showSettingsWindow:`/`showPreferencesWindow:` selector, `@FocusedDocument`, `DocumentGroupLaunchScene` on a Mac arm | hard-fail | flag | `scene-types-and-settings.md` |
| sw-02 | single `WindowGroup` + a `*Settings*`/`*Preferences*` view reached via `NavigationLink`/`.sheet` → missing `Settings {}` scene | warning | flag | `scene-types-and-settings.md` |
| sw-03 | a Settings/Preferences `Form` with **Save/Cancel/Apply** buttons (modal, Windows-style) → HIG violation | warning | flag | `scene-types-and-settings.md` |
| sw-04 | a separate window (inspector / second doc) faked with `.sheet(isPresented:)` or a `@State` bool | warning | flag | `windows-sizing-lifecycle.md` |
| sw-05 | `NSStatusItem` / `NSStatusBar.system.statusItem` / `NSMenu` in a SwiftUI-first app → should be `MenuBarExtra` | warning | flag | `menu-bar-activation-trap.md` |
| sw-06 | `openWindow(`/`openSettings(` inside a `MenuBarExtra { }` with no `NSApp.activate` — **or** a lone `NSApp.activate()`+`openSettings()` for an `.accessory` app on macOS 26 | hard-fail | flag | `menu-bar-activation-trap.md` |
| sw-07 | `SettingsLink` placed **directly inside** a `MenuBarExtra { }` (fails to surface Settings on macOS 26) | warning | flag | `menu-bar-activation-trap.md` |
| sw-08 | a `WindowGroup`/`Window`/`UtilityWindow` scene with **no** `.defaultSize` and **no** `.windowResizability` | advisory | flag | `windows-sizing-lifecycle.md` |
| sw-09 | `openWindow(id: "…")` / `dismissWindow(id: "…")` whose literal string matches **no** registered scene `id` → silent no-op | warning | flag | `windows-sizing-lifecycle.md` |
| sw-10 | `@Environment(\.openWindow)` present but **no** `@Environment(\.dismissWindow)` anywhere despite an auxiliary window | advisory | flag | `windows-sizing-lifecycle.md` |
| sw-11 | an `App` with scenes but **no** `@NSApplicationDelegateAdaptor`, needing quit-on-last-window / launch / terminate | warning | flag | `windows-sizing-lifecycle.md` |
| sw-12 | a content-forward window with the default titled chrome where `.windowStyle(.hiddenTitleBar)`/`.plain` is wanted | advisory | flag | `windows-sizing-lifecycle.md` |
| sw-13 | `navigationTitle(_:)` placed inside a `Window` scene → replaces the window titlebar (cross_ref nav-toolbars) | advisory | flag | `windows-sizing-lifecycle.md` |

**UNVERIFIED — carry as the flagged status, never assert as fact** (each is `source: verify against
Xcode 26 SDK`): the `menuBarExtraStyle` case names (`.menu`/`.window`/`.automatic`); the exact
`windowStyle` case strings; `dismissWindow`'s verbatim description; and the **macOS 26 activation
regression itself** is an *open, unresolved platform gap* (sw-06) — flag it, do not promise the workaround works.

## The real API, at a glance

**Real scene types (macOS):** `WindowGroup` (11.0+, ⌘N-duplicable; prefer the value-based
`WindowGroup(id:for:content:)` — string-`title`-label inits are deprecated), `Window` (13.0+, single
unique), `UtilityWindow` (15.0+, **macOS-only** floating inspector panel), `Settings {}` (11.0+,
**macOS-only**), `MenuBarExtra` (13.0+, **macOS-only**). **Actions:** `openWindow` (13.0+),
`dismissWindow` (**14.0+ — NOT 13**), `openSettings` (14.0+, macOS-only), `SettingsLink` (**14.0+**, macOS-only).
**Scene modifiers:** `defaultSize`, `windowResizability`, `windowStyle`, `defaultLaunchBehavior` (15.0+),
`windowIdealPlacement` (15.0+). **Lifecycle bridge:** `@NSApplicationDelegateAdaptor` (11.0+) →
`applicationShouldTerminateAfterLastWindowClosed(_:)` / `applicationWillTerminate(_:)`.

**Stale / invented (sw-01):** `Preferences {}` and the `showSettingsWindow:` / `showPreferencesWindow:`
selectors are **stale pre-`Settings`-scene** patterns; `@FocusedDocument` is **not a real Apple symbol**
(use a custom `FocusedValues` key — see the shared blacklist). **Floor-uncertain — carry `verify against
Xcode 26 SDK`:** `pushWindow` (Apple pages show **visionOS 2.0+ only; macOS unconfirmed** — do *not*
assert macOS 15) and `DocumentGroupLaunchScene` (**macOS ABSENT** — iOS/iPadOS/Mac Catalyst/visionOS only). `NSApp.activate(ignoringOtherApps:)`
is deprecated — use plain `NSApp.activate()` on macOS 14+.

Floor *values* are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
and the canonical invented-name list in `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`
— read, never restate them. Signatures + full ❌→✅ rewrites: `references/scene-types-and-settings.md`.

**Grounded ✅ shape (the consensus, from real code — not invented).** swiftui-ctx consensus for
`MenuBarExtra` is the trailing-closure form `MenuBarExtra { … } label: { … }` (50% of corpus call sites,
`introduced_macos: 13.0`); the canonical menu-bar + auxiliary-`Window` scene graph it anchors:

```swift
var body: some Scene {
    MenuBarExtra {
        MenuBarPopoverView(manager: manager, openLibrary: { showLibraryWindow() })
    } label: {
        Image(systemName: "play.rectangle.fill")
    }
    .menuBarExtraStyle(.window)

    Window("Phosphene", id: "library") {        // a real registered scene — what openWindow(id:) targets
        LibraryWindow(manager: manager)
    }
    .defaultSize(width: 900, height: 600)       // sw-08: scene-modifier sizing layer
}
```

Source (the FIX must cite a real permalink like this one, never a placeholder): `kageroumado/phosphene`
`Phosphene/PhospheneApp.swift#L11` — permalink
`https://github.com/kageroumado/phosphene/blob/757cae705aaf36ac13ba973919a181ea89fb2e3c/Phosphene/PhospheneApp.swift#L11`
· Apple doc (via Sosumi) `doc: https://sosumi.ai/documentation/swiftui/menubarextra` (access 2026-06-07).
Re-fetch the current consensus + permalink per audit with `swiftui-ctx lookup MenuBarExtra --json` →
`swiftui-ctx file <recommended.id> --smart` (steps 5 VERIFY · 7 FIX); the shape above is the live result, not a fixture.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Find the **`@main` `App` `struct`** and read its
   `body` — this domain lives there. Read the **deployment target** (`project.pbxproj`
   `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`) and the **activation policy**
   (`LSUIElement` in `Info.plist`, or `NSApp.setActivationPolicy(.accessory)`) — both are load-bearing
   for sw-06 (the trap is worst for an `.accessory` menu-bar-only app). Record the app **type**
   (document / single-window / menu-bar-only) — it decides every flag's ✅.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-scenes-windows --dir <sources> --json /tmp/sw.json --sarif /tmp/sw.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the activation-trap-in-`MenuBarExtra` and `SettingsLink`-in-`MenuBarExtra`
   containment rules grep can't express), plus a per-file **parse probe**, and emits unified JSON +
   SARIF. **Read its `parse_warnings`** — a flagged file did not fully parse, so a structural miss can't
   masquerade as clean; READ those by hand. The runner only LOCATES. Engine + rule-file format +
   degradation: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. The two
   load-bearing cross-line facts grep can't see: (a) does an `openWindow(id:)`/`dismissWindow(id:)`
   string match a *registered* `Window(id:)`/`WindowGroup(id:)` scene **somewhere else in the project**
   (sw-09) — build the scene-id ↔ open-call table; (b) is an `openWindow`/`openSettings` call **inside**
   a `MenuBarExtra` closure and is there an adjacent `NSApp.activate` (sw-06). Also inventory: every
   scene + its sizing modifiers, every `*Settings*` view + how it's reached, the `@NSApplicationDelegateAdaptor`.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. an `openWindow(id:)` with no matching scene; a stale `Preferences {}`; an
   `NSStatusItem` in a SwiftUI app; an `openSettings()` inside `MenuBarExtra` with no `NSApp.activate`).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, a
   behavior claim, the activation regression), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and `swiftui-ctx deprecated <api>`
   for a currency/deprecation rule): read its `consensus` (the canonical shape), `deprecated`+`replacement`,
   `recommended` permalink, `introduced_macos`, and `co_occurs_with`; a `lookup` **exit 3** (not-found,
   with a `suggestion`) corroborates a hallucination finding (sw-01). `swiftui-ctx recipe menubar-app`
   and `recipe window-scene` are the multi-API patterns for this domain. **Deeper corpus evidence (sw-02/sw-03):** for any Settings-scene finding, `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx settings` (+ `swiftui-ctx recipe settings-screen`) gives the real Settings-`Form` vocab — across 1,157 repos the 8,579 catalogued screens lead with Toggle (2,207)/Section (1,998)/Picker (1,678) and **no Save/Cancel/Apply** button in the vocab, which grounds the sw-03 ✅. (b) **Spec** — confirm via
   **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the
   path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never
   `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md`. The CLI
   contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the
   citation or discard. Carry the UNVERIFIED items as their status with `source: verify against Xcode 26 SDK`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit `cross_ref` on shared-seam findings (menu-item contents → menus-commands; content-frame
   sizing → layout-and-tables; `navigationTitle` migration → navigation-toolbars). Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   one conventional commit per finding citing its `rule_id`, never weaken a check. **Every defect here is
   `fix_mode: flag-only`** — leave findings `open` with the ✅ in `## Correct`. The ✅ "Correct" is **not
   a hand-written snippet** — it is the swiftui-ctx **consensus shape** put in `## Correct`, backed by a
   real macOS example fetched with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart`
   whose GitHub permalink (plus the Sosumi `doc:`) goes in `## Source`. For sw-06 the ✅ is the
   hidden-`Window`+`.regular`-policy workaround **with the runtime-test caveat**, never "this is fixed."
8. **DOUBLE-CHECK.** Re-grep each touched file to confirm the tell no longer matches; record the
   evidence in `## Fix applied?`. Re-confirm every citation still resolves. For sw-06/sw-07 note that the
   fix is **runtime-verified on the target OS only** — reading the diff is not enough.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. sw-09 (the `id` no-op) is 100% only once you have
confirmed *no* scene registers that string anywhere in the project. **Every defect is `fix_mode:
flag-only`** — there is no auto-fix set in this domain.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/scenes-windows/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/scenes-windows/_index.md`.
- `domain: scenes-windows`. Frontmatter is the canonical schema; `fix_mode` is `flag-only` for **every**
  rule here. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date
  (fetched via Sosumi) or `verify against Xcode 26 SDK`. Use `cross_ref` per the seam note.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `stale-scene-api/` | a stale/invented scene symbol — `Preferences {}`, `showSettingsWindow:`, `@FocusedDocument`, `DocumentGroupLaunchScene` on Mac (sw-01) |
| `settings-scene/` | Preferences are in the main window, or a Settings `Form` has Save/Cancel buttons (sw-02, sw-03) |
| `menu-bar-activation/` | a faked menu-bar app, the activation trap, or `SettingsLink`-in-`MenuBarExtra` (sw-05, sw-06, sw-07) |
| `auxiliary-windows/` | a window faked with a sheet/bool, an `openWindow(id:)` no-op, or a missing dismiss path (sw-04, sw-09, sw-10) |
| `window-sizing-style/` | a scene with no size/resizability, wrong/absent chrome style, or `navigationTitle`-in-`Window` (sw-08, sw-12, sw-13) |
| `app-lifecycle/` | a `WindowGroup`-only `App` missing the `@NSApplicationDelegateAdaptor` lifecycle bridge (sw-11) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/scenes-windows/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

> **Go-beyond artifact (optional):** `swiftui-audits/scenes-windows/_scene-graph.md` — a table of every
> scene the `App` declares (type · `id` · sizing · style · gate) plus every `openWindow`/`dismissWindow`
> call mapped to its scene (red where unmatched). See `references/windows-sizing-lifecycle.md`.

## Reference routing

| File | Open when |
|---|---|
| `references/scene-types-and-settings.md` | the five scene types, the `Settings {}` scene + its HIG hard rules, stale/invented scene names (sw-01/02/03) |
| `references/menu-bar-activation-trap.md` | `MenuBarExtra` vs `NSStatusItem`, the `openWindow`/`openSettings` activation trap + macOS 26 regression + workaround, `SettingsLink`-in-`MenuBarExtra` (sw-05/06/07) |
| `references/windows-sizing-lifecycle.md` | auxiliary windows + `openWindow`/`dismissWindow`, scene sizing/resizability/style, the `id` no-op, the `@NSApplicationDelegateAdaptor` lifecycle bridge, the scene-graph artifact (sw-04/08/09/10/11/12/13) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth — `SettingsLink`=14, `dismissWindow`=14, `pushWindow`/`DocumentGroupLaunchScene`=verify-SDK) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (incl. `@FocusedDocument` → custom `FocusedValues` key) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule for any floored scene API under a <floor target |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`recipe`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (the MenuBarExtra-contents and window-sizing tiebreakers) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-scenes-windows --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
sw-01/02/03/04/05/08/10/11/12/13) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` — sw-06
activation-trap-inside-`MenuBarExtra` and sw-07 `SettingsLink`-inside-`MenuBarExtra`, both `kind`-anchored
containment rules grep cannot express). sw-09 (the `id` no-op) is **deliberately not a lint rule** — it
needs the project-wide scene-id ↔ open-call cross-reference only the agent can build in READ (step 3);
the grep tell only surfaces the `openWindow(id:` call sites to cross-check. The runner runs a per-file
**parse probe** (surfaces "did not fully parse" so a structural miss can't look clean), emits unified
**JSON + SARIF**, exits **2** on any hard-fail (sw-01/06) for a CI gate, and **degrades to grep-only with
a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install
ast-grep`). It only LOCATES — always READ each hit in full before reporting (step 3). The thin
`scripts/scenes-lint.sh` is a pointer to this runner. Engine + rule-file format + JSON/SARIF shape +
safety rails: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
