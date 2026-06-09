---
name: audit-swiftui-appearance-color
description: Audits a finished or in-progress macOS SwiftUI codebase for appearance and color defects on macOS 26 Tahoe and writes per-finding Markdown to swiftui-audits/. Use when the user says Dark Mode looks broken, colors do not adapt, text is hardcoded gray, the app forces light or dark, contrast is too low, or a background looks flat or opaque; when they ask to verify Color, hardcoded RGB, asset-catalog colors, foregroundColor, foregroundStyle, accentColor, tint, Material, vibrancy, preferredColorScheme, colorScheme, or colorSchemeContrast on a Mac target; when AI may have written Color(red:green:blue:), Color.white, Color.black, .foregroundColor, .accentColor, .textColor, .backgroundColor, .tintColor, or UIColor; or when an app forces a color scheme app-wide or ignores Increase Contrast. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for AppKit NSColor/NSVisualEffectView, not for Liquid Glass, not for the general deprecation sweep, not for WCAG accessibility audits, not for writing new themed UI from scratch.
---

# Audit SwiftUI Appearance & Color

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way appearance and color go wrong on a macOS 26
(Tahoe) target: hardcoded `Color(red:green:blue:)` / `Color.white` / `Color.black` that freeze one
appearance, deprecated `.foregroundColor` / `.accentColor`, opaque `Color` backgrounds where a `Material`
belongs, a force-set `.preferredColorScheme` that overrides the user's system appearance, ignored
Increase-Contrast, and invented or cross-platform color APIs. Findings are written to disk in the
toolkit's unified schema; certain mechanical defects are fixed under the fix-safety protocol. This is
never a from-scratch theming generator.

Two of this domain's modifiers **deprecate at macOS 26.5** (after most training data), so AI frequently
emits `.foregroundColor` and `.accentColor`, and pads dark-broken literal RGB throughout. Be suspicious
wherever AI set a color.

## Boundary / seam note (stay in lane)

- **The `.foregroundColor(_:)` / `.accentColor(_:)` deprecation *flag*** is owned by
  `audit-swiftui-api-currency`; **this skill owns the positive `.foregroundStyle` hierarchy /
  asset-catalog / `.tint` craft.** Emit `cross_ref: api-currency` on ac-03/ac-04; do not double-own the flag.
- **Liquid Glass surfaces (`glassEffect`, the `.glass` button styles, `GlassEffectContainer`)** belong to
  `audit-swiftui-liquid-glass`. A *plain* `Material` (`.ultraThinMaterial` …) that is the right chrome
  fill stays here; a missing **glass** surface routes there. Emit `cross_ref: liquid-glass` on ac-06.
- **WCAG ratios, Differentiate-Without-Color, and the trait-level a11y audit** belong to
  `audit-swiftui-accessibility`; this skill detects the *mechanics* (an ignored `colorSchemeContrast`),
  a11y owns the contrast requirement. Emit `cross_ref: accessibility` on ac-07.
- **AppKit `NSColor` / `NSVisualEffectView` vibrancy** is out of scope — note it in one line and point to
  the future `audit-appkit-interop` / `audit-appkit-overuse` skills.

## Domain rules

1. **Color is semantic, not literal.** Use a system color (`.primary`, `.secondary`, `Color.accentColor`)
   or a **named asset-catalog color** that carries Any/Dark variants. A raw `Color(red:green:blue:)` or
   `Color.white`/`.black` paints one appearance and breaks Dark Mode.
2. **Style the foreground through the hierarchy.** `.foregroundStyle(.secondary)` / `.tertiary` adapts to
   appearance and vibrancy; a hardcoded gray does not. `.foregroundColor` is deprecated at 26.5.
3. **Let chrome breathe with a `Material`.** Sidebars, overlays, popovers, and bars behind content want
   `.ultraThinMaterial`/`.regularMaterial` (or a glass surface), not an opaque `Color` fill.
4. **Never force the appearance app-wide.** `.preferredColorScheme(.dark)` at the root overrides the
   user's macOS system setting — an anti-pattern. Scope it to a deliberate preview/island only.
5. **Honor Increase Contrast.** Read `@Environment(\.colorSchemeContrast)` and branch where custom colors
   would otherwise fall below the system contrast.

