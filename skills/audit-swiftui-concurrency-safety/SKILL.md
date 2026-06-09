---
name: audit-swiftui-concurrency-safety
description: Audits a finished or in-progress macOS SwiftUI codebase for Swift 6 / 6.2 data-race-safety and actor-isolation defects, writing per-finding Markdown to swiftui-audits/. Use when the build errors with "non-Sendable" or "main actor-isolated property can not be referenced from a Sendable closure", or data-race warnings became errors after a Swift 6 bump; when verifying Sendable, actor isolation, @MainActor, Task.detached, DispatchQueue.main.async, nonisolated(nonsending), or -default-isolation MainActor; when AI sprinkled @MainActor everywhere or assumed Swift 6.2 makes everything main-actor-by-default; or when Transferable / loadTransferable drag-drop stopped compiling under strict checking. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for the async-data loading lifecycle (.task vs onAppear), not the SwiftData @ModelActor fix, not the AppKit bridge implementation, not the general availability sweep, not writing new concurrent code from scratch.
---

# Audit SwiftUI Concurrency Safety

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way Swift concurrency goes wrong: non-`Sendable`
types crossing actor boundaries, `@Sendable` closures touching main-actor state, the
`DispatchQueue.main.async` cargo-cult, lifecycle-leaking `Task`s, `@MainActor` spam, the Swift 6.2
opt-in misreads (`@concurrent` / `nonisolated(nonsending)` / `NonisolatedNonsendingByDefault`), and
non-`Sendable` `Transferable` payloads. Findings are written in the toolkit's unified schema; the one
mechanical defect (`DispatchQueue.main.async`) is fixed under the fix-safety protocol. This is never a
from-scratch concurrency generator.

Concurrency is the toolkit's **most version-sensitive domain** — the rules changed twice in twelve
months and most training data predates both changes. **This is a CROSS-CUTTING SWEEP:** it owns the
*isolation verdict* wherever concurrency hazards appear, and routes the lifecycle / model / bridge fix
to the owning sibling.

## Two eras — keep them apart or every fix is wrong

- **Swift 6 language mode (Sept 2024) = strict DATA-RACE-SAFETY CHECKING by default.** Old warnings
  (non-`Sendable` crossing an actor, main-actor state in a `@Sendable` closure) are now **hard
  errors**. The default is *checking*, not isolation. **Opt-in per target** (`SWIFT_VERSION = 6` /
  `swiftLanguageMode(.v6)`) — projects stay on their declared mode until bumped.
- **Swift 6.2 (Sept 15 2025) = an OPT-IN "main actor by default" build mode**
  (`-default-isolation MainActor`, surfaced as *Approachable Concurrency* + *Default Actor Isolation =
  Main Actor*). A setting you turn on, **NOT** the unconditional default. AI conflates the two →
  `@MainActor` spam OR code that assumes isolation it never enabled.

Record which mode the **target** is in (ORIENT, step 1) — half the findings depend on it. Toolchain
facts (`@concurrent`, `nonisolated(nonsending)`, `-default-isolation MainActor`, the
`NonisolatedNonsendingByDefault` flag) are **Swift 6.2+** and verified against swift.org / Swift
Evolution, not swiftui-ctx.

## Boundary / seam note (stay in lane)

This skill owns the **isolation VERDICT**; the fix shape often belongs to a sibling. Emit a `cross_ref`
on every shared-seam finding (targets + primary-owner verdicts derive from
`${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` — do not restate them):

- **`Task` in `.onAppear` / `.onChange`** (conc-04, conc-10): **`async-data` owns the lifecycle fix**
  (`.task` / `.task(id:)`). THIS skill owns the verdict **only when an isolation hazard is present**
  (a non-`Sendable` capture, an off-actor mutation). `cross_ref: audit-swiftui-async-data`.
- **SwiftData `@Model` mutation off-context** (conc-11): **`swiftdata` prescribes `@ModelActor`**; this
  skill flags the race and routes. `cross_ref: audit-swiftui-swiftdata`.
- **`loadTransferable` / `Transferable` Sendable race** (conc-09): **THIS skill owns Sendable
  correctness** (primary); `sandbox-files` owns consent/bookmark. `cross_ref: audit-swiftui-sandbox-files`.
