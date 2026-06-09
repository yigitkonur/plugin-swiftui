---
name: audit-swiftui-animation-motion
description: Audits a finished or in-progress macOS SwiftUI codebase for animation and motion defects and writes per-finding Markdown to swiftui-audits/. Use when the user says animations feel janky, abrupt, non-native, or never animate; when they ask to verify animation, withAnimation, transition, matchedGeometryEffect, symbolEffect, contentTransition, PhaseAnimator, KeyframeAnimator, or spring presets; when AI may have written the deprecated single-arg .animation(_); when motion runs unconditionally and ignores Reduce Motion; when a hand-rolled Timer or repeatForever loop drives motion that PhaseAnimator fits; when raw .easeInOut(duration:) is used where .bouncy/.smooth/.snappy belongs; or when a hero transition is mis-wired. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for AppKit Core Animation, not for the glass morph itself (liquid-glass owns it), not for render-cost analysis (view-performance), not for writing new animations from scratch.
---

# Audit SwiftUI Animation & Motion

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, flag — every way animation goes wrong: the deprecated implicit
`.animation(_)`, a missing/wrong `value:`, raw duration curves where spring presets fit, ungated
macOS-14 spring presets / `symbolEffect`, hand-rolled loops that `PhaseAnimator`/`KeyframeAnimator`
replace, missing `contentTransition`, mis-wired `matchedGeometryEffect` hero transitions, and motion
that ignores Reduce Motion. Findings are written to disk in the toolkit's unified schema. This is never
a from-scratch animation generator.

## Boundary / seam note (stay in lane)

- **The Liquid Glass morph itself** (`glassEffectID`, `GlassEffectContainer` wiring) belongs to
  `audit-swiftui-liquid-glass`. This skill flags only a *generic* `matchedGeometryEffect` used on glassed
  views (anim-09) and `cross_ref`s there — it does not audit glass-morph mechanics.
- **Render cost of motion** (per-frame redraw, `.drawingGroup()`) belongs to `audit-swiftui-view-performance`.
  This skill owns the UX-restraint verdict on `.repeatForever` (anim-11) and `cross_ref`s the cost there.
- **"The app ignores Reduce Motion entirely"** across all surfaces belongs to `audit-swiftui-accessibility`;
  this skill owns the motion-specific missing reduced path (anim-10) and `cross_ref`s it.
- **Gesture-driven animation coupling** belongs to `audit-swiftui-pointer-gestures`; **`TimelineView`-as-clock**
  drawing belongs to `audit-swiftui-drawing-canvas`. **AppKit/Core Animation** is out of scope entirely.

## Domain rules (the spine)

1. **Scope every implicit animation.** `.animation(_:value:)` (or `withAnimation`) — never the deprecated
   single-arg `.animation(_)`, which animates every upstream change.
2. **Prefer the native primitive over the hand-rolled loop.** Spring presets over raw durations (macOS 14),
   `PhaseAnimator`/`KeyframeAnimator` over `Timer`/`repeatForever` chains (macOS 14), `symbolEffect` over a
   hand-spun SF Symbol, `contentTransition` on value changes (macOS 13).
3. **Motion is opt-out.** Continuous/large motion must read `accessibilityReduceMotion` and degrade.
4. **A hero transition needs all four wires** — one shared `@Namespace`, matching `id`, a single
   transaction, one `isSource`.

