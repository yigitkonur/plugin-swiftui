---
name: audit-macos-swiftui-full
description: Orchestrates a FULL macOS SwiftUI audit by routing one finished or in-progress codebase through the toolkit's 28 domain audit skills in a dependency-sensible order, then consolidates every per-skill finding into one swiftui-audits/_SUMMARY.md dashboard with severity, per-skill, and nativeness-score rollups. Use when the user says "audit my macOS SwiftUI app", "full SwiftUI review", "review the whole Mac app", "is this Mac app native", "pre-ship SwiftUI check", "run all the SwiftUI audits", or asks for an end-to-end / everything pass rather than one domain. Also use to gate a release (the per-skill hard-fail tally). AUDIT-ONLY, macOS-only, SwiftUI-only. This is a META skill: it sequences and aggregates the 28 owners; it contains NO domain rules or fixes of its own. Not for a single domain (route straight to that audit-swiftui-* skill), not for AppKit-only apps, not for writing UI from scratch, not for HIG snapshot review.
---

# Audit macOS SwiftUI — Full (orchestrator)

**AUDIT-ONLY · macOS-only · SwiftUI-only · META.** This skill runs an *entire* macOS-SwiftUI audit: it
**scans the codebase to steer to only the relevant domain skills**, runs them as **dependency-ordered
waves of parallel subagents** (each reading its scoped files and taking findings to disk), then rolls
every finding up into a single dashboard. It owns **scan-steering, sequence, parallelism, aggregation,
and the fix-safety ordering** — nothing else. Every rule, floor, and fix lives in the 28 owners and the shared
`references/_shared/` files; this orchestrator **points in, never restates**.

If the user wants only one domain ("audit my Liquid Glass", "check concurrency"), do **not** run the
full sweep — invoke that single `audit-swiftui-*` skill directly. Use the routing table below to map a
symptom or file-signal to the right subset.

## The evidence model (every skill, same three moves)

Each of the 28 skills, and therefore this orchestrator, runs the same governed pipeline:

1. **LOCATE** — the one shared hybrid lint runner
   (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill <skill> --dir <sources> --json -`)
   greps tier-1 tells + ast-grep tier-2 structural rules and emits unified JSON. It **only locates**;
   a hit is never a finding. Engine + JSON shape: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
2. **VERIFY** — the agent READS each located file in full, then corroborates with **Sosumi** (the
   Apple spec: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`) and **swiftui-ctx** (the
   shipping-corpus practice: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`).
   Report a finding only at 100% certainty; floors come from
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`, never from memory.
3. **FIX** — governed by `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`
   (clean-tree gate, findings-first, `fix_mode: auto` only, one commit per finding, never weaken a check).

The orchestrator's job is to run these 28 pipelines in the right order and merge their output.

## Run order (and why)

The order is **dependency-sensible**, not alphabetical. Cross-cutting guards run first so later domain
work never lands on a symbol that is about to be renamed or gated; the boundary/scoring skills run last
because they read the whole picture. Detection for a wave is parallel-safe (findings-only); **fixes are
applied serially in this same order** per the fix-safety protocol (§FIX below).

| Wave | Skills (run in this order) | Why here |
|---|---|---|
| **0 · Guards (cross-cutting, sequential)** | `audit-swiftui-api-currency` → `audit-swiftui-availability-gating` → `audit-swiftui-concurrency-safety` | Mechanical-rename + gating + isolation guards. They rewrite/flag symbols every other domain depends on, so they must settle first (fix-safety §5). |
| **1 · State & data** | `audit-swiftui-state-observation` → `audit-swiftui-swiftdata` → `audit-swiftui-async-data` → `audit-swiftui-state-restoration` → `audit-swiftui-document-model` | Where the model lives and how it loads/persists/restores — UI correctness depends on it. |
| **2 · UI domains** | `audit-swiftui-scenes-windows` → `audit-swiftui-menus-commands` → `audit-swiftui-navigation-toolbars` → `audit-swiftui-controls-forms` → `audit-swiftui-layout-and-tables` → `audit-swiftui-liquid-glass` → `audit-swiftui-animation-motion` → `audit-swiftui-drawing-canvas` → `audit-swiftui-charts` → `audit-swiftui-typography-text` → `audit-swiftui-appearance-color` → `audit-swiftui-accessibility` → `audit-swiftui-localization` → `audit-swiftui-pointer-gestures` → `audit-swiftui-previews` → `audit-swiftui-sandbox-files` → `audit-swiftui-view-performance` | Scene shell outward to content, chrome, motion, drawing, type, color, a11y, loc, pointer, previews, files, then render cost (`view-performance` reads over-rendering after state settles). Each owns its own gating in depth (guards already caught the misses). |
| **3 · Boundary & scoring (last)** | `audit-swiftui-appkit-interop` → `audit-swiftui-appkit-overuse` → `audit-swiftui-macos-nativeness` | The AppKit seam (HOW↔WHETHER) and the 0-100 nativeness meta-score read the full codebase + the prior findings; nativeness re-scores last for a before/after delta. |

28 skills total. The seam-ownership that decides who keeps a finding when two waves hit the same
`file:line` is the single source `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` — the
**same** file each skill's `cross_ref` emission reads, so the dedup pass and the skills cannot drift.

## Routing table (situation / file-signal → which skills)

The STEER scan (workflow step 2) auto-selects the relevant subset; this table is the manual override and the signal→skill mapping behind it:

| Situation / file-signal | Run these |
|---|---|
| "feels like an iPad app in a window" / rate the Mac-ness | `macos-nativeness` (it scores + routes to the owners) |
| glass / `glassEffect` / macOS 26 chrome | `liquid-glass`, then `availability-gating`, `appearance-color` |
| deprecation warnings / `NavigationView` / `.foregroundColor` | `api-currency` (guard), then the named owner |
| `@Observable` / state won't update / over-render | `state-observation`, `view-performance` |
| `@Model` / `@Query` / SwiftData crash | `swiftdata`, `concurrency-safety` |
| `.task`/`async`/data races / `Sendable` | `async-data`, `concurrency-safety` |
| `WindowGroup`/`Settings`/`MenuBarExtra`/window sizing | `scenes-windows`, `menus-commands`, `layout-and-tables` |
| `Table`/`List`/`Form`/control density | `layout-and-tables`, `controls-forms` |
| `NSViewRepresentable`/`NSOpenPanel`/AppKit bridge | `appkit-overuse` (whether), `appkit-interop` (how), `sandbox-files` |
| `fileImporter`/security-scoped bookmarks/sandbox | `sandbox-files`, `concurrency-safety` |
| `Chart`/`Canvas`/custom drawing | `charts`, `drawing-canvas`, `accessibility` |
| VoiceOver / Dynamic Type / contrast | `accessibility`, `appearance-color`, `typography-text` |
| `String(localized:)` / catalogs / RTL | `localization`, `typography-text` |
| `#Preview` / preview crashes | `previews`, `swiftdata`, `state-observation` |
| `DocumentGroup`/`FileDocument` | `document-model`, `state-restoration` |
| `@AppStorage`/`NavigationPath`/`onOpenURL` restore | `state-restoration` |

`tree`/`find` the sources first, read the **deployment target** (`MACOSX_DEPLOYMENT_TARGET` or
`Package.swift` `platforms:`) once — it is load-bearing for every gating rule — and pass it down.

## The orchestration workflow (execute verbatim)

1. **ORIENT (once).** `tree`/`find` the SwiftUI sources; record the deployment-target floor
   (`MACOSX_DEPLOYMENT_TARGET` / `Package.swift` `platforms:`). Confirm the git tree state (clean vs
   dirty) — it decides whether fixes may run (fix-safety §1).
2. **STEER (scan → only the relevant skills).** Run
   `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/audit-scan.py <sources> --json swiftui-audits/_scan.json`.
   It returns `relevant_skills` — the 8 always-on cross-cutting skills plus every conditional domain
   whose presence signal actually appears in the code — and `detail[].files`, the exact files each skill
   must read. **Skills whose domain is absent are skipped, never run** (no `@Model`/`import SwiftData` →
   no `swiftdata` subagent; no `Chart(`/`BarMark` → no `charts` subagent). Intersect `relevant_skills`
   with the wave order above to get each wave's skill list and **drop empty waves**. (An explicit user
   include/exclude overrides the scan.)
