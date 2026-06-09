---
name: audit-swiftui-typography-text
description: Audits a finished or in-progress macOS SwiftUI codebase for typography and text-rendering defects on macOS 26 Tahoe and writes per-finding Markdown to swiftui-audits/. Use when the user says text looks wrong, fonts jump on size change, numbers jiggle, labels are misaligned, or styled text is broken; when they ask to verify Text composition, Text + Text concatenation, AttributedString styling, Font.system design, Dynamic Type, ScaledMetric, lineLimit reservesSpace, TextRenderer, textRenderer, LabeledContent, or monospacedDigit on a Mac target; when AI may have written fontSize, textStyle, attributedText, Text(styled:), or font(size:); or when a deployment target below macOS 26 leaves Text + Text or Font.system(_:design:) ungated for deprecation. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for AppKit NSTextView/NSAttributedString rendering, not for color/material craft, not for string externalization or localization catalogs, not for the general deprecation sweep, not for writing new typographic UI from scratch.
---

# Audit SwiftUI Typography & Text

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way text and type go wrong on a macOS 26 (Tahoe)
target: deprecated `Text + Text` concatenation, malformed `AttributedString`, hardcoded font sizes that
defeat Dynamic Type, `lineLimit(N)` that jumps layout, the design-only `Font.system` overload, mis-gated
`TextRenderer`, hand-rolled label rows that should be `LabeledContent`, jiggling numerics missing
`monospacedDigit()`, and invented type APIs. Findings are written to disk in the toolkit's unified schema;
certain mechanical defects are fixed under the fix-safety protocol. This is never a from-scratch text-UI
generator.

Several of this domain's deprecations **close at macOS 26.0 / 26.5** (after most training data), so AI
frequently emits the now-deprecated `Text + Text` and design-only `Font.system`. Be suspicious wherever AI
composed styled text.

## Boundary / seam note (stay in lane)

- **The `Text + Text` / `Font.system(_:design:)` deprecation *flag*** is owned by `audit-swiftui-api-currency`;
  **this skill owns the positive `AttributedString` / interpolation / `system(_:design:weight:)` craft.**
  Emit `cross_ref: api-currency` on these findings; do not double-own the flag.
- **String externalization, `String(localized:)`, and the AttributedString localization facet** belong to
  `audit-swiftui-localization` — file the *catalog* implication there; this skill owns *rendering*.
- **Dynamic Type as an accessibility requirement** is cross-linked to `audit-swiftui-accessibility`; this
  skill detects the hardcoded-size mechanics, a11y owns the trait-level audit. Emit `cross_ref: accessibility`.
- **AppKit `NSTextView` / `NSAttributedString` rich-text bridging** is out of scope — note it in one line
  and point to the future `audit-appkit-interop` skill.

## Domain rules

1. **Compose, don't concatenate.** `Text + Text` is deprecated at macOS 26.0; build styled runs with
   `AttributedString` (`AttributeContainer`) or string interpolation into one `Text`.
2. **Size through the type system, never literals.** Use a semantic text style (`.system(.body)`) or
   `@ScaledMetric` so Dynamic Type scales it; `.font(.system(size: 14))` freezes the layout.
3. **Reserve space you'll need.** `.lineLimit(N, reservesSpace: true)` keeps the frame stable; bare
   `.lineLimit(N)` jumps when content arrives.
4. **Stop the digits from dancing.** Live-updating numerics (timers, counters, prices) need
   `.monospacedDigit()` or a monospaced-digit font; otherwise each frame re-flows.

