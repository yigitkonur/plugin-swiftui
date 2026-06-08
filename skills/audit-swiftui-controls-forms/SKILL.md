---
name: audit-swiftui-controls-forms
description: Audits a macOS SwiftUI app for control-style and keyboard-focus defects that read as "an iPad app in a window", writing per-finding Markdown to swiftui-audits/. Use when the user says a settings pane looks ungrouped, controls feel oversized, a custom field can't be tabbed to or shows no focus ring, an icon-only button has no tooltip, or a picker renders wrong; when they ask to verify formStyle, the grouped Form, focusable, @FocusState, the help tooltip, listStyle/buttonStyle/pickerStyle, or controlSize on macOS; when AI wrote a plain Form with no .formStyle(.grouped), a custom view with no .focusable(), an icon-only Button with no .help, a sidebar List with no .listStyle(.sidebar), .pickerStyle(.wheel) (no macOS arm), or .controlSize(.extraLarge) (a no-op). AUDIT-ONLY, macOS-only, SwiftUI-only. Not for hover/cursor/right-click/drag (pointer-gestures), VoiceOver or AccessibilityFocusState (accessibility), controlSize as a layout axis (layout-and-tables), color/material (appearance-color), or new control UI.
---

# Audit SwiftUI Controls & Forms

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way iOS-trained control habits read as non-native on a
Mac: an ungrouped `Form`, a custom view that drops out of the Tab order, an icon-only button with no
tooltip, the wrong `listStyle`/`buttonStyle`/`pickerStyle`, oversized `controlSize` density, a
`.pickerStyle(.wheel)` that has **no macOS arm** (compile error), and a `.controlSize(.extraLarge)` that
silently resolves to `.large`. Findings are written to disk in the toolkit's unified schema; certain
mechanical defects are fixed under the fix-safety protocol. This is never a from-scratch control generator.

**The Mac is pointer-and-keyboard-driven, not touch.** The training corpus is overwhelmingly iOS, where a
`Form` already looks grouped, there is no Tab-key focus ring, and control density is fixed — so AI never
learns to ask for `.formStyle(.grouped)`, `.focusable()`, `.help`, or a compact `controlSize`. The result
compiles and looks plausible on iOS but reads as "an iPad app in a window" on macOS. Be suspicious wherever
AI built a settings pane, a custom focus-taking control, or a styled `List`/`Button`/`Picker`.

## Boundary / seam note (stay in lane)

