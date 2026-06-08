---
name: audit-swiftui-state-restoration
description: Audits a finished or in-progress macOS SwiftUI codebase for state-restoration and persistence defects and writes per-finding Markdown to swiftui-audits/. Use when the user says the app forgets its window, tab, sidebar, or selection on relaunch; when settings leak between windows or do not persist; when they ask to verify @AppStorage vs @SceneStorage, UserDefaults usage, NavigationPath persistence, restorationBehavior, focusedSceneValue, onOpenURL, or a custom URL scheme; when deep links do nothing; when AI may have written restorationIdentifier, StateRestoration, or stuffed a custom type or large blob into scene/app storage. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for SwiftData model design, not for window/scene plumbing itself, not for navigation structure, not for writing new persistence from scratch.
---

# Audit SwiftUI State Restoration

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, flag the fix for — every way scene/app **state restoration and
lightweight persistence** goes wrong: `@AppStorage`↔`@SceneStorage` confusion, hand-rolled
`UserDefaults` where a wrapper fits, tab/sidebar/detail selection that suffers relaunch amnesia,
`NavigationPath` that is never persisted, custom types or oversized blobs in size-limited storage, dead
deep links, and ungated `restorationBehavior` / `focusedSceneValue`. Findings are written to disk in the
toolkit's unified schema. This is never a from-scratch persistence generator.

This is the toolkit's **orphaned domain**: `@AppStorage` (app-wide preferences) versus `@SceneStorage`
(per-window UI state) is the single most-confused axis. The wrapper *compiles either way* — the defect is
semantic, so READ before you report.

## Boundary / seam note (stay in lane)

- **SwiftData `@Model` design and `@Query` fetches** belong to `audit-swiftui-swiftdata`. This skill owns
  the *decision to move oversized scene/app storage out* (sr-08) and emits `cross_ref: audit-swiftui-swiftdata`;
  it does not audit the model graph.
- **Window/scene plumbing** (`WindowGroup`/`Window`/`MenuBarExtra` activation, `.defaultSize`,
  `.windowResizability`, `handlesExternalEvents` as a scene matcher) belongs to `audit-swiftui-scenes-windows`.
  This skill owns the *restoration* of scene UI state and `restorationBehavior`; defer scene activation
  there with a `cross_ref`.
- **Navigation structure** (`NavigationStack`/`NavigationSplitView` columns, `NavigationLink`) belongs to
  `audit-swiftui-navigation-toolbars`. This skill owns *persisting* the `NavigationPath`/selection across
  relaunch (sr-05/06), not the navigation shape.
- **`@FocusedValue`/`focusedSceneValue` command routing** belongs to `audit-swiftui-menus-commands`; this skill
  flags only the `focusedSceneValue` **availability floor** (sr-11) and `cross_ref`s the routing owner.

## The state-restoration model (the load-bearing distinction)

1. **`@AppStorage` = app-wide preference.** One value shared by *every* window/scene — theme, default
   units, "show line numbers". Backed by `UserDefaults`.
2. **`@SceneStorage` = per-window UI state.** Restored *per scene* by the system — selected tab, sidebar
   selection, current document section, scroll target. Two windows hold independent values.
3. **Both are size-limited key-value stores.** A custom type needs `RawRepresentable`/`Codable`; large
   `Data`/arrays/images belong in SwiftData or a file, never in scene/app storage.

**The wrapper test:** would *two open windows* legitimately disagree about this value? Yes → per-window UI
state → `@SceneStorage`. No, it's one app-wide truth → `@AppStorage`. Full reasoning + the ❌→✅ rewrites:
`references/wrapper-choice.md`.

**Grounded ✅ (real call site, not a placeholder).** Per-window UI state restores per scene when its key is
bound to `@SceneStorage`. The canonical shape — consensus from swiftui-ctx `lookup SceneStorage`
(`introduced_macos` 11.0; top shapes `("selectedTab")`, `("viewMode")`, `("selectedSettingsSection")`,
each ~13%) — and a verified shipping example:

```swift
// ✅ TableProApp/TablePro — @SceneStorage restores per-window search text on relaunch
@SceneStorage("tableList.searchText") private var searchText = ""
```

- Example (`swiftui-ctx file ex_596e50becb --smart`, real GitHub permalink): `https://github.com/TableProApp/TablePro/blob/e3afc6457cd819eca5226c3874a9b4d7ad318a67/TableProMobile/TableProMobile/Views/TableListView.swift#L12`
- Spec (`doc:`, via Sosumi): `https://sosumi.ai/documentation/swiftui/scenestorage` (macOS 11.0+, accessed 2026-06-07).

Re-fetch the live consensus + permalink in step VERIFY/FIX rather than trusting this snapshot.

