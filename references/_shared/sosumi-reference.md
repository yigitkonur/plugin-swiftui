# Shared Reference — Apple-Docs Fetch Protocol (Sosumi)

How every skill in this toolkit reads Apple documentation reliably. `developer.apple.com` pages are
**JavaScript-rendered**: a plain page fetch returns the **title only**, and a model then
**confabulates** the body — every availability floor, deprecation, and signature "read" that way is a
guess. Use **Sosumi** for every Apple-doc read. This is the universal verify path named by all 28
audit skills' "verify a &lt;100%-confidence finding" step and by build-time research. Do not restate
this protocol inside a skill's own `references/`.

**As of:** 2026-06-07.

**Helper:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sosumi.sh <symbol | doc-path | apple-url>` wraps the fetch
below (symbol→path normalization, the macOS-floor line, error/exit codes) — the spec-layer counterpart to
`scripts/swiftui-ctx`. e.g. `sosumi.sh MenuBarExtra` → the doc + `**Available on:** macOS 13.0+`.

---

## 1. The fetch commands

Sosumi renders any Apple Developer page (`/documentation/...` and `/videos/play/wwdc.../...`) to clean
Markdown — including the `**Available on:** … macOS N+ …` line, the declaration, overview, and code
samples.

```bash
# Preferred — hosted, cached, no install, block-resistant.
# Replace developer.apple.com with sosumi.ai:
curl -sSL https://sosumi.ai/documentation/swiftui/view/glasseffect(_:in:)
curl -sSL https://sosumi.ai/documentation/appkit/nsanimationcontext/animate(_:changes:completion:)

# CLI (downloads on first run; accepts a full URL OR a path; --json for structured output):
npx -y @nshipster/sosumi fetch https://developer.apple.com/documentation/swift/array
npx -y @nshipster/sosumi fetch /videos/play/wwdc2025/323
npx -y @nshipster/sosumi search "SwiftData inheritance"
```

---

## 2. Apple-source URL-pattern map

| Need | URL shape | Notes |
|---|---|---|
| A symbol's human doc + availability prose | `https://sosumi.ai/documentation/<framework>/<symbol>` | Lowercase the symbol path; parenthesized labels kept (e.g. `view/glasseffect(_:in:)`). |
| The precise per-platform availability array | `…/tutorials/data/documentation/<symbol>.json` | Fastest for the raw `introducedAt`/`deprecated` array **when it resolves** — see the 404 caveat below. |
| A WWDC session's content | `https://sosumi.ai/videos/play/wwdc<YYYY>/<id>` | Use for provenance (e.g. spring-preset floor truth). |
| Bridged-namespace symbol | the *bridged* path, not the obvious one | `String(localized:)` lives under `/swift/`, not `/foundation/`. |

---

## 3. The JSON-endpoint 404 caveat

The raw `*.json` availability endpoint is fine when it resolves and you need the exact per-platform
array — but it **404s** on:

- parenthesized-symbol families (`task(...)`, `init(text:selection:)`),
- bridged namespaces (`String(localized:)` under `/swift/`, not `/foundation/`),
- and assorted paths (notably the state-restoration & document-model parenthesized symbols).

**When the JSON 404s or you need prose, fall back to Sosumi** — it never 404s on a valid human URL.
Never trust `WebFetch` on `developer.apple.com`, and never paper a JSON 404 with a memory guess.

---

## 4. The DocC type-property floor-inheritance quirk

A `static var` / type-property's rendered floor can **inherit its enclosing type's floor**. Example:
spring presets (`Animation.bouncy` / `.smooth` / `.snappy`) render `macOS 10.15` because they inherit
`Animation`'s floor, but they are really **macOS 14** (WWDC23 provenance). For any type-property,
**cross-check the rendered "Available on" line against WWDC provenance** (also fetchable via Sosumi)
before trusting the floor. A gating audit that trusts the raw JSON for such symbols will set a floor
too low and ship a build break.

---

## 5. Rules

1. To learn an API's macOS floor, deprecation, signature, or a WWDC session's content → **Sosumi**.
   Never `WebFetch` on `developer.apple.com`.
2. The raw `*.json` endpoint is acceptable when it resolves and you need the exact per-platform array;
   on a 404 or for prose, fall back to Sosumi.
3. Cross-check **type-property** floors against WWDC provenance (the inheritance quirk, §4).
4. **Be polite / cache.** Prefer the hosted `sosumi.ai` (cached) for bulk; do not run tight loops
   against Apple or the proxy.
5. Every API/availability/deprecation claim a skill emits cites its Apple source + access date, or is
   flagged `verify against Xcode 26 SDK`. No confabulation.

> **Optional runtime enhancement:** a Sosumi MCP server (`sosumi serve` / its WebMCP surface) can be
> registered in the plugin's `.mcp.json` so a skill's verify step calls it at runtime instead of
> shelling `curl`. This is an enhancement, not a requirement — the `curl https://sosumi.ai/<path>`
> path works without it. Confirm the server's exact invocation via Sosumi's own docs before wiring.

---

## Sources

- Sosumi: `https://sosumi.ai/` and the `@nshipster/sosumi` CLI.
- `developer.apple.com` (the rendered source Sosumi converts) and `swift.org`.
