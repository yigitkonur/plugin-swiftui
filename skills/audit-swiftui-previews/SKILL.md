---
name: audit-swiftui-previews
description: Audits a finished or in-progress macOS SwiftUI codebase for broken #Preview / Xcode-canvas defects and writes per-finding Markdown to swiftui-audits/. Use when the user says a preview is blank, crashes the canvas, or won't compile; when they ask to verify #Preview, PreviewProvider, @Previewable, @Entry, EnvironmentKey, preview traits, PreviewModifier, or .modifier(_:); when AI may have written a legacy PreviewProvider struct, bare @State/@Binding/@Bindable in a #Preview body without @Previewable, hand-rolled EnvironmentKey boilerplate, Preview(windowStyle:) on a Mac target, .environmentObject for an @Observable, or a .frame sizing hack in a preview; when a #Preview of a @Query / SwiftData view ships no in-memory ModelContainer; or when a #Preview reads @Environment with no injection. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for SwiftData model design, not for live-app @Observable wiring, not for the blanket availability sweep, not for writing new previews from scratch.
---

# Audit SwiftUI Previews

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way the `#Preview` macro and the Xcode canvas go
wrong: the legacy `PreviewProvider` struct, bare `@State`/`@Binding`/`@Bindable` in a `#Preview` body
without `@Previewable`, hand-rolled `EnvironmentKey` boilerplate instead of `@Entry`, the visionOS-only
`Preview(windowStyle:)` overload, manual `.frame` sizing instead of traits, the wrong `.environmentObject`
injector, and the two **canvas-crash** traps (a `@Query`/SwiftData view with no in-memory container, an
`@Environment`-dependent view with no injected dependency). Findings are written to disk in the toolkit's
unified schema; certain mechanical defects are fixed under the fix-safety protocol. This is never a
from-scratch preview generator.

A preview **instantiates the view for real** — so a missing container or `@Environment` dependency traps
*the canvas*, not the app. The preview tooling is also where AI goes stale: it emits the
`PreviewProvider` struct (dominant 2019–2023) and forgets the modern macro era's `@Previewable` / `@Entry`.

## Boundary / seam note (stay in lane)

- **SwiftData *model design*** (`@Model`, schema, relationships, `@ModelActor`) belongs to
  `audit-swiftui-swiftdata`. This skill owns the **preview-construction** angle of the canvas crash (the
  missing in-memory container *in a `#Preview`*); emit `cross_ref: audit-swiftui-swiftdata` and let it own
  the model itself.
- **Live-app `@Observable` wiring** (where the model lives, the sample factory) belongs to
  `audit-swiftui-state-observation`. This skill owns only the **preview injection** of a sample
  `@Observable`; `cross_ref` it for the factory.
- **`@Entry`/`FocusedValueKey`** is a context-conditional seam: if the pattern is co-located with a
  `CommandMenu`/`CommandGroup` → `audit-swiftui-menus-commands` owns it; **in a preview / general
  environment setup → this skill owns it** (per the shared cross-ref graph). `cross_ref` the other way.
- **The blanket "is every floored API gated" sweep** is `audit-swiftui-availability-gating`; **macro
  modernity** (`PreviewProvider`-as-deprecated-era) shares a seam with `audit-swiftui-api-currency`.

## The three non-negotiable preview rules

1. **`#Preview` macro, not `PreviewProvider`.** The freestanding macro is the modern path (Xcode 15+,
   macOS 14+). One `#Preview` declaration per named preview — never the legacy
   `struct …_Previews: PreviewProvider { static var previews }` for new code.
2. **A `#Preview` body is an expanded view scope — tag dynamic state `@Previewable`.** Bare
   `@State`/`@Binding`/`@Bindable` at that scope is a **compile error**; `@Previewable @State var …`
   is the only legal stateful-preview shape.
3. **Previews run real code — inject every dependency.** A `@Query`/SwiftData view needs an in-memory
   `ModelContainer`; an `@Environment(Model.self)` view needs a sample injected with `.environment(_:)`.
   Omit either and the **canvas crashes** on launch.

**The instantiation test:** ask "does this view read state or a dependency the preview never provides?"
If yes, the canvas traps — supply it (`@Previewable`, `.modelContainer(… inMemory: true)`,
`.environment(_:)`). Full reasoning: `references/preview-crashes-and-injection.md`.