- **AppKit `Coordinator` / `NSViewRepresentable` boundary**: `appkit-overuse` owns *whether* the bridge
  exists, `appkit-interop` owns *how*. This skill flags only the Sendable/isolation hazard at the
  boundary. `cross_ref: audit-swiftui-appkit-interop`.
- **`@MainActor` on an `@Observable`** (conc-06): `state-observation` owns model-correctness; this skill
  owns the isolation angle. `cross_ref: audit-swiftui-state-observation`.

## Defect index (conc-01 … conc-11)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (errors under the Swift 6
language mode / never-correct), **warning** (compiles but unsafe / non-native), **advisory** (judgment
/ toolchain-gated). `auto` = mechanical single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| conc-01 | `Task.detached { … }` carrying a non-`Sendable` class / `ModelContext` / `NSView` across the boundary | warning | flag | `strict-checking-and-sendable.md` |
| conc-02 | `@Sendable` closure body reads `self.` / a `@MainActor` property ("can not be referenced from a Sendable closure") | warning | flag | `strict-checking-and-sendable.md` |
| conc-03 | `DispatchQueue.main.async` inside async / SwiftUI code (GCD cargo-cult) | warning | auto | `main-actor-hops.md` |
| conc-04 | bare `Task { }` in `.onAppear` / `.onChange` — not lifecycle-bound, not cancelled | warning | flag | `main-actor-hops.md` |
| conc-05 | `@MainActor` on a pure-value `struct`/`enum`/free `func` (isolation spam) | advisory | flag | `isolation-modes-and-execution.md` |
| conc-06 | `@Observable` UI type with **no** `@MainActor` while assuming "6.2 does it" | advisory | flag | `isolation-modes-and-execution.md` |
| conc-07 | `@concurrent` present — confirm the target is **Swift 6.2+** | advisory | flag | `isolation-modes-and-execution.md` |
| conc-08 | plain `nonisolated … func … async` assumed to run in the caller's context "because 6.2" | advisory | flag | `isolation-modes-and-execution.md` |
| conc-09 | `Transferable` / `loadTransferable` payload wraps a reference / non-`Sendable` type | warning | flag | `strict-checking-and-sendable.md` |
| conc-10 | rapid post-`await` writes (selection/refresh) with no cancel + generation guard → stale overwrite | advisory | flag | `main-actor-hops.md` |
| conc-11 | `@Model` / `modelContext` mutation inside `Task.detached` (off-context race) | warning | flag | `strict-checking-and-sendable.md` |

**UNVERIFIED / toolchain-gated — carry as `advisory` and never assert as Swift-6.0/6.1 fact** (each
becomes `source: verify against Xcode 26 SDK`): everything that needs **Swift 6.2+** —
`@concurrent` (conc-07), `nonisolated(nonsending)` and the `NonisolatedNonsendingByDefault` default
flip (conc-08), the `-default-isolation MainActor` mode (conc-05/06). Whether the target is in either
era is read in ORIENT, not assumed.

## The real API, at a glance

