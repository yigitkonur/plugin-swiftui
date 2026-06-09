---
name: audit-swiftui-api-currency
description: Audits a finished or in-progress macOS SwiftUI codebase for stale, deprecated, renamed, or hallucinated APIs and writes per-finding Markdown to swiftui-audits/. Use when the user says the code uses old APIs, deprecation warnings, or "is this current for macOS 26"; when AI may have emitted NavigationView, foregroundColor, cornerRadius, one-parameter onChange, tabItem, inline NavigationLink, Text plus Text concatenation, or DispatchQueue.main.async cargo-cult; when a macOS-26.5 deprecation appears (3-arg dropDestination, MagnificationGesture, RotationGesture, design-only Font.system, accentColor); or when an invented name like glassBackground, liquidGlass, LiquidGlassView, material(.glass), or visionOS-only glassBackgroundEffect slips into a Mac target. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for the deep Liquid-Glass design audit, not for the blanket availability-gating sweep, not for positive color or typography craft, not for from-scratch or inline single-file fixes (use swiftui-modernize).
---

# Audit SwiftUI API Currency

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way an API drifts out of currency on a macOS 26
(Tahoe) target: the **stale** symbol the model learned from a 2019–2022 corpus (`NavigationView`,
`.foregroundColor`, 1-param `onChange`), the freshly-**deprecated** macOS-26.5 call, the **renamed**
gesture, and the **hallucinated** modifier AI confabulated for a surface it never saw. Findings are
written to disk in the toolkit's unified schema; certain mechanical renames are fixed under the
fix-safety protocol. This is never a from-scratch modernizer.

Three mechanisms compound: **training recency** (renames every year; the corpus is the old surface),
**confident confabulation** (an unknown surface yields a plausible *invented* name, not an admission of
absence), and **no availability awareness** (a macOS-26-only call emitted with no gate). The unifying
tell: the code *reads* idiomatic and usually compiles, so it survives casual review.

## Boundary / seam note (stay in lane)

- **api-currency owns the deprecation/hallucination *flag*; the positive replacement *craft* is a
  sibling's.** Emit `cross_ref` on every shared seam (`${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`):
  - `.foregroundColor` / `.accentColor` / `.cornerRadius` craft → **`audit-swiftui-appearance-color`**.
  - `Text + Text` / `Font.system(_:design:)` craft → **`audit-swiftui-typography-text`**.
  - `NavigationView` / `tabItem` / inline `NavigationLink` structural migration → **`audit-swiftui-navigation-toolbars`**.
  - 1-param `onChange`, `ObservableObject` default → **`audit-swiftui-state-observation`**.
  - `DispatchQueue.main.async` isolation fix → **`audit-swiftui-async-data`** / concurrency.
  - Gesture renames mechanics → **`audit-swiftui-pointer-gestures`**; `dropDestination` → **`audit-swiftui-sandbox-files`**.
  - Hallucinated glass names + glass design → **`audit-swiftui-liquid-glass`**.
- **The blanket "is every OS-floored API gated" sweep belongs to `audit-swiftui-availability-gating`.**
  This skill flags the deprecation; whether a current-but-floored *replacement* is gated is noted and
  routed there. The Liquid-Glass design audit (placement, containers, morphing) is **out of scope** —
  this skill only flags the *hallucinated* glass names; route the rest to `audit-swiftui-liquid-glass`.

## The currency model (three failure shapes)

1. **Deprecated/renamed** — a real symbol Apple superseded; it compiles with a warning today and breaks
   when the window closes (`NavigationView` → 26.5; `Text + Text` → 26.0). Flag + cite the current idiom.
2. **Hallucinated** — a name that never existed on macOS; a hard-fail. A `swiftui-ctx lookup` **exit 3**
   (not-found) corroborates it: no shipping Mac app uses the symbol.
3. **Ungated current API** — the *right* replacement carries its own macOS floor; using it below the
   deployment target is a build break. This skill notes it and routes the depth to `availability-gating`.

