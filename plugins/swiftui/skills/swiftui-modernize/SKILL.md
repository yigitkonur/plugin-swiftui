---
name: swiftui-modernize
description: Modernize existing macOS SwiftUI code by replacing deprecated APIs with verified current production patterns.
license: MIT
---

## Bundled resource root

Let `<swiftui-plugin-root>` be the absolute plugin directory two levels above this `SKILL.md`. Resolve that path before running commands or opening shared references. When these instructions say `swiftui-ctx`, invoke `<swiftui-plugin-root>/scripts/swiftui-ctx`; do not assume the command is on `PATH`.

# swiftui-modernize — fix deprecated/stale SwiftUI

Operates on **code that already exists**: it finds deprecated and outdated SwiftUI and migrates it to what
shipping macOS apps use today, using `swiftui-ctx` as the source of truth. (Writing new code → `swiftui-examples`.
Scaffolding a whole pattern → `macos-app-patterns`.)

`swiftui-ctx` = `<swiftui-plugin-root>/scripts/swiftui-ctx` (or `swiftui-ctx` on PATH). It self-builds + self-locates the catalog.

## The rule
Do **not** guess whether an API is current. **Check it.** A call that compiles can still be deprecated — the catalog
knows (it's flagged across 200–1,100 real repos). Announce: *"Using swiftui-modernize to verify against production."*

## Workflow
1. **Find candidates.** Scan the target file/diff for SwiftUI symbols (modifiers, types, wrappers).
2. **Check each.** `swiftui-ctx deprecated <api>` → it returns `deprecated: true/false`, the `replacement`, and a note.
   Run `swiftui-ctx deprecated` (no arg) once to see the full deprecated-in-the-wild list to scan against.
3. **Get the real migration.** For each deprecated hit, `swiftui-ctx lookup <replacement>` → the modern idiom +
   `file --smart` a real example, then rewrite.
4. **Report**, don't silently change: list each `old → new` with the permalink evidence, then apply.

The common migrations are tabulated in `references/migrations.md` (read it for the fast path).

## Behavioral rules
- **Never leave a deprecated API in place** once flagged — migrate it or call out why you can't.
- Prefer the `replacement` the tool gives; confirm the new call's shape via `lookup <replacement>` `consensus`.
- Modernity isn't only deprecation: prefer `@Observable` over `ObservableObject`, `NavigationStack/Split` over
  `NavigationView`, the `Settings` scene + `MenuBarExtra` for macOS — `swiftui-ctx lookup` shows current adoption.
- Pair with **sosumi.ai** (the `doc:` link) to confirm the replacement's signature before rewriting.

## Errors → actions
`3` not-found → `swiftui-ctx search "<broader>"`. `5` no catalog → STOP, tell the user, don't fabricate a migration.

## References
| File | Read when |
|---|---|
| `references/migrations.md` | You want the common deprecated→modern macOS SwiftUI migration table up front. |
