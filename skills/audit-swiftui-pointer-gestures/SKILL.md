---
name: audit-swiftui-pointer-gestures
description: Audits a finished or in-progress macOS SwiftUI codebase for pointer-affordance and gesture defects and writes findings to swiftui-audits/. Use when the user says a Mac view feels dead under the pointer, gives no cursor or hover feedback, has no right-click menu, or its pinch/rotate gesture is broken; when they ask to verify onHover, onContinuousHover, pointerStyle, DragGesture, MagnifyGesture, RotateGesture, contextMenu, simultaneousGesture, highPriorityGesture, or GestureState; when AI may have written PointerStyle.grabbing, MagnificationGesture, or RotationGesture on a Mac target; when a gesture has no live state; or when pointer modifiers are ungated below their macOS floor. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for .help, .focusable, @FocusState, Form, or control density (controls-forms); not for Transferable drag payloads or file drops (sandbox-files); not for gesture-driven animation timing (animation-motion); not for the general availability sweep; not for writing new gesture UI from scratch.
---

# Audit SwiftUI Pointer & Gestures

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way the **pointer-affordance and gesture** layer goes
wrong on a Mac: views that give no hover feedback, missing cursor shapes, binary `.onHover` where the
live pointer position is needed, missing right-click menus, deprecated pinch/rotate gestures, gestures
with no live `@GestureState`, mis-composed gestures, and ungated pointer modifiers. Findings are written
to disk in the toolkit's unified schema; certain mechanical defects are fixed under the fix-safety
protocol. This is never a from-scratch gesture generator.

**The Mac is pointer-driven, not touch** — it has a cursor, a right mouse button, and a hover state.
iOS-trained corpora have almost no `.onHover`, `pointerStyle`, or right-click `.contextMenu` code, so AI
ships views that compile and look plausible but read as "an iPad app in a window." Be suspicious wherever
a custom interactive view has no pointer affordance.

## Boundary / seam note (stay in lane)

- **`.help` tooltips, `.focusable()` / `@FocusState` keyboard focus, `Form` / `.formStyle`, and control
  density (`.controlSize`/`.buttonStyle`/`.pickerStyle`)** belong to `audit-swiftui-controls-forms`. They
  are pointer-adjacent but are that skill's. Note them in one line and `cross_ref` — do not own them here.
- **`Transferable` drag *payloads*, `dropDestination`, `fileImporter`, security-scoped consent** belong
  to `audit-swiftui-sandbox-files`. This skill owns the *gesture mechanics* of a `DragGesture`; the
  dropped/transferred file's correctness is sandbox-files'.
- **Gesture-driven *animation timing*** (`withAnimation` coupled to a gesture, `.repeatForever`) belongs
  to `audit-swiftui-animation-motion`. This skill owns the gesture wiring; the motion is theirs.
- **`.contextMenu` action *semantics* + `keyboardShortcut`** lean on `audit-swiftui-menus-commands`; this
  skill flags a *missing* right-click menu where one belongs, then `cross_ref`s menus-commands.
- **The deprecation *flag* on `MagnificationGesture`/`RotationGesture`** is owned by
  `audit-swiftui-api-currency` (the blanket currency sweep); **this skill owns the replacement
  mechanics** (the `MagnifyGesture`/`RotateGesture` rewrite + its `@GestureState`). Emit `cross_ref:
  api-currency` on pg-08/pg-09.
- **The blanket "is every OS-floored API gated" sweep** belongs to `audit-swiftui-availability-gating`;
  this skill owns **pointer-modifier** gating in depth (pointerStyle=15, onContinuousHover=14) and defers
  the rest there.

## The three non-negotiable pointer rules

1. **A custom interactive view must answer the pointer.** A row/card/handle with no `.onHover` (and, for
   a draggable/resizable affordance, no `pointerStyle`) is dead on the Mac — it has a cursor to respond to.
2. **Right-click is a primary Mac interaction.** Actions on a row/item belong in a `.contextMenu`, not
   only as on-screen buttons or a touch swipe. The same modifier fires via long-press on iOS — the
   right-click idiom is the Mac's.
3. **A continuous gesture needs live state.** A pinch/drag/rotate must surface its in-flight value through
   `@GestureState` (auto-resets when the gesture ends) or a committed `@State`; reading nothing mid-gesture
   makes the interaction feel frozen.

**The affordance test:** remove the pointer modifier — did the view lose its *cursor signal* or *hover
feedback*? Then it was load-bearing (pointer affordance required). Full reasoning + the affordance-map
artifact: `references/pointer-affordances.md`.