## Defect index (prev-01 … prev-09)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (compile error / canvas crash),
**warning** (compiles but stale/non-idiomatic), **advisory** (judgment / polish). `auto` = mechanical
single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| prev-01 | `struct *_Previews: PreviewProvider` (legacy struct for new code) | warning | flag | `preview-macro-and-state.md` |
| prev-02 | bare `@State`/`@Binding`/`@Bindable` in a `#Preview` body, no `@Previewable` | hard-fail | flag | `preview-macro-and-state.md` |
| prev-03 | `struct *Key: EnvironmentKey` + `extension EnvironmentValues` boilerplate (use `@Entry`) | warning | flag | `entry-and-environment.md` |
| prev-04 | manual `.frame(width:height:)` in a `#Preview` body (use a trait) | advisory | flag | `preview-macro-and-state.md` |
| prev-05 | `Preview(…, windowStyle:)` on a Mac target (visionOS-only overload) | hard-fail | flag | `preview-macro-and-state.md` |
| prev-06 | `#Preview` of a `@Query`/SwiftData view, no `.modelContainer(… inMemory: true)` | warning | flag | `preview-crashes-and-injection.md` |
| prev-07 | `#Preview` of a view reading `@Environment(Model.self)`, no `.environment(_:)` injection | advisory | flag | `preview-crashes-and-injection.md` |
| prev-08 | `.environmentObject(…)` in a preview whose model is `@Observable` (wrong injector) | warning | flag | `entry-and-environment.md` |
| prev-09 | repeated `.modelContainer(for:inMemory:true)` + re-seed across many `#Preview`s (use `PreviewModifier`) | advisory | flag | `preview-modifier-shared.md` |

**Two claims need a floor check at audit time — confirm in VERIFY, never assert from memory:** the
`PreviewModifier` / `.modifier(_:)` floor (macOS 15.0+, carried `verify-SDK` in `floors-master.md`); and
that `@Previewable @Query` itself needs macOS 15 (prev-09 fallback path). Both reduce to a gating note,
not a hallucination.

## The real API, at a glance

**Real (exist on macOS):** `#Preview` / `Preview(_:traits:_:body:)` macro (macOS 14.0+), `@Previewable`
(macOS 14.0+), `@Entry` (macOS 10.15+, back-deploys; Xcode 15+ to expand → practical floor macOS 14),
`.fixedLayout(width:height:)` / `.sizeThatFitsLayout` / `.defaultLayout` traits, `PreviewModifier` +
`.modifier(_:)` trait (macOS 15.0+), `.modelContainer(for:inMemory:)`, `.environment(_:)`,
`PreviewProvider` (legacy but **not deprecated** — flag as stale-for-new-code, never as invented).

**Hallucinated / platform-wrong (never on macOS):** `Preview(_:windowStyle:traits:body:)` is
**visionOS-only** — there is no `windowStyle:` `#Preview` overload on macOS; `.environmentObject(_:)`
for an `@Observable` is the **wrong injector** (it takes only an `ObservableObject`).

### ✅ Correct — grounded in real macOS code (swiftui-ctx consensus)

The modern shape, from `swiftui-ctx lookup Preview` → `file <recommended.id> --smart`
(repo `utmapp/UTM`, 34k★) — the freestanding macro, one declaration per named preview, no
`PreviewProvider` struct:

```swift
@available(macOS 13, *)
#Preview {
    UTMServerView()
}
```

- **Source (real permalink):** https://github.com/utmapp/UTM/blob/e4a4c34b671284263fc69f81b607de494d7e9b65/Platform/macOS/UTMServerView.swift#L170
- **Apple doc (Sosumi):** `doc:` https://sosumi.ai/documentation/swiftui/preview (`#Preview` macro, `introduced_macos: 10.15` — DocC inheritance artifact; authoritative Apple docs badge is **macOS 14.0+**, same trap as `Animation.bouncy` in floors files)

This is the live grounding for prev-01: the canonical `#Preview { }` that replaces the legacy
`struct …_Previews: PreviewProvider`. At FIX time, re-fetch the per-defect consensus shape
(`swiftui-ctx file <recommended.id> --smart`) for that defect's exact ✅, never a hand-written snippet.

Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and the canonical invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate them. The
real macOS-26 shape for any symbol comes from `swiftui-ctx lookup <api>` (step 5), not memory.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing
   for prev-09 (`PreviewModifier`/`@Previewable @Query` need macOS 15). Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-previews --dir <sources> --json /tmp/prev.json --sarif /tmp/prev.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + the one tier-2 structural ast-grep
   rule (`lint/ast-grep/prev-02-*.yml` — the bare-`@State`-inside-a-`#Preview`-body containment rule grep
   can't express), plus a per-file **parse probe**, and emits unified JSON + SARIF. (prev-06's
   un-injected-container case stays a grep co-occurrence tell — a precise structural rule would need
   cross-declaration data flow ast-grep can't resolve and would false-positive on the correct
   separate-`#Preview` injection; READ the located site to confirm. See `lint-architecture.md`.) **Read its `parse_warnings`** — a flagged file did not fully
   parse, so a structural miss can't masquerade as clean; READ those by hand. The runner only LOCATES.
   Engine + rule-file format: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a
   `@State` sits at `#Preview` body scope vs inside the previewed view, whether a previewed view *reads*
   `@Query`/`@Environment`, and whether a container is already injected upstream are all invisible to
   grep. Build a per-file inventory: each `#Preview` + what state it declares + what dependencies the
   previewed view reads + whether each is provided.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a bare `@State` at `#Preview` body scope, a `windowStyle:` overload on a Mac
   target, a `@Query` view with no injected container).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place,
   a behavior claim), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated <api>` for a currency/deprecation rule
   like prev-01): read its `consensus` (the canonical shape), `deprecated`+`replacement`, `recommended`
   permalink, `introduced_macos`, and `co_occurs_with` (e.g. `modelContainer` co-occurs with `Query` /
   `Model` — exactly the prev-06 seam); a `lookup` **exit 3** (not-found, with a did-you-mean
   `suggestion`) corroborates a hallucination/platform-wrong finding. (b) **Spec** — confirm via
   **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the
   path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never
   `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the
   Sosumi `doc:` floor. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or
   discard. Carry the `PreviewModifier` floor and `@Previewable @Query` macOS-15 claim as gating notes
   with `source: verify against Xcode 26 SDK` until VERIFY confirms them.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (this domain ships **none** by default — every fix is `flag-only`; see
   below), one conventional commit per finding citing its `rule_id`, never weaken a check. The ✅
   "Correct" is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape** put in
   `## Correct`, backed by a real macOS example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source`. Leave `flag-only` findings `open` with that ✅.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves and still says the floor you claimed.
   If a fix introduced a new tell (e.g. a `.environment(_:)` you added now needs a sample factory that
   itself reads a dependency), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. **Every defect in this domain is
`fix_mode: flag-only`**: the correct preview body depends on the view's real dependencies and sample
data, which only the developer (or the swiftui-ctx consensus shape) can supply — there is no safe
mechanical single-answer rename. Surface every fix as a suggested diff with the ✅, never auto-applied.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/previews/<context>/NN-slug.md` (one finding per file, zero-padded, ordered).
  Per-run index: `swiftui-audits/previews/_index.md`.
