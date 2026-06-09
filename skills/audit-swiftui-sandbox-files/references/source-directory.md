# Reference — Apple/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
sandbox/files claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this
file is the sandbox/files-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the practice corpus (consensus shape +
permalinked example) is reached with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json`
per `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch `https://sosumi.ai/documentation/<framework>/<symbol-path>`
   and read the `**Available on:** … macOS N+ …` line. A `swiftui-ctx lookup` **exit 3** corroborates a
   platform-wrong finding (no shipping Mac app uses the symbol).
2. **Need the precise per-platform array?** The raw `…/tutorials/data/documentation/<symbol>.json`
   `introducedAt` works when it resolves; it **404s** on parenthesized-symbol families — fall back to
   Sosumi. Never `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess.
3. **Entitlement keys + Hardened-Runtime `cs.*`** bodies render via JavaScript and were not
   verbatim-captured — confirm the exact key string against the Xcode 26 SDK before asserting it.

---

## A. SwiftUI / Foundation file-access symbol map

Human doc path = `developer.apple.com/documentation/<framework>/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Framework path | macOS floor (floors-master) |
|---|---|---|
| `fileImporter(...)` | `swiftui/view/fileimporter` | 11.0+ |
| `fileExporter(...)` | `swiftui/view/fileexporter` | 11.0+ |
| `bookmarkData(options:...)` / `.withSecurityScope` | `foundation/url/bookmarkcreationoptions/withsecurityscope` | n/a (option) |
| `URL(resolvingBookmarkData:...)` | `foundation/url/init(resolvingbookmarkdata:options:relativeto:bookmarkdataisstale:)` | n/a |
| `startAccessingSecurityScopedResource()` | `foundation/url/startaccessingsecurityscopedresource()` | 10.10+ |
| `Transferable` | `coretransferable/transferable` | 13.0+ |
| `.draggable(_:)` | `swiftui/view/draggable(_:)` | 13.0+ |
| `.dropDestination(for:action:isTargeted:)` (3-arg, **deprecated 26.5**) | `swiftui/view/dropdestination(for:action:istargeted:)` | 13.0+ (dep 26.5) |
| `.dropDestination(for:isEnabled:action:)` (successor; action: `([T], DropSession) -> Void`) | `swiftui/view/dropdestination(for:isenabled:action:)` | 26.0+ |
| `NSOpenPanel` / `NSSavePanel` | `appkit/nsopenpanel` · `appkit/nssavepanel` | (AppKit Mac-only) |
| `NSPasteboard` | `appkit/nspasteboard` | (AppKit Mac-only) |

**Platform-wrong / stale (never emit on a Mac path):** `UIPasteboard` (iOS-only — use `NSPasteboard`);
`dropDestination(for:action:isTargeted:)` as the *current* API (deprecated 26.5). See
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`.

## B. Entitlement / Hardened-Runtime key map

Human doc path = `developer.apple.com/documentation/bundleresources/entitlements/<key>` (fetch via Sosumi).

| Key | Path | Note |
|---|---|---|
| `com.apple.security.app-sandbox` | `com.apple.security.app-sandbox` | required for App Store; macOS 10.7+ |
| `com.apple.security.files.user-selected.read-write` | `com.apple.security.files.user-selected.read-write` | panel-derived URL read/write |
| `com.apple.security.files.user-selected.read-only` | `com.apple.security.files.user-selected.read-only` | read-only variant |
| `com.apple.security.network.client` | `com.apple.security.network.client` | outbound `URLSession` |
| `com.apple.security.files.bookmarks.app-scope` | `com.apple.security.files.bookmarks.app-scope` | app-scoped bookmarks |
| `com.apple.security.cs.*` (Hardened Runtime) | `documentation/security/hardened-runtime` | **bodies not verbatim-captured — verify-SDK** |

## C. Apple conceptual pages

| Page | Path | Anchors |
|---|---|---|
| Accessing files from the macOS App Sandbox | `documentation/security/accessing-files-from-the-macos-app-sandbox` | open/save panel + security-scoped bookmark round-trip; container + user-selected reach |
| App Sandbox overview | `documentation/security/app-sandbox` | sandbox as a per-entitlement opt-in capability |
| Hardened Runtime | `documentation/security/hardened-runtime` | tightened defaults + `cs.*` exceptions (Developer-ID) |

## D. Practitioners (corroboration only — never primary; label `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Hacking with Swift | `hackingwithswift.com/example-code/system/how-to-use-security-scoped-bookmarks-to-access-the-file-system` | the `bookmarkData(options:.withSecurityScope)` ↔ `start/stopAccessing…` round-trip + stale re-create | high |
| r/swift (lived) | `reddit.com/r/swift/comments/1dk8ces/strict_concurrency_swift_6_causes/` | the Swift-6 `loadTransferable` `PhotosPickerItem` race + the `@Observable`-model fix (concurrency-safety owns) | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- The practice corpus contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07); floors cross-checked
  against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.
- Practitioner URLs as listed (trust labelled; corroboration only).
