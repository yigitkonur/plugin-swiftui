# Reference — Source Directory (VERIFY step)

The Apple/WWDC/practitioner source map for this domain, fetched via **Sosumi** (`curl -sSL
https://sosumi.ai/<apple-path>`; protocol in `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`
— never `WebFetch` `developer.apple.com`). Paired with the practice corpus via `swiftui-ctx lookup <api>
--json` (`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`). Use this to resolve a
≤70%-confidence finding in step 5.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## Apple primary docs (per defect)

| Defect | Apple path (prefix `https://developer.apple.com`) |
|---|---|
| doc-01 (`@FocusedDocument`) | `/documentation/swiftui/focusedvalues` · `/documentation/swiftui/focusedvalue` · `/documentation/swiftui/view/focusedscenevalue(_:_:)` |
| doc-02/03 (value vs reference) | `/documentation/swiftui/filedocument` · `/documentation/swiftui/referencefiledocument` · `/documentation/swiftui/referencefiledocument/snapshot(contenttype:)` |
| doc-04 (NSDocument) | `/documentation/swiftui/documentgroup` · `/documentation/appkit/nsdocument` |
| doc-05 (launch scene) | `/documentation/swiftui/documentgrouplaunchscene` |
| doc-06/07 (content types) | `/documentation/swiftui/filedocument/readablecontenttypes` · `/documentation/uniformtypeidentifiers/uttype` · `/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app` |
| doc-08 (MainActor serialization) | `/documentation/swiftui/building-a-document-based-app-with-swiftui` |
| doc-09 (FileWrapper) | `/documentation/foundation/filewrapper` |
| doc-10 (binding) | `/documentation/swiftui/filedocumentconfiguration` |
| doc-12 (undo) | `/documentation/swiftui/environmentvalues/undomanager` |

## WWDC

- WWDC20 — "Build document-based apps in SwiftUI" (`/videos/play/wwdc2020/10039`).
- WWDC22 — "Efficiency awaits: Background tasks in SwiftUI" / document migration notes (cross-check the
  `migrationPlan:` arm if seen), via Sosumi.

## Practice corpus (swiftui-ctx)

- `swiftui-ctx lookup DocumentGroup --json` — consensus call shape + `recommended` permalink + `co_occurs_with`.
- `swiftui-ctx lookup UTType --json` / `swiftui-ctx examples UTType` — real custom-type call sites.
- `swiftui-ctx lookup FocusedDocument --json` — returns `not_found` (corroborates the doc-01 hallucination).
- `swiftui-ctx file <recommended.id> --smart` — fetch the full enclosing view for the ✅ in `## Source`.

---

## Sources

This file is a routing index; every path above resolves to an Apple primary doc fetched via Sosumi (access
2026-06-07). No private or non-Apple URLs.
