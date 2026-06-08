---
name: audit-swiftui-accessibility
description: Audits a finished or in-progress macOS SwiftUI codebase for accessibility defects — icon-only controls with no label, ungrouped composite controls, custom controls with no value, color-only state, no Reduce-Motion path, undescribed Chart/Canvas, missing traits, broken VoiceOver focus — and writes per-finding Markdown to swiftui-audits/. Use when the user says VoiceOver reads nothing or the wrong thing, an icon button is unlabeled, a chart or canvas is unreadable, the app fails Differentiate Without Color or Reduce Motion, focus order is wrong, or when AI may have written accessibilityText, voiceOverLabel, a11yLabel, the legacy accessibility(label:) modifier, or an isToggle trait ungated below macOS 14. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for AppKit NSAccessibility, not for keyboard @FocusState (controls-forms), not for Dynamic-Type sizing (typography-text), not for writing new accessible UI from scratch.
---

# Audit SwiftUI Accessibility

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way the assistive-technology experience breaks:
unlabeled icon controls, composites that read as fragments, custom controls with no value, color- or
motion-only information, undescribed charts/canvases, missing traits, stranded VoiceOver focus, and
hallucinated or legacy accessibility APIs. Findings are written to disk in the toolkit's unified schema;
the mechanical defects (invented names, the legacy combinator) are fixed under the fix-safety protocol.
This is never a from-scratch accessibility generator.

Accessibility modifiers are **additive and invisible** — the code compiles and looks right with none of
them. The lint only *locates* candidates; whether a label is missing, wrong, or correctly present is an
LLM judgment from READING the view. Be suspicious wherever a control has no visible text.

## Boundary / seam note (stay in lane)

- **AppKit `NSAccessibility*` is out of scope.** If audited code drops to an `NSViewRepresentable` and sets
  `NSAccessibility` properties, note it in one line and defer to the future `audit-appkit-accessibility` —
  do not audit AppKit accessibility here.
- **Keyboard `@FocusState`** (Tab-key focus) belongs to `audit-swiftui-controls-forms`; this skill owns
  **`AccessibilityFocusState`** (VoiceOver focus). Different wrappers — keyboard = controls, VoiceOver = a11y.
- **`.help` text** is authored by `audit-swiftui-controls-forms`; this skill **reuses that `.help` string** as
  the `.accessibilityLabel` for an icon-only control. Keep both, cross-linked (`cross_ref controls-forms`).
