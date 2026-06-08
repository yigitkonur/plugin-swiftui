---
name: audit-swiftui-menus-commands
description: Audits a finished or in-progress macOS SwiftUI codebase for menu-bar, Commands, and keyboard-shortcut defects and writes per-finding Markdown to swiftui-audits/. Use when the user says the menu bar is missing, actions live as in-window buttons, a duplicate File/Edit/View/Window/Help menu appears, a menu command can't reach the focused document, a menu item is always greyed out or fires on the wrong window, a shortcut doesn't show in the menu bar, About/New is duplicated, or Help/Sidebar is hand-rolled; when they ask to verify .commands, CommandMenu, CommandGroup, CommandGroupPlacement, keyboardShortcut, @FocusedValue, @Entry, SidebarCommands, or commandsRemoved/commandsReplaced; or when AI wrote @FocusedDocument or a reserved shortcut (Command-Q/H/comma/Space). AUDIT-ONLY, macOS-only, SwiftUI-only. Not for NSMenu/AppKit menu bridging, not the MenuBarExtra scene/activation trap, not toolbar item layout, not the blanket availability sweep, not writing new menus from scratch.
---

# Audit SwiftUI Menus, Commands & Keyboard

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way the menu bar, `Commands`, `@FocusedValue`
command routing, and keyboard shortcuts go wrong: menu actions faked as in-window buttons, a parallel
`CommandMenu("File")` duplicating a standard menu, a command that can't reach the focused window's
state, a buried `keyboardShortcut`, duplicated About/New, hand-rolled Help/Sidebar, the hallucinated
`@FocusedDocument`, and reserved-shortcut conflicts. Findings are written to disk in the toolkit's
unified schema; certain mechanical defects are fixed under the fix-safety protocol. This is never a
from-scratch menu generator.

**Why AI gets this wrong:** iOS-default training bias. The iPhone has no menu bar, so the model has
few `.commands { }` examples; its highest-probability answer to "add an Export action" is an in-window
`Button`. Two structural traps follow — the **command-to-state gap** (a menu lives outside any window,
so a closure can't close over a view's `@State`; it must reach the focused window via `@FocusedValue`)
and **extend-don't-replace** (macOS already ships File/Edit/View/Window/Help; the correct move is
surgical `CommandGroup(after:/replacing:)`, not a parallel `CommandMenu`). Be suspicious wherever AI
wrote menu code on a Mac target.

## Boundary / seam note (stay in lane)

- **AppKit `NSMenu` / `NSMenuItem` / `addItem` bridging is out of scope.** If audited code reaches for an
  AppKit menu surface, note it in one line and point to `audit-swiftui-appkit-overuse` (whether to
  bridge) — do not audit AppKit menus here.
- **The `MenuBarExtra` *scene* + its activation/`.menuBarExtraStyle` trap** belongs to
  `audit-swiftui-scenes-windows`; **item-level issues *inside* a `MenuBarExtra` closure** stay here
  (emit `cross_ref: audit-swiftui-scenes-windows` on the seam).
- **`@Entry` / `FocusedValueKey` SEAM tiebreaker:** if the key is **co-located with a
  `CommandMenu`/`CommandGroup`** → this skill owns it; if it lives in a **preview / general environment
  setup** → `audit-swiftui-previews` owns it (`cross_ref` it).
- **Toolbar *item* placement/layout** is `audit-swiftui-navigation-toolbars`; a toolbar button that
  should be a menu action is the seam (`cross_ref` it). **The blanket "is every floored API gated"
  sweep** is `audit-swiftui-availability-gating`; this skill owns the **command-API** floors in depth.

## The four non-negotiable rules

1. **App actions → `.commands`, never in-window buttons.** Mac users expect File ▸ Export…,
   discoverable, with a shown shortcut. An in-window `Button` row misses the entire menu system.
2. **Extend, don't duplicate.** Add to / override Apple's menus with
   `CommandGroup(after:/before:/replacing: .placement)`; reserve `CommandMenu` for a *genuinely new*
   top-level menu. Naming a `CommandMenu` after a standard menu makes a second one.