## Defect index (ac-01 … ac-08)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (never-correct / invented),
**warning** (compiles but non-native / breaks Dark Mode / deprecated), **advisory** (judgment / craft).
`auto` = mechanical single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| ac-01 | hardcoded `Color(red:green:blue:)` / `Color(.sRGB…)` literal RGB → breaks Dark Mode | warning | flag | `colors-semantic-and-assets.md` |
| ac-02 | `Color.white` / `Color.black` / `Color(white:)` as content fg/bg → no Dark-Mode adapt | warning | flag | `colors-semantic-and-assets.md` |
| ac-03 | `.foregroundColor(_:)` deprecated 26.5 → `.foregroundStyle(_:)` (+ `.secondary` hierarchy) | warning | auto | `colors-semantic-and-assets.md` |
| ac-04 | `.accentColor(_:)` deprecated 26.5 → `.tint(_:)` | warning | auto | `colors-semantic-and-assets.md` |
| ac-05 | forced `.preferredColorScheme(_:)` at app/root scope → overrides user appearance | warning | flag | `color-scheme-and-contrast.md` |
| ac-06 | opaque `Color` background where a `Material` belongs (sidebar/overlay/bar) | advisory | flag | `materials-and-vibrancy.md` |
| ac-07 | custom colors with no `@Environment(\.colorSchemeContrast)` branch under Increase Contrast | advisory | flag | `color-scheme-and-contrast.md` |
| ac-08 | invented / cross-platform color API: `.textColor(`, `.backgroundColor(`, `.tintColor(`, `UIColor` | hard-fail | flag | `colors-semantic-and-assets.md` |

**Currency seam:** ac-03 and ac-04 carry `cross_ref: api-currency` (currency flags the deprecation;
appearance owns the replacement craft). ac-06 carries `cross_ref: liquid-glass`; ac-07 carries
`cross_ref: accessibility`.

## The real API, at a glance

**Real (exist on macOS 26):** `Color` (`.primary`, `.secondary`, `Color.accentColor`, named
asset-catalog `Color("Brand")`), `foregroundStyle(_:)` (macOS 12+, takes a `ShapeStyle` hierarchy —
`.secondary`/`.tertiary`), `tint(_:)` (Color overload macOS 12+; the `ShapeStyle` overload is macOS 13+),
`Material` (`.ultraThinMaterial` … macOS 12+),
`@Environment(\.colorScheme)` / `@Environment(\.colorSchemeContrast)` (macOS 10.15+),
`preferredColorScheme(_:)` (macOS 11+, *for scoped use*), `ShapeStyle` hierarchy levels
(`.primary`/`.secondary`/`.tertiary`/`.quaternary`/`.quinary` — all macOS 12+). **`foregroundColor(_:)` and `accentColor(_:)` still resolve but are
deprecated at macOS 26.5 → `foregroundStyle(_:)` / `tint(_:)`.**

**Invented / cross-platform (never SwiftUI-on-macOS):** `.textColor(_:)`, `.backgroundColor(_:)`,
`.tintColor(_:)`, `.foregroundColour(_:)`, `UIColor` (UIKit — absent on macOS; the bridge is
`Color(nsColor:)`). Confirm any uncertain name via `swiftui-ctx lookup <api>` (exit 3 = no shipping Mac
app uses it) + the canonical invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate.

