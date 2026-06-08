---
name: audit-swiftui-state-observation
description: Audits a finished or in-progress macOS SwiftUI codebase for state and observation defects — wrong ownership wrappers, mixed Observation worlds, and observation-killing view shapes — and writes per-finding Markdown to swiftui-audits/. Use when the user says state resets, a counter "won't count", a view "won't update", or re-renders too much; when they ask to verify @Observable, @State, @StateObject, @ObservedObject, @Bindable, @EnvironmentObject, @Environment(Type.self), or @Published on a Mac target; or when AI wrote @ObservedObject var x = Model(), an @Observable class still conforming to ObservableObject or carrying @Published, @StateObject on a struct, @EnvironmentObject for an @Observable model, $obj.prop with no @Bindable, or a computed some View property reading the model. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for SwiftData @Query, @Observable actor-isolation, over-broad-observation render cost as a perf budget, the blanket availability sweep, or writing new state code from scratch.
---

# Audit SwiftUI State and Observation

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way state ownership and `@Observable` observation
go wrong: the wrong ownership wrapper, the two Observation worlds mixed illegally, missing `@Bindable`
projection, environment injected the legacy way, and view shapes that defeat field-granular
observation. Findings are written to disk in the toolkit's unified schema; only the genuinely
mechanical defects are fixed under the fix-safety protocol. This is never a from-scratch state
generator.

Where state lives and how it's observed is the single most **error-dense** area of AI-written SwiftUI.
The data-flow rules changed in **macOS 14** (the `@Observable` macro); most training data predates that
split, so AI defaults to the legacy `ObservableObject` + `@Published` + `@StateObject` world, mixes the
two worlds illegally, and pairs the wrong wrapper with each model kind. **Two failure shapes** result —
know which you're looking at, because it *is* half the fix:

- **SILENT runtime reset** — a wrong-but-*legal* ownership wrapper on a real `ObservableObject`
  (compiles, then quietly resets state on every parent re-render). No crash, no error.
- **HARD compile error** — a legacy wrapper that *requires* `ObservableObject` conformance placed on an
  `@Observable` type (which does not conform).

## Boundary / seam note (stay in lane)

- **`@Observable` actor-isolation / `@MainActor` correctness** belongs to `audit-swiftui-concurrency-safety`.
  This skill flags a missing `@MainActor` on a view-only `@Observable` as a one-line note and emits a
  `cross_ref` — it does not audit Sendable/isolation hazards.
- **Over-broad-`@Observable` observation as a *render-cost budget*** belongs to `audit-swiftui-view-performance`.
  This skill owns the **state-correctness / granularity** angle of the computed-`some View` smell (state-07)
  and `cross_ref`s view-performance for the cost measurement; don't double-own the perf number.
- **`@Query` / SwiftData model fetches** belong to `audit-swiftui-swiftdata`; **`.task`/`onChange`
  lifecycle** to `audit-swiftui-async-data`; **preview sample-model injection** to `audit-swiftui-previews`.
  Where state lives is ours; how it's fetched/awaited/previewed routes out (`cross_ref`).
- **The blanket "is every OS-floored API gated" sweep** belongs to `audit-swiftui-availability-gating`;
  this skill gates the `@Observable`-era symbols it touches (floor `macOS 14`, `Observations` `macOS 26`)
  and defers non-state gating there.

## The two worlds — pick ONE per model

1. **Modern (default for new Mac code).** `@Observable final class` — **no** `@Published`, **no**
   `ObservableObject` conformance. Field-granular: a view invalidates only when the property it actually
   reads changes. Own with `@State`, bind with `@Bindable`, inject with `.environment(_:)` +
   `@Environment(Type.self)`.
2. **Legacy (only for Combine publishers / back-deployment below macOS 14).** `class: ObservableObject`
   + `@Published`. Whole-object `objectWillChange` over-renders. Own with `@StateObject`, observe with
   `@ObservedObject`, inject with `@EnvironmentObject`. **Not deprecated** — confirmed
   `deprecated:false` in the swiftui-ctx corpus — but not the idiom for new Mac code; a `@StateObject`
   holding a *plain* `@Observable` is a **migration smell**, not a hard error.

