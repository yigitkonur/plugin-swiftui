---
name: audit-swiftui-appkit-interop
description: Audits a finished or in-progress macOS SwiftUI codebase for broken AppKit bridges — how a JUSTIFIED escape hatch is wired — and writes per-finding Markdown to swiftui-audits/. Use when an NSViewRepresentable goes stale, an NSTextField/NSTextView wrapper does not update, typing does not flow back to a Binding, focus or first responder will not move, a custom NSView will not take focus, becomeFirstResponder does nothing, an editor wrapped as a bare view loses its lifecycle, SwiftUI will not embed in an NSWindow, a Coordinator hits a Swift 6 Sendable data-race error, a sidebar on ultraThinMaterial looks flat, or toolbar/navigationTitle/searchable do not appear under NSHostingView. Also when AI wrote a representable missing updateNSView, makeCoordinator, dismantleNSView, or acceptsFirstResponder. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for WHETHER to bridge (appkit-overuse), not NSGlassEffectView, not UIViewRepresentable, not writing a bridge from scratch.
---

# Audit SwiftUI AppKit Interop

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, flag with the canonical ✅ — every way a **justified** AppKit
bridge is wired wrong: a representable that compiles but never reflects state, a dead delegate
round-trip, a misunderstood first-responder chain, the wrong bridge protocol, a missing reverse bridge,
a Swift-6 race at the Coordinator boundary, in-window vibrancy faked as a native sidebar, and scene
chrome that silently does not bridge under `NSHostingView`. Findings are written to disk in the
toolkit's unified schema. This is never a from-scratch bridge generator.

This is the **BRIDGE-CORRECTNESS safety net: the HOW of a justified escape hatch.** The macOS responder
chain is *not* iOS's `becomeFirstResponder()`/`@FocusState`-covers-everything model — none of those
rules transfer. Default posture stays **in SwiftUI**; bridge only the one control that needs it.

## Boundary / seam note (stay in lane)

- **WHETHER a bridge should exist at all is `audit-swiftui-appkit-overuse`'s call**, not this skill's. The
  two are a bidirectional handshake: overuse = *whether*, interop = *how*. Every finding here emits a
  `cross_ref: appkit-overuse` so the consolidated pass can confirm the bridge was justified before we
  grade its wiring (`cross-ref-graph.md`).
- **The `@Sendable`/main-actor race (interop-06) is owned here for the bridge boundary** but `cross_ref:
  concurrency-safety` — that skill owns the isolation model in depth (use `swift_era` + `isolation_kind`).
- **The `NSVisualEffectView`-vs-material *decision* (interop-07) is shared with
  `audit-swiftui-appearance-color`** (vibrancy/material craft). Flag the in-window-flat sidebar here with
  `cross_ref: appearance-color`; defer broader color/material craft there.
- **`NSGlassEffectView` (AppKit Liquid Glass) is out of scope** — note in one line, do not audit here.

## The bridge rules (non-negotiable)

1. **A representable has two halves.** `makeNSView`/`makeNSViewController` runs **once**;
   `updateNSView`/`updateNSViewController` runs on every state change. Omit the update half → the AppKit
   view silently goes stale. Guard the write (`if nsView.stringValue != text`) or you reset the cursor.
2. **AppKit → SwiftUI flows through the Coordinator.** A `@Binding` with no `makeCoordinator()` + no
   `.delegate = context.coordinator` is a dead direction — edits never reach the bound value.
3. **macOS first-responder is window-scoped and explicit.** A custom `NSView` is unfocusable unless it
   returns `true` from `acceptsFirstResponder`; you activate it via `window.makeFirstResponder(_:)`.
   `@FocusState` covers SwiftUI-native controls only.
4. **Match the bridge surface to the shape.** Controller-shaped AppKit (`NSSplitViewController`, editor,
   scroll/ruler `NSTextView`) → `NSViewControllerRepresentable`; a bare `NSView` → `NSViewRepresentable`;
   SwiftUI inside AppKit → `NSHostingController` / `NSHostingView`.

