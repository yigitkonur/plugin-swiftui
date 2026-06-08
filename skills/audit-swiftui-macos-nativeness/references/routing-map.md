# Reference — Smell → Owner-Skill Routing & the Route-Not-Fix Discipline

This skill is a **router, not a repairer.** Its entire output is *routes*: each confirmed smell becomes a
finding whose `cross_ref` names the **owner skill** that holds the actual ❌→✅ fix, the floor, and any
auto-fix. This file is the map and the discipline. The authoritative seam graph (which never drifts from
the orchestrator's dedup) is `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` — the
`macos-nativeness` row; **read it, never restate seam ownership here.**

**As of:** 2026-06-07.

---

## 1. The route table (smell → owner skill)

| Smell | Owner skill (the `cross_ref` target) | Why that skill owns the fix |
|---|---|---|
| nat-01 onHover | `audit-swiftui-pointer-gestures` | pointer enter/exit affordance is its domain |
| nat-04 contextMenu | `audit-swiftui-pointer-gestures` | right-click semantics + `role:.destructive` |
| nat-05 pointerStyle | `audit-swiftui-pointer-gestures` | cursor-shape affordance (macOS 15+) |
| nat-15 swipe-only | `audit-swiftui-pointer-gestures` | touch-idiom → add right-click path |
| nat-02 help | `audit-swiftui-controls-forms` | tooltip on icon controls — **cross_ref** `audit-swiftui-accessibility` (keep-both: `.help` ↔ `.accessibilityLabel`) |
| nat-03 focusable | `audit-swiftui-controls-forms` | `@FocusState`/keyboard focus (VoiceOver focus is a11y's `AccessibilityFocusState`) |
| nat-06 formStyle | `audit-swiftui-controls-forms` | grouped-form density |
| nat-07 control density | `audit-swiftui-controls-forms` | style variants own density |
| nat-08 List→Table | `audit-swiftui-layout-and-tables` | the `Table` + `sortOrder:` migration |
| nat-09 content frame | `audit-swiftui-layout-and-tables` | content-frame layer of window sizing |
| nat-10 scene sizing | `audit-swiftui-scenes-windows` | scene-modifier layer (`defaultSize`/`windowResizability`) |
| nat-11 stack-as-shell | `audit-swiftui-navigation-toolbars` | the `NavigationSplitView` shell migration |
| nat-12 navigationBar* | `audit-swiftui-navigation-toolbars` | toolbar placements + `navigationTitle` |
| nat-13 commands | `audit-swiftui-menus-commands` | `.commands`/`CommandMenu` main-menu |
| nat-14 Settings/MenuBarExtra | `audit-swiftui-menus-commands` (commands/SettingsLink) **+** `audit-swiftui-scenes-windows` (the scene + activation trap) | scene-vs-contents split — `cross-ref-graph.md` §2 |

**Two-owner smells.** nat-14 legitimately touches two skills: the **commands/SettingsLink** angle →
menus-commands; the **scene declaration + the `MenuBarExtra→openSettings` activation trap** →
scenes-windows. Emit the `cross_ref` to the angle the specific site needs; if both, prefer the scene
owner for a missing-scene smell and note the second in the finding body.

---

## 2. How to emit the route (per finding)

Each finding is `fix_mode: flag-only` and carries:

- `cross_ref: <owner-skill-slug> <owner rule prefix if known>` — e.g. `cross_ref: audit-swiftui-pointer-gestures`.
- `status: open` — **never `fixed`** (this skill applies no change; only the owner can close it).
- `## Correct` body = **(a)** a one-line route — *"Run `audit-swiftui-pointer-gestures` on this file to
  add the affordance"* — **plus (b)** the canonical ✅ affordance **shape from `swiftui-ctx`**, not a
  hand-written snippet: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` → put its
  `consensus` shape in `## Correct` and the `recommended` permalink (via
  `swiftui-ctx file <recommended.id> --smart`) in `## Source`.
- A valid `cross_ref` slug **must** be one of the `audit-swiftui-<suffix>` skills in `cross-ref-graph.md`
  (there is no `audit-swiftui-controls` — it is `audit-swiftui-controls-forms`; no
  `audit-swiftui-pointer` — it is `audit-swiftui-pointer-gestures`).

**Worked example (nat-01).** `swiftui-ctx lookup onHover --json` returns `consensus` `{ }` (96%),
`introduced_macos` `10.15`, and a `recommended` permalink
`https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Components/TrimmingAVPlayer.swift#L729`
— so `## Correct` shows `.onHover { hovering in … }` (the consensus closure form) and `## Source` carries
that permalink as the real macOS-26 example. The *fix* itself belongs to pointer-gestures.

---

## 3. The route-not-fix discipline (do not cross the lane)

- **Never apply a code change here.** No `fix_mode: auto`; the fix-safety protocol
  (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`) is invoked only for its hand-off
  clause — this skill makes **no commit**.
- **Never restate the owner's fix depth.** Don't paste the `Table` migration or the
  `NavigationSplitView` shape — point to the owner skill, which owns it in depth.
- **Don't double-own.** If a site is also a deprecation (nat-11 `NavigationView`, nat-12 `navigationBar*`
  renames), `api-currency` owns the *deprecation flag* and `navigation-toolbars` owns the *structural
  fix* per `cross-ref-graph.md` — route to the structural owner and note the currency seam; do not file a
  competing primary finding.
- **The dashboard is the deliverable.** A developer reads the score + punch-list, then runs each owner
  skill. This skill's value is the *map*, not the repair.

---

## Sources

Internal routing derived from the toolkit's seam graph; cites no external API. The authoritative seam
ownership + valid slugs live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`; the
`swiftui-ctx` CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
