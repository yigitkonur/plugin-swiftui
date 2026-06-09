---
name: audit-swiftui-localization
description: Audits a finished or in-progress macOS SwiftUI codebase for localization and internationalization defects and writes per-finding Markdown to swiftui-audits/. Use when the user says the app is hardcoded to English, can't be translated, ships no String Catalog, or breaks in other languages; when they ask to verify localization, internationalization, i18n, LocalizedStringKey, Text(verbatim:), String(localized:), NSLocalizedString, .xcstrings String Catalogs, translator comments, pluralization, grammar agreement, locale-aware number/date formatting, or right-to-left (RTL) layout; when AI may have passed a String variable to Text, used String(format:) or DateFormatter for display, built UI sentences by interpolation, or hardcoded left/right directions on a Mac target. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for AttributedString styling or markdown rendering (typography-text), not for the general deprecated-API sweep (api-currency), not for writing new localized UI from scratch.
---

# Audit SwiftUI Localization

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and flag — every way localization & internationalization goes wrong: hardcoded
strings that never reach a translator, `Text(verbatim:)` used both too much and too little, missing
String Catalog (`.xcstrings`), no translator comments, sentences built by interpolation (no
pluralization / grammar agreement), locale-unaware number/date formatting, and right-to-left-unsafe
layout. Findings are written to disk in the toolkit's unified schema. This is never a from-scratch
localization generator.

The core SwiftUI fact: `Text("Save")` with a **string literal** is a `LocalizedStringKey` and
**auto-localizes** — the literal becomes the catalog key. The defects are the ways code *escapes* that
auto-localization (a `String` variable, `verbatim:`, `String(format:)`) or feeds it un-translatable
input (a sentence assembled by interpolation).

**✅ Correct (grounded, not a placeholder).** The consensus shape from `swiftui-ctx lookup Text --json`
is the `(_ key: LocalizedStringKey)` overload at **99%** (the bare-`String`/`(verbatim)` form is the 1%
outlier) — so a string **literal**, ideally with a translator `comment:`, is what shipping Mac apps
overwhelmingly write:

```swift
// localized literal + translator context — NetNewsWire (macOS-shipping)
Text("label.text.unread", comment: "Unread")
```

Real permalink (verified, macOS 26 corpus): `https://github.com/Ranchero-Software/NetNewsWire/blob/60295842054529c3450b91af15911cecb1a1cc4f/Widget/WidgetBundle.swift#L27`
· Apple spec via Sosumi `doc:` `https://sosumi.ai/documentation/swiftui/text`. Refresh either with
`swiftui-ctx lookup Text --json` (VERIFY) and `swiftui-ctx file <recommended.id> --smart` (FIX).

## Boundary / seam note (stay in lane)

- **`AttributedString` styling & markdown rendering belong to `audit-swiftui-typography-text`.** When
  `Text(verbatim:)` or markdown is about *rendering* (styling, `+` concatenation), typography-text is
  primary; this skill owns only the **catalog / translatability** angle and emits a
  `cross_ref: typography-text` on a shared site (per `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`).
- **The blanket deprecated-API sweep belongs to `audit-swiftui-api-currency`.** A legacy
  `NSLocalizedString` is flagged here for its *translatability* implication; currency owns generic
  deprecation. Emit `cross_ref: api-currency` if both fire.
- **Date/number `FormatStyle` for *async-loaded* data** seams to `audit-swiftui-async-data`; **RTL
  mirroring of layout containers** seams to `audit-swiftui-layout-and-tables`; **`\.locale` /
  `\.layoutDirection` preview coverage** seams to `audit-swiftui-previews`. Note in one line, route, do
  not double-own.

## Domain rules (the four that catch most bugs)

1. **A string literal in `Text`/`Label`/`.navigationTitle` IS localized; a `String` variable is NOT.**
   The `Text(_ key: LocalizedStringKey)` overload localizes; the `Text(_ content: some StringProtocol)`
   overload does not. Passing a variable silently bypasses the catalog (loc-02).
2. **`verbatim:` is a deliberate opt-OUT of localization.** Right for a brand name / version / number;
   wrong for any human-readable UI copy (loc-01) — and its *absence* on a genuinely non-translatable
   literal pollutes the catalog (loc-09).