3. **DISPATCH (wave by wave, parallel subagents).** For each non-empty wave **in order**, spawn **one
   subagent per relevant skill in that wave, in parallel** — the filesystem is their only shared channel
   (no subagent sees another's notes except through the files on disk). Each subagent's self-contained
   brief: *invoke the `audit-swiftui-<skill>` skill; read ONLY that skill's `detail.files` from the scan;
   run LOCATE→VERIFY→REPORT; write findings to `swiftui-audits/<domain>/<context>/NN-slug.md` + the
   per-skill `swiftui-audits/<domain>/_index.md` (the `macos-nativeness` index carries
   `kind: nativeness-dashboard`); return a one-line `hard/warn/adv` tally.* The orchestrator never writes
   into a domain folder. **Barrier:** wait for the whole wave to land on disk before starting the next —
   later waves read earlier findings for the seam pass. Detection is parallel-safe (findings-only,
   disjoint domain folders); **fixes are serial** (step 6).
4. **DEDUP (seam pass).** For any two findings on the same `file:line`, apply
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` §1: the **primary** keeps a top-level
   finding; the **sibling** is flipped to `status: duplicate-of <primary rule_id>` (kept on disk, excluded
   from the master table). `keep-both` rows stay, cross-linked.
5. **AGGREGATE.** Write the single top-level dashboard `swiftui-audits/_SUMMARY.md` (layout below).
6. **FIX (optional, only when asked + clean tree).** Apply fixes **serially in wave order**, guards
   first, one conventional commit per finding citing its `rule_id`, `fix_mode: auto` only, never weaken a
   check — `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`. Re-run `macos-nativeness`
   last for the before/after score delta.
7. **DOUBLE-CHECK.** Re-run the LOCATE lint on each fixed file to confirm the tell no longer matches;
   record it in each finding's `## Fix applied?`. Recompute the rollups so `_SUMMARY.md` reflects the
   committed state.

## The consolidated dashboard — `swiftui-audits/_SUMMARY.md`

This is the toolkit's **one top-level index/dashboard** (the shared finding-schema names it `_SUMMARY.md`;
treat it as the project-root audit index). The orchestrator is its sole author. It contains three
rollups plus a master table:

- **Rollup by severity** — total `hard-fail` / `warning` / `advisory` across all skills (the pre-ship
  signal: any `hard-fail` blocks).
- **Rollup by skill** — one row per skill run: `domain · hard · warn · adv · score?(nativeness only) ·
  link to its _index.md`. Domains the STEER scan marked absent are listed as `n/a — not present` so
  coverage is explicit (audited-and-clean vs not-applicable are never conflated).
- **Nativeness score** — the `macos-nativeness` 0-100 score + its per-category breakdown, surfaced at the
  top as the headline metric.
- **Master finding table** — every non-duplicate finding (`rule_id · severity · domain · file:line · api
  · status`), sorted severity-desc then domain. `status: duplicate-of …` rows are omitted (they remain on
  disk for the audit trail).

Two runs over the same code produce a structurally identical `swiftui-audits/` tree and an equivalent
`_SUMMARY.md` — determinism is a hard requirement.

## Pre-ship gate (CI)

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/audit-gate.sh <target-dir>` loops the shared lint runner over all 28
skills, tallies hard/warn/adv per skill + total, prints a summary to stderr and a combined JSON to
stdout, and **exits 2 if any skill reports a hard finding** (else 0). It is the mechanical LOCATE-tier
gate — a non-zero exit means a human-driven full audit (this skill) is required before shipping; it does
not replace the VERIFY/READ step.

## Boundaries (stay in lane)

- This skill **never contains domain rules or fixes** — if you find yourself describing how to fix a
  `glassEffect` or a `@Model` race, stop and invoke the owner skill.
- It does not touch `references/_shared/` or any sibling skill's `references/`/`lint/` — it consumes them.
- AppKit-only apps, HIG snapshot review, and from-scratch UI are out of scope (route to `build-macos-swiftui`
  / `review-macos-hig` respectively).

## Reference routing (all shared — point in, never restate)

| Shared file | Open when |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | step DEDUP — seam ownership (who keeps a colliding finding) + the 129-seam `cross_ref` graph |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the byte-identical finding format + the `_SUMMARY.md` contract every skill inherits |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | step FIX — the 8-point protocol + the guards-first cross-skill order |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md` | step LOCATE — the shared runner's engine, JSON/SARIF shape, degradation rails |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | any floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | any arm-gating question (a macOS-version / wrong-arch availability miss) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | any invented-name question (a confabulated API like `@FocusedDocument`, `.glassBackground`) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | step VERIFY — the Apple-doc spec fetch protocol |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | step VERIFY — the shipping-corpus practice CLI (consensus shape + permalinked example) |

The 28 domain owners are invoked as skills (by the slugs in the run-order table), not read as files.

## Sources

Internal orchestration over the toolkit's 28 audit skills; the run order derives from the cross-skill
fix-safety ordering and seam graph in `references/_shared/`. Cites no external API directly — every
floor, signature, and spec is owned by a domain skill or a `_shared/` file referenced above via
`${CLAUDE_PLUGIN_ROOT}`.
