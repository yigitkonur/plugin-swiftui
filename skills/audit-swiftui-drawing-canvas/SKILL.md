---
name: audit-swiftui-drawing-canvas
description: Audits a finished or in-progress macOS SwiftUI codebase for custom-drawing and Canvas defects and writes per-finding Markdown to swiftui-audits/. Use when the user says a drawing is slow, janky, or redraws too much; when many stacked Image or Shape views should be one Canvas; when a time-driven animation hand-rolls a Timer instead of TimelineView; when GeometryReader is used to arrange views instead of the Layout protocol; when absolute hard-coded frames should be containerRelativeFrame or a MeshGradient; when Path math looks wrong; when expensive static vector art lacks drawingGroup; when MeshGradient may be ungated below macOS 15; or when a Canvas has no accessibility description. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for Swift Charts, not for the Layout protocol mechanics themselves, not for general view-performance profiling, not for writing new drawings from scratch.
---

# Audit SwiftUI Drawing & Canvas

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way custom drawing goes wrong: dozens of stacked
`Image`/`Shape` views where one `Canvas` belongs, a hand-rolled `Timer` driving a redraw that
`TimelineView` does for free, `GeometryReader` abused as a layout container, absolute hard-coded frames
where `containerRelativeFrame`/`MeshGradient` fit, broken `Path` math, expensive static vector art with
no `.drawingGroup()`, an ungated `MeshGradient` below the macOS 15 floor, and a `Canvas` invisible to
VoiceOver. Findings are written to disk in the toolkit's unified schema; certain mechanical defects are
fixed under the fix-safety protocol. This is never a from-scratch drawing generator.

These APIs are mostly long-stable (macOS 12/10.15), so the failure mode is **misuse, not
hallucination** — the wrong tool, the wrong layer, an ungated `MeshGradient`. Judge architecture, not
just names.

## Boundary / seam note (stay in lane)

- **The `Layout` protocol itself belongs to `audit-swiftui-layout-and-tables`.** This skill flags
  `GeometryReader`-as-layout (a drawing-geometry smell) and **routes** the custom-`Layout` decision
  there with a `cross_ref`; it does not audit `Layout` conformance mechanics. `GeometryReader` that
  *feeds drawing geometry* (a `Canvas`/`Path` size) stays here.
- **Swift `Chart` and chart-shaped data viz belong to `audit-swiftui-charts`** — except a *hand-rolled,
  non-`Chart`* drawing of data, which stays here. If audited code reaches for `Chart`, note it in one
  line and defer.
- **Cost *measurement* / profiling belongs to `audit-swiftui-view-performance`.** This skill owns the
  `.drawingGroup()` *usage decision* (should it be there at all); the render-cost number is theirs —
  emit a `cross_ref` on the shared site.
- **The `Canvas`/drawing accessibility descriptor is a keep-both seam with `audit-swiftui-accessibility`**
  (intentional double-detection per both plans): file the finding here AND cross-link; do not collapse.
- **`withAnimation` timing of a drawing belongs to `audit-swiftui-animation-motion`** (`TimelineView`-as-
  clock is theirs at the seam) — flag the missing `TimelineView` here, route motion-curve choices there.

## The three drawing-architecture rules

1. **One `Canvas` beats a pile of views.** Many sibling `Image`/`Shape`/`Path` views drawing one scene
   each become their own layout node + render pass; `Canvas { ctx, size in … }` draws them all in one
   immediate-mode pass. Use a view per *interactive/identity* element; use `Canvas` for bulk static art.
2. **Time drives redraw through `TimelineView`, never a `Timer`+`@State`.** A `Timer` mutating `@State`
   to re-render is a manual render loop SwiftUI already owns; `TimelineView(.animation) { context in … }`
   (or `.periodic`/`.explicit`) hands you a `context.date` and redraws on the schedule, vsync-aligned.
3. **Geometry feeds drawing; it does not arrange views.** `GeometryReader` to read a size into `Canvas`
   math is correct; `GeometryReader` wrapping children to *position* them is a layout job → the `Layout`
   protocol / `containerRelativeFrame` (route to layout-and-tables). Absolute hard-coded frames don't
   survive resize on a free Mac window.

**The Canvas test:** is the element *interactive or independently identified* (its own gesture, its own
a11y node, its own animation)? → keep it a view. Is it *bulk static or procedurally-drawn* paint? →
`Canvas`. Full reasoning + the redraw-source map: `references/canvas-and-redraw.md`.

