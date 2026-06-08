---
name: audit-swiftui-availability-gating
description: Audits a finished or in-progress macOS SwiftUI codebase for the cross-cutting availability-gating sweep — every above-floor API that ships ungated, gated on the wrong arm, or gated at the wrong floor on a macOS 26 (Tahoe) target — and writes per-finding Markdown to swiftui-audits/. Use when the user says the build breaks on an older macOS, asks whether every API is gated, mentions #available, @available, deployment target, MACOSX_DEPLOYMENT_TARGET, back-deployment, or a macOS 15 + macOS 26 dual target; when AI may have written #available(iOS NN) in Mac code so the wildcard always fires; when a gate names the wrong floor or has no else fallback; or when an above-floor symbol (glass, @Observable, scrollEdgeEffect, symbolEffect, MeshGradient) is used with no gate at all. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for deprecation flagging (api-currency owns that), not for deep glass gating (liquid-glass owns that), not for writing new gated UI from scratch.
---

# Audit SwiftUI Availability Gating

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project as the toolkit's **blanket availability net**: every API floored above the project's deployment
target must be gated on the macOS arm at the correct floor with a real fallback — or the build breaks on
the older macOS it claims to support. This skill catches the ungated symbol, the wrong-arm gate (the
`*` wildcard that always fires), the floor mismatch, the missing `else`, the missing `*`, and the
macOS-ABSENT symbol wrapped in a Mac gate. Findings are written to disk in the toolkit's unified schema;
the two purely-mechanical defects are fixed under the fix-safety protocol. This is never a from-scratch
gated-UI generator.

The deployment target is **load-bearing** — read it first (ORIENT). Every gating defect is conditional
on it: a symbol floored at macOS 14 is only a finding when the target is below 14.

## Boundary / seam note (stay in lane)

- **Deprecation flagging belongs to `audit-swiftui-api-currency`.** A symbol that is *both* deprecated
  *and* ungated is a deprecation finding there (it owns the flag); do **not** double-report it here —
  emit a `cross_ref` to api-currency and let it carry the primary. We own *"is it gated"*; currency
  owns *"is it current."*
- **Deep glass gating belongs to `audit-swiftui-liquid-glass`.** Per `cross-ref-graph.md`, glass symbols
  (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `scrollEdgeEffect…`) are gated **in
  depth** by liquid-glass (it owns the pre-26 fallback table and the morph wiring). When this net catches
  an ungated/wrong-arm glass symbol, file it with `cross_ref: audit-swiftui-liquid-glass` and let glass
  keep the primary.
- **Each domain owns its own gating in depth** (state-observation, navigation-toolbars, scenes-windows,
  swiftdata, previews). This skill is the **catch-all net** for the gates those domains missed — file
  with a `cross_ref` to the owning domain when the symbol is clearly theirs.

## The cross-cutting gating rule (point in, never restate)

The macOS-arm rule, the required `*` wildcard, the wrong-arm failure, and how to read a multi-platform
availability string live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` — read it,
do not restate it. Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. **The floors-master table IS this skill's
floor map** (symbol → macOS floor); the LOCATE lint only finds candidate symbols, and you look each one
up there. **Never restate the floor table in this package.**

## Defect index (gate-01 … gate-08)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break on the target's
floor / never-correct), **warning** (compiles but wrong/fragile), **advisory** (verify-by-hand).
`auto` = mechanical single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| gate-01 | an above-floor symbol used with **no** availability gate under a deployment target below its floor | hard-fail | flag | `gating-defects.md` |
| gate-02 | `#available(iOS NN, *)` gating a macOS-floored API in a Mac target (wrong arm — the `*` always fires) | hard-fail | auto | `gating-defects.md` |
| gate-03 | `#available(macOS NN, *)` whose `NN` ≠ the symbol's floor in `floors-master.md` (floor mismatch) | warning | flag | `gating-defects.md` |
| gate-04 | an availability gate with **no `else`** where the gated view needs a pre-floor fallback | warning | flag | `gating-defects.md` |
| gate-05 | an `@available` type/decl gate whose use site is unguarded, or a use site with no decl gate | warning | flag | `gating-defects.md` |
| gate-06 | a **macOS-ABSENT** symbol wrapped in `#available(macOS …)` — replace, don't gate | hard-fail | flag | `absent-and-quirks.md` |
| gate-07 | `#available((macOS\|iOS) NN)` **missing the trailing `, *` wildcard** (compile error) | hard-fail | auto | `gating-defects.md` |
| gate-08 | a **type-property** whose floor differs from its type (the DocC inheritance quirk) — verify via Sosumi | advisory | flag | `absent-and-quirks.md` |