## Defect index (interop-01 … interop-10)

`id · tell · severity · fix · open reference`. **hard-fail** = build break / never-correct;
**warning** = compiles but broken/non-native; **advisory** = judgment / craft. Every fix in this domain
needs human context → `fix_mode: flag-only` across the board (show the ✅; the dev applies it).

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| interop-01 | `: NSViewRepresentable`/`…ControllerRepresentable` with **no** `updateNSView`/`updateNSViewController` (state staleness) | warning | flag | `representable-lifecycle.md` |
| interop-02 | a representable with a `@Binding` but **no** `makeCoordinator()` / no `.delegate = context.coordinator` (dead AppKit→SwiftUI) | warning | flag | `representable-lifecycle.md` |
| interop-03 | `becomeFirstResponder()` on a SwiftUI value, or a custom `NSView` expected to focus with **no** `override var acceptsFirstResponder` | warning | flag | `first-responder-focus.md` |
| interop-04 | controller-shaped AppKit (`…Controller`/`…VC`) flattened to a bare `NSView` via `vc.view` (wrong protocol) | warning | flag | `representable-lifecycle.md` |
| interop-05 | SwiftUI hand-instantiated in AppKit / `addSubview` of a `View` with **no** `NSHostingController`/`NSHostingView` | warning | flag | `reverse-bridge-hosting.md` |
| interop-06 | a `@Sendable` closure (or `DispatchQueue.main.async`/`Task.detached`) at the Coordinator boundary reading `self.parent.…`/main-actor state | warning | flag | `bridge-concurrency.md` |
| interop-07 | `.ultraThinMaterial` as a "native" sidebar/panel — composites in-window, never behind-window | advisory | flag | `vibrancy-material.md` |
| interop-08 | `.searchable`/`.toolbar`/`.navigationTitle` on a view installed via `NSHostingView` (no/incomplete `sceneBridgingOptions`) | warning | flag | `reverse-bridge-hosting.md` |
| interop-09 | observers / KVO / `Timer` added in `makeNSView` with **no** `static func dismantleNSView` (leak across identity) | warning | flag | `representable-lifecycle.md` |
| interop-10 | a newer bridge surface (`NSHostingMenu`, `NSAnimationContext.animate`, `sceneBridgingOptions`, `NSHostingSizingOptions`) ungated under its floor | warning | flag | `newer-bridge-surfaces.md` |

**Two claims are UNVERIFIED on a fresh Xcode 26 target — carry as the noted severity but cite `source:
verify against Xcode 26 SDK`, never assert as fact:** that *Default Actor Isolation = Main Actor*
(`-default-isolation MainActor`) is off (interop-06 fires only when it is off — it is opt-in, not the
language default); that `@concurrent`/`-default-isolation` are Swift-6.2+ toolchain-gated.

## The real API, at a glance

**Real (exist on macOS):** `NSViewRepresentable` / `NSViewControllerRepresentable` / `NSHostingController`
/ `NSHostingView` (`makeNSView`/`updateNSView`/`makeCoordinator`/`dismantleNSView`), `acceptsFirstResponder`,
`window.makeFirstResponder(_:)`, `NSVisualEffectView` (`.behindWindow` blending), `sceneBridgingOptions`
(`NSHostingSceneBridgingOptions`), `NSHostingSizingOptions`, `sizeThatFits(_:nsView:context:)`,
`NSHostingMenu`, `NSAnimationContext.animate(_:changes:completion:)`. **`@FocusState` covers SwiftUI-native
controls only — it does NOT drive arbitrary AppKit first-responder behaviour; never claim it does.**

**Does NOT exist / wrong direction:** a public "make this arbitrary SwiftUI view first responder" call;
`becomeFirstResponder()` on a SwiftUI value; embedding `MySwiftUIView()` as an `NSView` subview directly.
**`.searchable` has NO scene bridge** — it never renders under a bare `NSWindow` + `NSHostingView` on any macOS.