**The ownership test:** does *this view* create the model (`= Model()`)? → it **owns** it → `@State`
(modern) / `@StateObject` (legacy). Is the model **passed in / injected**? → `@Bindable` (modern, needs
bindings) / `@ObservedObject` (legacy). **Never initialize a model inside `@ObservedObject`/`@Bindable`.**
Full reasoning + the two-shape decision: `references/ownership-wrappers.md`.

### ✅ Correct — the grounded modern shape (real shipping code, not a placeholder)

The ✅ for the whole modern world is one real, permalinked consensus shape — `@Observable` (+ `@MainActor`)
on a `final class`, plain stored `var`s, **no** `@Published`, **no** `ObservableObject` (verified
`deprecated:false`, `introduced_macos:14.0`). This is the canonical target every wrong-wrapper fix
converges to; reproduce it from swiftui-ctx live during FIX, never hand-write it.

```swift
// swiftui-ctx lookup Observable → recommended ex_44cfa1bff8 (author_authority 165155, min_macos 14)
// permalink: https://github.com/Gremble-io/Detto/blob/ed96effda1699a8ef4aa2868f7f7a244f4f45fcf/Detto/Sources/Detto/App/MenuBarIcon.swift#L3
// doc: https://sosumi.ai/documentation/swiftui/observable
@Observable @MainActor
final class MenuBarAnimator {
    private let state: DictationState
    private var timer: Timer?          // bookkeeping — not read in a body; carries no @Published
    var wavePhase: Double = 0          // plain stored var → field-granular invalidation, no @Published
    var spinnerAngle: Double = 0
    init(state: DictationState) { self.state = state }
}
// owned by its view with `@State private var animator = MenuBarAnimator(state:)`,
// bound with `@Bindable`, injected with `.environment(_:)` + `@Environment(MenuBarAnimator.self)`.
```