## Defect index (sr-01 … sr-11)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct),
**warning** (compiles but wrong/amnesiac), **advisory** (judgment / perf). All fixes are `flag-only`: every
correction here turns on developer *intent* (is this value app-wide or per-window?), so none auto-applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| sr-01 | `.restorationIdentifier(` / `@StateRestoration` / `UIStateRestoring` / `restorationClass` (UIKit/invented on SwiftUI Mac) | hard-fail | flag | `restoration-gating.md` |
| sr-02 | `@SceneStorage` holding an app-wide preference (one truth for all windows) | warning | flag | `wrapper-choice.md` |
| sr-03 | `@AppStorage` holding per-window UI state (tab/sidebar/detail/scroll selection) → leaks across windows | warning | flag | `wrapper-choice.md` |
| sr-04 | hand-rolled `UserDefaults.standard.set/object(forKey:)` for a simple pref `@AppStorage` fits | warning | flag | `wrapper-choice.md` |
| sr-05 | `TabView`/`NavigationSplitView`/`List` selection bound to plain `@State` (no `@SceneStorage`) → relaunch amnesia | warning | flag | `navigation-restoration.md` |
| sr-06 | `NavigationPath` never persisted — no `NavigationPath(codable:)` / `.codable` round-trip into `@SceneStorage` | advisory | flag | `navigation-restoration.md` |
| sr-07 | custom type in `@AppStorage`/`@SceneStorage` without `RawRepresentable`/`Codable` conformance | warning | flag | `wrapper-choice.md` |
| sr-08 | oversized `Data`/array/image stored in `@SceneStorage`/`@AppStorage` (size-limited) → SwiftData/file | warning | flag | `wrapper-choice.md` |
| sr-09 | declared `CFBundleURLSchemes` / custom URL scheme but no `onOpenURL`/`onContinueUserActivity` handler (dead deep link) | warning | flag | `deep-linking.md` |
| sr-10 | `restorationBehavior(_:)` used/ungated under a deployment target < macOS 15 | warning | flag | `restoration-gating.md` |
| sr-11 | `focusedSceneValue(_:_:)` — key-path form macOS 12 / object form macOS 14; verify floor + gate | advisory | flag | `restoration-gating.md` |

**One claim is FLOOR-SENSITIVE — never assert without VERIFY:** `focusedSceneValue` has *two* floors (the
key-path overload is macOS 12, the object overload macOS 14, per the brief); confirm which overload the
code uses before quoting a floor (`source: verify against Xcode 26 SDK` until confirmed via swiftui-ctx +
Sosumi). `restorationBehavior` is macOS 15.

## The real API, at a glance

**Real (and their macOS floors — confirmed via swiftui-ctx `introduced_macos` + Sosumi):** `@AppStorage`
(macOS 11), `@SceneStorage` (macOS 11), `NavigationPath` + `NavigationPath(codable:)` / `.codable`
(macOS 13), `onOpenURL(perform:)` (macOS 11), `onContinueUserActivity(_:perform:)` (macOS 11),
`handlesExternalEvents(matching:)` (macOS 11 — Mac, iOS, visionOS; no tvOS/watchOS), `restorationBehavior(_:)`
(macOS 15), `focusedSceneValue(_:_:)` (key-path macOS 12 / object macOS 14). Floor *values* live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate.

**Hallucinated / wrong-framework (never on SwiftUI macOS):** `.restorationIdentifier(...)`,
`@StateRestoration`, `UIStateRestoring`, `restorationClass`, `encodeRestorableState`/`decodeRestorableState`
(all UIKit `UIViewController`/`NSResponder` restoration, not SwiftUI). `@FocusedDocument` is **not** a real
symbol — use a custom `FocusedValues` key (`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`).
The full ❌→✅ rewrites: `references/wrapper-choice.md` + `references/restoration-gating.md`.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   sr-10 fires only when the floor is **below macOS 15**, sr-11 only below the relevant `focusedSceneValue`
   floor. Also read `Info.plist`/`project.pbxproj` for any declared `CFBundleURLSchemes` (needed for sr-09).
   Record the target and any declared scheme.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-state-restoration --dir <sources> --json /tmp/sr.json --sarif /tmp/sr.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + the tier-2 structural ast-grep rule
   (`lint/ast-grep/*.yml` — the `restorationBehavior`-not-inside-a-`#available(macOS 15)`-gate rule grep
   can't express), plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its
   `parse_warnings`** — a flagged file did not fully parse, so a structural miss can't masquerade as clean;
   READ those by hand. The runner only LOCATES. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. The wrapper-choice
   defects (sr-02/03) are invisible to grep: only reading the value's *meaning* (app-wide vs per-window),
   its scope, and how many windows the app opens reveals the defect. Build a per-file inventory: each stored
   property + wrapper + value semantics + the wrapper test verdict.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a UIKit restoration symbol on SwiftUI, a custom type with no `RawRepresentable`, a
   `restorationBehavior` under a <15 floor).