**Real & era-stable (back-deploy to `macOS 10.15+`):** `@MainActor`, `Sendable`, `MainActor.run`,
`Task.detached`, `sending`, `@preconcurrency import`. **`.task` / `.task(id:)`** is `macOS 12.0+`; its closure
inherits the caller's isolation via `@isolated(any)`. **Swift 6.2+ only** (verify the toolchain): `@concurrent` (ALWAYS the global
executor), `nonisolated(nonsending)` (ALWAYS the caller's context, SE-0461), `-default-isolation
MainActor`, the `NonisolatedNonsendingByDefault` upcoming-feature flag, `Task(name:)`.

**The trap that is NOT a default:** a plain `nonisolated async` function still **hops to the global
executor** (SE-0338) — it stays on the caller's context *only* when `NonisolatedNonsendingByDefault`
is enabled. `@concurrent` and `nonisolated(nonsending)` behave the same with or without the flag.

Floor *values* are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
(read, never restate). There is no hallucinated-API surface here — concurrency defects are isolation
*mistakes on real symbols*, not invented names.

## ✅ Correct — the grounded lifecycle shape (the anchor every fix imitates)

The most common concurrency defect (conc-04) is a bare `Task { }` in `.onAppear` — unbound to view
lifetime, never cancelled. The lifecycle-correct shape is `.task` / `.task(id:)` (`macOS 12.0+`,
caller-isolation-inheriting via `@isolated(any)`, auto-cancelled on disappear). This is the **real consensus shape**, not a
hand-written snippet — verified live via `swiftui-ctx lookup task` (step 5): **`.task { }` 70% ·
`.task(id:)` 29%** across the corpus.

```swift
// ❌ leaks — never cancelled, re-runs on every re-appear, races a fast-toggling view
.onAppear { Task { activity = isActive ? begin(options, reason) : nil } }

// ✅ bound to view lifetime, auto-cancelled, re-keyed on input change
.task(id: Tuple3(isActive, options, reason)) {
    activity = isActive ? SSApp.beginActivity(options, reason: reason) : nil
}
```

- **Real example** (`swiftui-ctx file ex_a1cff2419c --smart`): `sindresorhus/Gifski` —
  https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Utilities.swift#L5590
- **doc:** https://sosumi.ai/documentation/swiftui/view/task(name:priority:file:line:_:) (`.task` floor `macOS 12.0+`)
- **Note the seam:** the lifecycle *fix* (`.task`) is `async-data`'s to prescribe — this skill owns the
  isolation verdict only when the captured value is non-`Sendable` or main-actor state is mutated
  off-context. Every ✅ in a written finding is reproduced this way: the consensus shape in `## Correct`,
  a permalinked `swiftui-ctx file … --smart` example + this `doc:` in `## Source` (step 7 FIX).

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read **(a)** the Swift language mode
   (`SWIFT_VERSION` in `project.pbxproj`, or `swiftLanguageMode` / `swift-tools-version` in
   `Package.swift`) and **(b)** whether the opt-in mode is on (`SWIFT_DEFAULT_ACTOR_ISOLATION =
   MainActor` / `-default-isolation MainActor` / `Approachable Concurrency`). Both are **load-bearing**:
   conc-01/02/09/11 are *errors* only under the Swift 6 language mode; conc-05/06 flip meaning under the
   opt-in mode; conc-07/08 require Swift 6.2+. Record the `swift_era`.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-concurrency-safety --dir <sources> --json /tmp/conc.json --sarif /tmp/conc.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the Task-in-`onAppear` and off-context-`@Model` containment rules grep can't
   express), plus a per-file **parse probe**, emitting unified JSON + SARIF. **Read its
   `parse_warnings`** — a flagged file did not fully parse, so a structural miss can't masquerade as
   clean; READ those by hand. The runner only LOCATES. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — actor isolation, closure capture lists, gate scope,
   and the `@Sendable`-vs-`@MainActor` interplay are invisible to grep. Build a per-file inventory: each
   crossing site + what type crosses + the receiving actor + which era's rule applies.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (a non-`Sendable` class in `Task.detached`, a `DispatchQueue.main.async` in async code,
   an `@Observable` UI type with no isolation under an OFF opt-in mode). Tag `isolation_kind` +
   `swift_era`.
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol's existence/floor, "does this run on the caller
   or the pool", whether a type is `Sendable`), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and `swiftui-ctx deprecated <api>`
   for a currency rule): read its `consensus` (the canonical shape), `recommended` permalink,
   `introduced_macos`, and `co_occurs_with`; an exit-3 corroborates an invented spelling. (b) **Spec** —
   for an **API floor / signature** confirm via **Sosumi** (`curl -sSL https://sosumi.ai/<apple-path>`
   using `references/source-directory.md` for the path + `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`
   for the protocol; never `WebFetch developer.apple.com`); for a **toolchain / isolation-semantics**
   fact (`@concurrent`, `nonisolated(nonsending)`, the flag, the language-mode default) the spec source
   is **swift.org / Swift Evolution (SE-0338, SE-0461)** in `references/source-directory.md`, NOT
   swiftui-ctx. Cross-check `introduced_macos` against `floors-master.md`. Promote with the citation or
   discard; carry toolchain-gated items as `advisory` with `source: verify against Xcode 26 SDK`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (conc-03 `DispatchQueue.main.async` → `await MainActor.run` /
   `@MainActor`), one conventional commit per finding citing its `rule_id`, never weaken a check. The ✅
   "Correct" is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape** put in
   `## Correct`, backed by a real macOS-26 example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the swift.org / Sosumi `doc:`) goes in `## Source`. Leave `flag-only` findings `open` with that
   ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves. If a fix introduced a new tell (a
   `MainActor.run` you added now needs an `await`, or a removed `Task.detached` leaves a non-`Sendable`
   capture), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5). Whether the