3. **Never assemble a user-facing sentence by interpolation or `+`.** Plurals and grammar agreement
   need the String Catalog's variations (`%lld`, automatic grammar agreement / `inflect`), not Swift
   string-building (loc-06).
4. **Never format numbers/dates for display with `String(format:)` or a hand-built formatter.** Those
   are locale-unaware; use a `FormatStyle` / `.formatted()` (loc-07).

## Defect index (loc-01 … loc-10)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct),
**warning** (compiles but non-native / wrong in another language), **advisory** (judgment / hygiene).
All fixes are `flag` — localization corrections are judgment-heavy (key naming, comment wording,
translatable-or-not), so this skill shows the ✅ and the dev applies it; none are mechanical auto-fixes.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| loc-01 | `Text(verbatim:)` wrapping human-readable UI copy → drop `verbatim:` so it auto-localizes | warning | flag | `strings-and-catalog.md` |
| loc-02 | a non-literal `String` passed to `Text(_)` / `Label` / `.navigationTitle` (StringProtocol overload — not localized) | warning | flag | `strings-and-catalog.md` |
| loc-03 | `NSLocalizedString(...)` legacy macro in SwiftUI code → `String(localized:)` / inline key | advisory | flag | `strings-and-catalog.md` |
| loc-04 | no `.xcstrings` String Catalog in the project (loose `.strings` or none) | advisory | flag | `strings-and-catalog.md` |
| loc-05 | a UI literal with no `comment:` for translators | advisory | flag | `strings-and-catalog.md` |
| loc-06 | a UI sentence built by interpolation / `+` → no pluralization / grammar agreement | warning | flag | `plurals-grammar-and-format.md` |
| loc-07 | `String(format:)` / `DateFormatter` / `NumberFormatter` for display → locale-unaware → `FormatStyle` | warning | flag | `plurals-grammar-and-format.md` |
| loc-08 | a directional SF Symbol `Image(systemName: "…left/right…")` doesn't mirror in RTL → `.backward`/`.forward` | warning | flag | `rtl-and-layout-direction.md` |
| loc-09 | a brand / version / non-translatable literal in `Text("…")` NOT wrapped `verbatim:` → pollutes the catalog | advisory | flag | `strings-and-catalog.md` |
| loc-10 | a hard-coded horizontal `.offset(x:)` / `.position(x:)` assumes LTR → mirror-unsafe | advisory | flag | `rtl-and-layout-direction.md` |

**loc-04 is project-level** (file-presence, not a `.swift` tell — checked in ORIENT). **loc-05 and
loc-09 are READ-judgment** (no clean regex distinguishes "human-readable copy" from "a brand name") —
they are detected in READ/DETECT, not by the lint runner. No rule is dropped; each is routed below.

## The real API, at a glance

**Real (use these):** `Text(_ key: LocalizedStringKey)` (literal → auto-localizes),
`Text(_:comment:)`, `Text(verbatim:)` (opt-out), `LocalizedStringKey`, `LocalizedStringResource`
(macOS 13+), `String(localized:_:)` / `String.LocalizationValue` (macOS 12+ — doc lives under
`/documentation/swift/`, **not** `/foundation/`), `FormatStyle` / `.formatted(…)`,
`@Environment(\.layoutDirection)`, `\.locale`, `flipsForRightToLeftLayoutDirection(_:)`,
`InflectionRule` (macOS 12+, automatic grammar agreement). **Catalog format:** the **String Catalog
(`.xcstrings`)**, not legacy `.strings`/`.stringsdict`.