## Defect index (anim-01 … anim-11)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (availability break),
**warning** (compiles but deprecated/non-native), **advisory** (judgment / restraint). `flag` = show the
✅, dev applies. No defect here is a mechanical single-answer rewrite, so **all are `fix_mode: flag-only`**
(the animated value / curve / primitive is always a judgment).

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| anim-01 | single-arg `.animation(x)` (deprecated implicit form, macOS 12) | warning | flag | `animation-currency-and-springs.md` |
| anim-02 | `.animation(_:value:)` on a constant, or `withAnimation` over no observed change | warning | flag | `animation-currency-and-springs.md` |
| anim-03 | raw `.easeInOut(duration:)`/`.linear(duration:)` where a spring preset fits | advisory | flag | `animation-currency-and-springs.md` |
| anim-04 | spring preset `.bouncy`/`.smooth`/`.snappy` ungated under a < macOS 14 floor (locator: `warn`; a real availability break **only** when the deployment floor is < 14 — the agent escalates per the reference) | warning | flag | `animation-currency-and-springs.md` |
| anim-05 | `Timer`/`.repeatForever`/`repeatCount` loop where `PhaseAnimator`/`KeyframeAnimator` fits | advisory | flag | `phase-keyframe-and-symbol.md` |
| anim-06 | `.symbolEffect` ungated under < macOS 14, or a hand-animated SF Symbol | warning | flag | `phase-keyframe-and-symbol.md` |
| anim-07 | a value change (numeric `Text`, swapped symbol) animates without `.contentTransition` | advisory | flag | `phase-keyframe-and-symbol.md` |
| anim-08 | `matchedGeometryEffect` missing shared `@Namespace` / matching `id` / one transaction | warning | flag | `hero-transitions-and-matched-geometry.md` |
| anim-09 | generic `matchedGeometryEffect` morphing glassed views (should be `glassEffectID`) | advisory | flag | `hero-transitions-and-matched-geometry.md` |
| anim-10 | continuous/large motion ignores `accessibilityReduceMotion` (no reduced path) | warning | flag | `reduce-motion-and-restraint.md` |
| anim-11 | `.repeatForever` / always-on motion — UX restraint | advisory | flag | `reduce-motion-and-restraint.md` |

**The spring-preset floor is UNVERIFIED-LOOKING but reconciled to macOS 14** — the shipped DocC renders
`macOS 10.15` (a type-property-inheritance quirk); the WWDC23 provenance is the truth. Carry **macOS 14**
for `.bouncy`/`.smooth`/`.snappy` (anim-04), never the rendered 10.15.

## The real API, at a glance

**Real (modern, prefer):** `animation(_:value:)` (macOS 10.15+), `withAnimation(_:_:)`,
`matchedGeometryEffect(id:in:…)` (11+), `contentTransition(_:)` (13+), `PhaseAnimator` / `KeyframeAnimator`
/ `symbolEffect(_:options:value:)` / `Animation.bouncy`·`.smooth`·`.snappy` (all **14+**),
`EnvironmentValues.accessibilityReduceMotion` (10.15+). **Deprecated:** `animation(_:)` single-arg
(deprecated at macOS 12 → `animation(_:value:)` / `withAnimation`).

Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and the invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, **never restate them**. Full
❌→✅ rewrites live in this skill's `references/*.md`.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree`/`find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). Load-bearing:
   anim-04 (spring presets) and anim-06 (`symbolEffect`) fire **only** when the floor is **below macOS 14**.
   Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-animation-motion --dir <sources> --json /tmp/anim.json --sarif /tmp/anim.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + the tier-2 structural ast-grep rule
   (`lint/ast-grep/anim-01-implicit-animation.yml` — single-arg arity grep can't express), plus a per-file
   **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a flagged file did not
   fully parse; READ those by hand. The runner only LOCATES — never treat a hit as a finding. Engine +
   rule-file format + degradation: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. The `value:`
   binding, the `@Namespace` identity, the gate scope, and whether a `withAnimation` body mutates observed
   state are invisible to grep. Build a per-file inventory: each animated view + its trigger state + its
   floor gate + its motion role.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100 %
   certainty** (a single-arg `.animation`, an ungated preset under a <14 floor, a hero transition with two
   different namespaces).
5. **VERIFY.** For anything ≤ ~70 % confidence run **both** sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (e.g. `animation` →
   `consensus` **92 % `(_, value)` / 7 % `(_)`**, `symbolEffect` → `introduced_macos` 14,
   `matchedGeometryEffect` → 93 % `(id, in)`); for the deprecation rule also
   `swiftui-ctx deprecated <api>`. Read `consensus`, `deprecated`+`replacement`, `recommended` permalink,
   `introduced_macos`, `co_occurs_with`. (b) **Spec** — confirm via **Sosumi**
   (`curl -sSL https://sosumi.ai/<apple-path>`; never `WebFetch` `developer.apple.com`); protocol in
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`. Cross-check `introduced_macos` against
   `floors-master.md`. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or discard.
   - **Deeper corpus evidence (the real Animation vocabulary).** Before flagging a raw curve where a
     preset fits (anim-03) or backing a preset ✅ (anim-04), run
     `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx valueBuilders ease` + `lookup bouncy`/`smooth`/`snappy` for the real spring presets, durations,
     and overloads — e.g. `.bouncy` ships in **405 uses across 92 repos** (incl. the `(duration, extraBounce)`
     overload, jellyfin/Swiftfin), so it is consensus, not exotic. For a custom transition (anim-08) run
     `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx conformances ViewModifier` (or `Transition`) for real
     conformers + permalinks (stable envelope, `next_actions` → `file <id>`); pair
     with `swiftui-ctx lookup animation` / `examples withAnimation --shape`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** This domain is **all `fix_mode: flag-only`** — leave each finding `open` with the ✅ in
   `## Correct`. The ✅ is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape** backed
   by a real macOS-26 example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source`. The verified canonical `.animation(_:value:)` ✅ — the
   live swiftui-ctx **consensus shape `(_, value)` (92 %)**, grounded in real corpus code, not a placeholder:

   ```swift
   // ✅ Correct — swiftui-ctx `lookup animation` consensus `(_, value)`; real example
   //    sindresorhus/Gifski `ex_7f40920aa8` (author_authority 1,013,769, 8,409★)
   Label("Copy", systemImage: "doc.on.doc")
       .opacity(isShowingSuccess ? 0 : 1)
       .disabled(isShowingSuccess)
       .animation(.easeInOut(duration: 0.3), value: isShowingSuccess)
   // permalink: https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Utilities.swift#L4974
   // doc: https://sosumi.ai/documentation/swiftui/view/animation
   ```

   Observe the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`); never weaken a check.
