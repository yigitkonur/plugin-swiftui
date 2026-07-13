---
name: swiftui-review
description: Review SwiftUI code or a diff for deprecated and non-idiomatic macOS usage. Use only when explicitly requested with $swiftui-review.
---

# SwiftUI review

## Bundled resource root

Let `<swiftui-plugin-root>` be the absolute plugin directory two levels above this `SKILL.md`. Resolve that path before running commands. Invoke the CLI as `<swiftui-plugin-root>/scripts/swiftui-ctx`; do not assume `swiftui-ctx` is on `PATH`.

1. Review the path named by the user, or changed Swift files when no path is given.
2. Run `"<swiftui-plugin-root>/scripts/swiftui-ctx" deprecated --json` once.
3. For each relevant SwiftUI symbol, run `deprecated <api> --json` and `lookup <api> --json`.
4. Use `file <recommended.id> --smart` where a real enclosing example will resolve uncertainty.
5. Report findings as `path:line — issue → fix`, ordered high for deprecated APIs, medium for outdated or non-consensus shapes, and low for nits. Include the returned permalink evidence.

Do not rewrite code unless the user asks for fixes. If the catalog cannot verify a claim, say so instead of guessing.