**gate-04 has no flat lint tell** (a missing `else` is structural absence ast-grep cannot positively
match) — the LOCATE lint surfaces every `#available(macOS …)` gate (gate-03 tell) and you decide in the
READ step whether a fallback is required. **gate-08** is surfaced during the floor cross-check in VERIFY,
not by a flat string. Never assert a floor or absence from memory — confirm it (VERIFY).

## The real API, at a glance

This is the *blanket* sweep, so the "real API" is the **floor map itself**, not one symbol family:
read each located symbol's macOS floor from
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and gate it on the macOS arm at exactly that
floor. Common above-floor symbols the lint locates (each has a floor in floors-master): `@Observable` /
`@Bindable` (14.0), `glassEffect` & glass family (26.0), `scrollEdgeEffectStyle` (26.0),
`backgroundExtensionEffect` (26.0), `symbolEffect` (14.0), `MeshGradient` (15.0), `TextRenderer` (14.0),
`@Model` class inheritance (26.0), `Tab(...)`/`TabSection` (15.0). **macOS-ABSENT** (never gate, replace):
`.glassBackgroundEffect()` (visionOS), `WheelPickerStyle`, `ToolbarItemPlacement.topBarLeading/.topBarTrailing`,
`WindowStyle.volumetric`, `navigationBarTitleDisplayMode`, `.bottomBar` — the canonical list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`. **Read, never restate.**

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`) — it is the pivot for
   every gate-01/03 finding. Record it. If the project ships a dual target (macOS 15 *and* 26), every
   ≥26 symbol needs a gate.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-availability-gating --dir <sources> --json /tmp/gating.json --sarif /tmp/gating.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the wrong-arm and absent-symbol-in-gate gate-scope rules grep can't express),
   plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a
   flagged file did not fully parse, so a gate hidden in an unparsed block can't masquerade as clean;
   READ those by hand. The runner only LOCATES. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — gate scope, container nesting, and the presence of an
   `else` are invisible to a flat grep. For each located symbol build an inventory: symbol · its floor
   (from floors-master) · the deployment target · is it inside a gate · is the gate's arm `macOS` · is
   the floor right · is there an `else`.
4. **DETECT.** Apply the index against the recorded deployment target. Assign each candidate a
   **confidence**; report a finding **only at 100% certainty** (e.g. an `iOS` arm wrapping a Mac symbol,
   a `macOS 26` symbol ungated under a 15.0 target, a `WheelPickerStyle` in a Mac gate). A floored
   symbol whose floor is ≤ the deployment target is **not** a finding — suppress it.
5. **VERIFY.** For anything ≤ ~70% confidence (a floor you can't place, a symbol you're unsure exists, a
   type-property quirk) run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json`: read its `introduced_macos` (the
   real floor), `deprecated`+`replacement` (if set, this is a **currency** seam → cross_ref, don't double-
   report), `consensus` (the canonical gated shape), and `recommended`/`diverse` permalink with `min_macos`;
   a `lookup` **exit 3** corroborates a hallucinated/absent name. For a currency/deprecation question also
   run `swiftui-ctx deprecated <api>`.
   **Deeper corpus evidence (deprecated-AND-above-floor):** when a finding sits on a deprecated symbol, run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated <api> --json` for its `replacement`, then
   `lookup <replacement> --introduced_macos` — a renamed API can migrate to an above-floor replacement that
   itself needs a gate (real corpus: `tabItem`→`Tab`, and `lookup Tab` = `introduced_macos: 15.0`, so the
   migration creates a new macOS-15 gate; cross_ref currency, but gate the replacement here). (b) **Spec** — confirm the floor via **Sosumi**:
   `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `swiftui-ctx introduced_macos` against the `floors-master.md` value
   and the Sosumi `doc:` floor — they must agree. **The DocC type-property quirk (gate-08):** a
   type-property page can render the *type's* floor, not the property's — always re-confirm a type-property
   floor against Sosumi, and note `.task`-family doc paths can return an SPA shell (retry / use the JSON
   endpoint per sosumi-reference). The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or
   discard. Carry any unconfirmable floor as `advisory` with `source: verify against Xcode 26 SDK`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit `cross_ref` on a seam finding (glass → liquid-glass; deprecated-and-ungated →
   api-currency; a domain's own symbol → that domain). Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (gate-02 arm swap `iOS`→`macOS`; gate-07 append `, *`), one conventional
   commit per finding citing its `rule_id`, never weaken a check. The ✅ "Correct" is **not** a hand-
   written snippet — it is the swiftui-ctx **consensus shape** put in `## Correct`, backed by a real
   macOS-26 example fetched with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart`
   whose GitHub permalink (plus the Sosumi `doc:`) goes in `## Source`. The canonical gated example this
   skill ships (verified `swiftui-ctx lookup glassEffect` → `diverse[0]`,
   `f/textream/ContentView.swift#L73`, `min_macos: 26`) is the `if #available(macOS 26.0, *) { … }
   else { .background(.ultraThinMaterial …) }` shape. Leave `flag-only` findings `open` with that ✅.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record it in
   `## Fix applied?`. Re-confirm every cited floor still resolves and still says the same `macOS NN`. If a
   fix introduced a new tell (an arm-swap that now needs an `else` fallback), loop that file to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**, and always relative to the recorded deployment target.