## Defect index (txt-01 … txt-09)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (never-correct / invented),
**warning** (compiles but non-native / deprecated), **advisory** (judgment / craft). `auto` = mechanical
single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| txt-01 | `Text(…) + Text(…)` concatenation (deprecated macOS 26.0) | warning | flag | `text-composition-and-attributed.md` |
| txt-02 | `Font.system(_:design:)` design-only overload (deprecated 26.5 → add `weight:`) | warning | auto | `fonts-and-dynamic-type.md` |
| txt-03 | `.font(.system(size: N))` hardcoded size — defeats Dynamic Type | advisory | flag | `fonts-and-dynamic-type.md` |
| txt-04 | `.lineLimit(N)` integer without `reservesSpace:` → layout jump | advisory | flag | `text-layout-and-rendering.md` |
| txt-05 | `AttributedString(…)` built wrong (String concat / no `AttributeContainer`) | warning | flag | `text-composition-and-attributed.md` |
| txt-06 | `.textRenderer(_:)` (macOS 15) / `TextRenderer` (macOS 14) mis-gated | warning | flag | `text-layout-and-rendering.md` |
| txt-07 | hand-rolled `HStack { Text; Spacer(); Text }` label row → `LabeledContent` | advisory | flag | `text-layout-and-rendering.md` |
| txt-08 | live numeric `Text` (`.formatted()`/`format:`) missing `.monospacedDigit()` | advisory | flag | `fonts-and-dynamic-type.md` |
| txt-09 | invented type API: `.fontSize(`, `.textStyle(`, `Text(styled:)`, `.attributedText(`, `.font(size:` | hard-fail | flag | `text-composition-and-attributed.md` |

**Currency seam:** txt-01 and txt-02 carry `cross_ref: api-currency` (currency flags the deprecation;
typography owns the craft). txt-03 carries `cross_ref: accessibility` (Dynamic Type).

## The real API, at a glance

**Real (exist on macOS 26):** `AttributedString` + `AttributeContainer`, `Text` string interpolation,
`Font.system(_:design:weight:)`, `@ScaledMetric(relativeTo:)`, `lineLimit(_:reservesSpace:)` (macOS 13+),
`TextRenderer` (protocol, macOS 14+) + `textRenderer(_:)` (modifier, macOS 15+), `LabeledContent` (macOS 13+),
`monospacedDigit()`, `Text(_:format:)`. **`Font.system(_:design:)` (no `weight:`) still resolves but is
deprecated at macOS 26.5 → `system(_:design:weight:)`; `Text("a") + Text("b")` is deprecated at 26.0.**

**Invented (never exist):** `.fontSize(_:)`, `.textStyle(_:)`, `Text(styled:)`, `.attributedText(_:)`,
`.font(size:)` (the real spelling is `.font(.system(size:))`). Confirm any uncertain name via
`swiftui-ctx lookup <api>` (exit 3 = no shipping Mac app uses it) + the canonical invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate.

Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate the table here.

## Grounded ✅ correct shape (real shipping code, not a placeholder)

The ✅ examples in this skill are **the swiftui-ctx consensus shape backed by a permalinked Mac app**, not
hand-written snippets. The canonical txt-08 fix (a live numeric `Text` that must not jiggle) — verified via
`swiftui-ctx lookup monospacedDigit --json` (consensus `()` at 100%, `introduced_macos` 10.15) and
`swiftui-ctx file ex_59de3fab78 --smart`:

```swift
// ✅ live numeric Text — .monospacedDigit() stops per-frame re-flow (sindresorhus/Gifski, macOS 26)
Text(progress.formatted(.percent.precision(.fractionLength(0))))
    .font(.system(size: 30, weight: .bold, design: .rounded))   // current overload carries weight: (txt-02 ✅)
    .monospacedDigit()                                           // txt-08 ✅
```

- **Source (real GitHub permalink):** https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Utilities.swift#L5210
- **Spec (Sosumi `doc:`):** doc: https://sosumi.ai/documentation/swiftui/view/monospaceddigit

