---
name: audit-swiftui-document-model
description: Audits a finished or in-progress macOS SwiftUI codebase for document-architecture defects and writes per-finding Markdown to swiftui-audits/. Use when the user has a DocumentGroup, FileDocument, or ReferenceFileDocument app and says saving is broken, edits do not persist, the document never gets dirty, autosave does nothing, the file type is not recognized, or open/save panels look wrong; when AI may have written @FocusedDocument, a class conforming to FileDocument, a ReferenceFileDocument with no snapshot, DocumentGroupLaunchScene on a Mac, NSDocument inside SwiftUI, or serialization pinned to the main actor; or when readableContentTypes / writableContentTypes / a custom UTType is misdeclared. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for SwiftData stores, not for plain file import/drag sandbox consent, not for window/scene plumbing, not for writing a new document app from scratch.
---

# Audit SwiftUI Document Model

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where certain, fix — every way the **document architecture** goes wrong:
the wrong document protocol (value `FileDocument` vs reference `ReferenceFileDocument`), a missing
`snapshot(contentType:)`, mis-declared content types / UTTypes, mishandled `FileWrapper` (data loss),
mutation that bypasses the document binding (no dirty-state / no autosave), serialization pinned to the
main actor, a phantom `@FocusedDocument`, `NSDocument` smuggled into a SwiftUI app, and
`DocumentGroupLaunchScene` used where it has **no macOS arm**. Findings are written to disk in the
toolkit's unified schema; this domain has **no mechanical auto-fix** (every correction is judgment-
gated), so findings are emitted `flag-only` with the ✅ shown. Never a from-scratch document-app generator.

The document API surface (`DocumentGroup`/`FileDocument`/`ReferenceFileDocument`/`FileDocumentConfiguration`)
is **macOS 11.0+** but thinly used, so AI frequently confuses the value vs reference split and invents
`@FocusedDocument`. Be suspicious wherever AI wrote document-app scaffolding.

## Boundary / seam note (stay in lane)

- **SwiftData (`@Model`/`ModelContainer`/`@Query`) persistence is out of scope** → `audit-swiftui-swiftdata`.
  This skill owns the *document* file format (`FileDocument`/`ReferenceFileDocument`), not the database.
- **Sandbox file *consent* — `fileImporter`/`fileExporter`/`NSOpenPanel` security-scoped bookmarks** belongs
  to `audit-swiftui-sandbox-files`. This skill owns the document *type* and its read/write; manual file IO
  inside a document app (doc-11) is flagged here and `cross_ref`'d there.
- **Scene plumbing — window sizing, `MenuBarExtra`, restoration** belongs to `audit-swiftui-scenes-windows`.
  The `DocumentGroupLaunchScene` no-macOS-arm trap (doc-05) is flagged here and `cross_ref`'d there.
- **Serialization Sendable / actor-isolation correctness** is owned by `audit-swiftui-concurrency-safety`;
  this skill flags the *MainActor-pinned document* smell (doc-08) and `cross_ref`s it there.
- **Whether to bridge to AppKit at all** is `audit-swiftui-appkit-overuse`; `NSDocument` in a SwiftUI app
  (doc-04) is flagged here and `cross_ref`'d there.

## The document-model design rules (non-negotiable)

1. **Value vs reference is a type decision, not a style.** A small, snapshot-serializable model →
   `struct: FileDocument` (SwiftUI copies a value to write). A large/graph/incrementally-mutated model →
   `final class: ReferenceFileDocument` (reference semantics + `snapshot(contentType:)`). A **class
   conforming to `FileDocument`** (doc-02) defeats the value contract; a `ReferenceFileDocument` without
   `snapshot(contentType:)` (doc-03) does not compile / loses the write.
2. **All edits flow through the document binding.** Mutate via the `$document` binding from
   `FileDocumentConfiguration` (or the `@ObservableObject`/`@Observable` reference document) so SwiftUI
   marks the scene dirty and autosaves. Mutating a copy / `configuration.document` directly (doc-10) means
   no dirty-state and silent data loss.
