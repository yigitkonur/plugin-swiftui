---
name: audit-swiftui-async-data
description: Audits a finished or in-progress macOS SwiftUI codebase for async data-loading defects and writes per-finding Markdown to swiftui-audits/. Use when the user says a view loads data wrong, flashes empty, spins forever, has no error or empty state, leaks or double-fires network calls, searches on every keystroke, or shows blank remote images; when they ask to verify a screen's .task, .task(id:), .onAppear Task, .refreshable, .searchable debounce, AsyncImage phases, .redacted skeletons, URLSession in a view, or a stale-result race; when AI wrote a bare Task in onAppear, swallowed errors with try? await, or AsyncImage(url:) in a list with no cache. AUDIT-ONLY, macOS-only, SwiftUI-only. Not the Swift-6 isolation/Sendable verdict (that is concurrency-safety), not where the model lives (state-observation), not SwiftData @Query fetching, not the general availability sweep, not writing new data UI from scratch.
---

# Audit SwiftUI Async Data

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI project
to detect — and where certain, fix — every way **async data loading inside a view** goes wrong: a bare
`Task` in `.onAppear` that never cancels, no loading / error / empty state, raw `URLSession` decoded on the
main actor, search that fetches on every keystroke, `AsyncImage` whose failure phase is ignored, a list
with no `.refreshable`, a stale result overwriting a fresh one, and a load with no `.redacted` skeleton.
Findings are written to disk in the toolkit's unified schema; the few mechanical defects are fixed under
the fix-safety protocol. This is never a from-scratch data-layer generator.

This domain is **net-new** (the relevant `.task`/`Sendable` facts live in
`${CLAUDE_PLUGIN_ROOT}/skills/build-macos-swiftui/references/concurrency.md`); ground every ✅ in
`swiftui-ctx` consensus + a permalinked macOS-26 example, not a hand-written snippet.

## Boundary / seam note (stay in lane)

- **`Task`-in-`onAppear` is a SHARED seam with `concurrency-safety`.** **This skill owns the LIFECYCLE
  fix** — the Task is unstructured and not cancelled on disappear → move to `.task` / `.task(id:)`.
  `concurrency-safety` owns the **ISOLATION verdict** on the captured state (is the crossing type
  `Sendable`, does it race a `@MainActor`). When the captured loading state is non-`Sendable`, emit a
  `cross_ref: concurrency-safety` and fix only the lifecycle here.
- **Where the model *lives*** (`@State` vs `@Observable` vs `@StateObject`, observation granularity)
  belongs to `state-observation` — `cross_ref` it; this skill only audits the *loading* that mutates it.
- **`@Query` / SwiftData fetching** belongs to `swiftdata`; **the Swift-6 `Sendable`/`@concurrent`/
  `nonisolated` correctness** belongs to `concurrency-safety`; **`DispatchQueue.main.async` as a
  deprecated currency tell** belongs to `api-currency`. Defer all three.

## The four async-data rules

1. **Bind async work to view identity.** View-lifecycle loads go in `.task` / `.task(id:)` (auto-cancelled
   on disappear, closure is `@MainActor`), never a bare `Task {}` in `.onAppear`.
2. **Every load has four visible states.** loading · loaded · **empty** · **error** — each rendered. A spinner
   that never resolves, a blank list, or a swallowed `try? await` is a defect.
3. **Don't fetch faster than the user.** Debounce a search query before it drives a request; guard rapid
   `.task(id:)` writes with a generation counter so an older load can't overwrite a newer one.
4. **Remote images and pull-to-refresh are first-class.** `AsyncImage` handles its failure phase and is
   cached in lists; a primary async list offers `.refreshable`; a load shows a `.redacted` skeleton.