- **Dynamic-Type sizing** is `audit-swiftui-typography-text`; **Differentiate-Without-Color / WCAG contrast**
  construction is `audit-swiftui-appearance-color`; **Reduce-Motion construction** is
  `audit-swiftui-animation-motion` — this skill owns only *"the flag is ignored"*. Chart/Canvas descriptors
  are intentionally **double-detected** with `charts` / `drawing-canvas` (cross-link, don't collapse).

## The four assistive-technology axes (the lens)

1. **Perceivable.** Every control conveys its identity without sight: a *label* (icon-only → `.accessibilityLabel`),
   a *value* (custom control → `.accessibilityValue`), and never information by **color or motion alone**.
2. **Operable.** Anything tappable carries an actionable **trait** (`.isButton`, `.isToggle`) and a sane
   VoiceOver **focus order** (`AccessibilityFocusState`, `.accessibilitySortPriority`).
3. **Grouped.** A composite (HStack/VStack of Text+Image that is *one* control) is collapsed with
   `.accessibilityElement(children: .combine/.ignore)`; decorative imagery is `.accessibilityHidden(true)`.
4. **Represented.** A `Chart` / `Canvas` exposes an `.accessibilityChartDescriptor` / `.accessibilityRepresentation`.

**The element test:** ask "what does VoiceOver announce when it lands here, and can the user act?" No
answer → a finding. Full reasoning + the per-control coverage artifact: `references/labels-and-traits.md`.

## Defect index (a11y-01 … a11y-12)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (invented name / build-or-floor
break), **warning** (compiles but inaccessible), **advisory** (judgment / partial). `auto` = mechanical
single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| a11y-01 | icon-only control (`Image(systemName:)`/`Label` icon) is the sole content, no `.accessibilityLabel` | warning | flag | `labels-and-traits.md` |
| a11y-02 | purely-decorative `Image` not `.accessibilityHidden(true)` (VoiceOver clutter) | advisory | flag | `labels-and-traits.md` |
| a11y-03 | custom composite (Text+Image as one control) with no `.accessibilityElement(children:)` | warning | flag | `grouping-and-values.md` |
| a11y-04 | custom value control (hand-rolled gauge/slider/progress) with no `.accessibilityValue` | warning | flag | `grouping-and-values.md` |
| a11y-05 | state conveyed by **color only** — no label/shape/symbol fallback (Differentiate-Without-Color) | warning | flag | `perceptual-paths.md` |
| a11y-06 | animation/transition with no `accessibilityReduceMotion` branch (ignores the flag) | advisory | flag | `perceptual-paths.md` |
| a11y-07 | `Chart` / `Canvas` with no a11y representation (`accessibilityChartDescriptor`/`Representation`) | warning | flag | `perceptual-paths.md` |
| a11y-08 | `.onTapGesture`/`.onLongPressGesture` on a non-Button, no `.isButton`/`.isToggle` trait | warning | flag | `labels-and-traits.md` |
| a11y-09 | `AccessibilityFocusState` declared-but-never-driven, or broken VoiceOver reading order | advisory | flag | `grouping-and-values.md` |
| a11y-10 | INVENTED name — `.voiceOverLabel`/`.a11yLabel`/`.accessibilityText(`/`.screenReaderLabel`/`.accessibilityName(` | hard-fail | auto | `accessibility-api-surface.md` |
| a11y-11 | LEGACY combined `.accessibility(label:/hint:/addTraits:/value:)` modifier | warning | auto | `accessibility-api-surface.md` |
| a11y-12 | `.isToggle` trait (macOS 14) or closure-form label/value (macOS 15) ungated under a lower floor | warning | flag | `labels-and-traits.md` |

**`.accessibility(label:)` IS confirmed deprecated** — Apple docs show `macOS 10.15–26.5 Deprecated`, replacement
`accessibilityLabel(_:)` (the whole combined family — `hint:`/`value:`/`hidden:`/`identifier:`/`addTraits:`/
`removeTraits:`/`sortPriority:` — is deprecated likewise). The corpus `deprecated:false` was a false negative.
Carry a11y-11 as a `warning` migration with `source: macOS 10.15–26.5 Deprecated → accessibilityLabel(_:)`.

## The real API, at a glance

**Real (exist on macOS):** `accessibilityLabel(_:)` (string `StringProtocol` macOS 11; string `LocalizedStringResource` macOS 13; closure macOS 15), `accessibilityValue(_:)`
(macOS 11; closure form macOS 15), `accessibilityHint(_:)` (13), `accessibilityHidden(_:)` (11),
`accessibilityElement(children:)` (10.15), `accessibilityAddTraits(_:)`/`accessibilityRemoveTraits(_:)` (11),
`accessibilityFocused(_:)` + `AccessibilityFocusState` (12), `accessibilitySortPriority(_:)` (11),
`accessibilityChartDescriptor(_:)` (12), `accessibilityRepresentation(representation:)` (12),
`@Environment(\.accessibilityReduceMotion)` / `\.accessibilityDifferentiateWithoutColor` (10.15).
**`AccessibilityTraits.isToggle` is macOS 14.0+ — NOT 10.15; never assert it on a lower floor.**

**Hallucinated (never exist):** `.voiceOverLabel`, `.a11yLabel`, `.accessibilityText(…)`, `.screenReaderLabel`,
`.accessibilityName(…)`, `.voiceOverHint`. A `swiftui-ctx lookup` **exit 3** corroborates each.
**Real-but-legacy:** the combined `.accessibility(label:/hint:/addTraits:/value:)` modifier → split into the
per-aspect modifiers.