Floors (`13`/`14`/`14.4`/`15`) and signatures are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` and `references/newer-bridge-surfaces.md` —
read, never restate. The canonical invented-name list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`.

## Grounded ✅ — the canonical Correct (real code, not a placeholder)

The reverse bridge (interop-05) is the most-flagged shape, so its ✅ is anchored to live corpus evidence
rather than a hand-written snippet. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup
NSHostingController --json` returns `consensus: [{ shape: "(rootView)", pct: 100 }]`,
`introduced_macos: "10.15"`, and a `recommended` example with `author_authority: 28561`:

```swift
// ✅ the 100%-consensus reverse-bridge shape — SwiftUI hosted through the AppKit bridge type
self.contentViewController = NSHostingController(rootView: contentView)   // macOS 10.15+
```

**Source (real permalink + Apple spec, both verified 2026-06-07):**
- example: jordanbaird/Ice (28.5k★) — https://github.com/jordanbaird/Ice/blob/11edd39115f3f43a83ae114b5348df6a0e1741cf/Ice/MenuBar/Appearance/MenuBarAppearanceEditor/MenuBarAppearanceEditorPanel.swift#L105 (fetch the enclosing body with `swiftui-ctx file ex_ff382027c2 --smart`)
- Apple doc (via Sosumi): `doc: https://sosumi.ai/documentation/swiftui/nshostingcontroller`

Every other domain finding follows the same FIX discipline (step 7): the ✅ is the swiftui-ctx
`consensus` shape backed by a permalinked example, never an invented snippet.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`) and the **Swift
   language mode** / `SWIFT_STRICT_CONCURRENCY` / `-default-isolation` build setting. Both are
   load-bearing: interop-10 fires only when a surface's floor is **above** the target; interop-06 fires
   only under the Swift-6 language mode with *Main-Actor isolation off*. Record both.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-appkit-interop --dir <sources> --json /tmp/interop.json --sarif /tmp/interop.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the missing-`updateNSView`, missing-`makeCoordinator`, and
   controller-as-bare-view rules grep cannot express), plus a per-file **parse probe**, emitting unified
   JSON + SARIF. **Read its `parse_warnings`** — a flagged file did not fully parse, so a structural miss
   can't masquerade as clean; READ those by hand. The runner only LOCATES. Engine + rule-file format:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. A representable's
   two halves, the Coordinator's delegate wiring, gate scope, and `dismantleNSView` presence are spread
   across the type and invisible to grep. Build a per-file inventory: each representable + its
   `make`/`update`/`makeCoordinator`/`dismantle` members + delegate wiring + focus opt-in.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (a representable that genuinely lacks `updateNSView`; a `@Binding` with no Coordinator
   anywhere; a `becomeFirstResponder()` on a SwiftUI value).
5. **VERIFY.** For anything ≤ ~70% confidence (a member you're unsure is required, a floor you can't
   place, a behaviour claim), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and `swiftui-ctx deprecated <api>`
   for a currency rule): read its `consensus` (the canonical shape), `recommended` permalink,
   `introduced_macos`, and `co_occurs_with`; an `nsview-bridge` recipe redirect hands the real template; a
   `lookup` **exit 3** corroborates a hallucination. (b) **Spec** — confirm via **Sosumi**:
   `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md`. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or discard.
   **Deeper corpus evidence (this domain):** when you doubt a bridge shape is real or want the make/update/
   Coordinator/dismantle layout from a shipping app, run the bridges command —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx bridges NSViewControllerRepresentable` (stable envelope +
   `next_actions`) yields real bridges + permalinks (corpus: 4,698 bridges / 957 repos — 2,999 `NSViewRepresentable` +
   143 `NSViewControllerRepresentable`, e.g. AuroraEditor `FindNavigatorResultList`); `swiftui-ctx recipe nsview-bridge`
   hands the canonical template (interop-01/02/04/09).
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit `cross_ref` per the seam note. Write the run's `_index.md`.
7. **FIX.** This domain is `fix_mode: flag-only` end-to-end (every fix needs human bridge context) — leave
   findings `open` with the ✅ in `## Correct`, under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`: clean-tree gate, never weaken a
   check). The ✅ "Correct" is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape**
   backed by a real macOS example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source`. (e.g. the reverse bridge: `lookup NSHostingController`
   gives `consensus (rootView) 100%` + a permalinked `NSHostingController(rootView:)` from a 28k-star app.)