Seam verdicts are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`
— apply them in the tells and emit `cross_ref` on a shared-seam finding; do not double-own.

- **The pointer/gesture HALF is not mine.** `.onHover` cursor affordances, `pointerStyle`/`onContinuousHover`
  cursor shape, right-click `.contextMenu`, and drag gestures all belong to
  `audit-swiftui-pointer-gestures`. This skill owns the **control-styling + keyboard-focus** half only.
  Note a pointer smell in one line and `cross_ref: pointer-gestures` — do not audit it here.
- **Keyboard focus vs VoiceOver focus.** `@FocusState` / `.focusable()` (Tab order, focus ring) is **this
  skill** (cf-02). `AccessibilityFocusState` / `.accessibilityFocused` (VoiceOver focus) is
  `audit-swiftui-accessibility` — different wrappers; `cross_ref` it, don't claim it.
- **Icon-only button with no label.** The missing **`.help` tooltip** is **this skill** (cf-03); the missing
  **`.accessibilityLabel`** is `audit-swiftui-accessibility`. This is a **keep-both** seam — file the `.help`
  finding here, `cross_ref: accessibility`, and a11y reuses this skill's `.help` text for its label.
- **`controlSize` is a split axis.** The **density/style variant** (`.controlSize` as a control-style tuning,
  the `.extraLarge` no-op) is **this skill** (cf-08). `controlSize` as a **layout sizing axis** is
  `audit-swiftui-layout-and-tables`; `cross_ref` it when the issue is layout sizing, not control density.
- **Color / material crossover** (a control's tint/material choice) belongs to `audit-swiftui-appearance-color`.

## The five control rules (the judgment core)

1. **A macOS `Form` is grouped.** `.formStyle(.grouped)` is the System-Settings idiom; the macOS default is
   ungrouped and foreign — iOS forms are grouped out of the box, so AI omits it (cf-01).
2. **Custom focus-taking views must join the Tab order.** `.focusable()` + `@FocusState` + `.focused($_)`
   make a custom control keyboard-reachable and draw the focus ring; native `TextField`/`Button` are already
   focusable, a hand-rolled control is not (cf-02).
3. **Every icon-only control needs a `.help` tooltip** (title case) — the standard macOS tooltip on pointer
   rest, also fed to accessibility; there is no iOS tooltip analog so AI omits it (cf-03).
4. **Pick the Mac style + density explicitly.** `.listStyle(.sidebar)` for a source list, a
   `.buttonStyle(.bordered)`/`.borderless`, a `.pickerStyle(.menu)` pop-up, and a `.controlSize(.small)`/
   `.mini` for dense panes — iOS defaults read oversized (cf-04/05/06).
5. **Never reach for a touch-only style on a Mac.** `.pickerStyle(.wheel)` has **no macOS arm** (compile
   error, cf-07); `.controlSize(.extraLarge)` resolves to `.large` on macOS (a no-op, cf-08).

Full ❌→✅ + the canonical native-settings-pane exemplar: `references/forms-and-focus.md` and
`references/control-styles-density.md`.

## Defect index (cf-01 … cf-08)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (no macOS arm / never-correct),
**warning** (compiles but non-native), **advisory** (judgment / density). `auto` = mechanical single-answer
fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| cf-01 | `Form { … }` with no `.formStyle(.grouped)` in its chain → ungrouped, non-native settings pane | warning | flag | `forms-and-focus.md` |
| cf-02 | a custom `View` with a focus-taking control and no `.focusable()` / `@FocusState` → skipped by Tab, no focus ring | warning | flag | `forms-and-focus.md` |
| cf-03 | icon-only `Button { } label: { Image(systemName:) }` with no `.help(…)` → no tooltip | warning | flag | `forms-and-focus.md` |
| cf-04 | sidebar `List` (in a `NavigationSplitView`) with no `.listStyle(.sidebar)` → wrong sidebar material | advisory | flag | `control-styles-density.md` |
| cf-05 | `Button` in a dense pane with no `.buttonStyle` (`.bordered`/`.borderless`/`.plain`/`.link`) → oversized default | advisory | flag | `control-styles-density.md` |
| cf-06 | `Picker` with no `.pickerStyle(.menu)` / `.segmented` → not the Mac pop-up | advisory | flag | `control-styles-density.md` |
| cf-07 | `.pickerStyle(.wheel)` / `WheelPickerStyle` on a Mac target — **NO macOS arm (compile error)** | hard-fail | flag | `control-styles-density.md` |
| cf-08 | `.controlSize(.extraLarge)` / `ControlSize.extraLarge` — resolves to `.large` on macOS (a no-op) | advisory | flag | `control-styles-density.md` |

**cf-07 is the only hard-fail; cf-02 and cf-03 cross-ref siblings.** `WheelPickerStyle` is **`macOS
ABSENT`** in `floors-master.md` — it is platform-wrong, **not** under-gated; never wrap it in
`#available(macOS …)`, replace it with `.menu`/`.segmented`/`.inline`. A `swiftui-ctx lookup WheelPickerStyle`
**exit 3** corroborates it (no shipping Mac app uses it — confirmed during the build, see VERIFY).

## The real API, at a glance

**Real (exist on macOS; floors are the reconciled truth in `floors-master.md` — read, never restate):**
`formStyle(_:)` (`.grouped`/`.columns`/`.automatic`), `focusable(_:)`, `focused(_:)`, `@FocusState`,
`help(_:)`, `listStyle(_:)` (`.sidebar`/`.inset`/`.bordered`/`.plain`), `buttonStyle(_:)`
(`.bordered`/`.borderless`/`.plain`/`.link`/`.accessoryBar`/`.accessoryBarAction`/`.borderedProminent`), `pickerStyle(_:)`
(`.menu`/`.segmented`/`.inline`/`.radioGroup`), `controlSize(_:)` (`.mini`/`.small`/`.regular`/`.large`).
**`Glass.interactive` / `.buttonStyle(.glass)` are macOS 26.0+** and owned by `audit-swiftui-liquid-glass`;
note in one line and `cross_ref`, don't gate them here.

**Platform-wrong (never a Mac API):** `.pickerStyle(.wheel)` / `WheelPickerStyle` (**macOS ABSENT** —
compile error on non-Catalyst macOS; cf-07). **No-op trap:** `ControlSize.extraLarge` exists (macOS 14.0+)
but resolves to `.large` on macOS — the practical case list is `.mini`/`.small`/`.regular`/`.large` (cf-08).