## Defect index (curr-01 … curr-14)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (never-correct / build break),
**warning** (compiles but stale/deprecated), **advisory** (smell / judgment). `auto` = mechanical
single-answer rename; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| curr-01 | `NavigationView { … }` (deprecated macOS 10.15–26.5) | warning | flag | `deprecations-and-renames.md` |
| curr-02 | `.foregroundColor(_:)` (deprecated → `.foregroundStyle`) | warning | auto | `deprecations-and-renames.md` |
| curr-03 | `.cornerRadius(_:)` (deprecated → `.clipShape(.rect(cornerRadius:))`) | warning | auto | `deprecations-and-renames.md` |
| curr-04 | 1-param `.onChange(of:) { newValue in }` (introduced macOS 11, deprecated macOS 14) | warning | flag | `deprecations-and-renames.md` |
| curr-05 | `.tabItem { … }` (→ `Tab("…", systemImage:) { }`, macOS 15) | warning | flag | `deprecations-and-renames.md` |
| curr-06 | inline `NavigationLink(…, destination:)` inside `List`/`ForEach` | warning | flag | `deprecations-and-renames.md` |
| curr-07 | `Text("…") + Text("…")` concatenation (deprecated macOS 26.0) | warning | flag | `deprecations-and-renames.md` |
| curr-08 | `DispatchQueue.main.async` cargo-cult in async-aware code | advisory | flag | `deprecations-and-renames.md` |
| curr-09 | 3-arg `dropDestination(for:action:isTargeted:)` (deprecated macOS 26.5) | warning | flag | `deprecations-and-renames.md` |
| curr-10 | `MagnificationGesture` / `RotationGesture` (renamed macOS 26.5) | warning | auto | `deprecations-and-renames.md` |
| curr-11 | `Font.system(_:design:)` design-only, no `weight:` (deprecated 26.5) | advisory | flag | `deprecations-and-renames.md` |
| curr-12 | `.accentColor(_:)` (deprecated macOS 26.5 → `.tint(_:)`) | warning | auto | `deprecations-and-renames.md` |
| curr-13 | `.glassBackground()` / `.liquidGlass()` / `LiquidGlassView` / `.material(.glass)` / `.cardStyle()` | hard-fail | flag | `hallucinated-currency.md` |
| curr-14 | `.glassBackgroundEffect()` on a Mac target (visionOS-only) | hard-fail | flag | `hallucinated-currency.md` |

**Two claims are version-sensitive — confirm before asserting, never invent:** the exact `dropDestination`
successor signature (`dropDestination(for:isEnabled:action:)`) and any `GlassProminentButtonStyle`
availability; carry as the citation from `swiftui-ctx` + Sosumi or as `source: verify against Xcode 26 SDK`.

## The real API, at a glance

**Deprecated → current (macOS):** `NavigationView` → `NavigationStack` / `NavigationSplitView` ·
`.foregroundColor(_:)` → `.foregroundStyle(_:)` · `.cornerRadius(_:)` →
`.clipShape(.rect(cornerRadius:))` · 1-param `.onChange` → `(old, new)` or 0-param · `.tabItem` →
`Tab(){}` · inline `NavigationLink(destination:)` → `.navigationDestination(for:)` · `Text + Text` →
interpolation / `AttributedString` · `DispatchQueue.main.async` → `@MainActor` / `await MainActor.run`
· 3-arg `dropDestination` → `dropDestination(for:isEnabled:action:)` · `MagnificationGesture` /
`RotationGesture` → `MagnifyGesture` / `RotateGesture` · `Font.system(_:design:)` →
`Font.system(_:design:weight:)` · `.accentColor(_:)` → `.tint(_:)`.

**Hallucinated (never exist on macOS):** `.glassBackground()`, `.liquidGlass()`, `LiquidGlassView`,
`.material(.glass)`, `.background(.glass)`, `.cardStyle()`. **Real-but-platform-wrong:**
`.glassBackgroundEffect()` (visionOS-only). **NOT hallucinated — do not flag:** `Glass.interactive(_:)`
is `macOS 26.0+` and pointer-driven on the Mac.

**Grounded ✅ example (the shape step 7 FIX embeds — real code, not a placeholder).** For curr-02
(`.foregroundColor` → `.foregroundStyle`), `swiftui-ctx lookup foregroundStyle --json` returns the
`consensus` shape `(_)` at 100% with `recommended` permalink below — this is what `## Correct` carries:

```swift
// ✅ .foregroundStyle(_:) — consensus shape (_), real macOS-26 call site
Circle()
    .stroke(lineWidth: lineWidth)
    .opacity(0.3)
    .foregroundStyle(.secondary)
```

- **Source (real GitHub permalink):** sindresorhus/Gifski (8.4k★, `min_macos: 26`) —
  https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Utilities.swift#L5192