3. **Reach the focused window via `@FocusedValue`, guarded with `.disabled(value == nil)`.** A menu is
   global; closing over one view's `@State` targets the wrong window or won't compile. The `.disabled`
   is load-bearing — without it the command fires against nothing.
4. **Shortcuts live on menu items** so they both *fire* and *render* their key equivalent — and never
   collide with a reserved shortcut (⌘Q/⌘H/⌘,/⌘Space/⌘Tab).

Full reasoning + the focused-routing skeleton: `references/commands-structure.md`,
`references/focused-routing.md`.

## Defect index (menu-01 … menu-10)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct),
**warning** (compiles but non-native), **advisory** (judgment / craft). `auto` = mechanical
single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| menu-01 | A scene with **no `.commands { }` anywhere** + app actions as an in-window `Button` row | warning | flag | `commands-structure.md` |
| menu-02 | `CommandMenu("File"\|"Edit"\|"View"\|"Window"\|"Help")` — title matches a *standard* menu | warning | flag | `commands-structure.md` |
| menu-03 | a `CommandMenu`/`CommandGroup` closure referencing a concrete `@State`/model directly (not `@FocusedValue`) | warning | flag | `focused-routing.md` |
| menu-04 | `.keyboardShortcut(` on a `Button` that is **not inside `.commands { }`**, expected app-global | warning | flag | `shortcuts-and-reserved.md` |
| menu-05 | `CommandGroup(after: .appInfo\|.newItem)` duplicating About/New instead of `(replacing:)` | warning | flag | `commands-structure.md` |
| menu-06 | hand-rolled `CommandMenu("Help")` / "Show Sidebar"/"Toolbar" toggle instead of `SidebarCommands()` / `ToolbarCommands()` / `CommandGroup(replacing: .help)` | warning | flag | `commands-structure.md` |
| menu-07 | **no `.disabled(focusedValue == nil)`** on a command acting on a focused document | warning | flag | `focused-routing.md` |
| menu-08 | `@FocusedDocument` — hallucinated; not a real Apple symbol | hard-fail | flag | `focused-routing.md` |
| menu-09 | `.keyboardShortcut("q"\|"h"\|","\|.space, modifiers: .command)` — reserved-shortcut collision | advisory | flag | `shortcuts-and-reserved.md` |
| menu-10 | a floored command API (`.singleWindowList`/`InspectorCommands`/`commandsRemoved`/`commandsReplaced`) ungated under a <13/14 floor | warning | flag | `command-api-availability.md` |

**One claim carries UNVERIFIED nuance — never assert beyond the corpus:** the exact `@Entry`-macro
toolchain requirement (back-deploys to macOS 10.15 but needs Xcode 15+/Swift 5.9+ to *expand*) is a
build-environment fact, not a runtime floor; carry it as advisory context, never as a hard finding.

## The real API, at a glance

**Real (exist on macOS):** `.commands { }`, `CommandMenu(_:)` (macOS 11.0+, a *new* top menu),
`CommandGroup(after:/before:/replacing:)` + `CommandGroupPlacement` (macOS 11.0+; `.singleWindowList`
macOS 13.0+), `keyboardShortcut(_:modifiers:)` (macOS 11.0+), `@FocusedValue` / `@FocusedBinding` /
`FocusedValueKey` / `focusedValue(_:_:)` (macOS 11.0+), the `@Entry` macro on `FocusedValues` (macOS
10.15+, back-deploys; Xcode 15+/Swift 5.9+ to expand), `SidebarCommands()` / `ToolbarCommands()` /
`TextEditingCommands()` / `TextFormattingCommands()` / `EmptyCommands()` (macOS 11.0+),
`ImportFromDevicesCommands()` (macOS 12.0+), `InspectorCommands()` (macOS 14.0+),
`commandsRemoved()` / `commandsReplaced(content:)` (scene modifiers, macOS 13.0+).