8. **DOUBLE-CHECK.** Re-confirm every citation still resolves and still says the floor you reported. If a
   recommended rewrite would introduce a new tell (e.g. a spring preset now needs a macOS-14 gate), loop
   that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100 % certainty**. Anything ≤ ~70 % goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. Everything here is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized:

- Findings: `swiftui-audits/animation-motion/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/animation-motion/_index.md`.
- `domain: animation-motion`. Additive field **`motion_role`** (the animation's role — e.g.
  `state-feedback`, `hero-transition`, `attention`, `ambient`) per `finding-schema.md` §4. `fix_mode` is
  `flag-only` for every defect. `availability` reads from `floors-master.md`. `source` is an Apple URL +
  access date (via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` on anim-09 (`liquid-glass`),
  anim-10 (`accessibility`), anim-11 (`view-performance`).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `implicit-and-currency/` | a deprecated single-arg `.animation`, a dead `value:`, or a no-op `withAnimation` (anim-01, anim-02) |
| `spring-and-curves/` | a raw curve where a preset fits, or an ungated spring preset under a <14 floor (anim-03, anim-04) |
| `phase-keyframe-symbol/` | a hand-rolled loop, an ungated/avoidable `symbolEffect`, or a missing `contentTransition` (anim-05, anim-06, anim-07) |
| `hero-transitions/` | a mis-wired `matchedGeometryEffect`, or a generic effect that should be a glass morph (anim-08, anim-09) |
| `reduce-motion-and-restraint/` | motion that ignores Reduce Motion, or always-on `.repeatForever` (anim-10, anim-11) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/animation-motion/` with a lowercase-hyphen slug and note it in the run's `_index.md`.
Prefer an existing folder when the fit is reasonable.* Two runs over the same code produce structurally
identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/animation-currency-and-springs.md` | the deprecated `.animation(_)`, dead `value:`, raw-curve-vs-preset, the spring-preset floor quirk (anim-01/02/03/04) |
| `references/phase-keyframe-and-symbol.md` | hand-rolled loops vs `PhaseAnimator`/`KeyframeAnimator`, `symbolEffect` floor/use, missing `contentTransition` (anim-05/06/07) |
| `references/hero-transitions-and-matched-geometry.md` | the four hero-transition wires, and the glass-morph seam (anim-08/09) |
| `references/reduce-motion-and-restraint.md` | the Reduce-Motion path and `.repeatForever` restraint (anim-10/11) |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative rule set fed to the shared runner (tier-1 grep + tier-2 single-arg structural rule); tune detection here |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth; the spring-preset macOS-14 correction) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm failure (anim-04, anim-06) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + the `motion_role` additive field |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (anim-09/10/11) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-animation-motion --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, anim-01…anim-11) + the **tier-2 ast-grep**
structural rule (`lint/ast-grep/anim-01-implicit-animation.yml` — single-argument `.animation` arity grep
cannot express). It runs a per-file **parse probe**, emits unified **JSON + SARIF**, emits warnings/advisories only
(no hard-fail tells — nothing blocks the gate), and **degrades to grep-only with a notice** if ast-grep is unreachable
(`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES — always READ
each hit in full before reporting (step 3). The thin `scripts/anim-lint.sh` forwards to this runner. Engine
+ rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