8. **DOUBLE-CHECK.** Re-read each flagged type to confirm the missing member is still missing (no
   false positive from a member declared far away) and the ✅ still compiles against the recorded floor.
   Re-confirm every citation still resolves at its recorded floor.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) first — never emit a
speculative finding (e.g. don't flag a "missing `updateNSView`" until you've read the whole type). All
findings are `fix_mode: flag-only`; show the ✅, the dev applies it.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized:

- Findings: `swiftui-audits/appkit-interop/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/appkit-interop/_index.md`.
- `domain: appkit-interop`. `fix_mode: flag-only` for all. `availability` reads from `floors-master.md`.
  `source` is an Apple URL + access date (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit
  `cross_ref` per the seam note. interop-06 may add `swift_era` + `isolation_kind` (concurrency-safety's
  catalogued fields).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `representable-lifecycle/` | a missing `updateNSView`, dead Coordinator, controller-as-bare-view, or missing `dismantleNSView` (interop-01/02/04/09) |
| `first-responder/` | first-responder misuse — `becomeFirstResponder()` on a value or a missing `acceptsFirstResponder` (interop-03) |
| `reverse-bridge/` | SwiftUI-in-AppKit hosting gaps or scene-chrome that doesn't bridge under `NSHostingView` (interop-05/08) |
| `bridge-concurrency/` | a Swift-6 `@Sendable`/main-actor race at the Coordinator boundary (interop-06) |
| `vibrancy-material/` | in-window `.ultraThinMaterial` faking a behind-window native sidebar (interop-07) |
| `availability-gating/` | a newer bridge surface ungated under its macOS floor (interop-10) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/appkit-interop/` with a lowercase-hyphen slug, and note it in the run's `_index.md`.
Prefer an existing folder when the fit is reasonable; consistency across runs is a hard requirement.* Two
runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/representable-lifecycle.md` | the two halves, Coordinator/delegate round-trip, controller-vs-view protocol choice, `dismantleNSView` cleanup (interop-01/02/04/09) |
| `references/first-responder-focus.md` | the macOS responder chain, `acceptsFirstResponder`, `window.makeFirstResponder`, `@FocusState` limits (interop-03) |
| `references/reverse-bridge-hosting.md` | `NSHostingController`/`NSHostingView`, `sceneBridgingOptions`, why `.searchable` never bridges (interop-05/08) |
| `references/bridge-concurrency.md` | the Swift-6 `@Sendable`/main-actor error at the Coordinator boundary + the isolation fixes (interop-06) |
| `references/vibrancy-material.md` | behind-window vibrancy vs in-window material, the `NSVisualEffectView` bridge (interop-07) |
| `references/newer-bridge-surfaces.md` | the macOS 13/14/14.4/15 bridge surfaces + their floors and gating (interop-10) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm failure (interop-10 gates) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys (incl. `swift_era`/`isolation_kind`) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`recipe`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (appkit-overuse · concurrency-safety · appearance-color) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-appkit-interop --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
interop-03/05/06/07/08/09/10) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` — interop-01
representable-missing-`updateNSView`, interop-02 representable-missing-`makeCoordinator`, interop-04
controller-flattened-to-view) that grep cannot express. It runs a per-file **parse probe**, emits unified
**JSON + SARIF**, emits warnings/advisories only (no hard-fail tells — nothing blocks the gate), and **degrades to grep-only with a notice**
if ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It
only LOCATES — always READ each hit in full before reporting (step 3). The thin `scripts/interop-lint.sh`
forwards to this runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