Anything ≤ ~70% (a floor, an existence, a type-property quirk) goes to VERIFY (step 5) first — never emit
a speculative gate finding. Auto-fix only the two mechanical defects (gate-02 arm swap, gate-07 wildcard);
everything else is `fix_mode: flag-only` (the right `else` fallback and the right floor are judgment).

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/availability-gating/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/availability-gating/_index.md`.
- `domain: availability-gating`. `fix_mode` is `auto` for gate-02/gate-07, else `flag-only`.
  `availability` reads from `floors-master.md`. `source` is an Apple URL + access date (fetched via
  Sosumi) or `verify against Xcode 26 SDK`. `cross_ref` per the seam note.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `ungated-symbol/` | an above-floor symbol ships with no gate under a sub-floor target (gate-01) |
| `wrong-arm/` | a Mac-floored API is gated on the `iOS` arm (gate-02) |
| `floor-mismatch/` | a `#available(macOS NN)` floor disagrees with floors-master, incl. the type-property quirk (gate-03, gate-08) |
| `missing-fallback/` | a gate has no `else` where the view needs a pre-floor fallback (gate-04) |
| `decl-vs-use/` | an `@available` decl gate and its `#available` use site disagree (gate-05) |
| `platform-wrong/` | a macOS-ABSENT symbol is wrapped in a Mac gate instead of replaced (gate-06) |
| `missing-wildcard/` | an `#available`/`@available` omits the trailing `, *` (gate-07) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/availability-gating/` with a lowercase-hyphen slug naming the sub-category, and note it
in the run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs
is a hard requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/gating-defects.md` | the ungated / wrong-arm / floor-mismatch / no-else / decl-vs-use depth and ❌→✅ rewrites (gate-01/02/03/04/05/07) |
| `references/absent-and-quirks.md` | a macOS-ABSENT symbol (replace, don't gate) or the DocC type-property floor quirk + `.task`-family SPA-shell caution (gate-06/08) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set (tier-1 grep tells + tier-2 structural wrong-arm/absent gate-scope rules); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value — **this skill's floor map**; the reconciled truth |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule, the `*` wildcard, the wrong-arm failure, reading multi-platform strings |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical macOS-ABSENT / invented-name list (gate-06) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for `introduced_macos`, the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (glass → liquid-glass; deprecation → api-currency; each domain's own gating) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-availability-gating --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
gate-01/02/03/05/06/07) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` — gate-02 wrong-arm
gate-scope, gate-06 macOS-ABSENT-symbol-in-a-macOS-gate) that grep cannot express. It runs a per-file
**parse probe** (surfaces "did not fully parse" so a hidden gate can't look clean), emits unified
**JSON + SARIF**, exits **2** on any hard-fail (gate-06/07) for a CI gate, and **degrades to
grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`; faster:
`brew install ast-grep`). It only LOCATES — always READ each hit in full before reporting (step 3), and
always judge it against the recorded deployment target. The thin `scripts/gating-lint.sh` is a pointer to
this runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
