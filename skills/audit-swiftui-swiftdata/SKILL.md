---
name: audit-swiftui-swiftdata
description: Audits a finished or in-progress macOS SwiftUI codebase for SwiftData persistence defects on macOS 14+ and writes per-finding Markdown to swiftui-audits/. Use when the user says SwiftData crashes, data vanishes on relaunch, the preview canvas crashes, or a relationship is empty after Quit; when they ask to verify a @Model class, @Relationship, ModelContainer, ModelContext, @Query, @ModelActor, ModelConfiguration, or a SwiftData migration; when a relationship is declared let, a relationship is assigned in init, an init is missing, @Relationship(.cascade) is written positionally, a to-one relationship is non-optional, a ModelContainer is wrapped in fatalError, a @Model is mutated off the main context, save() is missing, or a @Model subclass targets macOS 26. AUDIT-ONLY, macOS-only, SwiftUI-only. Not for Core Data NSManagedObject, not for generic concurrency outside SwiftData, not for the blanket availability sweep, not for writing a new data model from scratch.
---

# Audit SwiftUI SwiftData

**AUDIT-ONLY · macOS-only · SwiftUI-only.** Run this on a *finished or in-progress* macOS SwiftUI
project to detect — and where mechanical, fix — every way SwiftData goes wrong on a macOS 14+ target:
`let` on a relationship, a relationship assigned in `init`, a missing initializer, the positional
`@Relationship(.cascade)` type error, a non-optional to-one relationship, a container-crashing
preview, a `fatalError` on `ModelContainer`, off-actor `@Model` mutation, a missing `save()`, an
unordered relationship array, and an ungated macOS-26 `@Model` subclass. Findings are written to disk
in the toolkit's unified schema; the one mechanical defect (`@Relationship(.cascade)`) is fixed under
the fix-safety protocol. This is never a from-scratch data-model generator.

SwiftData is a **thin macro façade over Core Data**: the *Swift-language* semantics an LLM reasons
about (`let` is immutable, a non-optional is non-optional, `init` assigns stored properties) are
silently violated by the Core Data machinery underneath, and **almost none of the violations produce a
compiler diagnostic**. The code compiles, looks idiomatic, then crashes at runtime, loses data on
relaunch, or kills the preview canvas. Apple's own samples make it worse — they show no `@Model`
initializer, ship a non-compiling `@Relationship(.cascade)`, and recommend `fatalError` on the
container. **Be suspicious wherever the compiler stayed silent.**

## Boundary / seam note (stay in lane)

- **Core Data `NSManagedObject` / `NSPersistentContainer`** is out of scope. If audited code uses raw
  Core Data, note it in one line — do not audit Core Data here.
- **The concurrency isolation hazard itself** (`@Model` is non-`Sendable`, `@MainActor` boundaries)
  belongs to `audit-swiftui-concurrency-safety`, which *flags the race*; **this skill prescribes the
  `@ModelActor` fix shape**. On an off-context-mutation site, emit a `cross_ref: concurrency-safety`
  (per `cross-ref-graph.md`) — concurrency owns the race, swiftdata owns the data-correct fix.
- **Preview-container construction mechanics** (in-memory container, sample factory) are owned by
  `audit-swiftui-previews`; this skill detects the *model-design* reason a preview crashes (sd-06) and
  routes preview-rig depth there with a `cross_ref: previews`.
- **Store location / group-container entitlement** is owned by `audit-swiftui-sandbox-files`; this
  skill flags the *multi-process container* smell (sd-12) and cross_refs it.
- **The blanket "is every OS-floored API gated" sweep** belongs to `audit-swiftui-availability-gating`;
  this skill owns the macOS-26 `@Model`-inheritance gate (sd-11) in depth and defers other gating there.

## The eight invariants (non-negotiable)

1. **Relationships are always `var`, defaulted** — `let` on a bidirectional `@Relationship` compiles
   clean, then crashes at runtime (an opaque `KeyPath`→`ReferenceWritableKeyPath` cast failure).
2. **Never assign a relationship in `init`** — `self.floors = floors` bypasses SwiftData's hooks, the
   child FK saves `NULL`, and the relationship is empty on relaunch. `append(contentsOf:)` is fine.
