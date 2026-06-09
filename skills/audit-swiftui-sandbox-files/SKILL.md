---
name: audit-swiftui-sandbox-files
description: Audits a finished macOS SwiftUI codebase for App-Sandbox, entitlement, and file-access defects and writes per-finding Markdown to swiftui-audits/. Use when file reads fail at runtime though the path exists, a picked file is unreachable next launch, or the Mac App Store rejected the sandbox; when AI wrote String(contentsOf:)/Data(contentsOf:)/FileManager on a hard-coded path with no fileImporter or NSOpenPanel; when a picked URL is saved by .path or a plain bookmarkData() with no .withSecurityScope; when startAccessingSecurityScopedResource has no balancing stop/defer; when .entitlements lacks files.user-selected or network.client under com.apple.security.app-sandbox; when drag-drop uses NSItemProvider/onDrop or UIPasteboard instead of Transferable/.dropDestination/NSPasteboard. AUDIT-ONLY, macOS-only, SwiftUI-only. Not the loadTransferable Sendable-race owner (concurrency-safety), not whether to bridge NSOpenPanel (appkit-overuse), not SwiftData store design (swiftdata), not the blanket availability sweep.
---

# Audit SwiftUI Sandbox & Files

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way file access goes wrong under the **App Sandbox**:
arbitrary-path reads without user consent, a picked URL persisted without a security-scoped bookmark, a
`start` access with no balancing `stop`, missing entitlement keys, legacy `NSItemProvider`/`UIPasteboard`
instead of `Transferable`, the deprecated 3-arg `dropDestination`, and Hardened-Runtime `cs.*` gaps.
Findings are written to disk in the toolkit's unified schema; certain mechanical defects are fixed under
the fix-safety protocol. This is never a from-scratch file-pipeline generator.