**Hallucinated (never exists):** `@FocusedDocument` → a custom `FocusedValues` key (`@Entry var
document: …` + `@FocusedValue(\.document)`). `@FocusedBinding` *does* exist — verify the key exists
before flagging it.

**✅ Grounded `CommandMenu` shape (real shipping code, not a placeholder).** `swiftui-ctx lookup
CommandMenu --json` reports `consensus: (_)` 100%, `introduced_macos: 11.0`, and a `recommended`
example at `min_macos: 26` — `tahseen-kakar/harbor` `DownloadCommands.swift` (verified live via
`swiftui-ctx file ex_4109450990 --smart`). A *genuinely new* top-level menu, each item carrying its own
shortcut + `.disabled(…)` guard — the pattern a finding's `## Correct` must mirror:

```swift
// Source: https://github.com/tahseen-kakar/harbor/blob/064c6b7c706c255ca30ae2c0ce607b6ba21e2edd/Harbor/App/DownloadCommands.swift#L15
// doc: https://sosumi.ai/documentation/swiftui/commandmenu
CommandMenu("Downloads") {                              // a brand-NEW top menu (not File/Edit/…)
    Button("New Download...") { center.presentAddSheet() }
        .keyboardShortcut("n")                          // shortcut on the menu item → fires AND renders
    Button("Pause or Resume Selected") { center.togglePauseResumeForSelection() }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .disabled(center.canToggleSelectedDownload == false)   // ← load-bearing guard
    Button("Open Downloaded File") { center.openSelectedDownload() }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(center.canOpenSelectedDownload == false)
}
```

Signatures, placements, and the full ❌→✅ rewrites: `references/commands-structure.md`,
`references/focused-routing.md`. Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the canonical invented-name list (incl.
`@FocusedDocument`) is `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read,
never restate them.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing
   for menu-10: `.singleWindowList`/`commandsRemoved`/`commandsReplaced` need ≥ macOS 13,
   `InspectorCommands()` ≥ 14. Locate the `App` `body` — the only place `.commands { }` is valid.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-menus-commands --dir <sources> --json /tmp/menus.json --sarif /tmp/menus.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the keyboardShortcut-outside-`.commands` and standard-name-`CommandMenu`
   rules grep can't fully scope), plus a per-file **parse probe**, and emits unified JSON + SARIF.
   **Read its `parse_warnings`** — a flagged file did not fully parse, so a structural miss can't
   masquerade as clean; READ those by hand. The runner only LOCATES — never treat a hit as a finding.
   Engine + rule-file format + degradation: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a
   `CommandMenu` duplicates a standard menu, whether a closure reaches `@State` vs `@FocusedValue`,
   whether a shortcut sits inside `.commands`, and whether `.disabled(value == nil)` is present are all
   invisible to grep. Build a per-file inventory: each command + its placement + its state route + its
   shortcut.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a `@FocusedDocument` use, a `CommandMenu("File")`, a `keyboardShortcut` on a
   non-`.commands` button). The whole-app menu-01 (no `.commands` anywhere) requires reading the `App`
   body, not a single line.
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, a
   behavior claim), run **both** evidence sources. (a) **Practice** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
   lookup <api> --json` (e.g. `CommandMenu`, `CommandGroup`, `keyboardShortcut`, `focusedValue`; add
   `swiftui-ctx deprecated <api>` for a currency rule): read its `consensus` (the canonical shape),
   `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and `co_occurs_with`
   (`CommandMenu` co-occurs with `FocusedValue`/`focusedValue` — the routing pattern is real). A
   `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a hallucination
   finding — `swiftui-ctx lookup FocusedDocument` exits 3 ("no usage found"), proof no shipping app uses
   it. (b) **Spec** — confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using
   `references/source-directory.md` for the path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`
   for the protocol (never `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against
   `floors-master.md` and the Sosumi `doc:` floor. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or discard.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit `cross_ref` on a shared-seam finding (MenuBarExtra scene, `@Entry`-in-preview,
   toolbar-vs-menu). Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (none in this domain default to auto — all menu fixes are structural; treat
   the set as `flag-only` and show the ✅), one conventional commit per finding citing its `rule_id`,
   never weaken a check. The ✅ "Correct" is **not a hand-written snippet** — it is the swiftui-ctx
   **consensus shape** put in `## Correct`, backed by a real macOS-26 example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source`. E.g. `CommandMenu`'s `recommended` is
   `tahseen-kakar/harbor` `DownloadCommands.swift` (a genuine new top menu, min_macos 26); `keyboardShortcut`'s
   is `sindresorhus/Gifski` `Utilities.swift`. Leave `flag-only` findings `open` with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves and still reports the expected floor.
   If a fix introduced a new tell (e.g. you moved an action into `.commands` and it now needs
   `@FocusedValue` routing + `.disabled`), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. menu-08 (`@FocusedDocument`) is corroborated by a
`swiftui-ctx lookup` **exit 3**. No defect in this domain is `fix_mode: auto` by default (every fix
restructures the menu/scene graph); the whole set is `flag-only` with the ✅ shown.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/menus-commands/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/menus-commands/_index.md`.
- `domain: menus-commands`. Frontmatter is the canonical schema; `fix_mode` is `flag-only` for every
  defect. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date (fetched
  via Sosumi) or `verify against Xcode 26 SDK`.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `missing-commands/` | app actions live as in-window buttons; no `.commands { }` anywhere (menu-01) |