## Defect index (async-01 … async-10)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct),
**warning** (compiles but non-native), **advisory** (judgment / perf). `auto` = mechanical single-answer
fix; `flag` = show the ✅, dev applies. Defects marked **DETECT-only** are *absence* defects — no grep/AST
tell can fire on a missing state; find them by READING the load site the proxy tells locate.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| async-01 | bare `Task {}` in `.onAppear` (no cancellation) → `.task`/`.task(id:)` | warn | flag | `lifecycle-and-cancellation.md` |
| async-02 | async load with no loading state (no `isLoading`/`ProgressView`/skeleton) — **DETECT-only** | warn | flag | `load-states-and-skeletons.md` |
| async-03 | `try? await` swallows the error; no error state rendered | warn | flag | `load-states-and-skeletons.md` |
| async-04 | a collection rendered with no empty-case view — **DETECT-only** | adv | flag | `load-states-and-skeletons.md` |
| async-05 | raw `URLSession` in a view; decode on the main actor / un-isolated write | warn | flag | `networking-and-images.md` |
| async-06 | `.searchable` query drives a fetch with no debounce (request per keystroke) | warn | flag | `networking-and-images.md` |
| async-07 | `AsyncImage(url:)` url-only shape — failure phase unhandled, no cache in lists | warn | flag | `networking-and-images.md` |
| async-08 | primary async list with no `.refreshable` — **DETECT-only** | adv | flag | `networking-and-images.md` |
| async-09 | rapid `.task(id:)` writes with no generation/stale-result guard | warn | flag | `lifecycle-and-cancellation.md` |
| async-10 | load with no `.redacted(.placeholder)` skeleton — **DETECT-only** | adv | flag | `load-states-and-skeletons.md` |

**Nothing here is a hallucination class** — every API is real and floored low (`.task` macOS 12,
`AsyncImage`/`refreshable`/`searchable` macOS 12, `.redacted` macOS 11). The defects are *omission and
lifecycle*, not invented names; carry behavior claims you cannot place as `advisory` (`source: verify
against Xcode 26 SDK`), never as fact.

## The real API, at a glance

**Real (all macOS, floored low — confirm exact floors in `floors-master.md`, never restate the table):**
`task(priority:_:)` and `task(id:priority:_:)`, `refreshable(action:)`, `searchable(text:…)`,
`AsyncImage(url:)` / `AsyncImage(url:content:placeholder:)` / `AsyncImage(url:transaction:content:)` (the
`phase` form), `redacted(reason:)` + `RedactionReasons.placeholder`, `unredacted()`, `Task`/`Task(id:)`
cancellation via `Task.isCancelled` / `Task.checkCancellation()`.

Floor *values* are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`;
the canonical invented-name list is `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`
— read, never restate them. The ✅ shapes are not hand-written: get the **consensus shape + a permalinked
macOS-26 example** from `swiftui-ctx` (VERIFY/FIX below).

### ✅ Correct (grounded, not a placeholder) — the async-01 lifecycle anchor

`swiftui-ctx lookup task --json` consensus: **`{ }` 70% · `(id)` 29%**, `introduced_macos: 12.0`. The
top-authority macOS-26 site (`swiftui-ctx file ex_a1cff2419c --smart`) — bind the load to view identity so
it auto-cancels on disappear; `.task(id:)` restarts on change:
```swift
// sindresorhus/Gifski — Gifski/Utilities.swift L5590 (min_macos 26)
content
    .task(id: Tuple3(isActive, options, reason)) {       // restarts when the id changes; cancels on disappear
        activity = isActive ? SSApp.beginActivity(options, reason: reason) : nil
    }
```
- Real example (permalink): `https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Utilities.swift#L5590`
- Spec (Sosumi): `https://sosumi.ai/documentation/swiftui/view/task(id:priority:_:)` (the `@MainActor`,
  auto-cancelled lifecycle modifier). Re-confirm the floor in `floors-master.md` before asserting it.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). Record it — every API
   here floors at macOS 11–12, so gating rarely fires, but note any target < macOS 12.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-async-data --dir <sources> --json /tmp/async.json --sarif /tmp/async.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — Task-in-onAppear containment, AsyncImage url-only shape), plus a per-file
   **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a flagged file did not
   fully parse, so a structural miss can't masquerade as clean; READ those by hand. The runner only
   LOCATES. The **absence** defects (async-02/04/08/10) will NOT fire any tell — find them in READ.
   Engine + rule-file format + degradation: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. For each view that
   loads data, build an inventory: the load trigger (`.task`/`.onAppear`/button), the four states it
   renders (loading/loaded/empty/error), whether its writes are guarded against stale results, and whether
   remote images / refresh / skeleton are present. Absence is the finding here.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty**. The absence defects are certain by inspection (the state is simply not there); lifecycle and
   isolation seams route a `cross_ref`.
