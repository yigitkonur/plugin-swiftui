# Reference — @Model Shape & Relationships (sd-01 … sd-05)

The five ways a `@Model` *definition* goes wrong. Every one **compiles clean** — SwiftData is a macro
façade over Core Data, so the Swift-language semantics the LLM reasons about are silently overridden.
This is the spine the other references cite. Floor *values* are not restated here — they live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. Get the canonical ✅ shape from
`swiftui-ctx`, not from memory (see each fix below).

**As of:** 2026-06-07 · macOS 14+ · Xcode 26 SDK.

---

## Why AI gets this wrong

The model reasons in Swift: `let` is immutable, a non-optional is non-optional, `init` assigns stored
properties. The Core Data machinery underneath breaks all three at runtime, and **the compiler stays
silent** — so a build pass proves nothing. Apple's own samples are the seed: the first SwiftData sample
ships a `@Model` with **no initializer** and a **non-compiling `@Relationship(.cascade)`**. AI copies
both. The auditor's job is to be the analyst the compiler refuses to be.

---

## sd-01 — `let` on a bidirectional relationship → runtime cast crash

SwiftData presumes every relationship is **mutable** and writes it through a
`ReferenceWritableKeyPath`. A `let` can't be written outside `init`, so the write fails — but **only at
runtime**, with an opaque cast crash. Every member that bidirectionally references another `@Model`
class **must** be `var`, regardless of intended semantics.

❌ `let` on a relationship — no warning, then a runtime crash:
```swift
@Model final class House {
    @Relationship(deleteRule: .cascade, inverse: \Floor.house)
    let floors: [Floor] = []        // ❌ let → 💣 at runtime, never at compile
}
// crash: "Could not cast value of type 'Swift.KeyPath<House, Array<Floor>>'
//         to 'Swift.ReferenceWritableKeyPath<…>'."
```
✅ relationships are always `var`, defaulted:
```swift
@Model final class House {                              // macOS 14+
    @Relationship(deleteRule: .cascade, inverse: \Floor.house)
    var floors: [Floor] = []        // ✅ var, even if you think of it as constant
}
```
**Detection:** ast-grep `sd-01` (a `property_declaration` whose `value_binding_pattern` is `let` AND
whose `modifiers` hold a `@Relationship` attribute — the two sit on separate lines, so grep can't bind
them). Severity **hard-fail**, `fix_mode: flag-only` (changing `let`→`var` is mechanical but may force
an `init` rewrite — see sd-02 — so the dev applies it).

## sd-02 — relationship assigned in `init` → child FK saved NULL → empty on relaunch

No compile or runtime error. Everything works until you Quit and relaunch — then the relationship is
empty, because the in-`init` assignment bypasses SwiftData's hooks and the child rows' foreign key back
to the parent is saved as `NULL`. **Never assign a relationship in `init`.** You may `append` to it
inside `init`, or assign it *outside* `init`.

❌ direct assignment in `init`:
```swift
init(floors: [Floor]) {
    self.floors = floors        // ❌ bypasses hooks → child FK NULL → empty on relaunch
}
```
✅ default to `[]`, then `append`:
```swift
var floors: [Floor] = []
init(floors: [Floor]) {
    self.floors.append(contentsOf: floors)   // ✅ append in init, or assign OUTSIDE init
}
```
**Detection:** ast-grep `sd-02` (a `self.X = Y` `assignment` inside a `function_body` — the init-scope
containment grep can't express; `self.floors.append(...)` is a call, not an assignment, so it is
correctly excluded). The agent READS to confirm `X` is a relationship, not a value property like
`self.name`. Severity **hard-fail**, `fix_mode: flag-only`.

## sd-03 — `@Model` with no `init` → uninitializable (Apple's incomplete sample)

Apple's very first SwiftData sample omits the initializer, so the class can't be constructed. Always
write a full `@Model` with an explicit `init`.

❌ no `init` (Apple's incomplete first sample):
```swift
@Model class Trip {                 // ❌ no init — can't be constructed
    var name: String
}
```
✅ explicit `init`:
```swift
@Model final class Trip {                               // macOS 14+
    var name: String
    init(name: String) { self.name = name }   // ✅ Apple omits this — you must write it
}
```
**Detection:** grep `sd-03` locates `@Model … class`; the agent READS the body to confirm stored
properties exist with no `init(`. Severity **warning**, `fix_mode: flag-only`.

## sd-04 — `@Relationship(.cascade)` positional → compile-time TYPE ERROR (the one auto-fix)

`.cascade` is a `Schema.Relationship.DeleteRule`, but the macro's first variadic parameter is a
`Schema.Relationship.Option` (whose only case is `.unique`), so the types don't match — it **does not
compile**. Apple's *current* docs still ship the broken form, which is why AI keeps copying it. The fix
is the named argument.

❌ `@Relationship(.cascade) var stops: [Stop]?`  → won't compile.
✅ `@Relationship(deleteRule: .cascade, inverse: \Stop.trip) var stops: [Stop] = []`

**Detection:** grep `sd-04` (`@Relationship\([[:space:]]*\.` — a positional first arg). Severity
**hard-fail**, `fix_mode: auto` — the single mechanical fix in this skill: insert `deleteRule: ` before
the leading `.`. Apply only under the fix-safety protocol.

## sd-05 — non-optional to-one relationship → implicitly-unwrapped nil-crash trap

A non-optional, `@Model`-class-typed to-one property (`var owner: Person`, not `Person?`) is a silent
trap: SwiftData stores the relationship with a **nullable** foreign key, so the property is really
`Person!`. Any read while the FK is `NULL` — mid-construction, mid-migration, after the inverse is
cleared — is a nil-unwrap crash with no compiler warning. Make to-one relationships **optional**
(`Person?`) unless you can prove the FK is never null.

❌ `var owner: Person`   ✅ `var owner: Person?`

**Detection:** grep `sd-05` locates `@Relationship`; the agent READS to confirm a to-one relationship
typed non-optional. Severity **warning**, `fix_mode: flag-only`.

---

## The canonical ✅ shape — get it from swiftui-ctx, not memory

When you write the `## Correct` block of a finding, the ✅ is **the corpus consensus shape + a
permalinked real example**, not a hand-written snippet:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Relationship --json   # consensus shape
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Model --json          # @Model usage + co_occurs_with
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart   # the real enclosing body
```
Put the `consensus` shape in `## Correct`; the `recommended.permalink` + the Sosumi `doc:` go in
`## Source`. (`Model` / `Relationship` co-occur in the corpus with `ModelContext`, `ModelConfiguration`,
`Query`, `Attribute`, `Transient` — confirming the canonical model-layer cluster.)

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://wadetregaskis.com/swiftdata-pitfalls/ | practitioner blog | high | relationships must be `var` not `let` ("irrespective of their actual intended semantics"); the `KeyPath`→`ReferenceWritableKeyPath` cast crash; "never assign the relationship in `init` … append … or assign outside of `init`" / "foreign key back to `House` is `NULL`"; "Apple never show a complete example of a `@Model` class"; `@Relationship(.cascade)` "doesn't even compile". Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftdata | primary-doc | high | `@Model`, `@Relationship(deleteRule:inverse:)`, `@Attribute` are macOS 14.0+. Confirmed 2026-06-07. |
| https://developer.apple.com/documentation/swiftdata/relationship | primary-doc | high | `@Relationship` macro signature: the first variadic slot is `Schema.Relationship.Option`, `deleteRule:` is a named parameter taking `Schema.Relationship.DeleteRule`. Confirmed 2026-06-07. |