Floor / deprecation *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate the table here.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   the ac-03/ac-04 deprecations are advisory below their 26.5 close and become live-warning at/after it.
   Also note whether an **asset catalog** (`*.xcassets`) with color sets exists — its presence changes the
   ac-01/02 ✅ to "move the literal into a color set." Record both.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-appearance-color --dir <sources> --json /tmp/ac.json --sarif /tmp/ac.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + the tier-2 structural ast-grep rule
   (`lint/ast-grep/*.yml` — the multi-arg `Color(red:green:blue:)` init grep can't reliably anchor across
   lines), a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a
   flagged file did not fully parse, so a structural miss can't masquerade as clean; READ those by hand.
   The runner only LOCATES. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a literal
   color is a content fill vs a deliberate brand mark, whether a `Color` background is chrome that wants a
   `Material`, whether a `.preferredColorScheme` is app-root vs a scoped preview, and whether a view even
   has custom colors that need a contrast branch are all invisible to grep. Build a per-file inventory:
   each color site + literal-or-semantic + its surface (content/chrome) + its scheme/contrast handling.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (an invented name, a literal `Color(red:`, a root `.preferredColorScheme`).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, a
   deprecation you can't date), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated <api>` for ac-03/ac-04): read its `consensus`
   (the canonical shape), `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and
   `co_occurs_with`; a `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates an
   ac-08 hallucination — no shipping Mac app uses the symbol. (b) **Spec** — confirm via **Sosumi**:
   `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi `doc:`
   floor. The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote
   with the citation or discard.

   **Deeper corpus evidence (this domain's VALUE vocabulary).** To ground an ac-06 Material pick or an
   ac-01/02 semantic-color/gradient replacement in the *real* vocabulary, run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx valueBuilders` (filter e.g. `gradient`/`material`; Color/Material/gradient builders ranked by usage) and
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx conformances ShapeStyle` (and `… conformances ButtonStyle`)
   for custom `ShapeStyle`/`ButtonStyle` conformers (stable envelope + `next_actions` + permalinks), and
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx examples foregroundStyle --shape "(_)"` for the consensus
   modifier shape (`(_)`, 100%). E.g. the corpus material consensus is **`.regular` (10,238 uses / 978
   repos) — not `.ultraThin` (32 / 13)**: prefer `.regularMaterial` as the ac-06 ✅ unless the surface is
   genuinely a thin overlay. Per the shared CLI surface in `swiftui-ctx-reference.md`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (ac-03 `.foregroundColor(x)` → `.foregroundStyle(x)`; ac-04 `.accentColor(x)`
   → `.tint(x)` — identical-argument mechanical renames), one conventional commit per finding citing its
   `rule_id`, never weaken a check. The ✅ "Correct" is **not a hand-written snippet** — it is the
   swiftui-ctx **consensus shape** put in `## Correct`, backed by a real macOS example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source`. Leave `flag-only` findings `open` with that ✅. The
   verified canonical `.foregroundStyle(_:)` ✅ — the live swiftui-ctx **consensus shape `(_)` (100 %)**,
   grounded in real corpus code, not a placeholder:

   ```swift
   // ✅ Correct — swiftui-ctx `lookup foregroundStyle` consensus `(_)` (100%); real example
   //    sindresorhus/Gifski `ex_032f0b9e2b` (author_authority 1,013,769, 8,409★, min_macos 26)
   Circle()
       .stroke(lineWidth: lineWidth)
       .opacity(0.3)
       .foregroundStyle(.secondary)   // adapts to appearance + vibrancy; no frozen literal
   // permalink: https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Utilities.swift#L5192
   // doc: https://sosumi.ai/documentation/swiftui/view/foregroundstyle(_:)
   ```
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence in
   `## Fix applied?`. Re-confirm every citation still resolves. If a fix introduced a new tell (e.g. a
   `.foregroundStyle` you wrote now takes a literal `Color(red:` that should be a hierarchy/asset color),
   loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can become
a finding — never emit a speculative finding. Auto-fix only the mechanical set (ac-03, ac-04 — both pure
same-argument renames); everything else is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/appearance-color/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/appearance-color/_index.md`.
- `domain: appearance-color`. Frontmatter is the canonical schema; `fix_mode` is `auto` for ac-03/ac-04,
  else `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date
  (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` for ac-03/ac-04
  (`api-currency`), ac-06 (`liquid-glass`), ac-07 (`accessibility`).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `hardcoded-color/` | a literal RGB / white / black color paints one appearance, or an invented color API appears (ac-01, ac-02, ac-08) |
| `deprecated-modifiers/` | `.foregroundColor` or `.accentColor` is used at/under their 26.5 close (ac-03, ac-04) |
| `color-scheme/` | the appearance is force-set app-wide, or Increase Contrast is ignored (ac-05, ac-07) |
| `materials/` | an opaque `Color` fills chrome that should breathe with a `Material` (ac-06) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/appearance-color/` with a lowercase-hyphen slug naming the sub-category, and note it in
the run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/colors-semantic-and-assets.md` | literal RGB / white-black colors, the `.foregroundColor`→`.foregroundStyle` and `.accentColor`→`.tint` rewrites, asset-catalog color sets, invented color names (ac-01/02/03/04/08) |
| `references/materials-and-vibrancy.md` | an opaque `Color` where a `Material` belongs, the Material-vs-glass boundary, vibrancy (ac-06) |
| `references/color-scheme-and-contrast.md` | force-set `.preferredColorScheme`, honoring `colorScheme`/`colorSchemeContrast`, Increase Contrast (ac-05/07) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + the tier-2 structural `Color(red:green:blue:)` init rule); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability/deprecation value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (ac-08) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (any `#available` near a color symbol) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (api-currency, liquid-glass, accessibility) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-appearance-color --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, ac-01…ac-08) + a **tier-2 ast-grep**
structural rule (`lint/ast-grep/ac-01-hardcoded-rgb.yml` — the `Color(red:green:blue:)` literal init,
anchored on the call so the multi-line / multi-arg form grep can't reliably catch is caught structurally).
It runs a per-file **parse probe** (surfaces "did not fully parse"), emits unified **JSON + SARIF**, exits
**2** on any hard-fail (ac-08) for a CI gate, and **degrades to grep-only with a notice** if ast-grep is
unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES —
always READ each hit in full before reporting (step 3). The legacy `scripts/appearance-lint.sh` is a thin
pointer to this runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