- **Spec (Sosumi `doc:`):** https://sosumi.ai/documentation/swiftui/view/foregroundstyle
- Re-fetch live with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file ex_032f0b9e2b --smart`; never
  hand-write the ✅ — it is always the current `swiftui-ctx` consensus + its permalinked example.

Floor *values* are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
and the canonical invented-name list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate them. The
canonical ✅ shape + a real macOS-26 example come from `swiftui-ctx` (step VERIFY/FIX), not a hand-written
snippet.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It governs the
   gating angle (a current-but-floored replacement must be gated below its floor). Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-api-currency --dir <sources> --json /tmp/curr.json --sarif /tmp/curr.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the 1-param-`onChange` shape and the inline-`NavigationLink`-in-`List`
   containment grep can't express), plus a per-file **parse probe**, and emits unified JSON + SARIF.
   **Read its `parse_warnings`** — a flagged file did not fully parse, so a structural miss can't
   masquerade as clean; READ those by hand. The runner only LOCATES — never treat a hit as a finding.
   Engine + rule-file format + degradation: `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. A 1-param vs
   2-param `onChange` closure, whether a `NavigationLink` is inside a `List`, whether a
   `DispatchQueue.main.async` sits in async-aware code, and whether a `Font.system` already passes
   `weight:` are all invisible to a flat grep. Build a per-file inventory: each candidate symbol + its
   era + its gate.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a literally-deprecated symbol, a verified hallucinated name, a 1-param `onChange`).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a deprecation date or
   floor you can't place, a successor signature), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` AND, for every currency rule,
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated <api>`: read its `consensus` (the canonical
   shape), `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and `co_occurs_with`.
   A `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a hallucination
   (curr-13/14) — no shipping Mac app uses the symbol. (b) **Spec** — confirm via **Sosumi**:
   `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi
   `doc:` floor. The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
   Promote with the citation or discard; carry an unconfirmed successor signature as `source: verify
   against Xcode 26 SDK`.
   - **Deeper corpus evidence (currency BASELINE).** Open the sweep with the corpus deprecation set:
     `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated --json` (no arg) or
     `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx insights deprecated` — the deprecated APIs real
     Mac apps STILL ship, with repo counts (e.g. `.foregroundColor`/curr-02 in **1,119** repos,
     `NavigationView`/curr-01 in 257). Use it to rank which curr-IDs to hunt first and to ground each
     finding's `era` ("still shipped by N repos"), per `_shared/swiftui-ctx-reference.md`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (curr-02/03/10/12 — the pure mechanical renames), one conventional commit
   per finding citing its `rule_id`, never weaken a check. The ✅ "Correct" is **not a hand-written
   snippet** — it is the swiftui-ctx **consensus shape** put in `## Correct`, backed by a real macOS-26
   example fetched with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart`
   whose GitHub permalink (plus the Sosumi `doc:`) goes in `## Source` as the canonical example. Leave
   `flag-only` findings `open` with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves. If a fix introduced a new tell (e.g.
   a `.foregroundStyle` replacement that now needs a macOS-12 gate below the floor), loop that file back
   to DETECT and route the gating note to `availability-gating`.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. Auto-fix only the mechanical rename set
(curr-02/03/10/12); everything else is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/api-currency/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/api-currency/_index.md`.
- `domain: api-currency`. Uses the additive field **`era`** (free-string release wave, e.g.
  `WWDC22/macOS-13`, `macOS-26.5`, `WWDC25/macOS-26`). `fix_mode` is `auto` for curr-02/03/10/12, else
  `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date
  (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` per the seam note.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `deprecated-renamed/` | a real symbol Apple superseded — nav, color, clip, onChange, tab, link, Text+Text (curr-01…07) |
| `concurrency-cargo-cult/` | a `DispatchQueue.main.async` hop in async-aware code (curr-08) |
| `macos-26-5-deprecations/` | a freshly-deprecated 26.5 surface — dropDestination, gesture renames, Font weight, accentColor (curr-09…12) |
| `hallucinated-api/` | an invented name (curr-13) or a visionOS-only symbol on a Mac target (curr-14) |
| `gating/` | a current-but-floored *replacement* used below the deployment target (route depth → availability-gating) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/api-currency/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/deprecations-and-renames.md` | any deprecated/renamed question — the full ❌→✅ catalog, deprecation dates, floors, the gating arm (curr-01…12) |
| `references/hallucinated-currency.md` | a name/existence question — the invented-name set + the visionOS-only trap, and the exit-3 corroboration (curr-13/14) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/curr-04-onchange-one-param.yml` + `lint/ast-grep/curr-06-inline-navlink-in-list.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep: `curr-04-onchange-one-param.yml` for the 1-param closure shape, `curr-06-inline-navlink-in-list.yml` for inline `NavigationLink` containment); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability/deprecation value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm failure |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys (incl. additive `era`) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-api-currency --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, curr-01…14 flat-presence /
deprecation-string tells) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` — curr-04
1-param `onChange` closure-shape, curr-06 inline `NavigationLink` *inside* a `List`/`ForEach`) that grep
cannot express. It runs a per-file **parse probe** (surfaces "did not fully parse" so a structural miss
can't look clean), emits unified **JSON + SARIF**, exits **2** on any hard-fail (curr-13/14) for a CI
gate, and **degrades to grep-only with a notice** if ast-grep is unreachable (`npx --package
@ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES — always READ each hit in
full before reporting (step 3). The thin `scripts/currency-lint.sh` is a pointer to this runner. Engine
+ rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
</content>
</invoke>