Signatures, the full ❌→✅ rewrites, and the canonical shapes (via `swiftui-ctx lookup`): the reference files.
Floor *values* are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and the
canonical invented-name list in `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read,
never restate them.

### ✅ Correct — the grounded shape (real corpus, not invented)

The fix for an icon-only control (a11y-01) is the **swiftui-ctx consensus shape** `accessibilityLabel(_)`
(**100% of real uses**, `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup accessibilityLabel --json`) — a
string label chained *outside* the visual node. Real shipping example, fetched live via
`swiftui-ctx file ex_e9a36e4789 --smart` (`jordanbaird/Ice`, 28k★):

```swift
// github.com/jordanbaird/Ice …/Ice/UI/IceBar/IceBar.swift#L406
Image(nsImage: image)
    .contentShape(Rectangle())
    .overlay { IceBarItemClickView(item: item, leftClickAction: …, rightClickAction: …) }
    .accessibilityLabel(item.displayName)              // ← the icon now announces a real name
    .accessibilityAction(named: "left click", leftClickAction)
    .accessibilityAction(named: "right click", rightClickAction)
```

- **Permalink:** `https://github.com/jordanbaird/Ice/blob/11edd39115f3f43a83ae114b5348df6a0e1741cf/Ice/UI/IceBar/IceBar.swift#L406`
- **Spec (Sosumi `doc:`):** `https://sosumi.ai/documentation/swiftui/view/accessibilitylabel` (macOS 13.0+, string form).