3. **Declare every content type you read or write.** `readableContentTypes` / `writableContentTypes` must
   be real `UTType`s, and any custom UTI must be exported/imported in `Info.plist` (doc-06); an editable
   document that omits `writableContentTypes` is read-only by accident (doc-07).
4. **Don't serialize on the main actor.** Apple: *"Don't perform serialization on MainActor."* A document
   type annotated `@MainActor` (doc-08) drags `init(configuration:)` / `fileWrapper(...)` onto the main
   thread and blocks the UI on every save.

Full reasoning + the value/reference decision table: `references/file-document-model.md`.

## Defect index (doc-01 … doc-12)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break / never-correct),
**warning** (compiles but unsound), **advisory** (judgment / perf). All findings are **`flag` (flag-only)**
— document architecture has no mechanical single-answer fix; show the ✅, the dev applies it.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| doc-01 | `@FocusedDocument` — phantom property wrapper (does not exist) | hard-fail | flag | `document-api-surface.md` |
| doc-02 | a **class** conforming to value-type `FileDocument` (use `ReferenceFileDocument`) | warning | flag | `file-document-model.md` |
| doc-03 | `: ReferenceFileDocument` with **no** `func snapshot(contentType:)` | hard-fail | flag | `file-document-model.md` |
| doc-04 | `NSDocument` / `NSDocumentController` inside a SwiftUI app | warning | flag | `document-scene.md` |
| doc-05 | `DocumentGroupLaunchScene` — has **no macOS arm** | hard-fail | flag | `document-scene.md` |
| doc-06 | `UTType(exportedAs:` / `importedAs:` not declared in `Info.plist` | warning | flag | `content-types-utis.md` |
| doc-07 | `readableContentTypes` set, `writableContentTypes` omitted on an editable doc | warning | flag | `content-types-utis.md` |
| doc-08 | `@MainActor` on the document type → serialization on the main actor | warning | flag | `file-document-model.md` |
| doc-09 | `FileWrapper.regularFileContents` force-unwrapped / un-guarded → data loss | warning | flag | `file-document-model.md` |
| doc-10 | `configuration.document` mutated directly (not via the `$document` binding) | warning | flag | `file-document-model.md` |
| doc-11 | `FileManager` / `Data(contentsOf:)` / `NSSavePanel` manual IO in a document app | advisory | flag | `document-scene.md` |
| doc-12 | `ReferenceFileDocument` app with no `@Environment(\.undoManager)` undo wiring | advisory | flag | `file-document-model.md` |

doc-10 has **no clean lint tell** (mutation-through-binding is semantic) — `configuration.document` is a
*locator* hint only; the real call is READ-by-hand at step 3. doc-03/doc-12 share the `ReferenceFileDocument`
grep locator and split in DETECT.

## The real API, at a glance

**Real (exist on macOS):** `DocumentGroup(newDocument:)` / `(viewing:)` / `(editing:migrationPlan:)` (macOS 14.0+),
`FileDocument` (a **struct** protocol), `ReferenceFileDocument` (a **class** + `Sendable` protocol, requires
`snapshot(contentType:)` + `fileWrapper(snapshot:configuration:)`), `FileDocumentConfiguration` (gives the
`$document` **binding** + `fileURL` + `isEditable`), `ReferenceFileDocumentConfiguration`,
`static readableContentTypes` / `writableContentTypes: [UTType]`, `init(configuration:)`,
`fileWrapper(configuration:)` / `fileWrapper(snapshot:configuration:)`, `FileWrapper`, `UTType(exportedAs:)` / `(importedAs:)`,
`@Environment(\.undoManager)`. **`DocumentGroupLaunchScene` is iOS/iPadOS-only — NO macOS arm.**

**Hallucinated / wrong:** `@FocusedDocument` (**not a real symbol** → custom `FocusedValues` `@Entry` key +
`@FocusedValue(\.focusedDocument)`); a **`class … : FileDocument`** (value protocol on a reference type);
`NSDocument` in a SwiftUI lifecycle.

Allow-list, signatures, and the `@FocusedDocument` → custom-key rewrite: `references/document-api-surface.md`.
Floor *values* are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the
canonical invented-name list (incl. `@FocusedDocument`) is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate them.