No invented names are central to this domain; if audited code reaches for a control/style symbol you can't
place, confirm via swiftui-ctx (`lookup` **exit 3** = likely hallucination or no-macOS-arm) + Sosumi before
flagging, and cross-check the canonical invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`. Signatures + full ❌→✅:
`references/forms-and-focus.md`, `references/control-styles-density.md`.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`) — it sets which floor a
   fix may rely on (`focusable`/`focused`/`@FocusState` = macOS 12.0+, `help` = macOS 11.0+,
   `formStyle` = macOS 13.0+, `controlSize` = macOS 10.15+; `accessoryBar*` button styles = macOS 14.0+). A
   fix that uses a floor above the target needs a `#available(macOS NN, *)` gate. Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-controls-forms --dir <sources> --json /tmp/cf.json --sarif /tmp/cf.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`, cf-01…cf-08) + tier-2 structural ast-grep
   rules (`lint/ast-grep/*.yml` — cf-01 Form-without-formStyle, cf-02 custom-view-not-focusable), plus a
   per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a flagged file
   did not fully parse, so a structural miss can't masquerade as clean; READ those by hand. The runner only
   LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a `Form`'s
   chain carries `.formStyle`, whether a custom `View` actually takes focus (vs a label-only view), whether a
   `Button` is genuinely icon-only, whether a `List` is the sidebar column of a `NavigationSplitView`, and
   whether a pane is genuinely dense are all invisible to grep. Build a per-file inventory: each `Form` + its
   style; each custom interactive `View` + its focus wiring; each icon-only `Button` + its `.help`; each
   `List`/`Button`/`Picker` + its style + `controlSize`.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a `Form` whose chain carries no `.formStyle`, a `.pickerStyle(.wheel)` on a Mac target,
   a `.controlSize(.extraLarge)`). A native control that is *already* focusable (`TextField`/`Button`), a
   non-settings `Form`, or a glanceable `List` of plain strings is *not* a defect — judge it.
5. **VERIFY.** For anything ≤ ~70% confidence (a style case you can't place, a floor you're unsure of, the
   canonical shape, whether a picker style exists on macOS), run **both** evidence sources. (a) **Practice**
   — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and `swiftui-ctx deprecated <api>`
   for a currency/deprecation rule): read its `consensus` (the canonical shape), `deprecated`+`replacement`,
   `recommended` permalink, `introduced_macos`, and `co_occurs_with`; a `lookup` **exit 3** (not-found, with
   a did-you-mean `suggestion`) corroborates a hallucination or a no-macOS-arm symbol — no shipping Mac app
   uses it (this is exactly how cf-07 `WheelPickerStyle` was confirmed). (b) **Spec** — confirm via
   **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the path
   and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi `doc:`
   floor — note the corpus reports `focusable` at 10.15 but `floors-master.md` corrects it to **macOS 12.0**;
   the reconciled floor wins. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or discard.
   **Deeper corpus evidence (settings/Form vocab):** to judge whether a `Form` is a genuine settings pane and
   which controls the native idiom uses, ground it in the corpus — `bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx recipe settings-form` for the canonical
   `Form { Section { Toggle/Picker/LabeledContent } }.formStyle(.grouped)` shape, or `bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx settings` for the real ranked vocabulary (8,579 settings screens
   across 1,157 repos: Toggle 2,207 · Section 1,998 · Form 1,681 · Picker 1,678) plus permalinked exemplar
   screens in `screens[]` — cite it to defend a cf-01 "this is a settings Form" call or "this Picker/Toggle is the Mac idiom".
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (none in this domain are auto — every fix is a judgment/structural call, so all
   are `flag-only`), one conventional commit per finding citing its `rule_id`, never weaken a check. The ✅
   "Correct" is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape** put in
   `## Correct`, backed by a real macOS-26 example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink (plus
   the Sosumi `doc:`) goes in `## Source` as the canonical example. The cf-01 ✅ is grounded in the live
   `swiftui-ctx lookup formStyle` consensus (`.formStyle(.grouped)`, 100%) + its recommended macOS-26 Gifski
   permalink (see `references/forms-and-focus.md`). Leave `flag-only` findings `open` with that ✅ in
   `## Correct`.
8. **DOUBLE-CHECK.** Re-grep / re-run the lint over each fixed file to confirm the tell no longer matches;
   record the evidence in `## Fix applied?`. Re-confirm every citation still resolves. If a fix introduced a
   new tell (e.g. a `.focusable()` you added under a < macOS 12 target now needs a gate, or a `Form` you
   grouped now wants per-control density), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can become a
finding — never emit a speculative finding. **No defect in this domain is auto-fixed**: every correct fix is
a structural/judgment call (which view takes focus, which density a pane wants, which picker style fits the
data, whether a `Form` is a settings pane at all), so all are `fix_mode: flag-only`. cf-07 is a hard-fail but
still flag-only — the replacement style (`.menu` vs `.segmented` vs `.inline`) depends on the data.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/controls-forms/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/controls-forms/_index.md`.
- `domain: controls-forms`. Frontmatter is the canonical schema; `fix_mode` is `flag-only` for every defect.
  `availability` reads from `floors-master.md`. `source` is an Apple URL + access date (fetched via Sosumi)
  or `verify against Xcode 26 SDK`. Emit `cross_ref` on cf-02 (→ `accessibility` when VoiceOver focus is also
  at stake), cf-03 (→ `accessibility`, the **keep-both** label seam), cf-08 (→ `layout-and-tables` when the
  issue is layout sizing not density), and any hover/cursor/right-click note (→ `pointer-gestures`).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `grouped-form/` | a `Form` lacks `.formStyle(.grouped)` and reads as an ungrouped, non-native settings pane (cf-01) |
| `keyboard-focus/` | a custom focus-taking `View` has no `.focusable()` / `@FocusState` and drops out of the Tab order (cf-02) — `cross_ref` accessibility |
| `tooltips-help/` | an icon-only control has no `.help` tooltip (cf-03) — `cross_ref` accessibility (keep-both label) |
| `control-style/` | a `List`/`Button`/`Picker` carries the wrong or default style for Mac density (cf-04, cf-05, cf-06) |
| `picker-platform/` | a touch-only `.pickerStyle(.wheel)` / `WheelPickerStyle` appears on a Mac target (cf-07) |
| `control-density/` | a `.controlSize(.extraLarge)` no-op, or a dense pane left at default density (cf-08) — `cross_ref` layout-and-tables when sizing |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/controls-forms/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a hard
requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/forms-and-focus.md` | the ungrouped `Form`, custom-view keyboard focus + `@FocusState` wiring, and the icon-only `.help` tooltip (cf-01/02/03) + the canonical native-settings-pane exemplar |
| `references/control-styles-density.md` | `listStyle`/`buttonStyle`/`pickerStyle` choice, the `.wheel` no-macOS-arm trap, and the `controlSize` density / `.extraLarge` no-op (cf-04/05/06/07/08) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells cf-01…cf-08 + tier-2 structural cf-01 Form-without-formStyle / cf-02 custom-view-not-focusable); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth — `focusable`/`focused`/`@FocusState` 12.0, `help` 11.0, `formStyle` 13.0, `controlSize` 10.15, `ControlSize.extraLarge` no-op, `WheelPickerStyle` macOS ABSENT) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (cross-check a made-up style/control symbol) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + the `macOS ABSENT`-is-not-a-low-floor trap (cf-07 is replaced, never gated; a macOS-12 focus fix under a lower target needs a gate) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys + context-folder ownership |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (pointer half, `@FocusState`-vs-`AccessibilityFocusState`, `.help`-vs-label keep-both, `controlSize` split axis) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-controls-forms --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, cf-01…cf-08) + **tier-2 ast-grep**
structural rules (`lint/ast-grep/*.yml` — cf-01 form-without-formstyle, cf-02 custom-view-not-focusable)
that grep cannot express (the **absence** of `.formStyle` across a `Form` closure's chain, the **absence** of
a `.focusable()`/`@FocusState` inside a custom `View` that uses a focus-taking control — both anchored on a
`kind`). It runs a per-file **parse probe** (surfaces "did not fully parse" so a structural miss can't look
clean), emits unified **JSON + SARIF**, exits **2** on any hard-fail (cf-07) for a CI gate, and **degrades
to grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`; faster:
`brew install ast-grep`). It only LOCATES — always READ each hit in full before reporting (step 3). The thin
`scripts/cf-lint.sh` is a pointer to this runner. Engine + rule-file format + JSON/SARIF shape + safety
rails: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
