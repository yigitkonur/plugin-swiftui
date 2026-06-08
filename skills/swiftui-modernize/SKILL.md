---
name: swiftui-modernize
description: Audit and modernize EXISTING SwiftUI code on macOS — find deprecated APIs and migrate them to the current idiom, backed by real production examples. Use when asked to "modernize", "upgrade", "clean up", or "update" SwiftUI, to "remove deprecated APIs", when raising a deployment target, or when reviewing old SwiftUI for staleness. Drives the swiftui-ctx CLI (deprecated + lookup). Do NOT use for writing brand-new code from scratch (use swiftui-examples), scaffolding whole features (use macos-app-patterns), or non-SwiftUI Swift.
license: MIT
---

# swiftui-modernize — fix deprecated/stale SwiftUI

Operates on **code that already exists**: it finds deprecated and outdated SwiftUI and migrates it to what
shipping macOS apps use today, using `swiftui-ctx` as the source of truth. (Writing new code → `swiftui-examples`.
Scaffolding a whole pattern → `macos-app-patterns`.)

`swiftui-ctx` = `${CLAUDE_PLUGIN_ROOT}/bin/swiftui-ctx` (or `swiftui-ctx` on PATH). It self-builds + self-locates the catalog.

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