## Defect index (draw-01 … draw-12)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / ungated below
floor), **warning** (compiles but non-native / wrong tool), **advisory** (judgment / perf). `auto` =
mechanical single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| draw-01 | many sibling `Image`/`Shape`/`Path` views drawing one static scene where one `Canvas` fits | advisory | flag | `canvas-and-redraw.md` |
| draw-02 | `Timer`/`Timer.publish`/`Date()` + `@State` driving a periodic redraw instead of `TimelineView` | warning | flag | `canvas-and-redraw.md` |
| draw-03 | `GeometryReader` wrapping children to *arrange* them (layout, not drawing geometry) | warning | flag | `geometry-and-frames.md` |
| draw-04 | absolute hard-coded `.frame(width:height:)` / `.position(x:y:)` for a resizable drawing surface | advisory | flag | `geometry-and-frames.md` |
| draw-05 | `MeshGradient` ungated under a deployment target < macOS 15 | warning | flag | `geometry-and-frames.md` |
| draw-06 | `MeshGradient(width:height:…)` where `points`/`colors` count ≠ `width*height` (mesh-arity) | warning | flag | `geometry-and-frames.md` |
| draw-07 | `Path` math smell — unbalanced `move(to:)`/`addLine`, no `closeSubpath()`, magic-number control points | advisory | flag | `path-and-shapes.md` |
| draw-08 | hand-rolled `Path`/`Shape` for a primitive that `Circle`/`Ellipse`/`RoundedRectangle`/`Capsule` already is | advisory | flag | `path-and-shapes.md` |
| draw-09 | expensive *static* vector art (large `Path`/many shapes, no animation) with no `.drawingGroup()` | advisory | flag | `canvas-and-redraw.md` |
| draw-10 | `.drawingGroup()` on a tiny/animated/text subtree (misapplied — flattens, breaks text/blends) | advisory | flag | `canvas-and-redraw.md` |
| draw-11 | `Canvas`/hand-drawn data viz with no `.accessibilityLabel`/`accessibilityChartDescriptor` (a11y) | advisory | flag | `path-and-shapes.md` |
| draw-12 | `#available(iOS 15, *)` gating `MeshGradient` in a macOS target (wrong arm) | hard-fail | auto | `geometry-and-frames.md` |