**Avoid for display:** `NSLocalizedString` (legacy), `String(format:)`, hand-built `DateFormatter` /
`NumberFormatter` without a `\.locale`, raw `\(interpolation)` for sentences. Floor *values* are the
reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate.
There is no localization hallucination blacklist; if a symbol's existence is in doubt, VERIFY (step 5).

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). Then check
   **loc-04**: `find . -name '*.xcstrings'` — if none (and the app has user-facing copy), the project
   ships no String Catalog. Note loose `.strings`/`.stringsdict` as the legacy form. Record both.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-localization --dir <sources> --json /tmp/loc.json --sarif /tmp/loc.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`, loc-01/03/06/07/08/10) + the tier-2
   structural ast-grep rule (`lint/ast-grep/loc-02-nonliteral-text.yml` — the `String`-variable-into-
   `Text` case grep can't express), plus a per-file **parse probe**, and emits unified JSON + SARIF.
   **Read its `parse_warnings`** — a flagged file did not fully parse, so READ those by hand. The runner
   only LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. For each `Text`/
   `Label`/title decide: literal-or-variable, human-readable-or-not, has a `comment:`. This READ is where
   loc-05 (missing comment) and loc-09 (a non-translatable literal that *should* be `verbatim:`) are
   judged — the lint can't see meaning.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty**. "Is this literal human-readable UI copy or a brand/version token?" is the load-bearing
   call for loc-01/loc-09.
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place,
   a "what do shipping apps actually write?" question) run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and
   `swiftui-ctx deprecated <api>` for a currency/deprecation rule): read its `consensus` (the canonical
   shape), `recommended` permalink, `introduced_macos`, `co_occurs_with`; a `lookup` **exit 3**
   (not-found, with a did-you-mean `suggestion`) corroborates a non-existent symbol. (b) **Spec** —
   confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md`
   for the path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol
   (never `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md`.
   The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with
   the citation or discard.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first.
   **Every loc rule is `fix_mode: flag-only`** — leave findings `open` with the ✅ in `## Correct`. The
   ✅ "Correct" is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape**, backed by
   a real macOS-26 example fetched with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart`
   whose GitHub permalink (plus the Sosumi `doc:`) goes in `## Source`.
8. **DOUBLE-CHECK.** Re-confirm every citation still resolves and still says the floor it claims. If a
   reader applied a suggested ✅ and it would introduce a new tell, loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. loc-01 vs loc-09 turns entirely on the
human-readable-vs-token judgment; when unsure, carry as `advisory` and say so, don't assert.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/localization/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/localization/_index.md`.
- `domain: localization`. Frontmatter is the canonical schema; `fix_mode` is `flag-only` for every loc
  rule. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date (fetched
  via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` per the seam note on shared sites.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `hardcoded-strings/` | a `String` var escapes localization, or `verbatim:` is misused either way (loc-01, loc-02, loc-09) |
| `string-catalog/` | the project ships no `.xcstrings`, or a UI literal lacks a translator `comment:` (loc-04, loc-05) |
| `legacy-api/` | a legacy `NSLocalizedString` macro is used where a literal key / `String(localized:)` belongs (loc-03) |
| `plurals-and-grammar/` | a sentence is built by interpolation/`+` so plurals & grammar agreement break (loc-06) |
| `locale-formatting/` | numbers or dates are formatted locale-unaware via `String(format:)` / a hand formatter (loc-07) |
| `rtl-layout/` | a directional SF Symbol or a hard-coded horizontal offset/position breaks in RTL (loc-08, loc-10) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/localization/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/strings-and-catalog.md` | literal-vs-variable, `verbatim:` both ways, String Catalog (`.xcstrings`), translator comments, `String(localized:)` (loc-01/02/03/04/05/09) |
| `references/plurals-grammar-and-format.md` | sentence assembly, pluralization, automatic grammar agreement / `inflect`, locale-aware number/date `FormatStyle` (loc-06/07) |
| `references/rtl-and-layout-direction.md` | RTL: directional SF Symbols, `layoutDirection`, image mirroring, hard-coded horizontal offsets (loc-08/10) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (typography-text, api-currency, async-data, previews, layout-and-tables) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-localization --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, loc-01/03/06/07/08/10) +
**tier-2 ast-grep** (`lint/ast-grep/loc-02-nonliteral-text.yml` — a `String` *variable* passed to
`Text(_)`, which grep cannot distinguish from a literal). It runs a per-file **parse probe** (surfaces
"did not fully parse" so a structural miss can't look clean), emits unified **JSON + SARIF**, and
**degrades to grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli
ast-grep`; faster: `brew install ast-grep`). loc-04 (no `.xcstrings`) is a project-file check done in
ORIENT, not by the runner; loc-05/loc-09 are READ-judgment. It only LOCATES — always READ each hit in
full before reporting (step 3). The thin `scripts/loc-lint.sh` is a pointer to this runner. Engine +
rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
</content>
</invoke>