## Grounded ✅ — the canonical document-app shape (real code, not a placeholder)

The `## Correct` block on every finding is the **swiftui-ctx consensus shape** backed by a real macOS
example — never a hand-invented snippet. From `swiftui-ctx lookup DocumentGroup --json` (introduced macOS
11.0; corpus `repo_count: 33`): consensus `(newDocument)` **77%**, `(viewing)` 8%, `(editing,migrationPlan)`
5%, `(newDocument,editor)` 3%; `co_occurs_with` = `focusedSceneValue`/`focusedValue`/`FocusedValue`/
`commandsRemoved`/`inspector` (the real focused-document wiring — not `@FocusedDocument`). The `recommended`
permalinked example (`ex_91cff38b97`, `RobertoMachorro/Moped`, min macOS 12) fetched via
`swiftui-ctx file ex_91cff38b97 --smart`:

```swift
// ✅ canonical DocumentGroup — Moped/MopedApp.swift L27-44 (verbatim from the practice corpus)
var body: some Scene {
    DocumentGroup(
        newDocument: { MopedDocument() },
        editor: { file in
            EditorView(document: file.document)                 // edits flow through the configuration (doc-10)
                .onChange(of: file.fileURL, initial: true) { _, newURL in
                    file.document.fileURL = newURL
                }
        }
    )
    .commands { MopedCommands() }
    Settings { PreferencesView(preferences: Preferences.userShared) }
}
```

- **Source (canonical example):** `https://github.com/RobertoMachorro/Moped/blob/5b109e33c83d38456a787115ec49fc28ced2bebe/Moped/MopedApp.swift#L28`
- **Spec (`doc:`):** `https://sosumi.ai/documentation/swiftui/documentgroup`

Step 7 (FIX) regenerates this same trio (consensus shape + `--smart` permalink + Sosumi `doc:`) for the
specific finding's API; the snippet above is the worked instance for `DocumentGroup`.

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Confirm this is a **document app** (a `DocumentGroup`
   scene in the `App` body) and read the deployment target (`project.pbxproj`
   `MACOSX_DEPLOYMENT_TARGET` / `Package.swift` `platforms:`). Note whether the model is value- or
   reference-shaped — it drives the doc-02/doc-03 split.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-document-model --dir <sources> --json /tmp/doc.json --sarif /tmp/doc.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the missing-`snapshot` and MainActor-pinned-document rules grep can't express),
   plus a per-file **parse probe**, and emits unified JSON + SARIF. **Read its `parse_warnings`** — a
   flagged file did not fully parse, so a structural miss can't masquerade as clean; READ those by hand.
   The runner only LOCATES — never treat a hit as a finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. The
   value/reference choice, the binding flow, container conformance, and `Info.plist` UTI declarations are
   invisible to grep. Build a per-file inventory: each document type + its kind (value/reference) + its
   content types + how edits reach it (binding vs copy) + its serialization actor.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a `@FocusedDocument`, a `class … : FileDocument`, a `ReferenceFileDocument` with no
   `snapshot`, a `DocumentGroupLaunchScene` on a Mac target).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol you're unsure exists, a floor you can't place, a
   serialization-actor claim), run **both** evidence sources. (a) **Practice** — `bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (and `swiftui-ctx deprecated <api>` for a
   currency rule): read its `consensus` (the canonical shape), `deprecated`+`replacement`, `recommended`
   permalink, `introduced_macos`, and `co_occurs_with`; a `lookup` returning **not_found** (`ok:false`,
   `error.class: not_found` + a did-you-mean `suggestion`) corroborates a hallucination finding — no shipping
   Mac app uses the symbol (this is how `@FocusedDocument` resolves). (b) **Spec** — confirm via **Sosumi**:
   `curl -sSL https://sosumi.ai/<apple-path>` using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi `doc:`
   floor. The CLI contract is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote
   with the citation or discard.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit a `cross_ref` on shared-seam findings (doc-04 → appkit-overuse, doc-05 → scenes-windows,
   doc-08 → concurrency-safety, doc-11 → sandbox-files). Write the run's `_index.md`.