Re-derive (don't trust this transcription) with
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Observable --json` then
`swiftui-ctx file <recommended.id> --smart`; if `lookup` exits 3 for the symbol you're fixing, pick
another concrete API from the defect index and look that up instead.

## Defect index (state-01 … state-12)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct),
**warning** (compiles but wrong/silent-bug), **advisory** (smell / perf / judgment). `auto` = mechanical
single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| state-01 | `@ObservedObject var x = Type()` — initializer on a non-owning wrapper | warning¹ | flag | `ownership-wrappers.md` |
| state-02 | `@Observable class … : ObservableObject` — redundant/contradictory conformance | warning | auto | `mixing-worlds.md` |
| state-03 | `@Published` inside an `@Observable`-annotated class | warning | auto | `mixing-worlds.md` |
| state-04 | `@StateObject` on a `struct`/`enum` (compile error); on a plain `@Observable` (smell) | warn²/adv | flag | `ownership-wrappers.md` |
| state-05 | `@EnvironmentObject` in a file whose model is `@Observable` | warning | flag | `environment-injection.md` |
| state-06 | `$obj.prop` on a non-owned `@Observable` with no `@Bindable` re-wrap nearby | warning | flag | `binding-and-bindable.md` |
| state-07 | `private var x: some View {` computed property that reads an `@Observable` model | advisory | flag | `observation-granularity.md` |
| state-08 | `@StateObject`/`@ObservedObject`/`@Published` kept after an `@Observable` migration | warning | flag | `mixing-worlds.md` |
| state-09 | heavy `init()` in a `@State` default of a frequently-re-evaluated view (row/cell) | advisory | flag | `model-lifecycle.md` |
| state-10 | `static let shared` app-state singleton / per-window state forced global | advisory | flag | `model-lifecycle.md` |
| state-11 | mutable cache / back-pointer in an `@Observable` with no `@ObservationIgnored` | advisory | flag | `observation-granularity.md` |
| state-12 | view-only `@Observable` with no `@MainActor` (older default-isolation builds) | advisory | flag | `model-lifecycle.md` |

¹ **state-01 is the headline two-shape defect** (read the model kind to pick the shape, the fix, AND the
severity): the initializer on `@ObservedObject` is a **SILENT runtime reset** if `Type` is a real
`ObservableObject` (warning — compiles, recreated every re-render) and a **likely COMPILE error** if
`Type` is `@Observable` (hard-fail in practice — Apple: *"may cause a compiler error"* because
`@ObservedObject` requires `ObservableObject` conformance, which `@Observable` does not provide; Apple
hedges with "may" — treat it as a build break but preserve the hedge when reporting). Same tell, opposite
`failure_shape`. ² state-04 is hard-fail (compile) on a value
type; advisory (migration smell) on a plain `@Observable`.

## The real API, at a glance

**Real, modern (`@Observable` world):** `@Observable` (macOS 14), `@State` (macOS 10.15),
`@Bindable` (macOS 14), `@Environment(Type.self)` + `.environment(_:)`, `@ObservationIgnored`
(macOS 14), `Observations` async sequence (**macOS 26**, for reacting to changes *outside* a view body).
**Real, legacy (`ObservableObject` world):** `@StateObject`, `@ObservedObject`, `@EnvironmentObject`,
`@Published`, `.environmentObject(_:)` — all real, **not deprecated**, just not the new-code idiom.

No state/observation symbol in this domain is hallucinated — the defects are **wrong-wrapper / wrong-world
pairings of real symbols**, not invented names (contrast `audit-swiftui-liquid-glass`). Floor *values*
are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (read, never
restate); the canonical invented-name list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`. Signatures, the per-wrapper
floors, and the full ❌→✅ rewrites: `references/*.md`.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   the whole `@Observable` world requires **macOS 14**; `Observations` requires **macOS 26**; below the
   floor, the legacy world is the *correct* default, not a smell. Record the floor and whether
   `SWIFT_DEFAULT_ACTOR_ISOLATION`/"Default Actor Isolation = MainActor" is on (governs state-12).
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-state-observation --dir <sources> --json /tmp/state.json --sarif /tmp/state.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the missing-`@Bindable` and computed-`some View` rules grep can't express),
   plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a
   flagged file did not fully parse, so a structural miss can't masquerade as clean; READ those by hand.
   The runner only LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. The model's
   **kind** (real `ObservableObject` vs `@Observable` vs value type), whether *this view* creates vs
   receives it, and whether a `@Bindable` re-wrap exists elsewhere in the same `body` are all invisible
   to grep and **decide the finding**. Build a per-file inventory: each model + its kind + its owner
   wrapper + whether it's owned-here-or-passed-in.
4. **DETECT.** Apply the index. The pivot for state-01/04/05/06/08 is **the model kind** — find the
   `class` declaration and check for `@Observable` vs `: ObservableObject`. Assign each candidate a
   **confidence**; report a finding **only at 100% certainty** (a clear two-world mix, an initializer on
   a non-owning wrapper of a known kind, a `$obj.prop` with no nearby `@Bindable`).
5. **VERIFY.** For anything ≤ ~70% confidence (a wrapper floor you can't place, a behavior claim, a
   "does this still compile" doubt), run BOTH evidence sources:
   - **Practice — swiftui-ctx:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json`
     (read `consensus`, `recommended`, `co_occurs_with`, `introduced_macos`, `deprecated`) and, for any
     "is this deprecated" doubt, `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated <api>`. A
     `lookup` **exit 3** corroborates a hallucination (no real Mac app uses it).
   - **Spec — Sosumi:** `curl -sSL https://sosumi.ai/<apple-path>` for floor/signature, via
     `references/source-directory.md` for the path and
     `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
     `developer.apple.com`).
   Cross-check the floor against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. Promote
   with the citation or discard; flag any residual doubt `source: verify against Xcode 26 SDK`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Set `model_kind` + `failure_shape` (the additive fields). Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (state-02 drop redundant `: ObservableObject`, state-03 drop `@Published`
   under `@Observable`), one conventional commit per finding citing its `rule_id`, never weaken a check.
   The ✅ "Correct" is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape** + a
   **`file <recommended.id> --smart` GitHub permalink** (see references; each routes the exact `lookup`).
   Leave `flag-only` findings `open` with the ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep / re-read each fixed file to confirm the tell no longer matches; record the
   evidence in `## Fix applied?`. Re-confirm every floor citation still resolves and still says
   `macOS 14.0` (or `26.0` for `Observations`). If a fix introduced a new tell (e.g. dropping
   `@StateObject` for `@State` on a model still conforming to `ObservableObject`), loop that file back to
   DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. The certainty pivot is **the model kind** — a wrapper
mismatch you can't classify (is `Type` an `ObservableObject` or `@Observable`?) is ≤ ~70% and goes to
VERIFY (step 5) before it can become a finding; never emit a speculative finding. Auto-fix only the
mechanical, single-answer set (state-02, state-03); everything else is `fix_mode: flag-only` — wrapper
swaps depend on ownership intent only a human can confirm.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/state-observation/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/state-observation/_index.md`.
- `domain: state-observation`. **Additive fields** (catalogued for this domain in the finding schema):
  `model_kind` (`observable` | `observableobject` | `value` | `unknown`) + `failure_shape`
  (`silent-reset` | `compile-error` | `over-render` | `migration-smell` | `lost-restoration`). `fix_mode`
  is `auto` for state-02/03, else `flag-only`. `availability` reads from `floors-master.md`. `source` is
  an Apple URL + access date (fetched via Sosumi) or `verify against Xcode 26 SDK`.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `ownership-wrapper/` | wrong owner for the model kind — initializer on a non-owning wrapper, `@StateObject` on a struct (state-01, state-04) |
| `mixing-worlds/` | the two worlds are crossed — `@Observable` + `: ObservableObject`/`@Published`, or legacy wrappers kept after migration (state-02, state-03, state-08) |
| `binding-projection/` | a non-owned `@Observable` is missing its `@Bindable` re-wrap for `$obj.prop` (state-06) |
| `environment-injection/` | an `@Observable` model is injected/read the legacy `@EnvironmentObject` way (state-05) |
| `observation-granularity/` | a computed `some View` reading the model, or a missing `@ObservationIgnored` (state-07, state-11) |
| `model-lifecycle/` | heavy `@State` init, a `static let shared` singleton / forced-global per-window state, or missing `@MainActor` (state-09, state-10, state-12) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/state-observation/` with a lowercase-hyphen slug naming the sub-category, and note it in
the run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

> **Go-beyond artifact (optional):** `swiftui-audits/state-observation/_world-map.md` classifying every
> model `class` as `modern`/`legacy`/`mixed` with its owner wrapper and a per-model ownership verdict —
> see `references/mixing-worlds.md`.

## Reference routing

| File | Open when |
|---|---|
| `references/ownership-wrappers.md` | the two failure shapes, the ownership test, initializer-on-non-owning-wrapper, `@StateObject`-on-a-value-type (state-01, state-04) |
| `references/mixing-worlds.md` | the `@Observable`/`ObservableObject` two-world split, redundant conformance, `@Published`, the not-a-drop-in migration, the world-map (state-02, state-03, state-08) |
| `references/binding-and-bindable.md` | `@Binding` vs `@Bindable`, projecting `$obj.prop`, the local re-wrap (state-06) |
| `references/environment-injection.md` | type-keyed `.environment`/`@Environment(Type.self)` vs legacy `@EnvironmentObject`, scene-level macOS injection (state-05) |
| `references/observation-granularity.md` | computed-`some View` invalidation cost, child-`View`-type extraction, `@ObservationIgnored` (state-07, state-11) |
| `references/model-lifecycle.md` | `@State` re-instantiation, app/scene-scoped ownership, the macOS multi-window / no-`static let shared` rule, `@MainActor` discipline (state-09, state-10, state-12) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map (Sosumi) + the swiftui-ctx `lookup`/`recipe` entry points for canonical shapes |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (no state symbol is on it) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule for the macOS-14 / macOS-26 floors |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + the `model_kind`/`failure_shape` additive fields |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc fetch protocol (step 5 VERIFY, spec side) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the swiftui-ctx CLI contract (step 5 VERIFY practice side + step 7 FIX consensus/permalink) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (view-performance, concurrency-safety, swiftdata, async-data, previews) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-state-observation --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
state-01/02/03/04/05/06/08/09/10/11) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` —
state-06 `$obj.prop` with no `@Bindable` re-wrap in the same body, state-07 computed `some View`
property) that grep cannot express. It runs a per-file **parse probe** (surfaces "did not fully parse"
so a structural miss can't look clean), emits unified **JSON + SARIF**, exits **2** on any hard-fail, and
**degrades to grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`;
faster: `brew install ast-grep`). It only LOCATES — always READ each hit in full before reporting
(step 3). The legacy `scripts/state-lint.sh` is a thin pointer to this runner. Engine + rule-file format
+ JSON/SARIF shape + safety rails: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