5. **VERIFY.** For anything ≤ ~70% confidence (a floor you can't place — especially `focusedSceneValue`'s
   two overloads — a symbol you're unsure exists, a "does this persist" behavior claim), run **both**
   evidence sources. (a) **Practice** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json`
   (and `swiftui-ctx deprecated <api>` for a currency rule): read its `consensus` (the canonical shape),
   `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and `co_occurs_with`; a `lookup`
   **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a hallucination — no shipping Mac
   app uses the symbol. (b) **Spec** — confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>`
   using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`; this domain's parenthesized-symbol JSON **404s** — Sosumi only). Cross-check
   `introduced_macos` against `floors-master.md`. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or discard.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** All findings here are `fix_mode: flag-only` — leave each `open` with the ✅ in `## Correct`. The
   ✅ is **not a hand-written snippet**: it is the swiftui-ctx **consensus shape** put in `## Correct`,
   backed by a real macOS example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source` as the canonical example. The fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`) still governs: clean-tree gate,
   findings-first, never weaken a check. Because the wrapper swap turns on intent, never auto-apply it.
8. **DOUBLE-CHECK.** Re-read each flagged property to confirm the ✅ wrapper matches the value's semantics
   (the wrapper test still holds). Re-confirm every citation still resolves and still says the floor you
   quoted. If a suggested ✅ introduces a new tell (e.g. moving a blob to `@SceneStorage` now needs `Codable`),
   loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. The wrapper-confusion defects (sr-02/03/04) are *semantic* —
treat them as ≤70% until READ confirms the value's app-wide-vs-per-window meaning; route them through VERIFY
for the floor and through the wrapper test for the verdict. Never emit a speculative finding. Nothing here
auto-fixes — every finding is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/state-restoration/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/state-restoration/_index.md`.
- `domain: state-restoration`. `fix_mode` is `flag-only` for every defect. An optional descriptive
  additive field `storage_kind` (`app` | `scene` | `userdefaults` | `navigation` | `url`) may record which
  store the finding concerns; emit `cross_ref` on shared-seam findings (sr-08 → `audit-swiftui-swiftdata`;
  sr-05/06 → `audit-swiftui-navigation-toolbars`; sr-10 → `audit-swiftui-scenes-windows`; sr-11 →
  `audit-swiftui-menus-commands`). `availability` reads from `floors-master.md`. `source` is an Apple URL +
  access date (fetched via Sosumi) or `verify against Xcode 26 SDK`.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `hallucinated-api/` | a UIKit/invented restoration symbol appears on SwiftUI (sr-01) |
| `wrapper-confusion/` | the wrong wrapper holds the value — scene/app swapped, or hand-rolled UserDefaults (sr-02, sr-03, sr-04) |
| `relaunch-amnesia/` | selection or navigation is not restored — plain `@State` selection, unpersisted `NavigationPath` (sr-05, sr-06) |
| `storage-correctness/` | a non-conforming custom type or an oversized blob sits in key-value storage (sr-07, sr-08) |
| `deep-linking/` | a declared URL scheme/activity has no handler (sr-09) |
| `restoration-gating/` | `restorationBehavior`/`focusedSceneValue` is ungated under its floor (sr-10, sr-11) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/state-restoration/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a hard
requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/wrapper-choice.md` | the `@AppStorage`↔`@SceneStorage`↔`UserDefaults` decision, the wrapper test, custom-type conformance, oversized-blob offload (sr-02/03/04/07/08) |
| `references/navigation-restoration.md` | restoring selection + `NavigationPath` across relaunch — `@SceneStorage` selection, `NavigationPath(codable:)` round-trip (sr-05/06) |
| `references/deep-linking.md` | URL scheme + `onOpenURL`/`onContinueUserActivity`/`handlesExternalEvents` wiring (sr-09) |
| `references/restoration-gating.md` | the hallucinated/UIKit symbols, `restorationBehavior` (macOS 15) + `focusedSceneValue` two-floor gating (sr-01/10/11) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + the one tier-2 structural rule); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (incl. `@FocusedDocument`) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm failure (sr-10/11) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-state-restoration --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, sr-01/02/03/04/05/06/07/08/09/10/11) +
**tier-2 ast-grep** (`lint/ast-grep/sr-10-restorationbehavior-ungated.yml` — `restorationBehavior` NOT inside
an `#available(macOS 15, *)` gate, a gate-scope rule grep cannot express). It runs a per-file **parse probe**
(surfaces "did not fully parse" so a structural miss can't look clean), emits unified **JSON + SARIF**, exits
**2** on any hard-fail (sr-01) for a CI gate, and **degrades to grep-only with a notice** if ast-grep is
unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES —
always READ each hit in full before reporting (step 3). The thin `scripts/sr-lint.sh` is a pointer to this
runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