Reproduce the grounding for any other defect: `swiftui-ctx lookup <api> --json` → read `consensus` +
`recommended` → `swiftui-ctx file <recommended.id> --smart` → put that consensus shape in `## Correct` and its
permalink + Sosumi `doc:` in `## Source` (step 7 FIX).

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   txt-06 mis-gating fires only when the floor is **below the symbol's introduction**, and the txt-01/02
   deprecations are advisory below their close (26.0 / 26.5) but become live-warning at/after it. Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-typography-text --dir <sources> --json /tmp/txt.json --sarif /tmp/txt.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + the tier-2 structural ast-grep rule
   (`lint/ast-grep/*.yml` — the multi-line `Text + Text` grep can't express), a per-file **parse probe**,
   and emits unified JSON + SARIF. **Read its `parse_warnings`** — a flagged file did not fully parse, so a
   structural miss can't masquerade as clean; READ those by hand. The runner only LOCATES. Engine +
   rule-file format + degradation: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a numeric
   `Text` updates live, whether a `lineLimit` frame matters, and whether an `HStack` is really a label row
   are invisible to grep. Build a per-file inventory: each text site + its composition shape + its sizing +
   its layout reservation.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (an invented name, a literal `Text + Text`, a bare integer `lineLimit`). 
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, a
   deprecation you can't date), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated <api>` for txt-01/02): read its `consensus`
   (the canonical shape), `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and
   `co_occurs_with`; a `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a
   txt-09 hallucination — no shipping Mac app uses the symbol. (b) **Spec** — confirm via **Sosumi**:
   `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi `doc:`
   floor. The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote
   with the citation or discard.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (txt-02 — append `weight: .regular`), one conventional commit per finding
   citing its `rule_id`, never weaken a check. The ✅ "Correct" is **not a hand-written snippet** — it is
   the swiftui-ctx **consensus shape** put in `## Correct`, backed by a real macOS example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source`. Leave `flag-only` findings `open` with that ✅.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence in
   `## Fix applied?`. Re-confirm every citation still resolves. If a fix introduced a new tell (e.g. an
   `AttributedString` you wrote now needs a gate), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can become a
finding — never emit a speculative finding. Auto-fix only the mechanical set (txt-02); everything else is
`fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/typography-text/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/typography-text/_index.md`.
- `domain: typography-text`. Frontmatter is the canonical schema; `fix_mode` is `auto` for txt-02, else
  `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date (fetched
  via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` for txt-01/02 (`api-currency`) and txt-03
  (`accessibility`).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `text-composition/` | text is concatenated, an `AttributedString` is malformed, or an invented type API appears (txt-01, txt-05, txt-09) |
| `fonts-dynamic-type/` | the design-only `Font.system`, a hardcoded size, or jiggling numerics (txt-02, txt-03, txt-08) |
| `text-layout-rendering/` | `lineLimit` reservation, a mis-gated `TextRenderer`, or a hand-rolled label row (txt-04, txt-06, txt-07) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/typography-text/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a hard
requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/text-composition-and-attributed.md` | composition, `AttributedString` craft, the `Text + Text` rewrite, invented type names (txt-01/05/09) |
| `references/fonts-and-dynamic-type.md` | the design-only `Font.system`, sizing via text styles / `@ScaledMetric`, monospaced digits (txt-02/03/08) |
| `references/text-layout-and-rendering.md` | `lineLimit` reservation, `TextRenderer`/`textRenderer` floors + gating, `LabeledContent` (txt-04/06/07) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + the tier-2 structural `Text + Text` rule); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability/deprecation value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (txt-09) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (txt-06 wrong-arm) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (api-currency, localization, accessibility) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-typography-text --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, txt-01…txt-09) + a **tier-2 ast-grep**
structural rule (`lint/ast-grep/txt-01-text-concat.yml` — multi-line `Text + Text` concatenation grep can't
express). It runs a per-file **parse probe** (surfaces "did not fully parse"), emits unified **JSON + SARIF**,
exits **2** on any hard-fail (txt-09) for a CI gate, and **degrades to grep-only with a notice** if ast-grep
is unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES —
always READ each hit in full before reporting (step 3). The legacy `scripts/typography-lint.sh` is a thin
pointer to this runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