| `menu-duplication/` | a `CommandMenu` duplicates a standard menu, or About/New is duplicated, or Help/Sidebar is hand-rolled (menu-02, menu-05, menu-06) |
| `focused-routing/` | a command reaches `@State` not `@FocusedValue`, lacks `.disabled(value == nil)`, or uses `@FocusedDocument` (menu-03, menu-07, menu-08) |
| `keyboard-shortcuts/` | a shortcut sits on a non-`.commands` button, or collides with a reserved shortcut (menu-04, menu-09) |
| `command-availability/` | a floored command API is ungated under a <13/14 floor (menu-10) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/menus-commands/` with a lowercase-hyphen slug naming the sub-category, and note it in
the run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is
a hard requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/commands-structure.md` | `.commands` placement, `CommandMenu` vs `CommandGroup(after:/replacing:)`, the placement table, in-window-buttons, About/New duplication, hand-rolled Help/Sidebar (menu-01/02/05/06) + the canonical `.commands` skeleton |
| `references/focused-routing.md` | the `@FocusedValue` command→window bridge, `@Entry` shorthand, the `.disabled(value == nil)` rule, the `@FocusedDocument` hallucination (menu-03/07/08) |
| `references/shortcuts-and-reserved.md` | `keyboardShortcut` placement (on menu items, not buried buttons) + the reserved-shortcut table (⌘Q/⌘H/⌘,/⌘Space/⌘Tab) (menu-04/09) |
| `references/command-api-availability.md` | the per-API floors for floored command symbols + the gating application (menu-10) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (incl. `@FocusedDocument`) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm failure (menu-10) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (MenuBarExtra, `@Entry`-in-preview, toolbar-vs-menu) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-menus-commands --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
menu-01/02/03/04/05/06/08/09/10) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` —
menu-04 keyboardShortcut-outside-`.commands`, menu-02 standard-name-`CommandMenu`) that grep cannot
scope. It runs a per-file **parse probe** (surfaces "did not fully parse" so a structural miss can't
look clean), emits unified **JSON + SARIF**, exits **2** on any hard-fail (menu-08) for a CI gate,
and **degrades to grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli
ast-grep`; faster: `brew install ast-grep`). It only LOCATES — always READ each hit in full before
reporting (step 3). The thin `scripts/menus-lint.sh` is a pointer to this runner. Engine + rule-file
format + JSON/SARIF shape + safety rails: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