5. **VERIFY.** For anything ≤ ~70% confidence (a floor you can't place, a behavior claim, "is this the
   native shape"), run **both** evidence sources. (a) **Practice** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
   lookup <api> --json` (and `swiftui-ctx deprecated <api>` for a currency claim): read its `consensus`
   (the canonical shape), `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and
   `co_occurs_with`. For this domain, `swiftui-ctx recipe cached-async-image` gives the consensus AsyncImage
   loader. (b) **Spec** — confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using
   `references/source-directory.md` for the path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`
   for the protocol (never `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against
   `floors-master.md`. The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
   Promote with the citation or discard.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit `cross_ref` on the lifecycle/isolation and model-location seams. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (async-01 the mechanical `Task{}`-in-`onAppear` → `.task` rewrite when the
   captured state is already `Sendable`/`@MainActor`-safe; everything else `flag-only`), one conventional
   commit per finding citing its `rule_id`, never weaken a check. The ✅ "Correct" is **not a hand-written
   snippet** — it is the swiftui-ctx **consensus shape** in `## Correct`, backed by a real macOS-26 example
   fetched with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub
   permalink (plus the Sosumi `doc:`) goes in `## Source`. Leave `flag-only` findings `open` with that ✅.
8. **DOUBLE-CHECK.** Re-grep / re-run the runner on each fixed file to confirm the tell no longer matches;
   record the evidence in `## Fix applied?`. Re-confirm every citation still resolves. If an async-01 fix
   added a `.task(id:)` that now needs a generation guard (async-09), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Absence defects are certain by inspection; behavior/floor
doubts go to VERIFY (step 5) first. Auto-fix only async-01 (and only when the captured state is already
`Sendable`/main-actor-safe — otherwise `flag-only` + `cross_ref: concurrency-safety`); everything else is
`fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/async-data/<context>/NN-slug.md` (one finding per file, zero-padded, ordered).
  Per-run index: `swiftui-audits/async-data/_index.md`.
- `domain: async-data`. Frontmatter is the canonical schema; `fix_mode` is `auto` only for the mechanical
  async-01 rewrite, else `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL
  + access date (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` on seam findings
  (concurrency-safety lifecycle/isolation; state-observation model location).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `lifecycle/` | a bare `Task` in `.onAppear`, or any view-lifecycle work not bound to `.task`/`.task(id:)` (async-01) |
| `stale-results/` | rapid `.task(id:)`/selection writes with no generation or cancelled-task guard (async-09) |
| `loading-state/` | no loading indicator / no `.redacted(.placeholder)` skeleton during the fetch (async-02, async-10) |
| `error-state/` | a swallowed `try? await` or any load with no error surface (async-03) |
| `empty-state/` | a collection rendered with no empty-case view (async-04) |
| `networking/` | raw `URLSession` in the view layer, on-main decode, or un-isolated write (async-05) |
| `search-debounce/` | a `.searchable` query that fires a request per keystroke (async-06) |
| `remote-images/` | `AsyncImage` failure phase ignored or no cache in a list/grid (async-07) |
| `refresh/` | a primary async list with no `.refreshable` (async-08) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/async-data/` with a lowercase-hyphen slug naming the sub-category, and note it in the run's
`_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a hard
requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/lifecycle-and-cancellation.md` | the `Task`→`.task` lifecycle fix, `.task(id:)` restart, cancellation, the generation/stale-result guard (async-01, async-09) |
| `references/load-states-and-skeletons.md` | the four states — loading/empty/error — and `.redacted(.placeholder)` skeletons; the swallowed-error trap (async-02/03/04/10) |
| `references/networking-and-images.md` | raw `URLSession` isolation, `.searchable` debounce, `AsyncImage` phases + caching, `.refreshable` (async-05/06/07/08) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (for any availability gate on an async API) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`recipe`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (concurrency-safety, state-observation, swiftdata) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-async-data --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, async-01/03/05/06/07/08/10) + **tier-2
ast-grep** structural rules (`lint/ast-grep/*.yml` — async-01 Task-in-onAppear containment, async-07
AsyncImage url-only shape) that grep cannot express. It runs a per-file **parse probe** (surfaces "did not
fully parse" so a structural miss can't look clean), emits unified **JSON + SARIF**, and **degrades to
grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`; faster:
`brew install ast-grep`). The **absence** defects (async-02/04/08/10) fire NO tell — they are found in READ
(step 3). It only LOCATES — always READ each hit in full before reporting. The thin `scripts/async-lint.sh`
is a pointer to this runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