target is in the Swift 6 language mode / opt-in mode is **read in ORIENT, never assumed** — an
era-dependent finding without a confirmed era is at best `advisory`. Auto-fix only conc-03; everything
else is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/concurrency-safety/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/concurrency-safety/_index.md`.
- `domain: concurrency-safety`. `fix_mode` is `auto` only for conc-03, else `flag-only`. **Additive
  fields** (per `finding-schema.md` §4 — concurrency-safety owns these): `swift_era:`
  (`swift6-checking` | `swift6.2-optin` | `era-independent`) and `isolation_kind:` (`boundary-crossing`
  | `sendable-closure` | `gcd-cargo-cult` | `lifecycle-task` | `mainactor-spam` | `nonisolated-misread`
  | `transferable-sendable` | `modelactor-race`). MUST use `swift_era`, never `era` (that is
  api-currency's). `source` is a swift.org / Swift-Evolution / Apple URL + access date, or `verify
  against Xcode 26 SDK`.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `sendable-crossing/` | a non-`Sendable` type crosses an actor (conc-01), or a `@Model` mutates off-context (conc-11) |
| `sendable-closures/` | a `@Sendable` closure touches main-actor state (conc-02) |
| `main-actor-hops/` | a `DispatchQueue.main.async` cargo-cult or un-batched post-async write (conc-03) |
| `task-lifecycle/` | a bare `Task` in `.onAppear`/`.onChange`, or a stale-result race (conc-04, conc-10) |
| `isolation-modes/` | `@MainActor` spam, a missing-isolation `@Observable`, or an opt-in-mode misread (conc-05, conc-06) |
| `execution-semantics/` | `@concurrent` / `nonisolated(nonsending)` / `nonisolated async` caller-context confusion (conc-07, conc-08) |
| `transferable-sendable/` | a `Transferable` / `loadTransferable` payload isn't `Sendable`-correct (conc-09) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/concurrency-safety/` with a lowercase-hyphen slug, and note it in the run's `_index.md`.
Prefer an existing folder when the fit is reasonable; consistency across runs is a hard requirement.*
Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/strict-checking-and-sendable.md` | a Sendable-crossing, `@Sendable`-closure, `Transferable`, or off-context-`@Model` question — the Swift 6 strict-checking era (conc-01/02/09/11) |
| `references/main-actor-hops.md` | a GCD cargo-cult, the `.task`-vs-`Task` lifecycle, `MainActor.run` batching, or a stale-result generation guard (conc-03/04/10) |
| `references/isolation-modes-and-execution.md` | the Swift 6.2 opt-in confusion, `@MainActor` spam, `@concurrent`, and the `nonisolated(nonsending)` / `NonisolatedNonsendingByDefault` execution-context trap (conc-05/06/07/08) |
| `references/source-directory.md` | step VERIFY — the swift.org / Swift-Evolution / Apple source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + the `swift_era`/`isolation_kind` additive fields |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (async-data · swiftdata · sandbox-files · appkit-interop · state-observation) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (for any availability gate on a 6.2 API) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-concurrency-safety --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
conc-01/02/03/04/05/06/07/08/09) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` —
conc-04 `Task`-in-`onAppear` containment, conc-11 `@Model`-mutation-in-`Task.detached` co-occurrence)
that grep cannot express. conc-10 (a *missing* generation guard) is intentionally **read-only** — no
lint tell can prove an absence; READ rapid-trigger sites by hand. It runs a per-file **parse probe**,
emits unified **JSON + SARIF**, and **degrades to grep-only with a notice** if ast-grep is unreachable
(`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES — always
READ each hit in full before reporting (step 3). The legacy `scripts/conc-lint.sh` is a thin pointer to
this runner. Engine + rule-file format + JSON/SARIF shape:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