3. **Every `@Model` needs an explicit `init`**, and `@Relationship(deleteRule:)` is **named** — the
   positional `@Relationship(.cascade)` from Apple's docs is a compile-time type error.
4. **To-one relationships are optional** (`Person?`) — a non-optional to-one is an implicitly-unwrapped
   trap: the FK is nullable, so a read while it is `NULL` is a nil-unwrap crash.
5. **Previews need an in-memory container** (`ModelConfiguration(isStoredInMemoryOnly: true)`) with
   sample data inserted, or the canvas crashes ("failed to find a currently active container").
6. **Never `fatalError` on `ModelContainer` creation** — its `init` throws for *recoverable* reasons
   (schema mismatch, no disk, concurrent migration); classify and recover.
7. **Mutate `@Model` off-main only inside a `@ModelActor`**; hand off `PersistentIdentifier`
   (`Sendable`), never the non-`Sendable` `@Model`.
8. **Call `try modelContext.save()` explicitly** — auto-save is tens of seconds and a fast Quit /
   window close drops it. Order reads with `@Query(sort:)`; relationship-array order is not persisted.

Full ❌→✅ for each: the routed `references/*.md` below.

## Defect index (sd-01 … sd-12)

`id · tell · severity · fix · open reference`. Severities: **hard-fail** (build break or runtime
crash / data loss — never correct), **warning** (compiles but wrong), **advisory** (judgment / perf).
`auto` = mechanical single-answer fix; `flag` = show the ✅, dev applies.