## Defect index (pg-01 … pg-12)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct),
**warning** (compiles but non-native), **advisory** (judgment / perf). `auto` = mechanical single-answer
fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| pg-01 | `PointerStyle.grabbing` / `.pointerStyle(.grabbing)` — invented case | hard-fail | auto | `pointer-affordances.md` |
| pg-02 | custom interactive row/card/handle with **no** `.onHover` (pointer feedback dead) | warning | flag | `pointer-affordances.md` |
| pg-03 | draggable/resizable affordance with **no** `pointerStyle` (no cursor shape) | warning | flag | `pointer-affordances.md` |
| pg-04 | `.onHover { … }` reading only enter/exit where the live `CGPoint` is needed → `onContinuousHover` | advisory | flag | `pointer-affordances.md` |
| pg-05 | row/item view with action buttons but **no** right-click `.contextMenu` | warning | flag | `pointer-affordances.md` |
| pg-06 | `.swipeActions` as the *only* way to act on a row (touch idiom) — add `.contextMenu` | advisory | flag | `pointer-affordances.md` |
| pg-07 | `pointerStyle`(macOS 15) / `onContinuousHover`(macOS 14) ungated under a lower floor | warning | flag | `gesture-availability.md` |
| pg-08 | `MagnificationGesture` (deprecated 26.5) → `MagnifyGesture` (macOS 14) | warning | flag | `gestures-and-state.md` |
| pg-09 | `RotationGesture` (deprecated 26.5) → `RotateGesture` (macOS 14) | warning | flag | `gestures-and-state.md` |
| pg-10 | continuous `DragGesture`/`MagnifyGesture`/`RotateGesture` with **no** `@GestureState` (no live value) | warning | flag | `gestures-and-state.md` |
| pg-11 | `.gesture(` on a control that also has a built-in gesture → use `.simultaneousGesture` / `.highPriorityGesture` | advisory | flag | `gestures-and-state.md` |
| pg-12 | `#available(iOS …)` gating a pointer modifier in a macOS target (wrong arm) | hard-fail | auto | `gesture-availability.md` |

**Two claims are UNVERIFIED — carry as `advisory` with the flag, never assert as fact** (each is flagged
in its reference + becomes `source: verify against Xcode 26 SDK`): pg-04 (whether a given site truly needs
the continuous coordinate vs. a binary hover — judgment, not mechanics); the macOS gesture-vs-built-in
priority resolution for pg-11 (verify the specific control's built-in gesture against the Xcode 26 SDK).

## The real API, at a glance

**Real (exist on macOS):** `onHover(perform:)` (macOS 10.15+), `onContinuousHover(coordinateSpace:perform:)`
(macOS 14.0+; phases `.active(CGPoint)` / `.ended`), `pointerStyle(_:)` + `PointerStyle` (macOS 15.0+,
no iOS arm; cases `.grabActive` / `.grabIdle` / `.link` / `.zoomIn` / `.zoomOut` / `.columnResize` / `.rowResize` /
`.frameResize(position:directions:)`), `DragGesture` (macOS 10.15+), `MagnifyGesture` / `RotateGesture`
(macOS 14.0+), `SpatialTapGesture` (macOS 13.0+), `@GestureState`, `.gesture` / `.simultaneousGesture` /
`.highPriorityGesture`, `.contextMenu(menuItems:)` (macOS 10.15+, **deprecated** → prefer `contextMenu(menuItems:preview:)` macOS 13.0+). **`pointerStyle` is macOS + visionOS only (no iOS arm); `onContinuousHover` is cross-platform (iOS 17.0+, macOS 14.0+) — never flag either as invented.**

**Stale / invented (never use):** `PointerStyle.grabbing` (no such case → `.grabActive` / `.grabIdle`).
**Real-but-deprecated (26.5):** `MagnificationGesture` → `MagnifyGesture`; `RotationGesture` →
`RotateGesture`.

**Grounded ✅ — the pointer-feedback shape, from real shipping code (not a placeholder).** The pg-02
consensus is `.onHover { … }` (96% of 5,694 real uses across 732 macOS repos, `swiftui-ctx lookup onHover`).
The canonical example is `sindresorhus/Gifski` (8.4k★) — a hover-driven background highlight, the exact
shape this skill recommends:

```swift
// ✅ pg-02 consensus, verified in the corpus — commit-pinned, runs on the Mac
.background(Capsule().fill(.white.opacity(isHovered ? 0.2 : 0.05)))
.onHover { isHovered = $0 }
// Source: https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Components/TrimmingAVPlayer.swift#L729
// Spec:   https://sosumi.ai/documentation/swiftui/view/onhover  (onHover — macOS 10.15+)
```

Every finding's `## Source` carries the live `recommended` permalink for *its* API, fetched fresh via
`swiftui-ctx lookup <api>` + `file <recommended.id> --smart` (step 7) — the block above is the worked
template, not the only citation.

Signatures, floors, and the full ❌→✅ rewrites: `references/pointer-affordances.md` +
`references/gestures-and-state.md`. Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and the canonical invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate them.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   pg-07 fires **only** when the floor is **below** the modifier's floor (pointerStyle=15,
   onContinuousHover=14). Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-pointer-gestures --dir <sources> --json /tmp/pg.json --sarif /tmp/pg.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — wrong-arm gate-scope and gesture-composition co-occurrence grep can't
   express), plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`**
   — a flagged file did not fully parse, so a structural miss can't masquerade as clean; READ those by
   hand. The runner only LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a custom
   view is *interactive* (so pg-02/03/05 apply), whether a gesture is *continuous* (so pg-10 applies),
   gate scope, and gesture composition are invisible to grep. Build a per-file inventory: each interactive
   view + its pointer affordances (hover / cursor / right-click) + each gesture + its state + its gate.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a `.grabbing` case, a `MagnificationGesture`, an ungated `pointerStyle` under a <15
   floor, an `iOS` gate arm).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, a
   behavior claim), run **both** evidence sources. (a) **Practice** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
   lookup <api> --json` (and `swiftui-ctx deprecated <api>` for a currency/deprecation rule — pg-08/pg-09):
   read its `consensus` (the canonical shape), `deprecated`+`replacement`/`migrate_to`, `recommended`
   permalink, `introduced_macos`, and `co_occurs_with`; a `lookup` **exit 3** (not-found, with a
   did-you-mean `suggestion`) corroborates a hallucination finding (pg-01) — no shipping Mac app uses the
   symbol. (b) **Spec** — confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using
   `references/source-directory.md` for the path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`
   for the protocol (never `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against
   `floors-master.md` and the Sosumi `doc:` floor. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or
   discard. Carry the two UNVERIFIED items as `advisory` with `source: verify against Xcode 26 SDK`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit `cross_ref` on shared-seam findings (pg-08/pg-09 → `api-currency`; a missing-`.contextMenu`
   whose actions need shortcuts → `menus-commands`; a `DragGesture` carrying a `Transferable` payload →
   `sandbox-files`). Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (pg-01, pg-12), one conventional commit per finding citing its `rule_id`,
   never weaken a check. The ✅ "Correct" is **not a hand-written snippet** — it is the swiftui-ctx
   **consensus shape** put in `## Correct`, backed by a real macOS example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source` as the canonical example. Leave `flag-only` findings `open`
   with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence in
   `## Fix applied?`. Re-confirm every citation still resolves and still says the expected floor. If a fix
   introduced a new tell (e.g. a `pointerStyle` you added now needs a `#available(macOS 15, *)` gate), loop
   that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can become
