# Reference — Container Creation, Previews & Multi-Process (sd-06, sd-07, sd-12)

The `ModelContainer` lifecycle defects: a preview that crashes for lack of an in-memory container, a
`fatalError` that turns every recoverable container error into a hard crash, and the macOS-specific
multi-process container race. Floor *values* live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. Get the canonical container ✅ from
`swiftui-ctx` (see the bottom of this file).

**As of:** 2026-06-07 · macOS 14+ (the variadic `for:configurations:` init is macOS 15+) · Xcode 26 SDK.

---

## sd-06 — `#Preview` with no in-memory container → the canvas crashes

Constructing a `@Model` value (or touching `\.modelContext`) with no `ModelContainer` in scope crashes
the preview (*"failed to find a currently active container"*). Previews gate the whole edit loop, so
this is high-friction. Inject an **in-memory** container built from
`ModelConfiguration(isStoredInMemoryOnly: true)` and insert sample data so `@Query` finds something.
`try!` is acceptable **in a preview only**.

❌ model created with no container:
```swift
#Preview { EditingView(trip: Trip(name: "Test")) }   // ❌ no container → preview crash
```
✅ in-memory container + sample data:
```swift
#Preview {                                              // macOS 15+ (see init note)
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Trip.self, configurations: config) // try! OK in preview
    container.mainContext.insert(Trip(name: "Sample"))   // ✅ insert so @Query has data
    return EditingView(trip: Trip(name: "Sample")).modelContainer(container)
}
```
> **Init availability:** the variadic `ModelContainer(for:configurations:)` is **macOS 15.0+**. On a
> **macOS-14** target use `ModelContainer(for:migrationPlan:configurations:)` (which *is* macOS 14.0+)
> with `migrationPlan: nil`. `@Model`, `ModelContext`, `ModelConfiguration`, `isStoredInMemoryOnly` are
> all macOS 14+. Confirm every floor against `floors-master.md`.

**Detection:** grep `sd-06` locates `#Preview`; the agent READS to confirm it constructs a `@Model`
with no `ModelConfiguration(isStoredInMemoryOnly:` / `.modelContainer(` in scope. Severity **warning**,
`fix_mode: flag-only`. **Seam:** the preview-rig *mechanics* (sample factory, environment injection) are
owned by `audit-swiftui-previews` — emit `cross_ref: previews`; this skill owns the *model-design*
reason it crashes.

## sd-07 — `fatalError` (or `try!`) on `ModelContainer` creation → recoverable errors crash blind

`ModelContainer.init` throws for **recoverable, real-world reasons**: a schema/migration mismatch
(`Code=134504`, *"Cannot use staged migration with an unknown model version"*), no free disk space
(which produces *no* logs), or two processes migrating concurrently (`Code=134110` / `134100`). Apple's
getting-started code wraps this in `fatalError(error.localizedDescription)` — turning each into a hard
crash with no usable diagnostic (the `SwiftDataError` `_explanation` is typically `nil`). On macOS the
multi-process case is **routine** (app + menu-bar helper + widget on one container), so this is not a
corner case. Catch, classify, recover — or surface a real message.

❌ Apple's `fatalError`:
```swift
do { container = try ModelContainer(for: Trip.self) }
catch { fatalError(error.localizedDescription) }   // ❌ schema/disk/concurrent-migrate → blind crash
```
✅ classify and recover (never blind-`fatalError`):
```swift
do {
    // variadic `configurations:` init is macOS 15+; on macOS 14 add `migrationPlan: nil,`
    container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration())
} catch {
    // 134504 schema mismatch · no-free-space · 134110/134100 concurrent migration (common on macOS):
    // serialize multi-process opens with a lock file; check disk; clear+recreate on an unrecoverable
    // schema mismatch — or surface a real message. Do NOT fatalError(error).
}
```
**Detection:** grep `sd-07` (`fatalError\(` / `try!`); the agent READS to confirm it is on a non-preview
`ModelContainer` creation (`try!` inside a `#Preview` is fine — see sd-06). Severity **warning**,
`fix_mode: flag-only`.

## sd-12 — multi-process container with no lock-file serialization (macOS smell)

A sandboxed store lands in the app/group container (`…/Library/Application Support/default.store`).
Sharing it with a helper or widget needs a **group-container** entitlement, and those multi-process
opens are exactly what triggers the concurrent-migration crash class in sd-07. Serialize container
creation across processes with a lock file.

**Detection:** grep `sd-12` locates container sites; the agent READS the project for a second
container-opening target (a widget extension, a menu-bar helper) with no serialization. Severity
**advisory**, `fix_mode: flag-only`. **Seam:** the store-location / group-container **entitlement** is
owned by `audit-swiftui-sandbox-files` — emit `cross_ref: sandbox-files`.

---

## The canonical container ✅ — from swiftui-ctx (verified during this build)

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup ModelContainer --json` returns the dominant
real-world shape: **`(for, configurations)` at 64% consensus** (the variadic init; `(for)` is 9%). Its
`recommended` example (`introduced_macos: 14.0`, `doc: https://sosumi.ai/documentation/swiftui/modelcontainer`):

```swift
ModelContainer(for: schema, configurations: [modelConfiguration])
// fayazara/bucketdrop · BucketDropApp.swift#L29 · author_authority 9558 · 218★
// https://github.com/fayazara/bucketdrop/blob/92816bedcd2267022ede0c797d12e593f0997e4b/BucketDrop/BucketDropApp.swift#L29
```
`ModelContainer` `co_occurs_with` `Schema`, `ModelConfiguration`, `ModelContext`, `Query` — the real
container-layer cluster. Fetch the full enclosing body for `## Correct` with
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart`; put its permalink + the
Sosumi `doc:` in `## Source`.

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://scottdriggers.com/blog/swiftdata-modelcontainer-creation-crash/ | practitioner blog | high | "creating a `ModelContainer` can throw … they recommend crashing your app with `fatalError`"; the three causes (schema mismatch / no free disk space / concurrent migrators); `Code=134504`; `SwiftDataError(… _explanation: nil)`. Accessed 2026-06-06. |
| https://www.hackingwithswift.com/quick-start/swiftdata/how-to-use-swiftdata-in-swiftui-previews | practitioner tutorial (Paul Hudson, upd. Xcode 16.4) | high | "create a custom `ModelConfiguration` that stores data in memory only …" and "If you attempt to create a model object without first having created a container … your preview will crash." Accessed 2026-06-06. |
| https://www.reddit.com/r/swift/comments/145e4p7/swiftdata_crashes_in_preview/ | forum | medium | corroborates the preview-crash-without-container symptom. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftdata/modelcontainer | primary-doc | high | `init(for:configurations:)` (variadic) is macOS 15.0+; `init(for:migrationPlan:configurations:)` is macOS 14.0+ (pass `migrationPlan: nil`). Confirmed 2026-06-07. |
| https://github.com/fayazara/bucketdrop/blob/92816bedcd2267022ede0c797d12e593f0997e4b/BucketDrop/BucketDropApp.swift#L29 | corpus example (swiftui-ctx `recommended`) | high | the canonical `ModelContainer(for: schema, configurations: [modelConfiguration])` shape (64% consensus). Fetched 2026-06-07. |