**Two claims are UNVERIFIED — carry as `advisory` with the flag, never assert as fact** (each flagged in
its reference + becomes `source: verify against Xcode 26 SDK`): whether `.drawingGroup()` on a
*text-bearing* subtree drops the text rasterization fidelity (draw-10); whether a `MeshGradient` arity
mismatch is a *compile error* vs a runtime no-op on macOS 15+ (draw-06 — flag, don't assert a crash).

## The real API, at a glance

**Real (exist on macOS):** `Canvas(opaque:colorMode:rendersAsynchronously:renderer:)` (12.0+),
`GraphicsContext`, `TimelineView` + `.animation`/`.periodic`/`.explicit` schedules (12.0+), `Path` +
`move(to:)`/`addLine(to:)`/`addCurve`/`addArc`/`closeSubpath()` (10.15+), `Circle`/`Ellipse`/`Rectangle`/
`RoundedRectangle`/`Capsule` shapes (10.15+), `Gradient`/`LinearGradient`/`RadialGradient`/`AngularGradient`
(10.15+), **`MeshGradient(width:height:points:colors:)` (15.0+)**, `.drawingGroup()` (10.15+),
`containerRelativeFrame(_:alignment:)` (14.0+). All long-stable except `MeshGradient` (the one gating
concern). **`MeshGradient` is macOS 15.0+ — never flag it as invented; flag it only when ungated below a
<15 floor.**

**Hallucinated (do not invent):** there is no `Canvas2D`, no `.canvasRenderer`, no `MeshGradientView`,
no `DrawingContext` (the type is `GraphicsContext`). When unsure a symbol exists, VERIFY (a `swiftui-ctx
lookup` exit-3 + Sosumi index-absence = hallucinated). Signatures, floors, and the full ❌→✅ rewrites:
the routed `references/*.md`. Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and the canonical invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate them.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   draw-05/draw-12 fire **only** when the floor is **below macOS 15** (the `MeshGradient` floor). Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-drawing-canvas --dir <sources> --json /tmp/draw.json --sarif /tmp/draw.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the `MeshGradient`-not-gated, `GeometryReader`-arranges-children, and
   `Timer`-redraw-loop rules grep can't express), plus a per-file **parse probe**, and emits unified
   JSON + SARIF. **Read its `parse_warnings`** — a flagged file did not fully parse, so a structural miss
   can't masquerade as clean; READ those by hand. The runner only LOCATES — never treat a hit as a
   finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. View-vs-`Canvas`
   choice, the redraw *source*, gate scope, and whether a `GeometryReader` arranges or measures are all
   invisible to grep. Build a per-file inventory: each drawing surface + its redraw source (static /
   time / state) + the Canvas test verdict + its gate (if `MeshGradient`).
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. an ungated `MeshGradient` under a <15 floor, an `iOS` gate arm, a `Timer`+`@State`
   redraw loop a `TimelineView` replaces).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, an
   arity or behavior claim), run **both** evidence sources. (a) **Practice** — `bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and `swiftui-ctx deprecated <api>` for a
   currency rule): read its `consensus` (the canonical shape — e.g. `Canvas` is `{ }` at 90%,
   `TimelineView` is `(_)` at 99%, `MeshGradient` is `(width, height, points, colors)` at 70%),
   `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and `co_occurs_with`; a
   `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a hallucination finding.
   (b) **Spec** — confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using
   `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi `doc:`
   floor (`MeshGradient` = macOS 15.0). The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or
   discard. Carry the two UNVERIFIED items as `advisory` with `source: verify against Xcode 26 SDK`.
   **Deeper corpus evidence (custom-style):** before flagging draw-07/draw-08 (a hand-rolled `Path`/`Shape`)
   or routing a custom `Layout` (draw-03), prove the real idiom — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx conformances Shape --json`
   (313 repos conform; e.g. `LineShape` at `Repo-Radar/AnalyticsCharts.swift#L223`) and `conformances Layout` (198 repos)
   give a permalinked custom conformer for `## Source`; `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx examples Canvas --shape "( )" --json`
   gives a real `Canvas` call site for the draw-01 consolidation ✅.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (draw-12 wrong-arm), one conventional commit per finding citing its
   `rule_id`, never weaken a check. The ✅ "Correct" is **not a hand-written snippet** — it is the
   swiftui-ctx **consensus shape** put in `## Correct`, backed by a real macOS example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source` as the canonical example. Leave `flag-only` findings
   `open` with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves and still says its floor. If a fix
   introduced a new tell (e.g. a `MeshGradient` you added now needs a macOS-15 gate), loop that file back
   to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. Auto-fix only the mechanical set (draw-12 wrong-arm
gate); everything else is `fix_mode: flag-only` (architecture and judgment calls need a human).

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/drawing-canvas/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/drawing-canvas/_index.md`.
- `domain: drawing-canvas`. Frontmatter is the canonical schema; `fix_mode` is `auto` for draw-12, else
  `flag-only`. `availability` reads from `floors-master.md` (`MeshGradient` = macOS 15.0+). `source` is
  an Apple URL + access date (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` on
  the seam findings (draw-03 → `layout-and-tables`; draw-09/draw-10 → `view-performance`; draw-11 →
  `accessibility`).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `canvas-consolidation/` | a pile of `Image`/`Shape`/`Path` views should collapse to one `Canvas` (draw-01) |
| `redraw-source/` | a `Timer`+`@State` redraw loop should be a `TimelineView` (draw-02) |
| `geometry-as-layout/` | `GeometryReader` arranges children instead of feeding drawing geometry (draw-03) — `cross_ref` layout-and-tables |
| `absolute-frames/` | hard-coded `.frame`/`.position` for a resizable drawing surface (draw-04) |
| `availability-gating/` | `MeshGradient` ungated under a <15 floor, or gated on the `iOS` arm (draw-05, draw-12) |
| `mesh-gradient/` | a `MeshGradient` `points`/`colors` arity mismatch (draw-06) |
| `path-math/` | unbalanced/closed `Path` math, or a hand-rolled primitive a built-in shape covers (draw-07, draw-08) |
| `drawing-group/` | expensive static art missing `.drawingGroup()`, or `.drawingGroup()` misapplied (draw-09, draw-10) — `cross_ref` view-performance |
| `accessibility/` | a `Canvas`/hand-drawn data viz with no a11y descriptor (draw-11) — `cross_ref` accessibility (keep-both) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/drawing-canvas/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

> **Go-beyond artifact (optional):** `swiftui-audits/drawing-canvas/_redraw-map.md` classifying every
> drawing surface as `static`/`time-driven`/`state-driven` with a view-vs-`Canvas` verdict — see
> `references/canvas-and-redraw.md`.

## Reference routing

| File | Open when |
|---|---|
| `references/canvas-and-redraw.md` | view-vs-`Canvas` choice, the `Timer`→`TimelineView` redraw fix, the `.drawingGroup()` usage/misuse decision, the redraw map (draw-01/02/09/10) |
| `references/geometry-and-frames.md` | `GeometryReader`-as-layout, absolute frames vs `containerRelativeFrame`, `MeshGradient` gating + the wrong-arm trap + mesh arity (draw-03/04/05/06/12) |
| `references/path-and-shapes.md` | `Path` math correctness, hand-rolled-vs-built-in shapes, drawing accessibility (draw-07/08/11) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth — `MeshGradient` = macOS 15.0) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm failure (draw-12) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (layout-and-tables, view-performance, accessibility, animation-motion, charts) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-drawing-canvas --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
draw-01/02/04/05/06/07/08/09/10/11/12) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` —
draw-05 `MeshGradient`-not-gated, draw-03 `GeometryReader`-arranges-children, draw-02 `Timer`-redraw-loop)
that grep cannot express. It runs a per-file **parse probe** (surfaces "did not fully parse" so a
structural miss can't look clean), emits unified **JSON + SARIF**, emits warnings/advisories only
(no hard-fail tells — nothing blocks the gate), and **degrades to grep-only with a notice** if ast-grep is unreachable
(`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES — always READ
each hit in full before reporting (step 3). The legacy `scripts/draw-lint.sh` is a thin pointer to this
runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
