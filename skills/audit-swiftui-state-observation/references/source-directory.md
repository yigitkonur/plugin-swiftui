# Reference — Apple/WWDC/Practitioner + swiftui-ctx Source Map (the VERIFY map)

The navigable source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence state/observation
claim. **Two sources, both run:** **swiftui-ctx** for the PRACTICE half (the canonical shape + a permalinked
real example) and **Sosumi** for the SPEC half (the macOS floor + signature). The CLI contract is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`; the Apple-doc fetch protocol (curl/CLI
commands + JSON-404 caveat) is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`. Floor values
are `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (read, never restate).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocols in the two shared refs)

1. **Practice — how do shipping Mac apps write this?** Run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` → read `consensus` (the canonical
   shape), `recommended` (`{id, permalink}` — the FIX ✅), `introduced_macos`, `deprecated`,
   `co_occurs_with`. Drill in with `file <recommended.id> --smart` for the real enclosing view. For a
   "is it deprecated" doubt run `deprecated <api>`; a `lookup` **exit 3** corroborates a hallucination.
2. **Spec — does it exist + macOS floor?** Fetch `https://sosumi.ai/documentation/<framework>/<symbol-path>`
   and read the `**Available on:** … macOS N+ …` line. Cross-check the floor against `floors-master.md`.
3. Never `WebFetch` `developer.apple.com`; never paper a JSON-404 with a memory guess.

> **No state/observation symbol is hallucinated.** The defects are wrong-wrapper/wrong-world pairings of
> **real** symbols — so VERIFY here is mostly *floor* + *deprecation* + *the canonical shape*, rarely
> existence. (Contrast `audit-swiftui-liquid-glass`, the high-hallucination domain.)

---

## A. swiftui-ctx practice entry points (run these for the ✅)

| Need | Command |
|---|---|
| The own-with-`@State` modern pattern | `swiftui-ctx recipe observable-model` |
| `@Observable` consensus + recommended example | `swiftui-ctx lookup Observable --json` → `ex_44cfa1bff8` (`Gremble-io/Detto`, `@Observable @MainActor`) |
| `@State` consensus | `swiftui-ctx lookup State --json` (`introduced_macos 10.15`; 1608 repos) |
| `@Bindable` consensus | `swiftui-ctx lookup Bindable --json` → `ex_ff2273b082` (`sindresorhus/Gifski`, `@Bindable var appState = appState`) |
| `@StateObject` not-deprecated proof | `swiftui-ctx deprecated StateObject` → `deprecated:false` |
| `@Environment`/`@ObservationIgnored` real sites | `swiftui-ctx lookup Environment --json` · `swiftui-ctx lookup ObservationIgnored --json` |
| The real enclosing view of any example | `swiftui-ctx file <id|permalink> --smart` |

## B. SwiftUI symbol map (Sosumi spec — human path = `developer.apple.com/documentation/<...>`, fetch via `sosumi.ai/...`)

| Symbol | Path | macOS floor |
|---|---|---|
| `@Observable` macro | `observation/observable()` | 14.0+ |
| `@ObservationIgnored` macro | `observation/observationignored()` | 14.0+ |
| `Observations` (async sequence) | `observation/observations` | **26.0+** |
| `@State` | `swiftui/state` | 10.15+ |
| `@Binding` | `swiftui/binding` | 10.15+ |
| `@Bindable` | `swiftui/bindable` | 14.0+ |
| `@StateObject` | `swiftui/stateobject` | 11.0+ (not deprecated) |
| `@ObservedObject` | `swiftui/observedobject` | 10.15+ (not deprecated) |
| `@EnvironmentObject` | `swiftui/environmentobject` | 10.15+ (legacy) |
| `@Environment(\.keyPath)` / `.environment(\.keyPath, _:)` | `swiftui/environment` | 10.15+ |
| `@Environment(_ objectType: T.Type)` / `.environment(_:)` | `swiftui/environment/init(_:)-8slkf` | 14.0+ |
| Migration guide | `swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro` | — |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<YYYY>/<id>`, via Sosumi)

| id | Title | Covers |
|---|---|---|
| wwdc2023/10149 | Discover Observation in SwiftUI | the `@Observable` macro; `@State`/`@Bindable`/`@Environment`; field-granular invalidation |
| wwdc2024/10150 | (Observation follow-ups) | migration nuances; `@Observable` essentials |

## D. Practitioners (corroboration only — never primary; label `confidence:` accordingly)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Jesse Squires | `jessesquires.com/blog/2024/09/09/swift-observable-macro/` | `@Observable` is NOT a drop-in; `@StateObject`+OO vs `@State`+`@Observable` | high |
| Donny Wals | `donnywals.com/whats-the-difference-between-binding-and-bindable/` | `@Binding` vs `@Bindable`; `$obj` errors without `@Bindable` | high |
| Paul Hudson | `hackingwithswift.com/articles/281/what-to-fix-in-ai-generated-swift-code` | AI defaults to `ObservableObject`; computed-view perf | high |

---

## Sources

- swiftui-ctx CLI contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` (the
  bundled corpus — 1,857 macOS repos · macOS 26.5 SDK). Every `lookup` result carries a Sosumi `doc:` link.
- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