a finding — never emit a speculative finding. pg-02/03/05 hinge on the view being *interactive*: a static
label is not a defect for lacking hover. Auto-fix only the mechanical set (pg-01 stale-case rename, pg-12
wrong-arm rewrite); everything else is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/pointer-gestures/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/pointer-gestures/_index.md`.
- `domain: pointer-gestures`. Frontmatter is the canonical schema; `fix_mode` is `auto` for pg-01/pg-12,
  else `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date
  (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` per the seam note (step 6).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `stale-api/` | an invented/stale case name on a Mac target (pg-01) |
| `hover-affordance/` | a custom interactive view gives no hover/cursor feedback, or binary hover where the live coordinate is needed (pg-02, pg-03, pg-04) |
| `context-menu/` | a row/item has actions but no right-click menu, or only a touch swipe to act (pg-05, pg-06) |
| `gesture-currency/` | a deprecated pinch/rotate gesture needs its `MagnifyGesture`/`RotateGesture` rewrite (pg-08, pg-09) |
| `gesture-state/` | a continuous gesture has no live `@GestureState`, or composition is wrong (pg-10, pg-11) |
| `availability-gating/` | a pointer modifier is ungated under its floor, or gated on the `iOS` arm (pg-07, pg-12) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/pointer-gestures/` with a lowercase-hyphen slug naming the sub-category, and note it in
the run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

> **Go-beyond artifact (optional):** `swiftui-audits/pointer-gestures/_affordance-map.md` classifying every
> custom interactive view as `has-hover` / `has-cursor` / `has-right-click` with an affordance-coverage
> score — see `references/pointer-affordances.md`.

## Reference routing

| File | Open when |
|---|---|
| `references/pointer-affordances.md` | hover/cursor/right-click affordances — the `.onHover`/`pointerStyle`/`onContinuousHover`/`.contextMenu` rules, the affordance test + map (pg-01/02/03/04/05/06) |
| `references/gestures-and-state.md` | gesture currency, live `@GestureState`, and gesture composition — the deprecated-rename mechanics + `.gesture` vs `.simultaneousGesture`/`.highPriorityGesture` (pg-08/09/10/11) |
| `references/gesture-availability.md` | pointer-modifier gating depth, the wrong-arm trap, the pre-floor fallback choice (pg-07/12) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented/stale-name list (`.grabbing`; deprecated gesture renames) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm failure (pg-12) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-pointer-gestures --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, pg-01/02/03/04/05/06/07/08/09/10/11) +
**tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` — pg-12 wrong-arm gate-scope and pg-11
gesture-composition co-occurrence) that grep cannot express. It runs a per-file **parse probe** (surfaces
"did not fully parse" so a structural miss can't look clean), emits unified **JSON + SARIF**, exits **2**
on any hard-fail (pg-01/pg-12) for a CI gate, and **degrades to grep-only with a notice** if ast-grep
is unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES —
always READ each hit in full before reporting (step 3). The thin `scripts/pg-lint.sh` is a pointer to this
runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