| id | One-line tell | Sev | Fix | Reference |
|---|---|---|---|---|
| sd-01 | `let` on a bidirectional `@Relationship` property (runtime cast crash) | hard-fail | flag | `model-shape-and-relationships.md` |
| sd-02 | a relationship assigned in `init` (`self.x = y`) → child FK saved `NULL`, empty on relaunch | hard-fail | flag | `model-shape-and-relationships.md` |
| sd-03 | `@Model` class with stored properties but no `init(` (Apple's incomplete sample) | warning | flag | `model-shape-and-relationships.md` |
| sd-04 | `@Relationship(.cascade)` positional (`.cascade` is a `DeleteRule`, slot wants `.Option`) → type error | hard-fail | auto | `model-shape-and-relationships.md` |
| sd-05 | non-optional to-one `@Model` relationship (`var owner: Person`) → implicitly-unwrapped nil-crash | warning | flag | `model-shape-and-relationships.md` |
| sd-06 | `#Preview` constructs a `@Model` with no in-memory `ModelContainer` → canvas crash | warning | flag | `container-and-preview.md` |
| sd-07 | `fatalError` (or `try!`) on `ModelContainer` creation outside a preview → recoverable error crashes blind | warning | flag | `container-and-preview.md` |
| sd-08 | indexing a relationship array (`.floors[0]`) / `ForEach` over a relationship with no `@Query(sort:)` | warning | flag | `query-and-persistence.md` |
| sd-09 | off-actor `@Model` mutation in `Task`/`Task.detached`/`DispatchQueue` with no `@ModelActor` | hard-fail | flag | `concurrency-and-saving.md` |
| sd-10 | a mutation path with no `try modelContext.save()` (silent loss on Quit / window close) | advisory | flag | `concurrency-and-saving.md` |
| sd-11 | a `@Model` subclass ungated / its types not all registered (macOS-26 inheritance) | warning | flag | `query-and-persistence.md` |
| sd-12 | one container opened by app + widget/menu-bar helper with no lock-file serialization | advisory | flag | `container-and-preview.md` |

**Two claims are corpus-thin — carry with care.** `@ModelActor` and the off-context race (sd-09) are
real but **sparse in the practice corpus** (`swiftui-ctx lookup ModelActor` returns not-found — that is
`low_corpus`, **not** a hallucination; the symbol is `macOS 14.0+` per `floors-master.md`). Lean on
Sosumi for sd-09. The auto-save-window dropping a fast-Quit save (sd-10) is observed practitioner
behavior, not a documented guarantee — carry sd-10 as `advisory` with `source: verify against Xcode 26
SDK` unless Sosumi confirms a `save()` requirement.

## The real API, at a glance

**Real (exist on macOS 14.0+):** `@Model`, `ModelContext`, `ModelConfiguration(isStoredInMemoryOnly:)`,
`@Relationship(deleteRule:inverse:)`, `@Attribute`, `@Query`, `@Query(sort:)`, `.modelContainer(for:)`,
`@ModelActor` (macro: converts a Swift `actor` to conform to `protocol ModelActor`, giving it its own `ModelContext`), `PersistentIdentifier` (the `Sendable`
hand-off; macOS 13.0+). **macOS 15.0+:** the variadic `ModelContainer(for:configurations:)` (on a macOS-14
target use `ModelContainer(for:migrationPlan:configurations:)` with `migrationPlan: nil`), `#Index`,
`#Unique`, the history API (`HistoryDescriptor`, `fetchHistory(_:)`). **macOS 26.0+:** `@Model` class
inheritance (every subclass needs `@available(macOS 26, *)`; register base + every subclass in the
container) and `HistoryDescriptor.sortBy`.

**The type error (compiles never):** `@Relationship(.cascade)` — `.cascade` is a
`Schema.Relationship.DeleteRule`, the first variadic slot is a `Schema.Relationship.Option` (only
`.unique`). Fix: the named `@Relationship(deleteRule: .cascade)`.

Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate. The canonical
invented-name list is `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`. Signatures
and the full ❌→✅ rewrites: the routed `references/*.md`.

### ✅ Correct — the container shape, grounded in real shipping code

The corpus consensus for `ModelContainer` construction is **`(for, configurations)` at 64%**
(`swiftui-ctx lookup ModelContainer`; next at 9% is bare `(for)`). The canonical real example
(author-authority 9558, 218★) is `fayazara/bucketdrop`:

```swift
// https://github.com/fayazara/bucketdrop/blob/92816bedcd2267022ede0c797d12e593f0997e4b/BucketDrop/BucketDropApp.swift#L29
let schema = Schema([UploadedFile.self])
let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
do {
    return try ModelContainer(for: schema, configurations: [modelConfiguration])
} catch {
    // ❌ shipping code here writes `fatalError(...)` — that is exactly sd-07.
    // ✅ classify and recover: a schema mismatch / no-disk / concurrent-migration error is recoverable.
    throw error
}
```

The construction shape `try ModelContainer(for: schema, configurations: [config])` is the grounded
✅; the **same real file's `catch` proves sd-07 in the wild** (it `fatalError`s a recoverable throw).
Source of record: the permalink above + the Sosumi doc `doc:` link
`https://sosumi.ai/documentation/swiftdata/modelcontainer` (the variadic `(for:configurations:)`
overload is **macOS 15.0+** per `floors-master.md`; on a macOS-14 floor use the
`(for:migrationPlan:configurations:)` overload with `migrationPlan: nil`).

## The 8-step audit workflow (execute verbatim)

1. **ORIENT.** `tree` / `find` the SwiftUI sources. Read the **deployment target**
   (`project.pbxproj` `MACOSX_DEPLOYMENT_TARGET`, or `Package.swift` `platforms:`). It is load-bearing:
   sd-11 fires only when the floor includes macOS 26 *and* a subclass is ungated; the variadic
   `ModelContainer(for:configurations:)` init needs macOS 15 (note the 14 alternative). Record it.
2. **LOCATE.** Run the shared hybrid lint runner:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-swiftdata --dir <sources> --json /tmp/sd.json --sarif /tmp/sd.sarif`.
   It runs this skill's tier-1 grep tells (`lint/grep-tells.tsv`) + tier-2 structural ast-grep rules
   (`lint/ast-grep/*.yml` — the `let`-on-relationship, relationship-assigned-in-`init`, and
   `@Model`-subclass rules grep can't express), a per-file **parse probe**, and emits unified JSON +
   SARIF. **Read its `parse_warnings`** — a flagged file did not fully parse, so a structural miss
   can't masquerade as clean; READ those by hand. The runner only LOCATES — never treat a hit as a
   finding. Engine + rule-file format + degradation:
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
3. **READ.** Open every located file **in full** — never pattern-match-and-patch blind. Whether a
   relationship is bidirectional, whether an `init` exists, whether a `self.x =` assigns a relationship
   vs a value property, and whether a `Task` actually mutates a main-context object are all invisible
   to grep. Build a per-`@Model` inventory: each property's kind (value / to-one / to-many
   relationship), the `init`, the container site, the actor isolation, the save sites.
4. **DETECT.** Apply the index. Assign each candidate a **confidence**; report a finding **only at 100%
   certainty** (e.g. a `let` on a `@Relationship`, a positional `@Relationship(.cascade)`, a
   `fatalError` on `ModelContainer` in shipping code).
5. **VERIFY.** For anything ≤ ~70% confidence (a symbol/floor you can't place, a behavior claim), run
   **both** evidence sources. (a) **Practice** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx
   lookup <api> --json` (and `swiftui-ctx deprecated <api>` for a currency rule): read its `consensus`
   (the canonical shape — e.g. `ModelContainer` consensus is `(for, configurations)` at 64%),
   `recommended` permalink + `min_macos`, `introduced_macos`, `co_occurs_with`, and `low_corpus`. A
   `lookup` **exit 3** (not-found, with a did-you-mean `suggestion`) corroborates a hallucination — but
   for a known-sparse symbol (`ModelActor`) treat not-found as `low_corpus`, **not** a hallucination,
   and lean on Sosumi. (b) **Spec** — confirm via **Sosumi**: `curl -sSL https://sosumi.ai/<apple-path>`
   using `references/source-directory.md` for the path and
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` for the protocol (never `WebFetch`
   `developer.apple.com`). Cross-check `introduced_macos` against `floors-master.md` and the Sosumi
   `doc:` floor. The CLI contract is
   `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Promote with the citation or
   discard. Carry sd-10 (and any unprovable behavior claim) as `advisory` with `source: verify against
   Xcode 26 SDK`.
6. **REPORT.** Write each confirmed finding (output contract below). One finding per file, zero-padded,
   ordered. Emit a `cross_ref` on every shared-seam site (sd-09 → `concurrency-safety`; sd-06 →
   `previews`; sd-12 → `sandbox-files`). Write the run's `_index.md`.
7. **FIX.** Apply corrections under the fix-safety protocol
   (`${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md`): clean-tree gate, findings-first,
   **only `fix_mode: auto`** (sd-04 `@Relationship(.cascade)` → `@Relationship(deleteRule: .cascade)`),
   one conventional commit per finding citing its `rule_id`, never weaken a check. The ✅ "Correct" is
   **not a hand-written snippet** — it is the swiftui-ctx **consensus shape** put in `## Correct`,
   backed by a real macOS-era example fetched with
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart` whose GitHub permalink
   (plus the Sosumi `doc:`) goes in `## Source` as the canonical example. Leave `flag-only` findings
   `open` with that ✅ in `## Correct`.
8. **DOUBLE-CHECK.** Re-grep each fixed file to confirm the tell no longer matches; record the evidence
   in `## Fix applied?`. Re-confirm every citation still resolves and still says its floor. If a fix
   introduced a new tell (e.g. a `var` you added to a relationship now needs an `init` that `append`s,
   not assigns), loop that file back to DETECT.

## Confidence gating (load-bearing)

Report a finding **only at 100% certainty**. Anything ≤ ~70% goes to VERIFY (step 5) before it can
become a finding — never emit a speculative finding. The SwiftData trap is that *the compiler is
silent*, so the LLM is the only analyst that can tell a relationship from a value property and an
`append` from an assignment: READ before you report. Auto-fix only the one mechanical defect (sd-04);
everything else is `fix_mode: flag-only`.

## Output contract

Inherits the toolkit's unified contract (full schema + body sections + frontmatter keys:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` — do not restate it). Specialized for this
domain:

- Findings: `swiftui-audits/swiftdata/<context>/NN-slug.md` (one finding per file, zero-padded,
  ordered). Per-run index: `swiftui-audits/swiftdata/_index.md`.
- `domain: swiftdata`. Frontmatter is the canonical schema; `fix_mode` is `auto` for sd-04 only, else
  `flag-only`. `availability` reads from `floors-master.md`. `source` is an Apple URL + access date
  (fetched via Sosumi) or `verify against Xcode 26 SDK`. Emit `cross_ref` per the seam notes above.

**Starter `<context>` folders (file here when…):**

| `<context>` | File a finding here when… |
|---|---|
| `relationship-mutability/` | a relationship is `let`, or assigned in `init` (sd-01, sd-02) |
| `model-completeness/` | a `@Model` lacks an `init`, or `@Relationship(.cascade)` is positional (sd-03, sd-04) |
| `optionality-traps/` | a to-one relationship is non-optional (sd-05) |
| `container-lifecycle/` | a preview lacks an in-memory container, a container `fatalError`s, or a multi-process container is unserialized (sd-06, sd-07, sd-12) |
| `ordering-and-query/` | a relationship array is indexed / iterated unordered (sd-08) |
| `concurrency-and-saving/` | a `@Model` is mutated off-actor, or a mutation path omits `save()` (sd-09, sd-10) |
| `availability-gating/` | a `@Model` subclass is ungated or its types unregistered on a macOS-26 floor (sd-11) |

**New-folder rule:** *if a finding does not fit any existing context folder, create a new one under
`swiftui-audits/swiftdata/` with a lowercase-hyphen slug naming the sub-category, and note it in the
run's `_index.md`. Prefer an existing folder when the fit is reasonable; consistency across runs is a
hard requirement.* Two runs over the same code produce structurally identical trees.

## Reference routing

| File | Open when |
|---|---|
| `references/model-shape-and-relationships.md` | a `@Model` definition question — `let`-vs-`var`, init-assignment, missing init, positional `@Relationship`, to-one optionality (sd-01/02/03/04/05) |
| `references/container-and-preview.md` | `ModelContainer` creation, the `fatalError` trap, preview in-memory containers, multi-process serialization (sd-06/07/12) |
| `references/query-and-persistence.md` | `@Query` ordering, relationship-array order, and macOS-26 `@Model`-inheritance gating + registration (sd-08/11) |
| `references/concurrency-and-saving.md` | off-actor mutation, the `@ModelActor` fix shape, `PersistentIdentifier` hand-off, explicit `save()` and `ScenePhase`/window-close timing (sd-09/10) |
| `references/source-directory.md` | step VERIFY — the Apple/WWDC/practitioner source map fetched via Sosumi |
| `lint/grep-tells.tsv` + `lint/ast-grep/*.yml` | step LOCATE — this skill's declarative lint rule set fed to the shared runner (tier-1 grep tells + tier-2 structural ast-grep); edit here to tune detection |

**Shared toolkit references (point in, never restate):**

| Shared file | For |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` | every floor/availability value (the reconciled truth) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` | the canonical invented-name list |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` | the macOS-arm gating rule (sd-11 subclass gate) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` | the unified finding schema + frontmatter keys |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/fix-safety-protocol.md` | the 8-point fix-safety protocol (step 7) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md` | the Apple-doc spec fetch protocol (step 5 VERIFY) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` | the practice-corpus CLI contract — `lookup`/`deprecated`/`file --smart` for the consensus shape + permalinked example (steps 5 VERIFY · 7 FIX) |
| `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` | seam ownership + `cross_ref` targets (concurrency-safety · previews · sandbox-files) |

## Detection accelerator

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill audit-swiftui-swiftdata --dir <files-or-dir>
[--json out.json] [--sarif out.sarif]` — the toolkit's **one shared hybrid lint engine**, fed this
skill's declarative rules: **tier-1 grep tells** (`lint/grep-tells.tsv`,
sd-03/04/05/06/07/08/09/10/12 + a flat `let`-near-`Relationship` net) + **tier-2 ast-grep** structural
rules (`lint/ast-grep/*.yml` — sd-01 `let`-on-`@Relationship` across the attribute line, sd-02
relationship-assigned-in-`init` scope, sd-11 `@Model`-subclass inheritance) that grep cannot express.
It runs a per-file **parse probe** (surfaces "did not fully parse" so a structural miss can't look
clean), emits unified **JSON + SARIF**, exits **2** on any hard-fail (sd-04) for a CI gate,
and **degrades to grep-only with a notice** if ast-grep is unreachable (`npx --package @ast-grep/cli
ast-grep`; faster: `brew install ast-grep`). It only LOCATES — always READ each hit in full before
reporting (step 3). The thin `scripts/sd-lint.sh` is a pointer to this runner. Engine + rule-file
format + JSON/SARIF shape + safety rails:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md`.