Every finding's `## Correct` is built this way — never a hand-written snippet. The label *text* stays
`flag-only` (a judgment call); the *shape* is the corpus consensus above.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   a11y-12 fires **only** when the floor is **below macOS 14** (`.isToggle`) or **below 15** (closure-form
   label/value). Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-accessibility --dir <sources> --json /tmp/a11y.json --sarif /tmp/a11y.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the undescribed-Chart containment rule grep can't express),
   plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a flagged
   file did not fully parse, so a structural miss can't masquerade as clean; READ those by hand. The runner
   only LOCATES. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a control
   already has a label, whether an `Image` is decorative, whether a composite is *one* control, and the
   focus order are all invisible to grep. Build a per-view inventory: each control → its announced label +
   value + trait + (for composites) its grouping + (for charts/motion) its representation/Reduce path.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. an invented name, an icon-only Button with provably no label, an `.isToggle` under a
   <14 floor). An *absence* (no label) is a finding only after you have read the whole view and confirmed it.
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, a
   deprecation claim), run **both** evidence sources. (a) **Practice** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
   lookup <api> --json` (and `swiftui-ctx deprecated <api>` for a11y-11): read its `consensus` (the canonical
   shape), `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and `co_occurs_with`; a
   `lookup` **exit 3** (with a did-you-mean `suggestion`) corroborates an a11y-10 hallucination — no shipping
   Mac app uses the symbol. (b) **Spec** — confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>`
   using `references/source-directory.md` for the path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`
   for the protocol (never `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against
   `floors-master.md` and the Sosumi `doc:` floor. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or discard.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit `cross_ref` on the shared seams (a11y-05 → appearance-color, a11y-06 → animation-motion,
   a11y-07 → charts/drawing-canvas, a11y-01/08 → controls-forms `.help`). Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (a11y-10 invented-name swap, a11y-11 legacy-combinator split), one conventional
   commit per finding citing its `rule_id`, never weaken a check. The ✅ "Correct" is **not a hand-written
   snippet** — it is the swiftui-ctx **consensus shape** put in `## Correct`, backed by a real macOS example
   fetched with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub
   permalink (plus the Sosumi `doc:`) goes in `## Source`. The label *text* itself (a judgment call) stays
   `flag-only` — never auto-invent a string. Leave `flag-only` findings `open` with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence in
   `## Fix applied?`. Re-confirm every citation still resolves and its floor still matches. If a fix introduced
   a new tell (e.g. an added `.isToggle` now needs a macOS-14 gate), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. An accessibility *absence* (missing label/value/trait) is a
finding **only after reading the whole view** and confirming nothing supplies it — a `.help`, an
`.accessibilityLabel` on a parent, or a native control's built-in semantics can all already cover it.
Anything ≤ ~70% goes to VERIFY (step 5). Auto-fix only the mechanical set (a11y-10/11); the label/value/trait
*content* is always `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this domain:

- Findings: `swiftui-audits/accessibility/<context>/NN-slug.md` (one finding per file, zero-padded, ordered).
  Per-run index: `swiftui-audits/accessibility/_index.md`.
- `domain: accessibility`. Frontmatter is the canonical schema; `fix_mode` is `auto` for a11y-10/11, else
  `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date (via
  Sosumi) or `verify against Xcode 26 SDK`. **Additive field `a11y_axis`** records the broken axis —
  `perceivable` | `operable` | `grouped` | `represented` — so a run can be read by assistive-tech failure mode.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `missing-label/` | an icon-only control has no announced label, or a decorative image isn't hidden (a11y-01, a11y-02) |
| `missing-value/` | a custom value control announces no value (a11y-04) |
| `grouping/` | a composite reads as fragments — no `accessibilityElement(children:)` (a11y-03) |
| `traits-and-focus/` | a tappable lacks an actionable trait, or VoiceOver focus order is broken (a11y-08, a11y-09) |
| `color-and-motion/` | information is color-only or motion ignores Reduce Motion (a11y-05, a11y-06) |
| `chart-canvas-representation/` | a `Chart`/`Canvas` is undescribed to VoiceOver (a11y-07) |
| `hallucinated-api/` | a name doesn't exist, or the legacy combined modifier is used (a11y-10, a11y-11) |
| `availability-gating/` | `.isToggle` / closure-form label/value used ungated under a lower floor (a11y-12) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/accessibility/` with a lowercase-hyphen slug naming the sub-category, and note it in the run's
`_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a hard
requirement.* Two runs over the same code produce structurally identical trees.

> **Go-beyond artifact (optional):** `swiftui-audits/accessibility/_coverage-map.md` listing every interactive
> view with its announced label/value/trait and a per-axis coverage score — see `references/labels-and-traits.md`.

## Reference routing

| File | Open when |
|---|---|
| `references/accessibility-api-surface.md` | a name/signature/existence question — the real allow-list, the invented ❌→✅, the legacy-combinator split (a11y-10/11) |
| `references/labels-and-traits.md` | icon-only labels, decorative hiding, missing traits, `.isToggle`/closure-form gating, the coverage map (a11y-01/02/08/12) |
| `references/grouping-and-values.md` | composite grouping, custom-control values, VoiceOver focus order (a11y-03/04/09) |
| `references/perceptual-paths.md` | color-only state, Reduce-Motion path, Chart/Canvas representation (a11y-05/06/07) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth — incl. `.isToggle`=macOS 14, closure forms=15) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (a11y-12 floor gate) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys + the `a11y_axis` additive field |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (controls-forms, appearance-color, animation-motion, charts, drawing-canvas) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-accessibility --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, a11y-01/02/03/04/05/06/07/08/09/10/11/12)
+ **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` — a11y-07 Chart-no-descriptor — the
containment/absence form grep cannot express; a11y-01 stays grep-tier because a correct label chains *outside*
the Button node, so a containment rule would false-positive). It runs a per-file **parse probe**
(surfaces "did not fully parse" so a structural miss can't look clean), emits unified **JSON + SARIF**, exits
**2** on any hard-fail (a11y-10/12) for a CI gate, and **degrades to grep-only with a notice** if ast-grep is
unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES —
accessibility is additive and invisible, so always READ each hit in full before reporting (step 3). The thin
`scripts/a11y-lint.sh` is a pointer to this runner. Engine + rule-file format + JSON/SARIF shape + safety
rails: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