The governing rule that makes this domain counter-intuitive — and the reason AI gets it wrong (training
data is iOS-shaped, where the app never legitimately touches a path the user didn't already hand it):
**holding a URL is NOT the same as being allowed to open it.** A sandboxed app reaches only its own
container plus files the *user* hands it through a system panel, and that grant does **not** survive
relaunch without a security-scoped bookmark.

## Boundary / seam note (stay in lane)

- **The `loadTransferable` Swift-6 Sendable data race** ("Sending main actor-isolated value …") is owned
  by **`audit-swiftui-concurrency-safety`** (the isolation fix: move the picker item + transfer work into
  an `@Observable` model). This skill owns only the *file-consent* angle of the same site; emit a
  `cross_ref: audit-swiftui-concurrency-safety` when the isolation hazard is present (sf-07).
- **Whether an `NSOpenPanel`/`NSSavePanel` bridge should exist at all** is owned by
  **`audit-swiftui-appkit-overuse`** (prefer SwiftUI `fileImporter`/`fileExporter`). This skill owns
  **bookmark/consent correctness** once a panel or importer is in use; `cross_ref` it (sf-01, sf-02).
- **The `dropDestination(for:action:isTargeted:)` deprecation flag** is owned by
  **`audit-swiftui-api-currency`**; this skill flags it where it appears in a drag-drop pipeline and
  `cross_ref`s currency (sf-08).
- **Where the SwiftData store lives** (app-group container, store URL) is owned by
  **`audit-swiftui-swiftdata`**; `cross_ref` it when a bookmark/group-container question is really a store
  question.
- **The blanket "is every OS-floored API gated" sweep** belongs to `audit-swiftui-availability-gating`;
  this skill owns the macOS-26 floor of the `dropDestination` successor in depth and defers the rest.

## The three non-negotiable design rules

1. **Files come from the user.** A sandboxed app cannot read a path it wasn't granted. Get every URL
   through `fileImporter`/`fileExporter` (SwiftUI) or `NSOpenPanel`/`NSSavePanel` (AppKit) — never a
   hard-coded or user-typed path. `Bundle.main` resources are the one always-readable exception.
2. **Persistence needs a security-scoped bookmark.** To re-open a user file next launch, persist
   `bookmarkData(options: .withSecurityScope)` (the `Data`, not `.path`); resolve with `.withSecurityScope`
   and wrap re-access in ref-counted `startAccessingSecurityScopedResource()` … `stopAccessingSecurityScopedResource()`
   balanced by `defer`.
3. **Declare every entitlement you use and no more.** `com.apple.security.app-sandbox` plus exactly the
   capability keys in use (`files.user-selected.read-write`/`.read-only`, `network.client`, app-scope
   bookmarks). Sandbox-on with a missing key = silent runtime failure, not a compile error.

**The consent test:** trace each file URL back to its origin — a system panel (`fileImporter`/`NSOpenPanel`)
or a resolved security-scoped bookmark → **granted**; a string literal, a `URL(fileURLWithPath:)`, a
`.path` from `UserDefaults`, or a plain `bookmarkData()` → **ungranted, will fail at runtime.** Full
reasoning + the round-trip artifact: `references/consent-and-bookmarks.md`.

## Correct (grounded — real shipping code, not a placeholder)

The ✅ for the consent finding (sf-01) is the swiftui-ctx **consensus shape** for `fileImporter`
(265 repos, 618 uses; top shape `(isPresented, allowedContentTypes, allowsMultipleSelection)` 65%),
shown here as the highest-authority real call site — `sindresorhus/Gifski` (`recommended`,
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file ex_b884986158 --smart`):

```swift
// ✅ The URL comes from the user through a system panel — granted, survives the call.
// Source: github.com/sindresorhus/Gifski .../Gifski/MainScreen.swift#L26 (min_macos 26, 8.4k★)
.fileImporter(
    isPresented: $appState.isFileImporterPresented,
    allowedContentTypes: Device.supportedVideoTypes
) {
    do { appState.start(try $0.get()) }   // $0: Result<[URL], Error>
    catch { appState.error = error }
}
```

- **Permalink:** <https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/MainScreen.swift#L26>
- **Apple doc (Sosumi):** `doc:` <https://sosumi.ai/documentation/swiftui/view/fileimporter> — `fileImporter` introduced macOS 11.0.

Contrast the ❌: a `String(contentsOf: URL(fileURLWithPath: someHardCodedPath))` — the app holds a
URL it was never granted, so the read throws at runtime under the sandbox (sf-01). The fix is to source
the URL from the panel above and, to re-open it next launch, persist a `.withSecurityScope` bookmark (sf-02).

## Defect index (sf-01 … sf-09)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (silent runtime failure /
won't compile / never-correct on Mac), **warning** (compiles but breaks under the sandbox), **advisory**
(judgment / distribution). `auto` = mechanical single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| sf-01 | `String(contentsOf:` / `Data(contentsOf:` / `FileManager` read-write on a literal or `URL(fileURLWithPath:)` path, no preceding `fileImporter`/`NSOpenPanel` | warning | flag | `consent-and-bookmarks.md` |
| sf-02 | a picked `URL` persisted by `.path` **or** plain `bookmarkData()` with no `options: .withSecurityScope` | warning | flag | `consent-and-bookmarks.md` |
| sf-03 | `startAccessingSecurityScopedResource()` with no balancing `stopAccessing…`/`defer` (ref-count leak) | warning | flag | `consent-and-bookmarks.md` |
| sf-04 | file/network/bookmark APIs in use but no `.entitlements` keys, or `com.apple.security.app-sandbox` missing on a Mac App Store target | warning | flag | `entitlements-and-hardened-runtime.md` |
| sf-05 | `UIPasteboard` referenced in macOS code (absent from native macOS; Mac Catalyst 13.1+ carries it — this skill is native macOS only → won't compile) | hard-fail | auto | `transferable-and-clipboard.md` |
| sf-06 | `NSItemProvider` `loadObject`/`loadDataRepresentation` or `.onDrop(of:)` callbacks instead of `Transferable` + `.dropDestination` | warning | flag | `transferable-and-clipboard.md` |
| sf-07 | `loadTransferable` / `.task` touching a `@MainActor`-created picker item (file-consent angle; isolation = concurrency-safety) | warning | flag | `transferable-and-clipboard.md` |
| sf-08 | `dropDestination(for:action:isTargeted:)` (3-arg Bool-returning) — deprecated macOS 26.5 | advisory | flag | `transferable-and-clipboard.md` |
| sf-09 | Developer-ID build that JITs / loads plug-ins / injects, Hardened Runtime off or no `com.apple.security.cs.*` | advisory | flag | `entitlements-and-hardened-runtime.md` |

**Two claims are carried as `advisory` and never asserted as fact** (each flagged in its reference +
written `source: verify against Xcode 26 SDK`): the exact `com.apple.security.cs.*` Hardened-Runtime
entitlement **bodies** (sf-09, Apple pages not verbatim-captured); and the *Xcode-26 Default-Actor-Isolation
= Main Actor* build setting that can pre-isolate and mask sf-07 (never assume it is on — it is opt-in).

## The real API, at a glance

**Real (exist on macOS):** `fileImporter(...)` / `fileExporter(...)` (macOS 11.0+), `NSOpenPanel` /
`NSSavePanel` / `NSPasteboard` (AppKit), `URL.bookmarkData(options: .withSecurityScope)` /
`URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)`, `startAccessingSecurityScopedResource()`
(macOS 10.10+, ref-counted) / `stopAccessingSecurityScopedResource()`, `Transferable` (macOS 13.0+) +
`.draggable(_:)` (macOS 13.0+) / `.dropDestination(for:isEnabled:action:)` (the macOS-26.0+ successor),
`CodableRepresentation`, entitlement keys `com.apple.security.app-sandbox` /
`…files.user-selected.read-write` / `…files.bookmarks.app-scope` / `…network.client` /
`com.apple.security.cs.*`.

**Wrong on Mac / stale:** `UIPasteboard` (absent from native macOS; Mac Catalyst 13.1+ carries it — the clipboard on native macOS is
`NSPasteboard`); `dropDestination(for:action:isTargeted:)` (the 3-arg Bool-returning form — **deprecated
macOS 26.5** → `dropDestination(for:isEnabled:action:)`); persisting a picked URL by `.path` or a plain
`bookmarkData()` (round-trips the path, **not** the permission).

Floor *values* are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`;
the canonical platform-wrong/invented-name list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate them.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources **and** every `*.entitlements` file and
   `Info.plist`. Read the **deployment target** (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or
   `Package.swift` `platforms:`) and whether `com.apple.security.app-sandbox` is present — both are
   load-bearing: sf-04 fires on a sandbox-on target missing capability keys; sf-08's successor floor is
   macOS 26. Record the sandbox state and target.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-sandbox-files --dir <sources> --json /tmp/sf.json --sarif /tmp/sf.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the start-without-stop and item-provider-in-onDrop rules grep can't express),
   plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a
   flagged file did not fully parse, so a structural miss can't masquerade as clean; READ those by hand.
   The runner only LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`. The lint scans `*.swift`; the
   **`.entitlements`/`Info.plist` checks (sf-04, sf-09) are read by hand** in this step.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. The URL's
   *origin* (panel vs literal vs bookmark), the `start`/`stop` balance across a function body, and the
   match between APIs-in-use and entitlement keys are invisible to grep. Build a per-file inventory: each
   file URL + its origin (consent test) + its persistence (bookmark or `.path`) + its `start`/`stop`
   balance.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a `UIPasteboard` on Mac, a `String(contentsOf:)` on a literal path with no panel, a
   `.path` persistence, a `bookmarkData()` with no `.withSecurityScope`). For sf-07, if the `loadTransferable`
   site also carries an isolation hazard, set `cross_ref: audit-swiftui-concurrency-safety`.
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, an
   entitlement string, a deprecation), run **both** evidence sources. (a) **Practice** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated <api>` for sf-08): read its `consensus` (the
   canonical shape), `deprecated`+`replacement`, `recommended` permalink, `introduced_macos`, and
   `co_occurs_with`; a `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a
   platform-wrong/hallucination finding — no shipping Mac app uses the symbol. (b) **Spec** — confirm via
   **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the
   path and `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never
   `WebFetch` `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the
   Sosumi `doc:` floor. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. **When the corpus and floors-master
   disagree, floors-master wins** — the catalog predates the macOS-26.5 doc and reports `dropDestination`
   as not-deprecated, but floors-master records the 26.5 deprecation; carry it as fact and note the lag.
   Promote with the citation or discard. Carry the two UNVERIFIED items as `advisory` with
   `source: verify against Xcode 26 SDK` — never as fact.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (sf-05 `UIPasteboard` → `NSPasteboard`), one conventional commit per finding
   citing its `rule_id`, never weaken a check. The ✅ "Correct" is **not a hand-written snippet** — it is
   the swiftui-ctx **consensus shape** put in `## Correct`, backed by a real macOS-26 example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source` as the canonical example. For the consent finding (sf-01),
   the corpus `recommended` for `fileImporter` is `sindresorhus/Gifski`
   (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file ex_b884986158 --smart`). Leave `flag-only`
   findings `open` with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves and still says the recorded floor. If a
   fix introduced a new tell (e.g. a `fileImporter` you added now needs a `files.user-selected`
   entitlement), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. Auto-fix only the mechanical set (sf-05
`UIPasteboard` → `NSPasteboard`); every entitlement/consent/bookmark fix is `fix_mode: flag-only` because
it depends on the app's distribution model and the panel wiring (never blindly add an entitlement).

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/sandbox-files/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/sandbox-files/_index.md`.
- `domain: sandbox-files`. Frontmatter is the canonical schema; `fix_mode` is `auto` for sf-05, else
  `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date
  (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` per the boundary note
  (concurrency-safety for sf-07, appkit-overuse for sf-01/02 panels, api-currency for sf-08, swiftdata for
  store-location bookmarks).

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `arbitrary-path-read/` | a file is read/written from a literal or user-typed path with no panel consent (sf-01) |
| `security-scoped-bookmarks/` | a picked URL is persisted by `.path`/plain bookmark, or `start` has no balancing `stop` (sf-02, sf-03) |
| `entitlements/` | sandbox-on with missing capability keys, or `app-sandbox` missing on a store target (sf-04) |
| `transferable-drag-drop/` | legacy `NSItemProvider`/`onDrop`, the `loadTransferable` consent angle, or the deprecated `dropDestination` (sf-06, sf-07, sf-08) |
| `clipboard/` | `UIPasteboard` on Mac → `NSPasteboard` (sf-05) |
| `hardened-runtime/` | a Developer-ID JIT/plug-in/inject build needs `com.apple.security.cs.*` (sf-09) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/sandbox-files/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

> **Go-beyond artifact (optional):** `swiftui-audits/sandbox-files/_consent-map.md` tracing every file
> URL to its origin (panel / bookmark / literal) with a consent-coverage score — see
> `references/consent-and-bookmarks.md`.

## Reference routing

| File | Open when |
|---|---|
| `references/consent-and-bookmarks.md` | a consent/persistence question — the literal-path trap, the security-scoped-bookmark round-trip, the `start`/`stop` ref-count balance, the stale-bookmark re-create, the consent map (sf-01/02/03) |
| `references/entitlements-and-hardened-runtime.md` | the entitlement keys you must declare per API, the sandbox ON-vs-OFF fork, and the Hardened-Runtime `com.apple.security.cs.*` exceptions (sf-04/09) |
| `references/transferable-and-clipboard.md` | drag-drop modernization (`NSItemProvider`/`onDrop` → `Transferable` + `.dropDestination`), the `loadTransferable` consent seam, the deprecated 3-arg `dropDestination`, and `NSPasteboard` vs `UIPasteboard` (sf-05/06/07/08) |
| `references/source-directory.md` | step VERIFY — the Apple/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth — incl. the `dropDestination` 26.5 deprecation) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical platform-wrong/invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (the `dropDestination` successor's macOS-26 floor) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (concurrency-safety · appkit-overuse · api-currency · swiftdata) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-sandbox-files --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
sf-01/02/04/05/06/07/08/09 flat presence) + **tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` —
sf-03 `start` with no balancing `stop` in the same function, sf-06 `NSItemProvider.load*` inside an
`.onDrop` closure) that grep cannot express. It runs a per-file **parse probe** (surfaces "did not fully
parse" so a structural miss can't look clean), emits unified **JSON + SARIF**, exits **2** on any
hard-fail (sf-05) for a CI gate, and **degrades to grep-only with a notice** if ast-grep is
unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only LOCATES —
always READ each hit in full before reporting (step 3), and read the `.entitlements`/`Info.plist`
by hand (the lint is `*.swift`-only). The thin `scripts/sandbox-lint.sh` is a pointer to this runner.
Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