- `domain: previews`. Frontmatter is the canonical schema; `fix_mode` is `flag-only` for **every**
  prev-NN (see confidence gating). `availability` reads from `floors-master.md`. `source` is an Apple
  URL + access date (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` on the
  shared-seam findings (prev-06 → swiftdata, prev-07 → state-observation, prev-03 → menus-commands when
  command-co-located, prev-01 → api-currency).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `legacy-preview-struct/` | a `PreviewProvider` struct stands in for the `#Preview` macro (prev-01) |
| `previewable-state/` | bare `@State`/`@Binding`/`@Bindable` lives at `#Preview` body scope (prev-02) |
| `environment-entry/` | hand-rolled `EnvironmentKey` boilerplate, or the wrong `.environmentObject` injector (prev-03, prev-08) |
| `preview-traits/` | a manual `.frame` sizing hack, or the visionOS-only `windowStyle:` overload (prev-04, prev-05) |
| `canvas-crash-injection/` | a `@Query`/SwiftData or `@Environment` view ships no injected dependency (prev-06, prev-07) |
| `preview-modifier/` | repeated inline in-memory containers should collapse to one `PreviewModifier` (prev-09) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/previews/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/preview-macro-and-state.md` | the macro-vs-`PreviewProvider` call, `@Previewable` state, traits-vs-`.frame`, the `windowStyle:` platform trap (prev-01/02/04/05) |
| `references/entry-and-environment.md` | `@Entry`-vs-`EnvironmentKey` boilerplate and the `.environment` vs `.environmentObject` injector (prev-03/08) |
| `references/preview-crashes-and-injection.md` | the two canvas-crash traps — missing in-memory container, missing `@Environment` injection — and the instantiation test (prev-06/07) |
| `references/preview-modifier-shared.md` | collapsing repeated inline in-memory containers into one shared `PreviewModifier` (macOS 15+) (prev-09) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (`@Previewable`, `@Entry`, `#Preview`, `PreviewModifier`, `ModelContainer.init`) — the reconciled truth |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented / platform-wrong name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (prev-09 floor gates) + the `macOS ABSENT` (visionOS-only `windowStyle:`) rule |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (the previews row + the `@Entry`/`FocusedValueKey` and preview-container tiebreakers) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-previews --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
prev-01/03/04/05/06/07/08/09 flat presence) + **one tier-2 ast-grep** structural rule
(`lint/ast-grep/prev-02-*.yml` — bare-`@State`-inside-a-`#Preview`-body containment, which grep cannot
express). prev-06's un-injected `@Query` view is a grep co-occurrence tell, not a structural rule (a
precise one needs cross-declaration data flow ast-grep can't resolve — `lint-architecture.md`). It runs a per-file
**parse probe** (surfaces "did not fully parse" so a structural miss can't look clean), emits unified
**JSON + SARIF**, and **degrades to grep-only with a notice** if ast-grep is unreachable
(`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). This domain ships no
tier-1 `hard` tell, so the runner does not exit 2 — it emits warnings/advisories only (no hard-fail
tells — nothing blocks the gate). The located traps (prev-02/05/06/07) are still confirmed by
the LLM in DETECT after READ, never by a flat grep. It only LOCATES — always READ each hit in full
before reporting (step 3). The thin `scripts/preview-lint.sh` is a pointer to this runner. Engine +
rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
