# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
state-restoration claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the
curl/CLI commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`;
this file is the domain-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The practice corpus is the swiftui-ctx CLI
(`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Absence from the SwiftUI index = treat as hallucinated until proven (sr-01).
2. **JSON 404s on this domain.** The raw `…/tutorials/data/documentation/swiftui/<symbol>.json` `introducedAt`
   array **404s** on the parenthesized-symbol families here (`onOpenURL(perform:)`, `focusedSceneValue(_:_:)`,
   `restorationBehavior(_:)`) — **use Sosumi only**; it never 404s on a valid human URL. Never `WebFetch`
   `developer.apple.com`; never paper a 404 with a memory guess.
3. **Practice cross-check.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` returns
   `introduced_macos`, the `consensus` key shapes, and a `recommended` real call site — cross-check its
   floor against Sosumi and `floors-master.md`.

---

## A. SwiftUI state-restoration symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Sosumi path | Floor (verify) |
|---|---|---|
| `AppStorage` | `/documentation/swiftui/appstorage` | macOS 11.0 |
| `SceneStorage` | `/documentation/swiftui/scenestorage` | macOS 11.0 |
| `NavigationPath` / `.codable` | `/documentation/swiftui/navigationpath` | macOS 13.0 |
| `onOpenURL(perform:)` | `/documentation/swiftui/view/onopenurl(perform:)` | macOS 11.0 |
| `onContinueUserActivity(_:perform:)` | `/documentation/swiftui/view/oncontinueuseractivity(_:perform:)` | macOS 11.0 |
| `handlesExternalEvents(matching:)` | `/documentation/swiftui/scene/handlesexternalevents(matching:)` | macOS 11.0 (Mac, iOS, visionOS; no tvOS/watchOS) |
| `restorationBehavior(_:)` | `/documentation/swiftui/scene/restorationbehavior(_:)` | macOS 15.0 |
| `focusedSceneValue(_:_:)` key-path | `/documentation/swiftui/view/focusedscenevalue(_:_:)` | macOS 12.0 |
| `focusedSceneValue(_:)` object | `/documentation/swiftui/view/focusedscenevalue(_:)` | macOS 14.0 |

## B. UIKit (confirms the sr-01 hallucinations are out-of-framework)

- `restorationIdentifier` / `UIStateRestoring` / restoration class:
  `/documentation/uikit/restoring-your-app-s-state` — UIKit only, absent from SwiftUI.

## C. Practitioner (high-trust, corroborating)

- Majid Jabrayilov — "State restoration in SwiftUI" (`@SceneStorage` for per-scene UI; `@AppStorage` for
  app-wide): `https://swiftwithmajid.com/2020/08/26/state-restoration-in-swiftui/` (accessed 2026-06-07).
- Apple WWDC — "Bring multiple windows to your SwiftUI app" / scene restoration sessions (scene-state
  restoration model) — confirm specifics against Sosumi before quoting.

## Sources

- Apple Developer Documentation (SwiftUI + UIKit), fetched via `https://sosumi.ai/...` per the shared
  Sosumi protocol, accessed 2026-06-07.
- Majid Jabrayilov — "State restoration in SwiftUI":
  `https://swiftwithmajid.com/2020/08/26/state-restoration-in-swiftui/` (accessed 2026-06-07, high trust).
- swiftui-ctx practice corpus — `lookup {AppStorage,SceneStorage,NavigationPath,onOpenURL}` run 2026-06-07.