7. **FIX.** This domain is **`fix_mode: flag-only` end-to-end** — no auto-fix (document type / binding /
   UTI changes are never a mechanical single answer). Under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`) leave every finding `open` with the
   ✅ in `## Correct`. The ✅ is **not a hand-written snippet** — it is the swiftui-ctx **consensus shape**
   put in `## Correct`, backed by a real macOS example fetched with `bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink (plus the
   Sosumi `doc:`) goes in `## Source` as the canonical example. The canonical `DocumentGroup` shape is
   `(newDocument:editor:)` (per `swiftui-ctx lookup DocumentGroup`, `recommended` =
   `ex_91cff38b97` → `RobertoMachorro/Moped` `MopedApp.swift#L28`).
8. **DOUBLE-CHECK.** Re-grep each touched file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves and still says the floor it claimed. If a
   change introduced a new tell (e.g. switching to `ReferenceFileDocument` now needs a `snapshot`), loop
   that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can become
a finding — never emit a speculative finding. There is **no auto-fix** in this domain; everything is
`fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/document-model/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/document-model/_index.md`.
- `domain: document-model`. Frontmatter is the canonical schema; `fix_mode` is `flag-only` for every
  finding. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date (fetched
  via Sosumi) or `verify against Xcode 26 SDK`.
- **Additive field** (catalogued, this domain only): `doc_kind` = `FileDocument` | `ReferenceFileDocument`
  | `DocumentGroup` | `n/a` — the document shape the finding concerns. Add it alongside the canonical
  frontmatter; nothing else.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `phantom-api/` | a name doesn't exist — `@FocusedDocument` (doc-01) |
| `value-vs-reference/` | the wrong document protocol — class-on-`FileDocument`, missing `snapshot` (doc-02, doc-03) |
| `scene-architecture/` | `NSDocument` in SwiftUI, or `DocumentGroupLaunchScene` with no macOS arm (doc-04, doc-05) |
| `content-types/` | a `UTType` undeclared in `Info.plist`, or missing `writableContentTypes` (doc-06, doc-07) |
| `serialization-safety/` | serialization on the main actor, or a force-unwrapped `FileWrapper` (doc-08, doc-09) |
| `dirty-state-autosave/` | edits bypass the `$document` binding (doc-10) |
| `manual-io/` | hand-rolled file IO inside a document app (doc-11) |
| `undo/` | a reference document with no `UndoManager` wiring (doc-12) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/document-model/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a hard
requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/document-api-surface.md` | a name/existence question — the real allow-list + the `@FocusedDocument` → custom-`FocusedValues`-key rewrite (doc-01) |
| `references/file-document-model.md` | the value/reference decision, `snapshot`, `FileWrapper`, binding-mutation, MainActor serialization, undo (doc-02/03/08/09/10/12) |
| `references/content-types-utis.md` | `readableContentTypes`/`writableContentTypes`, custom `UTType`, the `Info.plist` declaration (doc-06/07) |
| `references/document-scene.md` | `DocumentGroup` vs `NSDocument`, `DocumentGroupLaunchScene` no-macOS-arm, manual IO (doc-04/05/11) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list (incl. `@FocusedDocument`) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule + wrong-arm/no-arm failure (doc-05) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys (incl. additive `doc_kind`) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the fix-safety protocol (step 7 — all flag-only here) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (doc-04/05/08/11) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-document-model --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this skill's
declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`, doc-01/02/04/05/06/07/09/10/11/12) +
**tier-2 ast-grep** structural rules (`lint/ast-grep/*.yml` — doc-03 `ReferenceFileDocument`-missing-`snapshot`,
doc-08 `@MainActor`-pinned document type) that grep cannot express. It runs a per-file **parse probe**
(surfaces "did not fully parse" so a structural miss can't look clean), emits unified **JSON + SARIF**, exits
**2** on any hard-fail (doc-01/03/04/05) for a CI gate, and **degrades to grep-only with a notice** if
ast-grep is unreachable (`npx --package @ast-grep/cli ast-grep`; faster: `brew install ast-grep`). It only
LOCATES — always READ each hit in full before reporting (step 3). The thin `scripts/doc-lint.sh` is a
pointer to this runner. Engine + rule-file format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
